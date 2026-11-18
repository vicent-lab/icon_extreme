import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design/tokens.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models/project.dart';
import '../../data/providers.dart';
import '../collab/approvals_view.dart';
import '../collab/chat_view.dart';
import '../collab/payments_view.dart';
import 'project_form.dart';
import 'project_providers.dart';
import 'projects_page.dart' show canRunProjects;
import 'tabs/budget_tab.dart';
import 'tabs/documents_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/schedule_tab.dart';
import 'tabs/site_log_tab.dart';

/// Staff view of one project. Clients use the read-only portal instead (features/portal).
class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, required this.id, this.tab});
  final int id;
  final String? tab; // opens straight onto a tab, e.g. from a notification

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(profileProvider).value?.role;
    final ops = role != null && canRunProjects(role);
    return AsyncBody<Project?>(
      value: ref.watch(projectProvider(id)),
      onRetry: () => ref.invalidate(projectProvider(id)),
      builder: (p) {
        if (p == null) return const EmptyState('This project was not found.');
        final tabs = <(String, String, Widget)>[
          ('overview', 'Overview', OverviewTab(project: p, ops: ops)),
          if (ops) ('schedule', 'Schedule', ScheduleTab(projectId: id)),
          if (ops) ('log', 'Site log', SiteLogTab(projectId: id)),
          if (ops) ('messages', 'Messages', ChatView(projectId: id)),
          if (ops) ('approvals', 'Approvals', ApprovalsView(projectId: id, asClient: false)),
          if (ops) ('payments', 'Payments', PaymentsView(projectId: id, canEdit: true)),
          if (ops) ('documents', 'Documents', DocumentsTab(projectId: id)),
          if (ops) ('budget', 'Budget', BudgetTab(projectId: id, budget: p.budgetUgx)),
        ];
        final start = tabs.indexWhere((t) => t.$1 == tab);
        final narrow = MediaQuery.sizeOf(context).width < 640;
        return DefaultTabController(
          length: tabs.length,
          initialIndex: start < 0 ? 0 : start,
          child: Padding(
            padding: EdgeInsets.fromLTRB(narrow ? 12 : 28, 20, narrow ? 12 : 28, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconButton(tooltip: 'Back to projects', onPressed: () => context.go('/projects'), icon: const Icon(Icons.arrow_back)),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text('${p.projectType} · ${p.location}', style: const TextStyle(color: Colors.black54)),
                  ]),
                ),
                StatusChip(pretty(p.status), color: statusColor(p.status)),
                if (ops && !narrow) ...[
                  const SizedBox(width: Space.md),
                  OutlinedButton.icon(
                    onPressed: () => openProjectForm(context, ref, p),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                ],
                if (ops && narrow) IconButton(tooltip: 'Edit project', onPressed: () => openProjectForm(context, ref, p), icon: const Icon(Icons.edit_outlined)),
              ]),
              const SizedBox(height: Space.sm),
              TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final t in tabs) Tab(text: t.$2)]),
              Expanded(child: TabBarView(children: [for (final t in tabs) t.$3])),
            ]),
          ),
        );
      },
    );
  }
}
