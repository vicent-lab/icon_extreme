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

## Google sign-in (one-time setup)
1. Google Cloud Console → APIs & Services → OAuth consent screen: create it (External), add your email as a test user.
2. Credentials → Create credentials → OAuth client ID → **Web application**.
   Authorized redirect URI: `https://ioktaopzboaremkamwmd.supabase.co/auth/v1/callback`
3. Copy the Client ID and Client secret into Supabase → Authentication → Providers → Google → turn it on → Save.
4. Supabase → Authentication → URL Configuration: Site URL `https://icon-extreme.pages.dev`;
   Redirect URLs: `https://icon-extreme.pages.dev`, `http://localhost:*` and `com.iconconstruction.icon://login-callback/`.
5. Sign in once with Google, then make yourself super admin:
   `update public.profiles set role = 'super_admin' where id = (select id from auth.users where email = 'YOUR_GMAIL');`
Anyone can sign in with Google, but they start as `client` and see nothing in the staff app until an admin promotes them.
