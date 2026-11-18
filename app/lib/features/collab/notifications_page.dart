import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design/theme.dart';
import '../../core/design/tokens.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models/collab.dart';
import '../../data/providers.dart';
import 'collab_providers.dart';

IconData _icon(String kind) => switch (kind) {
      'message' => Icons.chat_bubble_outline,
      'approval' || 'decision' => Icons.task_alt,
      'change' => Icons.edit_note,
      'update' => Icons.photo_camera_outlined,
      'document' => Icons.description_outlined,
      'phase' => Icons.flag_outlined,
      'delay' => Icons.warning_amber_outlined,
      'lead' => Icons.inbox_outlined,
      _ => Icons.notifications_none,
    };

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, AppNotification n) async {
    if (n.unread) {
      try {
        await ref.read(collabRepoProvider).markRead(n.id);
      } catch (_) {/* still open the link */}
    }
    if (n.link != null && context.mounted) context.go(n.link!);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return PageFrame(
      title: 'Notifications',
      subtitle: 'Updates, messages and approvals, newest first.',
      actions: [
        if (unread > 0)
          OutlinedButton(
            onPressed: () async {
              final me = ref.read(profileProvider).value?.id;
              if (me != null) await ref.read(collabRepoProvider).markAllRead(me);
            },
            child: const Text('Mark all as read'),
          ),
      ],
      child: AsyncBody<List<AppNotification>>(
        value: ref.watch(notificationsProvider),
        onRetry: () => ref.invalidate(notificationsProvider),
        builder: (rows) => rows.isEmpty
            ? const EmptyState('Nothing yet. You will see site updates, messages and approvals here.')
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.xs),
                itemBuilder: (context, i) {
                  final n = rows[i];
                  return Card(
                    color: n.unread ? Colors.white : Brand.concrete,
                    child: ListTile(
                      onTap: () => _open(context, ref, n),
                      leading: CircleAvatar(
                        backgroundColor: n.unread ? Brand.ink : Colors.black12,
                        child: Icon(_icon(n.kind), color: n.unread ? Brand.gold : Colors.black54, size: 20),
                      ),
                      title: Text(n.title, style: TextStyle(fontWeight: n.unread ? FontWeight.w800 : FontWeight.w500)),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (n.body != null) Text(n.body!, maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text(dateTime(n.createdAt), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ]),
                      trailing: n.unread ? const Icon(Icons.circle, size: 10, color: Brand.gold) : null,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
