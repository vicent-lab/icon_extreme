import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/form_kit.dart';
import '../../core/providers.dart';
import '../../core/roles.dart';
import '../../core/widgets.dart';
import '../leads/leads_page.dart' show pretty;

final projectsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref
      .watch(supabaseProvider)
      .from('projects')
      .select('id, title, location, project_type, status, progress_pct, is_published')
      .order('display_order')
      .order('created_at', ascending: false)
      .limit(200);
  return List<Map<String, dynamic>>.from(rows);
});

Color statusColor(String s) => switch (s) {
      'ongoing' => Colors.orange.shade800,
      'completed' => Colors.green.shade700,
      'on_hold' => Colors.red.shade700,
      'done' => Colors.green.shade700,
      'in_progress' => Colors.orange.shade800,
      'delayed' => Colors.red.shade700,
      _ => Colors.blueGrey,
    };

/// People you can pick as project manager / client (from profiles).
final peopleProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref.watch(supabaseProvider).from('profiles').select('id, full_name, role').order('full_name');
  return List<Map<String, dynamic>>.from(rows);
});

String personLabel(Map<String, dynamic> p) {
  final n = '${p['full_name'] ?? ''}'.trim();
  return n.isEmpty ? 'Unnamed (${'${p['id']}'.substring(0, 6)})' : n;
}

Future<List<FieldSpec>> projectFields(WidgetRef ref) async {
  List<Map<String, dynamic>> people = [];
  try {
    people = await ref.read(peopleProvider.future);
  } catch (_) {/* form still works without the people lists */}
  final staff = people.where((p) => AppRole.parse(p['role'] as String?).isStaff).toList();
  final clients = people.where((p) => !AppRole.parse(p['role'] as String?).isStaff).toList();
  return [
    const FieldSpec('title', 'Project name', required: true),
    const FieldSpec('slug', 'Web address', kind: FieldKind.slug, from: 'title'),
    const FieldSpec('project_type', 'Type of work', required: true, hint: 'e.g. Residential building, Road, Renovation'),
    const FieldSpec('location', 'Location', required: true),
    const FieldSpec('client_name', 'Client name (as shown to the team)'),
    const FieldSpec('status', 'Status', kind: FieldKind.select, required: true, options: [
      Opt('upcoming', 'Upcoming'), Opt('ongoing', 'Ongoing'), Opt('completed', 'Completed'), Opt('on_hold', 'On hold'),
    ]),
    const FieldSpec('start_date', 'Start date', kind: FieldKind.date),
    const FieldSpec('end_date', 'Expected end date', kind: FieldKind.date),
    const FieldSpec('budget_ugx', 'Budget (UGX)', kind: FieldKind.number, min: 0),
    FieldSpec('project_manager', 'Project manager', kind: FieldKind.select, options: [
      const Opt('', 'Not assigned'),
      for (final p in staff) Opt('${p['id']}', personLabel(p)),
    ]),
    FieldSpec('client_id', 'Client account (can see this project later)', kind: FieldKind.select, options: [
      const Opt('', 'No client account'),
      for (final p in clients) Opt('${p['id']}', personLabel(p)),
    ]),
    const FieldSpec('summary', 'Short summary', kind: FieldKind.multiline),
    const FieldSpec('description', 'Full description', kind: FieldKind.multiline),
    const FieldSpec('challenge', 'The challenge', kind: FieldKind.multiline),
    const FieldSpec('solution', 'Our solution', kind: FieldKind.multiline),
    const FieldSpec('results', 'The result', kind: FieldKind.multiline),
    const FieldSpec('featured_image', 'Main picture', kind: FieldKind.image, folder: 'projects'),
    const FieldSpec('is_featured', 'Show on the home page', kind: FieldKind.toggle),
    const FieldSpec('is_published', 'Visible on the website', kind: FieldKind.toggle),
  ];
}

Map<String, dynamic> projectPrepare(Map<String, dynamic> d) {
  final out = {...d};
  for (final k in ['project_manager', 'client_id']) {
    if (out[k] == '') out[k] = null;
  }
  return out;
}

Map<String, dynamic> projectInitial(Map<String, dynamic> r) =>
    {...r, 'project_manager': '${r['project_manager'] ?? ''}', 'client_id': '${r['client_id'] ?? ''}'};

Future<bool> openProjectForm(BuildContext context, WidgetRef ref, [Map<String, dynamic>? row]) async {
  final fields = await projectFields(ref);
  if (!context.mounted) return false;
  final saved = await showRecordForm(
    context,
    title: 'Project',
    table: 'projects',
    fields: fields,
    initial: row == null ? null : projectInitial(row),
    allowDelete: false, // projects are never deleted; hide or put on hold instead
    beforeSave: projectPrepare,
  );
  if (saved) ref.invalidate(projectsProvider);
  return saved;
}

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(profileProvider).value?.role ?? AppRole.client;
    final canEdit = role == AppRole.superAdmin || role == AppRole.admin || role == AppRole.projectManager;
    return PageFrame(
      title: 'Projects',
      subtitle: 'Tap a project to open its schedule, site log, documents and budget.',
      actions: [
        if (canEdit) FilledButton.icon(onPressed: () => openProjectForm(context, ref), icon: const Icon(Icons.add), label: const Text('New project')),
      ],
      child: AsyncBody<List<Map<String, dynamic>>>(
        value: ref.watch(projectsProvider),
        onRetry: () => ref.invalidate(projectsProvider),
        builder: (rows) => rows.isEmpty
            ? const Center(child: Text('No projects yet. Press "New project" to start the first one.'))
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = rows[i];
                  final pct = (r['progress_pct'] as num?)?.toInt() ?? 0;
                  return Card(
                    child: ListTile(
                      onTap: () => context.go('/projects/${r['id']}'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text('${r['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${r['project_type']} · ${r['location']} · $pct% done'),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: pct / 100, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                        ]),
                      ),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        StatusChip(pretty('${r['status']}'), color: statusColor('${r['status']}')),
                        const SizedBox(width: 12),
                        Tooltip(
                          message: r['is_published'] == true ? 'Visible on website' : 'Hidden from website',
                          child: Switch(
                            value: r['is_published'] == true,
                            onChanged: !canEdit
                                ? null
                                : (v) async {
                                    try {
                                      await ref.read(supabaseProvider).from('projects').update({'is_published': v}).eq('id', r['id']);
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
                },
              ),
      ),
    );
  }
}
