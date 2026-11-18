-- Phone alerts (web push). Every bell notification is also sent to the person's devices,
-- except during their quiet hours. The bell itself always works; phone alerts are a bonus.

create table public.push_subscriptions (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now());
create index push_subscriptions_user on public.push_subscriptions (user_id);
alter table public.push_subscriptions enable row level security;
grant select, insert, delete on public.push_subscriptions to authenticated;
grant select, insert, update, delete on public.push_subscriptions to service_role;
create policy "own devices read" on public.push_subscriptions for select to authenticated using (user_id = (select auth.uid()));
create policy "own devices add" on public.push_subscriptions for insert to authenticated with check (user_id = (select auth.uid()));
create policy "own devices remove" on public.push_subscriptions for delete to authenticated using (user_id = (select auth.uid()));

-- quiet hours, in Kampala time; both empty = alerts any time
alter table public.profiles
  add column quiet_from smallint default 20 check (quiet_from between 0 and 23),
  add column quiet_to   smallint default 7  check (quiet_to between 0 and 23);
grant update (quiet_from, quiet_to) on public.profiles to authenticated;

-- "send me a test alert": lets anyone check their own phone alerts work
create function public.test_my_alerts() returns void language plpgsql security definer set search_path = '' as $$
begin
  if private.current_role() is null then raise exception 'not allowed'; end if;
  insert into public.notifications (user_id, kind, title, body, link)
  values ((select auth.uid()), 'test', 'Test alert', 'Alerts are working on this device.', null);
end $$;
revoke execute on function public.test_my_alerts() from public, anon;
grant execute on function public.test_my_alerts() to authenticated;

-- Hand each new notification to the send-push function.
-- The function's address and a shared secret live in Supabase Vault (set once, never in this file).
-- If pg_net or the Vault entries are missing (for example in the test database), this quietly does nothing.
do $$ begin
  create extension if not exists pg_net with schema extensions;
exception when others then raise notice 'pg_net not available here; phone alerts stay off';
end $$;

create function private.push_notification() returns trigger language plpgsql security definer set search_path = '' as $$
declare url text; secret text;
begin
  if to_regclass('vault.decrypted_secrets') is null or to_regnamespace('net') is null then return new; end if;
  execute $q$select decrypted_secret from vault.decrypted_secrets where name = 'push_hook_url'$q$ into url;
  execute $q$select decrypted_secret from vault.decrypted_secrets where name = 'push_hook_secret'$q$ into secret;
  if url is null or secret is null then return new; end if;
  if not exists (select 1 from public.push_subscriptions where user_id = new.user_id) then return new; end if;
  execute 'select net.http_post(url := $1, body := $2, headers := $3)'
    using url, jsonb_build_object('notification_id', new.id),
          jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', secret);
  return new;
exception when others then
  raise warning 'push hand-off failed: %', sqlerrm;   -- never block the notification itself
  return new;
end $$;
create trigger push_on_notification after insert on public.notifications
  for each row execute function private.push_notification();
