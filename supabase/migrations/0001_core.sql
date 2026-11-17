-- ICON Construction — core schema: roles, profiles, website content, leads, audit log.
-- Rules used everywhere: RLS ON, explicit GRANTs, no anon write access, roles checked in the DATABASE.

create schema if not exists private;                 -- helper functions live here (not exposed to the API)
revoke all on schema private from public;
grant usage on schema private to authenticated, anon, service_role;

create type public.app_role as enum
  ('super_admin','admin','project_manager','editor','support','client');

-- ───────── profiles (one row per auth user) ─────────
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  full_name   text not null default '',
  phone       text,
  avatar_url  text,
  role        public.app_role not null default 'client',
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- helpers (security definer so policies can read profiles without recursion)
create function private.current_role() returns public.app_role
language sql stable security definer set search_path = '' as $$
  select role from public.profiles where id = (select auth.uid()) and is_active
$$;

create function private.has_role(roles public.app_role[]) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(private.current_role() = any(roles), false)
$$;

create function private.is_staff() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(private.current_role() in
    ('super_admin','admin','project_manager','editor','support'), false)
$$;

grant execute on function private.current_role(), private.has_role(public.app_role[]),
  private.is_staff() to authenticated, anon, service_role;

-- new sign-ups are ALWAYS 'client'. Staff roles are only given by an admin (see set_user_role).
create function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''));
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

create function private.touch_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at = now(); return new; end $$;

alter table public.profiles enable row level security;
grant select on public.profiles to authenticated;
grant update (full_name, phone, avatar_url) on public.profiles to authenticated;  -- NOT role / is_active
grant select, insert, update, delete on public.profiles to service_role;
create trigger profiles_touch before update on public.profiles
  for each row execute function private.touch_updated_at();

create policy "read own profile or staff reads all" on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.is_staff());
create policy "update own profile" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- Only admins change roles, with rules: nobody edits themselves; only super_admin makes admins.
create function public.set_user_role(target uuid, new_role public.app_role, active boolean default true)
returns void language plpgsql security definer set search_path = '' as $$
declare caller public.app_role := private.current_role();
begin
  if caller not in ('super_admin','admin') then raise exception 'not allowed'; end if;
  if target = (select auth.uid()) then raise exception 'you cannot change your own role'; end if;
  if new_role in ('super_admin','admin') and caller <> 'super_admin'
     then raise exception 'only a super admin can grant admin roles'; end if;
  if (select role from public.profiles where id = target) in ('super_admin','admin')
     and caller <> 'super_admin' then raise exception 'only a super admin can change an admin'; end if;
  update public.profiles set role = new_role, is_active = active where id = target;
end $$;
revoke execute on function public.set_user_role(uuid, public.app_role, boolean) from public, anon;
grant  execute on function public.set_user_role(uuid, public.app_role, boolean) to authenticated;

-- ───────── audit log (append-only) ─────────
create table public.audit_log (
  id         bigint generated always as identity primary key,
  at         timestamptz not null default now(),
  actor      uuid,
  action     text not null,          -- INSERT / UPDATE / DELETE
  table_name text not null,
  row_id     text,
  old_data   jsonb,
  new_data   jsonb
);
alter table public.audit_log enable row level security;
grant select on public.audit_log to authenticated;       -- read only; writes come from the trigger
grant select, insert on public.audit_log to service_role;
create policy "admins read audit log" on public.audit_log for select to authenticated
  using (private.has_role(array['super_admin','admin']::public.app_role[]));

create function private.audit() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.audit_log(actor, action, table_name, row_id, old_data, new_data)
  values ((select auth.uid()), tg_op, tg_table_name,
          coalesce((to_jsonb(new)->>'id'), (to_jsonb(old)->>'id')),
          case when tg_op <> 'INSERT' then to_jsonb(old) end,
          case when tg_op <> 'DELETE' then to_jsonb(new) end);
  return coalesce(new, old);
end $$;
create trigger audit_profiles after update or delete on public.profiles
  for each row execute function private.audit();

-- ───────── website content ─────────
-- one macro-ish pattern per table: public reads PUBLISHED rows, staff manage per role.
create table public.company_settings (
  key text primary key, value text not null default '', is_public boolean not null default true,
  updated_at timestamptz not null default now());
create table public.services (
  id bigint generated always as identity primary key,
  name text not null, slug text not null unique, short_description text not null,
  full_description text not null default '', icon text not null default 'building', image_path text,
  is_featured boolean not null default false, display_order int not null default 0,
  is_active boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.projects (
  id bigint generated always as identity primary key,
  title text not null, slug text not null unique, summary text, description text not null default '',
  location text not null, project_type text not null, client_name text,
  status text not null default 'upcoming' check (status in ('upcoming','ongoing','completed','on_hold')),
  start_date date, end_date date, budget_ugx numeric(15,2) check (budget_ugx >= 0),
  progress_pct smallint not null default 0 check (progress_pct between 0 and 100),
  project_manager uuid references public.profiles(id) on delete set null,
  client_id uuid references public.profiles(id) on delete set null,   -- client portal owner
  challenge text, solution text, results text, featured_image text,
  is_featured boolean not null default false, is_published boolean not null default false,
  is_demo boolean not null default false, display_order int not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.project_images (
  id bigint generated always as identity primary key,
  project_id bigint not null references public.projects(id) on delete cascade,
  image_path text not null, alt_text text not null default '', caption text,
  category text not null default 'building-construction', display_order int not null default 0,
  created_at timestamptz not null default now(), unique (project_id, image_path));
create table public.testimonials (
  id bigint generated always as identity primary key,
  client_name text not null, client_role text, company text,
  project_id bigint references public.projects(id) on delete set null,
  quote text not null, rating smallint check (rating between 1 and 5), photo_path text,
  client_permission boolean not null default false,     -- must be true to publish
  is_published boolean not null default false, is_featured boolean not null default false,
  is_demo boolean not null default false, display_order int not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (not is_published or client_permission));
create table public.team_members (
  id bigint generated always as identity primary key,
  name text not null, job_title text not null, bio text, image_path text,
  display_order int not null default 0, is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.blog_categories (
  id bigint generated always as identity primary key,
  name text not null, slug text not null unique, description text);
create table public.blog_posts (
  id bigint generated always as identity primary key,
  category_id bigint references public.blog_categories(id) on delete set null,
  title text not null, slug text not null unique, excerpt text, content text not null,
  featured_image text, author text, reading_time smallint, seo_title text, seo_description text,
  status text not null default 'draft' check (status in ('draft','published')),
  published_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now());

do $$
declare t text;
  content_tables text[] := array['company_settings','services','projects','project_images',
    'testimonials','team_members','blog_categories','blog_posts'];
begin
  foreach t in array content_tables loop
    execute format('alter table public.%I enable row level security', t);
    execute format('grant select on public.%I to anon, authenticated', t);
    execute format('grant insert, update, delete on public.%I to authenticated', t);
    execute format('grant select, insert, update, delete on public.%I to service_role', t);
    execute format('create trigger audit_%1$s after insert or update or delete on public.%1$I
                    for each row execute function private.audit()', t);
    if t <> 'project_images' and t <> 'blog_categories' then
      if t <> 'company_settings' then
        execute format('create trigger touch_%1$s before update on public.%1$I
                        for each row execute function private.touch_updated_at()', t);
      end if;
    end if;
  end loop;
end $$;
revoke delete on public.projects from authenticated;   -- projects are archived, deleted only by service_role

-- Public (anon) may only see published/active rows; staff see everything.
create policy "public reads settings"   on public.company_settings for select to anon, authenticated using (is_public or private.is_staff());
create policy "public reads services"   on public.services   for select to anon, authenticated using (is_active or private.is_staff());
create policy "public reads projects"   on public.projects   for select to anon, authenticated
  using (is_published or private.is_staff() or client_id = (select auth.uid()));
create policy "public reads images"     on public.project_images for select to anon, authenticated
  using (private.is_staff() or exists (select 1 from public.projects p where p.id = project_id and (p.is_published or p.client_id = (select auth.uid()))));
create policy "public reads testimonials" on public.testimonials for select to anon, authenticated using (is_published or private.is_staff());
create policy "public reads team"       on public.team_members for select to anon, authenticated using (is_active or private.is_staff());
create policy "public reads categories" on public.blog_categories for select to anon, authenticated using (true);
create policy "public reads posts"      on public.blog_posts for select to anon, authenticated
  using ((status = 'published' and published_at <= now()) or private.is_staff());

-- Who may WRITE what:  admins everything · editors content · project managers projects/images
create policy "admin writes settings" on public.company_settings for all to authenticated
  using (private.has_role(array['super_admin','admin']::public.app_role[]))
  with check (private.has_role(array['super_admin','admin']::public.app_role[]));
create policy "editors write services" on public.services for all to authenticated
  using (private.has_role(array['super_admin','admin','editor']::public.app_role[]))
  with check (private.has_role(array['super_admin','admin','editor']::public.app_role[]));
create policy "editors write team" on public.team_members for all to authenticated
  using (private.has_role(array['super_admin','admin','editor']::public.app_role[]))
  with check (private.has_role(array['super_admin','admin','editor']::public.app_role[]));
create policy "editors write testimonials" on public.testimonials for all to authenticated
  using (private.has_role(array['super_admin','admin','editor']::public.app_role[]))
  with check (private.has_role(array['super_admin','admin','editor']::public.app_role[]));
create policy "editors write categories" on public.blog_categories for all to authenticated
  using (private.has_role(array['super_admin','admin','editor']::public.app_role[]))
  with check (private.has_role(array['super_admin','admin','editor']::public.app_role[]));
create policy "editors write posts" on public.blog_posts for all to authenticated
  using (private.has_role(array['super_admin','admin','editor']::public.app_role[]))
  with check (private.has_role(array['super_admin','admin','editor']::public.app_role[]));
create policy "managers write projects" on public.projects for all to authenticated
  using (private.has_role(array['super_admin','admin','project_manager','editor']::public.app_role[]))
  with check (private.has_role(array['super_admin','admin','project_manager','editor']::public.app_role[]));
create policy "managers write images" on public.project_images for all to authenticated
  using (private.has_role(array['super_admin','admin','project_manager','editor']::public.app_role[]))
  with check (private.has_role(array['super_admin','admin','project_manager','editor']::public.app_role[]));

-- ───────── leads (contact messages + quote requests in one pipeline) ─────────
create table public.leads (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('contact','quote')),
  full_name text not null, email text not null, phone text,
  subject text, message text not null, location text, project_type text,
  budget_ugx numeric(15,2) check (budget_ugx >= 0), preferred_contact text check (preferred_contact in ('phone','email','whatsapp')),
  stage text not null default 'new' check (stage in ('new','contacted','site_visit','quoted','won','lost','spam')),
  assigned_to uuid references public.profiles(id) on delete set null,
  internal_notes text, source text not null default 'website',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create index leads_stage_created on public.leads (stage, created_at desc);
alter table public.leads enable row level security;
-- NO anon grant: the public form posts through an Edge Function (rate limit + spam checks) using service_role.
grant select on public.leads to authenticated;
grant update (stage, assigned_to, internal_notes) on public.leads to authenticated;  -- customer text is read-only
grant select, insert, update, delete on public.leads to service_role;
create policy "sales staff read leads" on public.leads for select to authenticated
  using (private.has_role(array['super_admin','admin','project_manager','support']::public.app_role[]));
create policy "sales staff work leads" on public.leads for update to authenticated
  using (private.has_role(array['super_admin','admin','project_manager','support']::public.app_role[]))
  with check (private.has_role(array['super_admin','admin','project_manager','support']::public.app_role[]));
create trigger touch_leads before update on public.leads for each row execute function private.touch_updated_at();
create trigger audit_leads after update on public.leads for each row execute function private.audit();
