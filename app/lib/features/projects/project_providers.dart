import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/profile.dart';
import '../../data/models/project.dart';
import '../../data/providers.dart';

final projectsProvider = FutureProvider.autoDispose<List<Project>>((ref) => ref.watch(projectRepoProvider).list());

final projectProvider = FutureProvider.autoDispose.family<Project?, int>((ref, id) => ref.watch(projectRepoProvider).get(id));

final phasesProvider = FutureProvider.autoDispose.family<List<Phase>, int>((ref, id) => ref.watch(childrenProvider).phases.list(id));
final logsProvider = FutureProvider.autoDispose.family<List<SiteLog>, int>((ref, id) => ref.watch(childrenProvider).logs.list(id));
final documentsProvider = FutureProvider.autoDispose.family<List<ProjectDocument>, int>((ref, id) => ref.watch(childrenProvider).documents.list(id));
final expensesProvider = FutureProvider.autoDispose.family<List<Expense>, int>((ref, id) => ref.watch(childrenProvider).expenses.list(id));

/// Every person this role can see (admins and staff only; clients get just themselves).
final peopleProvider = FutureProvider.autoDispose<List<Profile>>((ref) => ref.watch(profileRepoProvider).all());

/// The projects linked to the signed-in client account.
final myProjectsProvider = FutureProvider.autoDispose<List<Project>>((ref) async {
  final me = ref.watch(profileProvider).value;
  if (me == null) return const [];
  return ref.watch(projectRepoProvider).mine(me.id);
});
