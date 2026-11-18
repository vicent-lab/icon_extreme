-- The send-push function reads its keys from Supabase Vault (encrypted) through this door.
-- Only the server key (service_role) may call it; signed-in users and visitors cannot.
-- Vault entries (set once, by hand, never in this repo): push_hook_url, push_hook_secret, vapid_public_key, vapid_private_key.
create function public.push_config() returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare out jsonb;
begin
  if to_regclass('vault.decrypted_secrets') is null then return '{}'; end if;
  execute $q$select coalesce(jsonb_object_agg(name, decrypted_secret), '{}') from vault.decrypted_secrets
            where name in ('push_hook_secret','vapid_public_key','vapid_private_key')$q$ into out;
  return out;
end $$;
revoke execute on function public.push_config() from public, anon, authenticated;
grant execute on function public.push_config() to service_role;
