-- Client collaboration rules: chat, approvals, payments, notifications.
-- a super_admin · c project_manager of project 1 · d support · e client of project 1 · f other client · g pending
\set A '''00000000-0000-0000-0000-00000000000a'''
\set C '''00000000-0000-0000-0000-00000000000c'''
\set D '''00000000-0000-0000-0000-00000000000d'''
\set E '''00000000-0000-0000-0000-00000000000e'''
\set F '''00000000-0000-0000-0000-00000000000f'''
\set G '''00000000-0000-0000-0000-000000000007'''

begin;
insert into auth.users (id, email) values (:A,'a@icon.test'),(:C,'c@icon.test'),(:D,'d@icon.test'),(:E,'e@icon.test'),(:F,'f@icon.test'),(:G,'g@icon.test');
update public.profiles set role = 'super_admin', is_active = true, approved_at = now(), full_name = 'Alice' where id = :A;
update public.profiles set role = 'project_manager', is_active = true, approved_at = now(), full_name = 'Carl' where id = :C;
update public.profiles set role = 'support', is_active = true, approved_at = now() where id = :D;
update public.profiles set is_active = true, approved_at = now(), full_name = 'Eve' where id in (:E, :F);
insert into public.projects (id, title, slug, location, project_type, client_id, project_manager) overriding system value values
  (1, 'House', 'house', 'Kampala', 'Residential', :E, :C), (2, 'Other', 'other', 'Jinja', 'Road', :F, null);
insert into public.project_payments (project_id, label, amount_ugx) values (1, 'Deposit', 10000000), (2, 'Deposit', 5000000);

-- chat --------------------------------------------------------------------------------------
select t.as_user(:E, 'authenticated');
select t.allowed($q$insert into public.project_messages (project_id, body) values (1, 'Hello team')$q$, 'client writes in their own project chat');
select t.denied($q$insert into public.project_messages (project_id, body) values (2, 'hi')$q$, 'client cannot write in another project chat');
select t.denied($q$insert into public.project_messages (project_id, body, author_id) values (1, 'fake', '00000000-0000-0000-0000-00000000000c')$q$, 'nobody can post as someone else');
select t.denied($q$insert into public.project_messages (project_id, body, photo_path) values (1, '', '2/x.jpg')$q$, 'a chat photo must belong to the same project');
select t.rows('select 1 from public.project_messages where project_id = 2', 0, 'client cannot read another project chat');
select t.changes($q$update public.project_messages set body = 'Hello team!' where project_id = 1$q$, 1, 'author fixes a typo within 5 minutes');
select t.rows($q$select 1 from public.project_messages where edited_at is not null$q$, 1, 'an edited message is marked as edited');
select t.denied($q$delete from public.project_messages$q$, 'chat messages can never be deleted');
select t.allowed($q$insert into public.message_reads (project_id) values (1)$q$, 'client marks the chat as seen');
select t.back();
update public.project_messages set created_at = now() - interval '10 minutes';
select t.as_user(:E, 'authenticated');
select t.changes($q$update public.project_messages set body = 'changed later'$q$, 0, 'after 5 minutes a message can no longer be changed');
select t.back();
select t.rows($q$select 1 from public.notifications where user_id = '00000000-0000-0000-0000-00000000000c' and kind = 'message'$q$, 1, 'client message notifies the project manager');
select t.rows($q$select 1 from public.notifications where user_id = '00000000-0000-0000-0000-00000000000e'$q$, 0, 'the author is not notified of their own message');

select t.as_user(:C, 'authenticated');
select t.allowed($q$insert into public.project_messages (project_id, body) values (1, 'Hi Eve')$q$, 'project manager replies');
select t.back();
select t.rows($q$select 1 from public.notifications where user_id = '00000000-0000-0000-0000-00000000000e' and kind = 'message' and link like '/portal/%'$q$, 1, 'team reply notifies the client with a portal link');

select t.as_user(:D, 'authenticated');
select t.rows('select 1 from public.project_messages', 0, 'support staff cannot read project chats');
select t.denied($q$insert into public.project_messages (project_id, body) values (1, 'x')$q$, 'support staff cannot write in project chats');
select t.as_user(:G, 'authenticated');
select t.rows('select 1 from public.project_messages', 0, 'a pending account reads no chat');

-- approvals -----------------------------------------------------------------------------------
select t.as_user(:C, 'authenticated');
select t.allowed($q$insert into public.project_requests (project_id, kind, title) values (1, 'decision', 'Approve roof colour')$q$, 'team asks the client to approve something');
select t.denied($q$insert into public.project_requests (project_id, kind, title, status) values (1, 'decision', 'sneaky', 'approved')$q$, 'team cannot create an already-approved request');
select t.back();
select t.rows($q$select 1 from public.notifications where user_id = '00000000-0000-0000-0000-00000000000e' and kind = 'approval'$q$, 1, 'client is told something waits for approval');

select t.as_user(:C, 'authenticated');
select t.denied($q$select public.decide_request((select id from public.project_requests limit 1), true)$q$, 'the team cannot approve on the client''s behalf');
select t.denied($q$update public.project_requests set status = 'approved'$q$, 'the team cannot mark a request approved directly');
select t.as_user(:F, 'authenticated');
select t.rows('select 1 from public.project_requests', 0, 'another client cannot see these requests');
select t.denied($q$select public.decide_request((select min(id) from public.project_requests), true)$q$, 'another client cannot decide');
select t.as_user(:E, 'authenticated');
select t.changes($q$update public.project_requests set status = 'approved'$q$, 0, 'client cannot change a request directly');
select t.allowed($q$select public.decide_request((select min(id) from public.project_requests), true, 'Looks good')$q$, 'client approves');
select t.rows($q$select 1 from public.project_requests where status = 'approved' and decided_by = '00000000-0000-0000-0000-00000000000e' and decided_at is not null$q$, 1, 'approval records who and when');
select t.denied($q$select public.decide_request((select min(id) from public.project_requests), false)$q$, 'a decision cannot be answered twice');
select t.allowed($q$select public.request_change(1, 'Add a window', 'In the kitchen')$q$, 'client asks for a change');
select t.denied($q$select public.request_change(2, 'x')$q$, 'client cannot ask for changes on another project');
select t.back();
select t.denied($q$update public.project_requests set title = 'rewritten' where status = 'approved'$q$, 'even the database owner cannot rewrite a closed decision');
select t.rows($q$select 1 from public.notifications where user_id = '00000000-0000-0000-0000-00000000000c' and kind in ('decision','change')$q$, 2, 'team is told about the approval and the change request');

select t.as_user(:C, 'authenticated');
select t.changes($q$update public.project_requests set cost_impact_ugx = 800000, days_impact = 3, status = 'awaiting_client' where status = 'awaiting_team'$q$, 1, 'team prices the change and sends it to the client');
select t.back();

-- payments ------------------------------------------------------------------------------------
select t.as_user(:E, 'authenticated');
select t.rows('select 1 from public.project_payments', 1, 'client sees only their own payment schedule');
select t.changes($q$update public.project_payments set paid_on = current_date$q$, 0, 'client cannot mark a payment as paid');
select t.rows('select 1 from public.project_finance', 0, 'client still cannot see the internal budget');
select t.as_user(:C, 'authenticated');
select t.changes($q$update public.project_payments set paid_on = current_date where project_id = 1$q$, 1, 'project manager records a payment');
select t.changes($q$delete from public.project_payments$q$, 0, 'only admins delete payment lines');

-- notifications -------------------------------------------------------------------------------
select t.as_user(:E, 'authenticated');
select t.rows($q$select 1 from public.notifications where user_id <> '00000000-0000-0000-0000-00000000000e'$q$, 0, 'people only see their own notifications');
select t.changes($q$update public.notifications set read_at = now()$q$, 3, 'client marks their notifications read');
select t.denied($q$update public.notifications set title = 'x'$q$, 'notification text cannot be changed');
select t.denied($q$insert into public.notifications (user_id, kind, title) values ('00000000-0000-0000-0000-00000000000c', 'x', 'spoof')$q$, 'nobody can create fake notifications');
select t.back();

insert into public.site_logs (project_id, work_done, client_visible) values (1, 'Roof sheets on', true);
select t.rows($q$select 1 from public.notifications where user_id = '00000000-0000-0000-0000-00000000000e' and kind = 'update'$q$, 1, 'a shared site update notifies the client');
insert into public.leads (kind, full_name, email, message) values ('contact', 'Visitor', 'v@x.test', 'Need a house');
select t.rows($q$select 1 from public.notifications where kind = 'lead'$q$, 2, 'a website lead notifies admins and support');
select t.rows($q$select 1 from public.notifications where kind = 'lead' and user_id = '00000000-0000-0000-0000-00000000000e'$q$, 0, 'clients are never told about leads');

rollback;

-- phone alerts --------------------------------------------------------------------------------
begin;
insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000000e','e@icon.test'),('00000000-0000-0000-0000-00000000000f','f@icon.test');
update public.profiles set is_active = true, approved_at = now() where id in ('00000000-0000-0000-0000-00000000000e','00000000-0000-0000-0000-00000000000f');
select t.as_user('00000000-0000-0000-0000-00000000000e', 'authenticated');
select t.allowed($q$insert into public.push_subscriptions (endpoint, p256dh, auth) values ('https://push.example/1', 'k', 'a')$q$, 'a person registers their own device');
select t.denied($q$insert into public.push_subscriptions (user_id, endpoint, p256dh, auth) values ('00000000-0000-0000-0000-00000000000f', 'https://push.example/2', 'k', 'a')$q$, 'nobody registers a device for someone else');
select t.changes($q$update public.profiles set quiet_from = 21, quiet_to = 6 where id = '00000000-0000-0000-0000-00000000000e'$q$, 1, 'a person sets their own quiet hours');
select t.allowed($q$select public.test_my_alerts()$q$, 'a person sends themselves a test alert');
select t.rows($q$select 1 from public.notifications where kind = 'test'$q$, 1, 'the test alert lands in their own bell');
select t.as_user('00000000-0000-0000-0000-00000000000f', 'authenticated');
select t.rows('select 1 from public.push_subscriptions', 0, 'people cannot see other people''s devices');
select t.back();
rollback;
