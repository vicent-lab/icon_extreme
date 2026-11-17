import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/providers.dart';
import 'core/roles.dart';
import 'core/theme.dart';
import 'features/auth/login_page.dart';
import 'features/content/content_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/leads/leads_page.dart';
import 'features/projects/projects_page.dart';
import 'features/shell/app_shell.dart';
import 'features/users/users_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Config.isConfigured) {
    await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabaseAnonKey);
  }
  runApp(const ProviderScope(child: IconApp()));
}

/// Tells go_router to re-check redirects whenever auth or profile changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(profileProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  Widget gate(Section s, Widget page) => Consumer(builder: (context, ref, _) {
        final role = ref.watch(profileProvider).value?.role ?? AppRole.client;
        return canOpen(role, s) ? page : const _NoAccess();
      });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      if (!Config.isConfigured) return state.matchedLocation == '/setup' ? null : '/setup';
      final signedIn = Supabase.instance.client.auth.currentUser != null;
      final onLogin = state.matchedLocation == '/login';
      if (!signedIn) return onLogin ? null : '/login';
      final profile = ref.read(profileProvider);
      if (profile.isLoading) return null;
      final p = profile.value;
      if (p == null || !p.isActive) return '/blocked';
      if (!p.role.isStaff) return state.matchedLocation == '/portal' ? null : '/portal';
      if (onLogin || state.matchedLocation == '/portal' || state.matchedLocation == '/blocked') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/setup', builder: (_, _) => const _SetupNeeded()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/blocked', builder: (_, _) => const _Blocked()),
      GoRoute(path: '/portal', builder: (_, _) => const _PortalSoon()),
      ShellRoute(
        builder: (_, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => gate(Section.dashboard, const DashboardPage())),
          GoRoute(path: '/leads', builder: (_, _) => gate(Section.leads, const LeadsPage())),
          GoRoute(path: '/projects', builder: (_, _) => gate(Section.projects, const ProjectsPage())),
          GoRoute(path: '/services', builder: (_, _) => gate(Section.services, ContentPage(spec: ContentSpec.services))),
          GoRoute(path: '/team', builder: (_, _) => gate(Section.team, ContentPage(spec: ContentSpec.team))),
          GoRoute(path: '/testimonials', builder: (_, _) => gate(Section.testimonials, ContentPage(spec: ContentSpec.testimonials))),
          GoRoute(path: '/blog', builder: (_, _) => gate(Section.blog, ContentPage(spec: ContentSpec.blog))),
          GoRoute(path: '/users', builder: (_, _) => gate(Section.users, const UsersPage())),
        ],
      ),
    ],
  );
});

class IconApp extends ConsumerWidget {
  const IconApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'ICON Construction',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: ref.watch(routerProvider),
      );
}

class _Message extends StatelessWidget {
  const _Message(this.title, this.body, {this.action});
  final String title, body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(body, textAlign: TextAlign.center),
                if (action != null) ...[const SizedBox(height: 20), action!],
              ]),
            ),
          ),
        ),
      );
}

class _NoAccess extends StatelessWidget {
  const _NoAccess();
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Your role does not have access to this section.'));
}

class _SetupNeeded extends StatelessWidget {
  const _SetupNeeded();
  @override
  Widget build(BuildContext context) => const _Message('Almost ready',
      'Start the app with --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=... (see README).');
}

class _Blocked extends ConsumerWidget {
  const _Blocked();
  @override
  Widget build(BuildContext context, WidgetRef ref) => _Message(
        'Account not active',
        'Your account is disabled or not set up yet. Ask an administrator for help.',
        action: OutlinedButton(
          onPressed: () => Supabase.instance.client.auth.signOut(),
          child: const Text('Sign out'),
        ),
      );
}

class _PortalSoon extends StatelessWidget {
  const _PortalSoon();
  @override
  Widget build(BuildContext context) => _Message(
        'Client portal',
        'Your project progress, photos and invoices will appear here soon.',
        action: OutlinedButton(
          onPressed: () => Supabase.instance.client.auth.signOut(),
          child: const Text('Sign out'),
        ),
      );
}
