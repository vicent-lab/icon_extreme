import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/forms/form_kit.dart';
import '../../data/models/profile.dart';
import '../../data/models/project.dart';
import '../../data/providers.dart';
import 'project_providers.dart';

/// Opens the add/edit project form. Returns true when something was saved.
Future<bool> openProjectForm(BuildContext context, WidgetRef ref, [Project? project]) async {
  List<Profile> people = const [];
  try {
    people = await ref.read(peopleProvider.future);
  } catch (_) {/* the form still works without the people lists */}
  if (!context.mounted) return false;
  final staff = people.where((p) => p.role.isStaff && p.isActive).toList();
  final clients = people.where((p) => !p.role.isStaff && p.isActive).toList();

  String label(Profile p) => p.email == null ? p.displayName : '${p.displayName} (${p.email})';

  final fields = <FieldSpec>[
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
    const FieldSpec('budget_ugx', 'Budget (UGX), private to operations staff', kind: FieldKind.number, min: 0),
    FieldSpec('project_manager', 'Project manager', kind: FieldKind.select, options: [
      const Opt('', 'Not assigned'),
      for (final p in staff) Opt(p.id, label(p)),
    ]),
    FieldSpec('client_id', 'Client account (sees this project in their portal)', kind: FieldKind.select, options: [
      const Opt('', 'No client account'),
      for (final p in clients) Opt(p.id, label(p)),
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

  final saved = await showRecordForm(
    context,
    title: 'Project',
    store: ref.read(projectRepoProvider).store(),
    fields: fields,
    initial: project == null ? null : {...project.row, 'project_manager': '${project.row['project_manager'] ?? ''}', 'client_id': '${project.row['client_id'] ?? ''}'},
    allowDelete: false, // projects are never deleted; hide them or put them on hold
    beforeSave: (d) => {
      ...d,
      for (final k in ['project_manager', 'client_id']) k: (d[k] == '' ? null : d[k]),
    },
  );
  if (saved) {
    ref.invalidate(projectsProvider);
    if (project != null) ref.invalidate(projectProvider(project.id));
  }
  return saved;
}
