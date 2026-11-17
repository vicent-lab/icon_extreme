-- Access-rule tests. Every line states a rule and fails loudly if the database breaks it.
-- Roles: a super_admin · b admin · c project_manager · d support · e client (owns project 1)
--        f client (other) · g stranger who just signed up (pending approval)

\set A '''00000000-0000-0000-0000-00000000000a'''
\set B '''00000000-0000-0000-0000-00000000000b'''
\set C '''00000000-0000-0000-0000-00000000000c'''
\set D '''00000000-0000-0000-0000-00000000000d'''
\set E '''00000000-0000-0000-0000-00000000000e'''
\set F '''00000000-0000-0000-0000-00000000000f'''
\set G '''00000000-0000-0000-0000-000000000007'''

create schema t;
grant usage on schema t to public;

create function t.as_user(uid uuid, r text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(uid::text, ''), true);
  execute format('set local role %I', r);
end $$;
create function t.back() returns void language plpgsql as $$
begin execute 'reset role'; perform set_config('request.jwt.claim.sub', '', true); end $$;

create function t.rows(q text, n bigint, msg text) returns void language plpgsql as $$
declare got bigint;
begin
  execute format('select count(*) from (%s) x', q) into got;
  if got is distinct from n then raise exception 'FAIL: % (expected % rows, got %)', msg, n, got; end if;
  raise notice 'ok   %', msg;
end $$;

create function t.denied(q text, msg text) returns void language plpgsql as $$
declare refused boolean := false;
begin
  begin execute q; exception when others then refused := true; end;
  if not refused then raise exception 'FAIL: % (was allowed, should be refused)', msg; end if;
  raise notice 'ok   %', msg;
end $$;

create function t.allowed(q text, msg text) returns void language plpgsql as $$
begin
  begin execute q; exception when others then raise exception 'FAIL: % (refused: %)', msg, sqlerrm; end;
  raise notice 'ok   %', msg;
end $$;

create function t.changes(q text, n bigint, msg text) returns void language plpgsql as $$
declare got bigint;
begin
  execute q;
  get diagnostics got = row_count;
  if got <> n then raise exception 'FAIL: % (expected % rows changed, got %)', msg, n, got; end if;
  raise notice 'ok   %', msg;
end $$;

grant execute on all functions in schema t to public;

begin;

-- setup (as database owner) --------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  (:A, 'a@icon.test', '{"full_name":"Alice Admin"}'), (:B, 'b@icon.test', '{}'), (:C, 'c@icon.test', '{}'),
  (:D, 'd@icon.test', '{}'), (:E, 'e@icon.test', '{}'), (:F, 'f@icon.test', '{}'), (:G, 'g@icon.test', '{}');

select t.rows($q$select 1 from public.profiles where is_active$q$, 0, 'new sign-ups start inactive (pending approval)');
select t.rows($q$select 1 from public.profiles where id = '00000000-0000-0000-0000-00000000000a' and email = 'a@icon.test' and full_name = 'Alice Admin' and role = 'client'$q$, 1,
  'profile copies email and name, and the role is client');

update public.profiles set role = 'super_admin', is_active = true, approved_at = now() where id = :A;
update public.profiles set role = 'admin',       is_active = true, approved_at = now() where id = :B;
update public.profiles set role = 'project_manager', is_active = true, approved_at = now() where id = :C;
update public.profiles set role = 'support',     is_active = true, approved_at = now() where id = :D;
update public.profiles set is_active = true, approved_at = now() where id in (:E, :F);

insert into public.projects (id, title, slug, location, project_type, is_published, client_id) overriding system value values
  (1, 'Private job', 'private-job', 'Kampala', 'Residential', false, :E),
  (2, 'Pending job', 'pending-job', 'Entebbe', 'Commercial', false, :G),
  (3, 'Showcase',    'showcase',    'Jinja',   'Road',       true,  null);
insert into public.project_finance (project_id, budget_ugx) values (1, 90000000), (3, 50000000);
insert into public.project_phases (project_id, name, start_date, end_date, progress_pct) values
  (1, 'Foundation', '2026-12-01', '2026-12-20', 100), (1, 'Walls', '2026-12-21', '2027-01-30', 50);
insert into public.site_logs (project_id, work_done, client_visible) values (1, 'Poured slab', true), (1, 'Internal note', false);
insert into public.project_documents (project_id, title, storage_path, client_visible) values
  (1, 'Floor plan', '1/plan.pdf', true), (1, 'Contract', '1/contract.pdf', false);
insert into public.project_expenses (project_id, description, amount_ugx) values (1, 'Cement', 4500000);
insert into storage.objects (bucket_id, name) values ('project-documents', '1/plan.pdf'), ('project-documents', '1/contract.pdf');
insert into public.leads (kind, full_name, email, message) values ('contact', 'Visitor', 'v@x.com', 'a message from the website');

select t.rows($q$select 1 from public.projects where id = 1 and progress_pct = 75$q$, 1, 'project progress is the average of its phases (75)');

-- anonymous visitors ---------------------------------------------------------------------
select t.as_user(null, 'anon');
select t.rows('select id from public.projects', 1, 'anon sees only the published project');
select t.denied('select budget_ugx from public.project_finance', 'anon cannot read budgets');
select t.denied('select client_name from public.projects', 'anon cannot read client names');
select t.denied('select * from public.projects', 'anon cannot select every column of projects');
select t.allowed('select id, title, summary, progress_pct from public.projects', 'anon can read the public columns');
select t.denied('select * from public.leads', 'anon cannot read leads');
select t.denied('select * from public.profiles', 'anon cannot read profiles');
select t.back();

-- stranger waiting for approval ----------------------------------------------------------
select t.as_user(:G, 'authenticated');
select t.rows('select id from public.projects where id = 2', 0, 'pending account cannot open the project it is linked to');
select t.rows('select id from public.project_phases', 0, 'pending account sees no schedule');
select t.rows('select id from public.leads', 0, 'pending account sees no leads');
select t.rows('select id from public.profiles', 1, 'pending account sees only its own profile');
select t.denied($q$update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-000000000007'$q$, 'nobody can promote themselves');
select t.denied($q$update public.profiles set is_active = true where id = '00000000-0000-0000-0000-000000000007'$q$, 'nobody can approve themselves');
select t.denied($q$select public.set_user_role('00000000-0000-0000-0000-000000000007', 'admin', true)$q$, 'pending account cannot call the role function');
select t.denied($q$select public.set_user_role('00000000-0000-0000-0000-00000000000e', 'super_admin', true)$q$, 'pending account cannot promote someone else either');
select t.back();

-- client -----------------------------------------------------------------------------------
select t.as_user(:E, 'authenticated');
select t.rows('select id from public.projects where id = 1', 1, 'client sees their own project');
select t.rows('select id from public.projects where id = 2', 0, 'client does not see other private projects');
select t.rows('select id from public.project_phases', 2, 'client sees their schedule');
select t.rows('select id from public.site_logs', 1, 'client sees only logs marked for them');
select t.rows('select id from public.project_documents', 1, 'client sees only documents marked for them');
select t.rows($q$select 1 from storage.objects where bucket_id = 'project-documents'$q$, 1, 'client can open only the shared file');
select t.rows('select id from public.project_expenses', 0, 'client never sees expenses');
select t.rows('select project_id from public.project_finance', 0, 'client never sees the budget');
select t.rows('select id from public.leads', 0, 'client sees no leads');
select t.changes($q$update public.project_phases set progress_pct = 0$q$, 0, 'client schedule update changes nothing');
select t.denied($q$insert into public.site_logs (project_id, work_done) values (1, 'fake')$q$, 'client cannot write site logs');
select t.denied($q$insert into storage.objects (bucket_id, name) values ('project-documents', '1/evil.pdf')$q$, 'client cannot upload files');
select t.back();

select t.as_user(:F, 'authenticated');
select t.rows('select id from public.projects where id = 1', 0, 'another client cannot see this project');
select t.rows('select id from public.project_phases', 0, 'another client cannot see this schedule');
select t.back();

-- support ----------------------------------------------------------------------------------
select t.as_user(:D, 'authenticated');
select t.allowed($q$insert into public.leads (kind, full_name, email, message, source) values ('contact', 'Walk-in', 'w@x.com', 'called the office today', 'manual')$q$, 'support can add a manual lead');
select t.denied($q$insert into public.leads (kind, full_name, email, message, source) values ('contact', 'Fake', 'f@x.com', 'pretending to be the website', 'website')$q$, 'support cannot forge a website lead');
select t.rows('select id from public.project_expenses', 0, 'support cannot see expenses');
select t.rows('select project_id from public.project_finance', 0, 'support cannot see budgets');
select t.denied($q$insert into public.project_phases (project_id, name) values (1, 'nope')$q$, 'support cannot edit the schedule');
select t.back();

-- project manager --------------------------------------------------------------------------
select t.as_user(:C, 'authenticated');
select t.rows('select id from public.project_expenses', 1, 'project manager sees expenses');
select t.rows('select project_id from public.project_finance', 2, 'project manager sees budgets');
select t.allowed($q$insert into public.project_phases (project_id, name, start_date, end_date) values (1, 'Roof', '2027-02-01', '2027-03-01')$q$, 'project manager adds a phase');
select t.denied($q$insert into public.project_phases (project_id, name, start_date, end_date) values (1, 'Bad dates', '2027-02-10', '2027-02-01')$q$, 'an end date before the start is refused');
select t.changes('delete from public.project_expenses', 0, 'project manager cannot delete expenses');
select t.changes('delete from public.project_finance', 0, 'project manager cannot delete budgets');
select t.back();

-- admin: approving, inviting, limits ------------------------------------------------------
select t.as_user(:B, 'authenticated');
select t.allowed($q$select public.set_user_role('00000000-0000-0000-0000-000000000007', 'client', true)$q$, 'admin approves a pending client');
select t.denied($q$select public.set_user_role('00000000-0000-0000-0000-00000000000e', 'admin', true)$q$, 'admin cannot make another admin');
select t.denied($q$select public.set_user_role('00000000-0000-0000-0000-00000000000b', 'client', true)$q$, 'admin cannot change their own role');
select t.denied($q$select public.set_user_role('00000000-0000-0000-0000-00000000000a', 'client', false)$q$, 'admin cannot demote the super admin');
select t.changes('delete from public.project_expenses', 1, 'admin can delete an expense');
select t.rows('select id from public.audit_log limit 1', 1, 'admin can read the activity log');
select t.back();

select t.rows($q$select 1 from public.profiles where id = '00000000-0000-0000-0000-000000000007' and is_active and approved_at is not null$q$, 1, 'approval records the time');

select t.as_user(:G, 'authenticated');
select t.rows('select id from public.projects where id = 2', 1, 'once approved, the client sees their project');
select t.back();

-- suspending keeps history but closes the door
select t.as_user(:A, 'authenticated');
select t.allowed($q$select public.set_user_role('00000000-0000-0000-0000-000000000007', 'client', false)$q$, 'super admin suspends an account');
select t.allowed($q$select public.set_user_role('00000000-0000-0000-0000-00000000000f', 'admin', true)$q$, 'super admin grants admin');
select t.denied($q$select public.set_user_role('00000000-0000-0000-0000-00000000000a', 'client', true)$q$, 'super admin cannot change themselves');
select t.back();

select t.as_user(:G, 'authenticated');
select t.rows('select id from public.projects where id = 2', 0, 'a suspended account loses access to its project');
select t.back();

select t.rows($q$select 1 from public.audit_log where table_name = 'project_phases' limit 1$q$, 1, 'schedule changes are written to the activity log');
select t.rows($q$select 1 from public.audit_log where table_name = 'profiles' and action = 'UPDATE' limit 1$q$, 1, 'role changes are written to the activity log');

select t.as_user(:E, 'authenticated');
select t.rows('select id from public.audit_log', 0, 'clients cannot read the activity log');
select t.back();

rollback;
