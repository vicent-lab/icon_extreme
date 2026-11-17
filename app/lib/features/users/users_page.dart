import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/tokens.dart';
import '../../core/errors.dart';
import '../../core/roles.dart';
import '../../core/widgets.dart';
import '../../data/models/profile.dart';
import '../../data/providers.dart';
import '../../data/repositories/profile_repository.dart';
import '../projects/project_providers.dart';

final usersProvider = FutureProvider.autoDispose<List<Profile>>((ref) => ref.watch(profileRepoProvider).all());

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(profileProvider).value;
    return PageFrame(
      title: 'Users & roles',
      subtitle: 'People who sign up wait here for approval. Invite someone to skip the wait.',
      actions: [
        FilledButton.icon(
          onPressed: () async {
            await showDialog<void>(context: context, builder: (_) => const _InviteDialog());
            ref.invalidate(usersProvider);
          },
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Invite someone'),
        ),
      ],
      child: AsyncBody<List<Profile>>(
        value: ref.watch(usersProvider),
        onRetry: () => ref.invalidate(usersProvider),
        builder: (rows) {
          // Waiting people first: they are the ones who need a decision.
          final sorted = [...rows]..sort((a, b) {
              int rank(Profile p) => p.access == Access.pending ? 0 : (p.access == Access.active ? 1 : 2);
              return rank(a).compareTo(rank(b));
            });
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: sorted.length,
            separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
            itemBuilder: (context, i) => _UserRow(user: sorted[i], me: me),
          );
        },
      ),
    );
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow({required this.user, required this.me});
  final Profile user;
  final Profile? me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMe = user.id == me?.id;
    final iAmSuper = me?.role == AppRole.superAdmin;
    // Admins may only hand out non-admin roles; the database enforces this too.
    final options = AppRole.values.where((x) => iAmSuper || !x.isAdmin).toList();
    final locked = isMe || (user.role.isAdmin && !iAmSuper);

    Future<void> save(AppRole role, bool active, {String? done}) async {
      try {
        await ref.read(profileRepoProvider).setRole(user.id, role, active);
        ref.invalidate(usersProvider);
        if (context.mounted && done != null) showOk(context, done);
      } catch (e) {
        if (context.mounted) showError(context, friendlyError(e));
      }
    }

    final (label, color) = switch (user.access) {
      Access.pending => ('Waiting for approval', Tone.active),
      Access.active => ('Active', Tone.done),
      Access.suspended => ('Suspended', Tone.problem),
    };

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text('${user.displayName}${isMe ? '  (you)' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (user.email != null) Text(user.email!, style: const TextStyle(color: Colors.black54)),
            StatusChip(label, color: color),
          ]),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (user.access == Access.pending && !locked)
            FilledButton(
              onPressed: () => save(user.role, true, done: '${user.displayName} can now sign in.'),
              child: const Text('Approve'),
            ),
          const SizedBox(width: 8),
          DropdownButton<AppRole>(
            value: options.contains(user.role) ? user.role : null,
            hint: Text(user.role.label),
            underline: const SizedBox.shrink(),
            items: [for (final x in options) DropdownMenuItem(value: x, child: Text(x.label))],
            onChanged: locked ? null : (v) => v == null ? null : save(v, user.isActive),
          ),
          if (user.access != Access.pending) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: user.isActive ? 'Active. Switch off to suspend.' : 'Suspended. Switch on to restore.',
              child: Switch(value: user.isActive, onChanged: locked ? null : (v) => save(user.role, v)),
            ),
          ],
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- invite

class _InviteDialog extends ConsumerStatefulWidget {
  const _InviteDialog();
  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  AppRole _role = AppRole.client;
  int? _projectId;
  bool _busy = false;
  InviteResult? _result;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return showError(context, 'Enter a valid email address.');
    setState(() => _busy = true);
    try {
      final r = await ref.read(profileRepoProvider).invite(email: email, fullName: _name.text, role: _role, projectId: _role == AppRole.client ? _projectId : null);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    if (r != null) return _InviteDone(result: r, name: _name.text.trim());

    final me = ref.watch(profileProvider).value;
    final roles = AppRole.values.where((x) => me?.role == AppRole.superAdmin || !x.isAdmin).toList();
    final projects = ref.watch(projectsProvider).value ?? const [];
    return AlertDialog(
      title: const Text('Invite someone'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 12),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email *')),
            const SizedBox(height: 12),
            DropdownButtonFormField<AppRole>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [for (final x in roles) DropdownMenuItem(value: x, child: Text(x.label))],
              onChanged: (v) => setState(() => _role = v ?? AppRole.client),
            ),
            if (_role == AppRole.client) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _projectId,
                decoration: const InputDecoration(labelText: 'Their project (optional)'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Link a project later')),
                  for (final p in projects) DropdownMenuItem<int?>(value: p.id, child: Text(p.title, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _projectId = v),
              ),
            ],
            const SizedBox(height: 8),
            const Text('You get a private link to send them. It works once.', style: TextStyle(color: Colors.black54, fontSize: 12)),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _send, child: const Text('Create invite')),
      ],
    );
  }
}

class _InviteDone extends StatelessWidget {
  const _InviteDone({required this.result, required this.name});
  final InviteResult result;
  final String name;

  @override
  Widget build(BuildContext context) {
    final link = result.link;
    final who = name.isEmpty ? result.email : name;
    final text = 'Hello $who, ICON Construction has set up your account. Open this link to choose your password: $link';
    return AlertDialog(
      title: Text(link == null ? 'Already has an account' : 'Invite ready'),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(result.message),
          if (link != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(Radii.control)),
              child: SelectableText(link, style: const TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 8),
            const Text('Send it only to this person. It can be used once.', style: TextStyle(color: Colors.black54, fontSize: 12)),
          ],
        ]),
      ),
      actions: [
        if (link != null) ...[
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) showOk(context, 'Link copied.');
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
          ),
          TextButton.icon(
            onPressed: () => launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('WhatsApp'),
          ),
        ],
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}
