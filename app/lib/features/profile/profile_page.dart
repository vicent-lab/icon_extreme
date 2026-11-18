import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../core/widgets.dart';
import '../../data/models/profile.dart';
import '../../data/providers.dart';
import '../collab/alerts_card.dart';

/// "My profile": the only screen every role shares. Name, phone, password, sign out.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageFrame(
        title: 'My profile',
        subtitle: 'Your details and password.',
        child: AsyncBody<Profile?>(
          value: ref.watch(profileProvider),
          onRetry: () => ref.invalidate(profileProvider),
          builder: (me) => me == null
              ? const EmptyState('Sign in to see your profile.')
              : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _DetailsCard(me: me),
                        const SizedBox(height: 16),
                        const AlertsCard(),
                        const SizedBox(height: 16),
                        const _PasswordCard(),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => ref.read(supabaseProvider).auth.signOut(),
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign out'),
                        ),
                      ]),
                    ),
                  ),
                ]),
        ),
      );
}

class _DetailsCard extends ConsumerStatefulWidget {
  const _DetailsCard({required this.me});
  final Profile me;
  @override
  ConsumerState<_DetailsCard> createState() => _DetailsCardState();
}

class _DetailsCardState extends ConsumerState<_DetailsCard> {
  late final _name = TextEditingController(text: widget.me.fullName);
  late final _phone = TextEditingController(text: widget.me.phone ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return showError(context, 'Please enter your name.');
    setState(() => _busy = true);
    try {
      await ref.read(profileRepoProvider).updateMine(fullName: _name.text, phone: _phone.text);
      ref.invalidate(profileProvider);
      if (mounted) showOk(context, 'Saved.');
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your details', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 12),
            TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Email (used to sign in)'),
              child: Text(widget.me.email ?? ''),
            ),
            const SizedBox(height: 4),
            Text('Role: ${widget.me.role.label}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving...' : 'Save')),
          ]),
        ),
      );
}

class _PasswordCard extends ConsumerStatefulWidget {
  const _PasswordCard();
  @override
  ConsumerState<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends ConsumerState<_PasswordCard> {
  final _pw = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pw.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_pw.text.length < 8) return showError(context, 'Use at least 8 characters.');
    if (_pw.text != _again.text) return showError(context, 'The two passwords do not match.');
    setState(() => _busy = true);
    try {
      await ref.read(supabaseProvider).auth.updateUser(UserAttributes(password: _pw.text));
      _pw.clear();
      _again.clear();
      if (mounted) showOk(context, 'Password changed.');
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Password', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('If you sign in with Google you can still set a password here.', style: TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 14),
            TextField(controller: _pw, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
            const SizedBox(height: 12),
            TextField(controller: _again, obscureText: true, decoration: const InputDecoration(labelText: 'Type it again')),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving...' : 'Change password')),
          ]),
        ),
      );
}
