-- ICON Construction — operations: schedule (phases), daily site logs, documents/plans, expenses,
-- manual leads, storage buckets. Same rules: RLS on, explicit grants, roles checked in the database.

-- helpers ---------------------------------------------------------------------------------
create function private.is_ops() returns boolean            -- people who run projects
language sql stable security definer set search_path = '' as $$
  select coalesce(private.current_role() in ('super_admin','admin','project_manager'), false)
$$;
create function private.is_project_client(pid bigint) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.projects p where p.id = pid and p.client_id = (select auth.uid()))
$$;
grant execute on function private.is_ops(), private.is_project_client(bigint) to authenticated, anon, service_role;

-- tables ----------------------------------------------------------------------------------
create table public.project_phases (
  id bigint generated always as identity primary key,
  project_id bigint not null references public.projects(id) on delete cascade,
  name text not null, description text,
  start_date date, end_date date,
  status text not null default 'planned' check (status in ('planned','in_progress','done','delayed')),
  progress_pct smallint not null default 0 check (progress_pct between 0 and 100),
  sort_order int not null default 0,
  assigned_to uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (start_date is null or end_date is null or end_date >= start_date));
create index project_phases_project on public.project_phases (project_id, sort_order, start_date);

create table public.site_logs (
  id bigint generated always as identity primary key,
  project_id bigint not null references public.projects(id) on delete cascade,
  log_date date not null default current_date,
  weather text, workers_on_site int check (workers_on_site >= 0),
  work_done text not null, issues text, safety_notes text,
  client_visible boolean not null default false,
  created_by uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now());
create index site_logs_project on public.site_logs (project_id, log_date desc);

create table public.project_documents (
  id bigint generated always as identity primary key,
  project_id bigint not null references public.projects(id) on delete cascade,
  title text not null,
  category text not null default 'other'
    check (category in ('plan','drawing','contract','permit','quotation','invoice','report','photo','other')),
  storage_path text not null unique, file_name text, size_bytes bigint,
  client_visible boolean not null default false,
  uploaded_by uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now());
create index project_documents_project on public.project_documents (project_id, created_at desc);

create table public.project_expenses (
  id bigint generated always as identity primary key,
  project_id bigint not null references public.projects(id) on delete cascade,
  spent_on date not null default current_date,
  category text not null default 'materials'
    check (category in ('materials','labour','equipment','transport','subcontractor','permits','other')),
  description text not null,
  amount_ugx numeric(15,2) not null check (amount_ugx >= 0),
  supplier text, paid boolean not null default false,
  created_by uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now());
create index project_expenses_project on public.project_expenses (project_id, spent_on desc);

do $$
declare t text;
begin
  foreach t in array array['project_phases','site_logs','project_documents','project_expenses'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('grant select, insert, update, delete on public.%I to service_role', t);
    execute format('create trigger audit_%1$s after insert or update or delete on public.%1$I for each row execute function private.audit()', t);
  end loop;
end $$;
create trigger touch_project_phases before update on public.project_phases
  for each row execute function private.touch_updated_at();

-- Staff who run projects: full access. Delete of expenses = admins only (money records).
create policy "ops read phases"  on public.project_phases for select to authenticated
  using (private.is_ops() or private.is_project_client(project_id));   -- clients see their own schedule
create policy "ops write phases" on public.project_phases for insert to authenticated with check (private.is_ops());
create policy "ops edit phases"  on public.project_phases for update to authenticated using (private.is_ops()) with check (private.is_ops());
create policy "ops delete phases" on public.project_phases for delete to authenticated using (private.is_ops());

create policy "ops read logs"  on public.site_logs for select to authenticated
  using (private.is_ops() or (client_visible and private.is_project_client(project_id)));
create policy "ops write logs" on public.site_logs for insert to authenticated with check (private.is_ops());
create policy "ops edit logs"  on public.site_logs for update to authenticated using (private.is_ops()) with check (private.is_ops());
create policy "ops delete logs" on public.site_logs for delete to authenticated using (private.is_ops());

create policy "ops read docs"  on public.project_documents for select to authenticated
  using (private.is_ops() or (client_visible and private.is_project_client(project_id)));
create policy "ops write docs" on public.project_documents for insert to authenticated with check (private.is_ops());
create policy "ops edit docs"  on public.project_documents for update to authenticated using (private.is_ops()) with check (private.is_ops());
create policy "ops delete docs" on public.project_documents for delete to authenticated using (private.is_ops());

create policy "ops read expenses"  on public.project_expenses for select to authenticated using (private.is_ops());  -- never clients
create policy "ops write expenses" on public.project_expenses for insert to authenticated with check (private.is_ops());
create policy "ops edit expenses"  on public.project_expenses for update to authenticated using (private.is_ops()) with check (private.is_ops());
create policy "admin delete expenses" on public.project_expenses for delete to authenticated
  using (private.has_role(array['super_admin','admin']::public.app_role[]));

-- Project progress = average of its phases (kept in sync automatically).
create function private.sync_project_progress() returns trigger
language plpgsql security definer set search_path = '' as $$
declare pid bigint := coalesce(new.project_id, old.project_id);
begin
  update public.projects p
     set progress_pct = coalesce((select round(avg(progress_pct))::smallint from public.project_phases where project_id = pid), p.progress_pct)
   where p.id = pid;
  return null;
end $$;
create trigger sync_progress after insert or update of progress_pct or delete on public.project_phases
  for each row execute function private.sync_project_progress();

-- Manual leads (phone calls, walk-ins). Website leads still only arrive through the Edge Function.
grant insert on public.leads to authenticated;
create policy "sales staff add manual leads" on public.leads for insert to authenticated
  with check (source = 'manual' and private.has_role(array['super_admin','admin','project_manager','support']::public.app_role[]));
create trigger audit_leads_insert after insert on public.leads for each row execute function private.audit();

-- Storage ---------------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
 ('project-documents','project-documents', false, 26214400, array[
   'application/pdf','image/jpeg','image/png','image/webp','application/zip',
   'application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document',
   'application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']),
 ('site-media','site-media', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

-- private plans/contracts: staff who run projects; clients only for files marked client_visible
create policy "ops read project files" on storage.objects for select to authenticated
  using (bucket_id = 'project-documents' and (private.is_ops() or exists (
    select 1 from public.project_documents d
    where d.storage_path = name and d.client_visible and private.is_project_client(d.project_id))));
create policy "ops upload project files" on storage.objects for insert to authenticated
  with check (bucket_id = 'project-documents' and private.is_ops());
create policy "ops update project files" on storage.objects for update to authenticated
  using (bucket_id = 'project-documents' and private.is_ops());
create policy "ops delete project files" on storage.objects for delete to authenticated
  using (bucket_id = 'project-documents' and private.is_ops());

-- public website images: anyone can VIEW by link (no listing policy), content staff can change
create policy "staff upload site media" on storage.objects for insert to authenticated
  with check (bucket_id = 'site-media' and private.has_role(array['super_admin','admin','project_manager','editor']::public.app_role[]));
create policy "staff update site media" on storage.objects for update to authenticated
  using (bucket_id = 'site-media' and private.has_role(array['super_admin','admin','project_manager','editor']::public.app_role[]));
create policy "staff delete site media" on storage.objects for delete to authenticated
  using (bucket_id = 'site-media' and private.has_role(array['super_admin','admin','project_manager','editor']::public.app_role[]));
