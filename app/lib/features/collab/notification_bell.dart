import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design/theme.dart';
import 'collab_providers.dart';

/// The bell with a red count. [path] is where the list lives for this kind of user.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(unreadCountProvider);
    return IconButton(
      tooltip: n == 0 ? 'Notifications' : '$n new notifications',
      onPressed: () => context.go(path),
      icon: Badge(
        isLabelVisible: n > 0,
        label: Text(n > 99 ? '99+' : '$n'),
        child: const Icon(Icons.notifications_none, color: Brand.ink),
      ),
    );
  }
}
