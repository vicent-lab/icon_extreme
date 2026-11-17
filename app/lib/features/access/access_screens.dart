import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design/theme.dart';
import '../../data/providers.dart';

/// A centred message card used by every "you cannot go further yet" screen.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body, this.actions = const []});
  final IconData icon;
  final String title, body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: Brand.ink, borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, color: Brand.gold),
                    ),
                    const SizedBox(height: 20),
                    Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                    const SizedBox(height: 24),
                    Wrap(spacing: 10, runSpacing: 10, children: actions),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

Future<void> _signOut() => Supabase.instance.client.auth.signOut();

/// Signed in, but nobody has approved this account yet.
class WaitingScreen extends ConsumerWidget {
  const WaitingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider).value;
    final email = p?.email ?? Supabase.instance.client.auth.currentUser?.email ?? 'your account';
    return _Notice(
      icon: Icons.hourglass_top,
      title: 'Waiting for approval',
      body: 'You are signed in as $email, but an ICON administrator has not given this account access yet.\n\n'
          'If you are a client or a team member, ask your ICON contact to send you an invitation. '
          'This page checks again by itself every few seconds, so it will open as soon as you are approved.',
      actions: [
        FilledButton(onPressed: () => ref.invalidate(profileProvider), child: const Text('Check again')),
        OutlinedButton(onPressed: _signOut, child: const Text('Sign out')),
      ],
    );
  }
}

/// Was approved once, switched off later.
class SuspendedScreen extends StatelessWidget {
  const SuspendedScreen({super.key});
  @override
  Widget build(BuildContext context) => _Notice(
        icon: Icons.lock_outline,
        title: 'Access switched off',
        body: 'An administrator has turned off this account. If you think this is a mistake, contact ICON and ask them to switch it back on.',
        actions: [OutlinedButton(onPressed: _signOut, child: const Text('Sign out'))],
      );
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.path});
  final String path;
  @override
  Widget build(BuildContext context) => _Notice(
        icon: Icons.search_off,
        title: 'Page not found',
        body: 'There is nothing at "$path". The link may be old or mistyped.',
        actions: [FilledButton(onPressed: () => context.go('/'), child: const Text('Go to the start'))],
      );
}

class SetupNeededScreen extends StatelessWidget {
  const SetupNeededScreen({super.key});
  @override
  Widget build(BuildContext context) => const _Notice(
        icon: Icons.settings_outlined,
        title: 'Almost ready',
        body: 'Start the app with --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=... (see the README).',
      );
}

/// Shown inside a page when the person's role may not open that section.
class NoAccessView extends StatelessWidget {
  const NoAccessView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Your role does not have access to this section.'));
}
