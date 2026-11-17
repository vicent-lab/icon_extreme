import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design/tokens.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/roles.dart';
import '../../core/widgets.dart';
import '../../data/models/project.dart';
import '../../data/providers.dart';
import 'project_form.dart';
import 'project_providers.dart';

bool canRunProjects(AppRole role) => role == AppRole.superAdmin || role == AppRole.admin || role == AppRole.projectManager;

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(profileProvider).value?.role ?? AppRole.client;
    final canEdit = canRunProjects(role);
    return PageFrame(
      title: 'Projects',
      subtitle: 'Tap a project to open its schedule, site log, documents and budget.',
      actions: [
        if (canEdit) FilledButton.icon(onPressed: () => openProjectForm(context, ref), icon: const Icon(Icons.add), label: const Text('New project')),
      ],
      child: AsyncBody<List<Project>>(
        value: ref.watch(projectsProvider),
        onRetry: () => ref.invalidate(projectsProvider),
        builder: (rows) => rows.isEmpty
            ? const EmptyState('No projects yet. Press "New project" to start the first one.')
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                itemBuilder: (context, i) => _ProjectRow(project: rows[i], canEdit: canEdit),
              ),
      ),
    );
  }
}

class _ProjectRow extends ConsumerWidget {
  const _ProjectRow({required this.project, required this.canEdit});
  final Project project;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = project;
    return Card(
      child: ListTile(
        onTap: () => context.go('/projects/${p.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p.projectType} · ${p.location} · ${p.progressPct}% done'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: p.progressPct / 100, minHeight: 6, borderRadius: BorderRadius.circular(3)),
          ]),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          StatusChip(pretty(p.status), color: statusColor(p.status)),
          const SizedBox(width: 12),
          Tooltip(
            message: p.isPublished ? 'Visible on website' : 'Hidden from website',
            child: Switch(
              value: p.isPublished,
              onChanged: !canEdit
                  ? null
                  : (v) async {
                      try {
                        await ref.read(projectRepoProvider).store().update(p.id, {'is_published': v});
                        ref.invalidate(projectsProvider);
                      } catch (e) {
                        if (context.mounted) showError(context, friendlyError(e));
                      }
                    },
            ),
          ),
        ]),
      ),
    );
  }
}
