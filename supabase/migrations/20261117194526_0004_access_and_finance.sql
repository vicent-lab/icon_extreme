-- Phase 1 — access model + keep money out of public view.
--   1. New accounts start PENDING (inactive) until an admin approves or invites them.
--   2. profiles remember email and approval time, so admins can tell people apart.
--   3. Clients may read their project only while their account is active.
--   4. Budget moves to its own ops-only table (anon and clients used to be able to read it).
--   5. Anon can read only the public columns of projects.

-- 1 + 2 ---------------------------------------------------------------------------------
alter table public.profiles add column email text, add column approved_at timestamptz;
update public.profiles p set email = u.email from auth.users u where u.id = p.id;
update public.profiles set approved_at = created_at where is_active;       -- everyone active today was accepted
alter table public.profiles alter column is_active set default false;      -- strangers wait for approval

create or replace function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name, email, is_active)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), new.email, false);
  return new;
end $$;

create function private.sync_profile_email() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.profiles set email = new.email where id = new.id;
  return new;
end $$;
create trigger on_auth_user_email_changed after update of email on auth.users
  for each row when (old.email is distinct from new.email) execute function private.sync_profile_email();

create or replace function public.set_user_role(target uuid, new_role public.app_role, active boolean default true)
returns void language plpgsql security definer set search_path = '' as $$
declare caller public.app_role := private.current_role();
begin
  -- caller is NULL for pending/suspended accounts; a bare NOT IN would let NULL through
  if caller is null or caller not in ('super_admin','admin') then raise exception 'not allowed'; end if;
  if target = (select auth.uid()) then raise exception 'you cannot change your own role'; end if;
  if new_role in ('super_admin','admin') and caller <> 'super_admin'
     then raise exception 'only a super admin can grant admin roles'; end if;
  if (select role from public.profiles where id = target) in ('super_admin','admin')
     and caller <> 'super_admin' then raise exception 'only a super admin can change an admin'; end if;
  update public.profiles
     set role = new_role,
         is_active = active,
         approved_at = case when active then coalesce(approved_at, now()) else approved_at end
   where id = target;
end $$;

-- 3 -------------------------------------------------------------------------------------
create or replace function private.is_project_client(pid bigint) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.current_role() is not null
     and exists (select 1 from public.projects p where p.id = pid and p.client_id = (select auth.uid()))
$$;

drop policy "public reads projects" on public.projects;
create policy "public reads projects" on public.projects for select to anon, authenticated
  using (is_published or private.is_staff() or (client_id = (select auth.uid()) and private.current_role() is not null));
drop policy "public reads images" on public.project_images;
create policy "public reads images" on public.project_images for select to anon, authenticated
  using (private.is_staff() or exists (select 1 from public.projects p where p.id = project_id
         and (p.is_published or (p.client_id = (select auth.uid()) and private.current_role() is not null))));

-- 4 -------------------------------------------------------------------------------------
create table public.project_finance (
  project_id bigint primary key references public.projects(id) on delete cascade,
  budget_ugx numeric(15,2) not null check (budget_ugx >= 0),
  updated_at timestamptz not null default now());
insert into public.project_finance (project_id, budget_ugx)
  select id, budget_ugx from public.projects where budget_ugx is not null;
alter table public.projects drop column budget_ugx;

alter table public.project_finance enable row level security;
grant select, insert, update, delete on public.project_finance to authenticated, service_role;
create policy "ops read budget"  on public.project_finance for select to authenticated using (private.is_ops());
create policy "ops write budget" on public.project_finance for insert to authenticated with check (private.is_ops());
create policy "ops edit budget"  on public.project_finance for update to authenticated using (private.is_ops()) with check (private.is_ops());
create policy "admin delete budget" on public.project_finance for delete to authenticated
  using (private.has_role(array['super_admin','admin']::public.app_role[]));
create trigger touch_project_finance before update on public.project_finance
  for each row execute function private.touch_updated_at();
create trigger audit_project_finance after insert or update or delete on public.project_finance
  for each row execute function private.audit();

-- 5 -------------------------------------------------------------------------------------
revoke select on public.projects from anon;
grant select (id, title, slug, summary, description, location, project_type, status, start_date, end_date,
              progress_pct, challenge, solution, results, featured_image, is_featured, is_published,
              is_demo, display_order, created_at, updated_at)
  on public.projects to anon;
