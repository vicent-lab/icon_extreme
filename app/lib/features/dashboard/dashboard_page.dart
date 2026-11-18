import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/roles.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../install/install_card.dart';
import '../projects/projects_page.dart' show canRunProjects;

class _Stat {
  const _Stat(this.label, this.value);
  final String label;
  final int value;
}

/// Only counts what this role is allowed to see (the database would hide the rest anyway).
final dashboardProvider = FutureProvider.autoDispose<List<_Stat>>((ref) async {
  final role = ref.watch(profileProvider).value?.role ?? AppRole.client;
  final stats = ref.watch(statsRepoProvider);
  return [
    if (canOpen(role, Section.leads)) _Stat('New leads', await stats.count('leads', column: 'stage', equals: 'new')),
    if (canOpen(role, Section.leads)) _Stat('Quoted, waiting', await stats.count('leads', column: 'stage', equals: 'quoted')),
    if (canOpen(role, Section.projects)) _Stat('Ongoing projects', await stats.count('projects', column: 'status', equals: 'ongoing')),
    if (canOpen(role, Section.projects)) _Stat('Completed projects', await stats.count('projects', column: 'status', equals: 'completed')),
    // schedule data is visible to project runners only (editors would see a misleading 0)
    if (canRunProjects(role)) _Stat('Delayed phases', await stats.count('project_phases', column: 'status', equals: 'delayed')),
  ];
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(profileProvider).value?.displayName ?? '';
    return PageFrame(
      title: name.isEmpty ? 'Dashboard' : 'Welcome, ${name.split(' ').first}',
      subtitle: 'What needs your attention today.',
      child: AsyncBody<List<_Stat>>(
        value: ref.watch(dashboardProvider),
        onRetry: () => ref.invalidate(dashboardProvider),
        builder: (stats) => stats.isEmpty
            ? const EmptyState('Nothing to show for your role yet.')
            : SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const InstallCard(), Wrap(spacing: 16, runSpacing: 16, children: [
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
                ])]),
              ),
      ),
    );
  }
}
