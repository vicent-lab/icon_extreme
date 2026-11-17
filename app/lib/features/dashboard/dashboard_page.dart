import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../core/roles.dart';
import '../../core/widgets.dart';

class _Stat {
  _Stat(this.label, this.value);
  final String label;
  final int value;
}

/// Only counts what this role is allowed to see (the database would hide the rest anyway).
final dashboardProvider = FutureProvider.autoDispose<List<_Stat>>((ref) async {
  final role = ref.watch(profileProvider).value?.role ?? AppRole.client;
  final db = ref.watch(supabaseProvider);

  Future<int> count(String table, [String? col, Object? val]) async {
    var q = db.from(table).select('id');
    if (col != null) q = q.eq(col, val!);
    return (await q.count(CountOption.exact)).count;
  }

  return [
    if (canOpen(role, Section.leads)) _Stat('New leads', await count('leads', 'stage', 'new')),
    if (canOpen(role, Section.leads)) _Stat('Quoted, waiting', await count('leads', 'stage', 'quoted')),
    if (canOpen(role, Section.projects)) _Stat('Ongoing projects', await count('projects', 'status', 'ongoing')),
    if (canOpen(role, Section.projects)) _Stat('Completed projects', await count('projects', 'status', 'completed')),
    // schedule data is visible to project runners only (editors would see a misleading 0)
    if (role == AppRole.superAdmin || role == AppRole.admin || role == AppRole.projectManager)
      _Stat('Delayed phases', await count('project_phases', 'status', 'delayed')),
  ];
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(profileProvider).value?.fullName ?? '';
    return PageFrame(
      title: name.isEmpty ? 'Dashboard' : 'Welcome, ${name.split(' ').first}',
      subtitle: 'What needs your attention today.',
      child: AsyncBody<List<_Stat>>(
        value: ref.watch(dashboardProvider),
        onRetry: () => ref.invalidate(dashboardProvider),
        builder: (stats) => stats.isEmpty
            ? const Text('Nothing to show for your role yet.')
            : Wrap(spacing: 16, runSpacing: 16, children: [
                for (final s in stats)
                  SizedBox(
                    width: 220,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.label, style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 8),
                          Text('${s.value}', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                  ),
              ]),
      ),
    );
  }
}
