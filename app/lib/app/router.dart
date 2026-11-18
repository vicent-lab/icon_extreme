import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/roles.dart';
import '../data/models/profile.dart';
import '../data/providers.dart';
import '../features/access/access_screens.dart';
import '../features/auth/accept_page.dart';
import '../features/auth/forgot_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/set_password_page.dart';
import '../features/collab/notifications_page.dart';
import '../features/content/content_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/leads/leads_page.dart';
import '../features/portal/portal_pages.dart';
import '../features/profile/profile_page.dart';
import '../features/projects/project_detail_page.dart';
import '../features/projects/projects_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shell/app_shell.dart';
import '../features/users/users_page.dart';

/// Tells go_router to re-check its redirect rules whenever sign-in or the profile changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(profileProvider, (_, _) => notifyListeners());
  }
}

/// Pages a signed-out visitor may open.
const _publicPaths = {'/login', '/accept', '/forgot'};

/// Pages any signed-in person may open, whatever their access.
const _anyoneSignedIn = {'/set-password'};

/// Where a person belongs, by who they are. This one function is the whole access map for navigation.
/// (The database still enforces the real rules; this only decides what to show.)
String? decideRoute({
  required bool configured,
  required bool signedIn,
  required AsyncValue<Profile?> profile,
  required String location,
}) {
  if (!configured) return location == '/setup' ? null : '/setup';
  if (!signedIn) return _publicPaths.contains(location) ? null : '/login';
  if (_anyoneSignedIn.contains(location)) return null;
  if (profile.isLoading && !profile.hasValue) return null; // still finding out who this is

  final p = profile.value;
  final access = p?.access ?? Access.pending;
  if (access == Access.pending) return location == '/waiting' ? null : '/waiting';
  if (access == Access.suspended) return location == '/suspended' ? null : '/suspended';

  final home = p!.role.isStaff ? '/' : '/portal';
  const entry = {'/login', '/accept', '/forgot', '/waiting', '/suspended'};
  if (entry.contains(location)) return home;
  if (p.role.isStaff && location.startsWith('/portal')) return '/';
  if (!p.role.isStaff && !location.startsWith('/portal')) return '/portal';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  Widget gate(Section s, Widget page) => Consumer(builder: (context, ref, _) {
        final role = ref.watch(profileProvider).value?.role ?? AppRole.client;
        return canOpen(role, s) ? page : const NoAccessView();
      });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    errorBuilder: (_, state) => NotFoundScreen(path: state.uri.toString()),
    redirect: (context, state) => decideRoute(
      configured: Config.isConfigured,
      signedIn: Config.isConfigured && Supabase.instance.client.auth.currentUser != null,
      profile: ref.read(profileProvider),
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/setup', builder: (_, _) => const SetupNeededScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/forgot', builder: (_, _) => const ForgotPage()),
      GoRoute(
        path: '/accept',
        builder: (_, state) => AcceptPage(tokenHash: state.uri.queryParameters['token_hash'], type: state.uri.queryParameters['type']),
      ),
      GoRoute(path: '/set-password', builder: (_, _) => const SetPasswordPage()),
      GoRoute(path: '/waiting', builder: (_, _) => const WaitingScreen()),
      GoRoute(path: '/suspended', builder: (_, _) => const SuspendedScreen()),
      // ---- clients ----
      ShellRoute(
        builder: (_, state, child) => PortalShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/portal', builder: (_, _) => const PortalHome()),
          GoRoute(
            path: '/portal/project/:id',
            builder: (_, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              return id == null ? const NoAccessView() : PortalProjectPage(id: id, tab: state.uri.queryParameters['tab']);
            },
          ),
          GoRoute(path: '/portal/profile', builder: (_, _) => const ProfilePage()),
          GoRoute(path: '/portal/notifications', builder: (_, _) => const NotificationsPage()),
        ],
      ),
      // ---- staff ----
      ShellRoute(
        builder: (_, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => gate(Section.dashboard, const DashboardPage())),
          GoRoute(path: '/leads', builder: (_, _) => gate(Section.leads, const LeadsPage())),
          GoRoute(path: '/projects', builder: (_, _) => gate(Section.projects, const ProjectsPage())),
          GoRoute(
            path: '/projects/:id',
            builder: (_, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              return gate(Section.projects, id == null ? const NoAccessView() : ProjectDetailPage(id: id, tab: state.uri.queryParameters['tab']));
            },
          ),
          GoRoute(path: '/services', builder: (_, _) => gate(Section.services, ContentPage(spec: ContentSpec.services))),
          GoRoute(path: '/team', builder: (_, _) => gate(Section.team, ContentPage(spec: ContentSpec.team))),
          GoRoute(path: '/testimonials', builder: (_, _) => gate(Section.testimonials, ContentPage(spec: ContentSpec.testimonials))),
          GoRoute(path: '/blog', builder: (_, _) => gate(Section.blog, ContentPage(spec: ContentSpec.blog))),
          GoRoute(path: '/users', builder: (_, _) => gate(Section.users, const UsersPage())),
          GoRoute(path: '/settings', builder: (_, _) => gate(Section.settings, const SettingsPage())),
          GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
          GoRoute(path: '/notifications', builder: (_, _) => const NotificationsPage()),
        ],
      ),
    ],
  );
});
