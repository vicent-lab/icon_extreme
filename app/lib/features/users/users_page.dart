import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/roles.dart';
import '../../core/widgets.dart';

final usersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref.watch(supabaseProvider).from('profiles').select('id, full_name, role, is_active').order('created_at');
  return List<Map<String, dynamic>>.from(rows);
});

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(profileProvider).value;
    return PageFrame(
      title: 'Users & roles',
      subtitle: 'New sign-ups start as Client. Give staff roles here. Only a Super admin can create admins.',
      child: AsyncBody<List<Map<String, dynamic>>>(
        value: ref.watch(usersProvider),
        onRetry: () => ref.invalidate(usersProvider),
        builder: (rows) => ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final r = rows[i];
            final isMe = r['id'] == me?.id;
            final role = AppRole.parse(r['role'] as String?);
            final active = r['is_active'] == true;
            // Admins may only hand out non-admin roles; the database enforces this too.
            final options = AppRole.values.where((x) => me?.role == AppRole.superAdmin || !x.isAdmin).toList();
            final locked = isMe || (role.isAdmin && me?.role != AppRole.superAdmin);

            Future<void> save(AppRole newRole, bool isActive) async {
              try {
                await ref.read(supabaseProvider).rpc('set_user_role', params: {
                  'target': r['id'], 'new_role': newRole.db, 'active': isActive,
                });
                ref.invalidate(usersProvider);
              } catch (_) {
                if (context.mounted) showError(context, 'Could not change this user.');
              }
            }

            return Card(
              child: ListTile(
                title: Text(((r['full_name'] as String?) ?? '').isEmpty ? '(no name yet)' : '${r['full_name']}${isMe ? '  (you)' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(active ? 'Active' : 'Disabled'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButton<AppRole>(
                    value: options.contains(role) ? role : null,
                    hint: Text(role.label),
                    underline: const SizedBox.shrink(),
                    items: [for (final x in options) DropdownMenuItem(value: x, child: Text(x.label))],
                    onChanged: locked ? null : (v) => v == null ? null : save(v, active),
                  ),
                  const SizedBox(width: 8),
                  Switch(value: active, onChanged: locked ? null : (v) => save(role, v)),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}
