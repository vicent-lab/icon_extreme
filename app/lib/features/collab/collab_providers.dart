import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/collab.dart';
import '../../data/providers.dart';

/// Live list of my notifications (updates the moment something happens).
final notificationsProvider = StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final me = ref.watch(profileProvider.select((p) => p.value?.id));
  if (me == null) return const Stream.empty();
  return ref.watch(collabRepoProvider).notifications(me);
});

final unreadCountProvider = Provider.autoDispose<int>((ref) => ref.watch(notificationsProvider).value?.where((n) => n.unread).length ?? 0);

final messagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, int>((ref, id) => ref.watch(collabRepoProvider).messages(id));

final requestsProvider = FutureProvider.autoDispose.family<List<ProjectRequest>, int>((ref, id) => ref.watch(collabRepoProvider).requests(id));

final paymentsProvider = FutureProvider.autoDispose.family<List<Payment>, int>((ref, id) => ref.watch(collabRepoProvider).payments(id));
