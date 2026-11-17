# ICON Construction platform

| Folder | What it is |
|---|---|
| `app/` | Flutter app (web, Android, iOS) for staff and, later, clients |
| `supabase/migrations/` | Database: tables, roles, security rules (RLS), audit log |
| `legacy-php/` | The old PHP/MySQL site, kept as reference until the new public site replaces it |

## Run the app
1. Create a Supabase project for ICON. Run the files in `supabase/migrations/` in order.
2. In Supabase: Authentication → Users → add your first user. Then in the SQL editor run
   `update public.profiles set role = 'super_admin' where id = '<that user id>';`
   (This is the only time you do it by hand. After that, use **Users & roles** in the app.)
3. Start the app, with the project URL and publishable key from Supabase → Settings → API:
   ```
   cd app
   flutter run -d chrome --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
   ```
4. If it fails with "Almost ready", the two `--dart-define` values are missing.

## Security rules in one minute
- Roles live in the database. The app only hides buttons; **Postgres RLS decides what is allowed**.
- New sign-ups are always `client`. Only an admin can promote someone; only a super admin can make admins.
- Visitors can read published content only. Nobody anonymous can write anything.
- Never put the `service_role` key in the app or in git.

## Status
Done: schema + RLS (tested), login, role-based navigation, dashboard, leads, projects, content toggles, users & roles.
Next: quotes, project phases/site logs, invoices, documents, client portal, public site, edge function for the website forms, data import from the old MySQL.
