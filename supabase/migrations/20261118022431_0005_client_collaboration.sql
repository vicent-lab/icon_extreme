-- Phase: client collaboration — notifications, project chat, approvals/change requests, payment schedule.
-- Rules: RLS on, explicit grants, decisions are permanent, chat is never deleted.

-- may this person take part in this project's conversation / approvals?
create function private.in_project(pid bigint) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.is_ops() or private.is_project_client(pid)
$$;

-- ───────── notifications (the bell) ─────────
create table public.notifications (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null,
  title text not null,
  body text,
  link text,                                     -- where tapping it takes you, e.g. /portal/project/3
  project_id bigint references public.projects(id) on delete cascade,
  created_at timestamptz not null default now(),
  read_at timestamptz);
create index notifications_user_unread on public.notifications (user_id, created_at desc);
alter table public.notifications enable row level security;
grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;   -- people can only mark as read
grant select, insert, update, delete on public.notifications to service_role;
create policy "own notifications" on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));
create policy "mark own read" on public.notifications for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- one helper every trigger uses; skips the person who caused the event and inactive accounts
create function private.notify(targets uuid[], actor uuid, kind text, title text, body text, link_staff text, link_client text, pid bigint)
returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notifications (user_id, kind, title, body, link, project_id)
  select pr.id, kind, title, left(body, 240),
         case when pr.role = 'client' then link_client else link_staff end, pid
    from public.profiles pr
   where pr.id = any(targets) and pr.is_active and pr.id is distinct from actor;
end $$;

create function private.project_title(pid bigint) returns text
language sql stable security definer set search_path = '' as $$ select title from public.projects where id = pid $$;

create function private.client_of(pid bigint) returns uuid[]
language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(client_id), '{}') from public.projects where id = pid and client_id is not null $$;

create function private.team_of(pid bigint) returns uuid[]
language sql stable security definer set search_path = '' as $$
  -- the project manager; when there is none, the admins
  select coalesce((select array[project_manager] from public.projects where id = pid and project_manager is not null),
                  (select array_agg(id) from public.profiles where is_active and role in ('super_admin','admin')), '{}') $$;

-- ───────── project chat ─────────
create table public.project_messages (
  id bigint generated always as identity primary key,
  project_id bigint not null references public.projects(id) on delete cascade,
  author_id uuid not null default auth.uid() references public.profiles(id),
  body text not null default '' check (length(body) <= 4000),
  photo_path text,
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  check (length(trim(body)) > 0 or photo_path is not null));
create index project_messages_project on public.project_messages (project_id, created_at);
alter table public.project_messages enable row level security;
grant select, insert on public.project_messages to authenticated;
grant update (body) on public.project_messages to authenticated;   -- fix a typo; never delete
grant select, insert, update, delete on public.project_messages to service_role;
create policy "project people read chat" on public.project_messages for select to authenticated
  using (private.in_project(project_id));
create policy "project people write chat" on public.project_messages for insert to authenticated
  with check (author_id = (select auth.uid()) and private.in_project(project_id)
              and (photo_path is null or photo_path like project_id::text || '/%'));
create policy "fix own message for 5 minutes" on public.project_messages for update to authenticated
  using (author_id = (select auth.uid()) and created_at > now() - interval '5 minutes')
  with check (author_id = (select auth.uid()));

create function private.message_edited() returns trigger language plpgsql set search_path = '' as $$
begin new.edited_at := now(); return new; end $$;
create trigger mark_message_edited before update on public.project_messages
  for each row when (old.body is distinct from new.body) execute function private.message_edited();

-- "seen": the last time each person opened the conversation
create table public.message_reads (
  project_id bigint not null references public.projects(id) on delete cascade,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  last_read_at timestamptz not null default now(),
  primary key (project_id, user_id));
alter table public.message_reads enable row level security;
grant select, insert, update on public.message_reads to authenticated;
grant select, insert, update, delete on public.message_reads to service_role;
create policy "project people see reads" on public.message_reads for select to authenticated
  using (private.in_project(project_id));
create policy "mark own read insert" on public.message_reads for insert to authenticated
  with check (user_id = (select auth.uid()) and private.in_project(project_id));
create policy "mark own read update" on public.message_reads for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create function private.notify_message() returns trigger language plpgsql security definer set search_path = '' as $$
declare is_client boolean := exists (select 1 from public.projects where id = new.project_id and client_id = new.author_id);
        who text := (select coalesce(nullif(full_name,''), 'Someone') from public.profiles where id = new.author_id);
begin
  perform private.notify(
    case when is_client then private.team_of(new.project_id) else private.client_of(new.project_id) end,
    new.author_id, 'message', who || ' · ' || private.project_title(new.project_id),
    case when new.photo_path is not null and length(trim(new.body)) = 0 then 'Sent a photo' else new.body end,
    '/projects/' || new.project_id || '?tab=messages', '/portal/project/' || new.project_id || '?tab=messages', new.project_id);
  return new;
end $$;
create trigger notify_on_message after insert on public.project_messages
  for each row execute function private.notify_message();

-- chat photos: private bucket, files under "<project id>/..."
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('project-chat', 'project-chat', false, 10485760, array['image/jpeg','image/png','image/webp']);
create policy "project people read chat photos" on storage.objects for select to authenticated
  using (bucket_id = 'project-chat' and (storage.foldername(name))[1] ~ '^[0-9]+$'
         and private.in_project(((storage.foldername(name))[1])::bigint));
create policy "project people upload chat photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'project-chat' and (storage.foldername(name))[1] ~ '^[0-9]+$'
              and private.in_project(((storage.foldername(name))[1])::bigint));

-- ───────── approvals ("waiting on you") and change requests ─────────
-- kind 'decision': the team asks the client to approve something.
-- kind 'change'  : the client asks for a change; the team adds cost/time, then the client approves it.
create table public.project_requests (
  id bigint generated always as identity primary key,
  project_id bigint not null references public.projects(id) on delete cascade,
  kind text not null check (kind in ('decision','change')),
  title text not null check (length(trim(title)) > 0),
  details text,
  cost_impact_ugx numeric(15,2),
  days_impact integer,
  status text not null default 'awaiting_client'
    check (status in ('awaiting_team','awaiting_client','approved','rejected','withdrawn')),
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  decided_by uuid references public.profiles(id),
  decided_at timestamptz,
  decision_note text);
create index project_requests_project on public.project_requests (project_id, status);
alter table public.project_requests enable row level security;
grant select on public.project_requests to authenticated;
grant insert (project_id, kind, title, details, cost_impact_ugx, days_impact, status) on public.project_requests to authenticated;
grant update (title, details, cost_impact_ugx, days_impact, status) on public.project_requests to authenticated;
grant select, insert, update, delete on public.project_requests to service_role;
create policy "project people read requests" on public.project_requests for select to authenticated
  using (private.in_project(project_id));
create policy "team raises requests" on public.project_requests for insert to authenticated
  with check (private.is_ops() and created_by = (select auth.uid()) and status in ('awaiting_client','awaiting_team'));
create policy "team edits open requests" on public.project_requests for update to authenticated
  using (private.is_ops() and status in ('awaiting_team','awaiting_client'))
  with check (private.is_ops() and status in ('awaiting_team','awaiting_client','withdrawn'));

-- Decisions are permanent: nobody (not even an admin through the app) can change a decided request.
create function private.guard_request() returns trigger language plpgsql set search_path = '' as $$
begin
  if old.status in ('approved','rejected','withdrawn') then raise exception 'this request is already closed and cannot change'; end if;
  new.updated_at := now();
  return new;
end $$;
create trigger guard_request before update on public.project_requests for each row execute function private.guard_request();

-- the client answers here (and only here), so who/when is always recorded by the database itself
create function public.decide_request(request_id bigint, approve boolean, note text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare r public.project_requests;
begin
  select * into r from public.project_requests where id = request_id;
  if r.id is null or not private.is_project_client(r.project_id) then raise exception 'not allowed'; end if;
  if r.status <> 'awaiting_client' then raise exception 'this request is not waiting for you'; end if;
  update public.project_requests
     set status = case when approve then 'approved' else 'rejected' end,
         decided_by = (select auth.uid()), decided_at = now(), decision_note = left(note, 2000)
   where id = request_id;
end $$;
revoke execute on function public.decide_request(bigint, boolean, text) from public, anon;
grant execute on function public.decide_request(bigint, boolean, text) to authenticated;

-- the client asks for a change here
create function public.request_change(pid bigint, title text, details text default null)
returns bigint language plpgsql security definer set search_path = '' as $$
declare new_id bigint;
begin
  if not private.is_project_client(pid) then raise exception 'not allowed'; end if;
  if length(trim(coalesce(title,''))) = 0 then raise exception 'please describe the change'; end if;
  insert into public.project_requests (project_id, kind, title, details, status, created_by)
  values (pid, 'change', left(trim(title), 200), left(details, 4000), 'awaiting_team', (select auth.uid()))
  returning id into new_id;
  return new_id;
end $$;
revoke execute on function public.request_change(bigint, text, text) from public, anon;
grant execute on function public.request_change(bigint, text, text) to authenticated;

create function private.notify_request() returns trigger language plpgsql security definer set search_path = '' as $$
declare pt text := private.project_title(new.project_id);
        ls text := '/projects/' || new.project_id || '?tab=approvals';
        lc text := '/portal/project/' || new.project_id || '?tab=approvals';
        actor uuid := (select auth.uid());
begin
  if new.status = 'awaiting_client' and (tg_op = 'INSERT' or old.status is distinct from 'awaiting_client') then
    perform private.notify(private.client_of(new.project_id), actor, 'approval', 'Waiting for your approval · ' || pt, new.title, ls, lc, new.project_id);
  elsif new.status = 'awaiting_team' and tg_op = 'INSERT' then
    perform private.notify(private.team_of(new.project_id), actor, 'change', 'Change requested · ' || pt, new.title, ls, lc, new.project_id);
  elsif tg_op = 'UPDATE' and new.status in ('approved','rejected') and old.status = 'awaiting_client' then
    perform private.notify(private.team_of(new.project_id) || array[new.created_by], actor, 'decision',
      (case when new.status = 'approved' then 'Approved · ' else 'Not approved · ' end) || pt,
      new.title || coalesce(' — ' || new.decision_note, ''), ls, lc, new.project_id);
  end if;
  return new;
end $$;
create trigger notify_on_request after insert or update on public.project_requests
  for each row execute function private.notify_request();
create trigger audit_project_requests after insert or update or delete on public.project_requests
  for each row execute function private.audit();

-- ───────── payment schedule (what the client owes and has paid; not internal costs) ─────────
create table public.project_payments (
  id bigint generated always as identity primary key,
  project_id bigint not null references public.projects(id) on delete cascade,
  label text not null check (length(trim(label)) > 0),     -- e.g. "Deposit", "After roofing"
  amount_ugx numeric(15,2) not null check (amount_ugx >= 0),
  due_date date,
  paid_on date,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now());
create index project_payments_project on public.project_payments (project_id, sort_order);
alter table public.project_payments enable row level security;
grant select, insert, update, delete on public.project_payments to authenticated, service_role;
create policy "project people read payments" on public.project_payments for select to authenticated
  using (private.in_project(project_id));
create policy "ops add payments" on public.project_payments for insert to authenticated with check (private.is_ops());
create policy "ops edit payments" on public.project_payments for update to authenticated using (private.is_ops()) with check (private.is_ops());
create policy "admins delete payments" on public.project_payments for delete to authenticated
  using (private.has_role(array['super_admin','admin']::public.app_role[]));
create trigger touch_project_payments before update on public.project_payments for each row execute function private.touch_updated_at();
create trigger audit_project_payments after insert or update or delete on public.project_payments
  for each row execute function private.audit();

-- ───────── notifications for things that already exist ─────────
-- (one function per table: a trigger body may only name columns its own table has)
create function private.notify_site_log() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.client_visible and (tg_op = 'INSERT' or not old.client_visible) then
    perform private.notify(private.client_of(new.project_id), (select auth.uid()), 'update',
      'New site update · ' || private.project_title(new.project_id), new.work_done,
      '/projects/' || new.project_id, '/portal/project/' || new.project_id || '?tab=updates', new.project_id);
  end if;
  return new;
end $$;
create function private.notify_document() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.client_visible and (tg_op = 'INSERT' or not old.client_visible) then
    perform private.notify(private.client_of(new.project_id), (select auth.uid()), 'document',
      'Document shared · ' || private.project_title(new.project_id), new.title,
      '/projects/' || new.project_id, '/portal/project/' || new.project_id || '?tab=documents', new.project_id);
  end if;
  return new;
end $$;
create function private.notify_phase() returns trigger language plpgsql security definer set search_path = '' as $$
declare pt text := private.project_title(new.project_id);
begin
  if tg_op = 'UPDATE' and old.status is not distinct from new.status then return new; end if;
  if new.status in ('in_progress','done') then
    perform private.notify(private.client_of(new.project_id), (select auth.uid()), 'phase',
      (case when new.status = 'done' then 'Phase finished · ' else 'Phase started · ' end) || pt, new.name,
      '/projects/' || new.project_id, '/portal/project/' || new.project_id || '?tab=schedule', new.project_id);
  elsif new.status = 'delayed' then
    perform private.notify(private.team_of(new.project_id), (select auth.uid()), 'delay', 'Phase delayed · ' || pt, new.name,
      '/projects/' || new.project_id || '?tab=schedule', '/portal/project/' || new.project_id, new.project_id);
  end if;
  return new;
end $$;
create trigger notify_on_site_log after insert or update on public.site_logs for each row execute function private.notify_site_log();
create trigger notify_on_document after insert or update on public.project_documents for each row execute function private.notify_document();
create trigger notify_on_phase after insert or update on public.project_phases for each row execute function private.notify_phase();

create function private.notify_lead() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform private.notify(
    (select coalesce(array_agg(id), '{}') from public.profiles where is_active and role in ('super_admin','admin','support')),
    null, 'lead', 'New ' || case when new.kind = 'quote' then 'quote request' else 'message' end || ' · ' || new.full_name,
    new.message, '/leads', '/portal', null);
  return new;
end $$;
create trigger notify_on_lead after insert on public.leads for each row execute function private.notify_lead();

-- live updates for the bell and the chat
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.notifications, public.project_messages;
  end if;
end $$;
