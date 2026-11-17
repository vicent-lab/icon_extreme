import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/form_kit.dart';
import '../../core/providers.dart';
import '../../core/roles.dart';
import '../../core/widgets.dart';
import '../leads/leads_page.dart' show pretty;
import 'projects_page.dart';

// ---------------------------------------------------------------- data

typedef Rows = List<Map<String, dynamic>>;

final projectProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, int>((ref, id) async {
  return await ref.watch(supabaseProvider).from('projects').select().eq('id', id).maybeSingle();
});

final phasesProvider = FutureProvider.autoDispose.family<Rows, int>((ref, id) async {
  final r = await ref.watch(supabaseProvider).from('project_phases').select().eq('project_id', id).order('sort_order').order('start_date');
  return Rows.from(r);
});
final logsProvider = FutureProvider.autoDispose.family<Rows, int>((ref, id) async {
  final r = await ref.watch(supabaseProvider).from('site_logs').select().eq('project_id', id).order('log_date', ascending: false).limit(200);
  return Rows.from(r);
});
final docsProvider = FutureProvider.autoDispose.family<Rows, int>((ref, id) async {
  final r = await ref.watch(supabaseProvider).from('project_documents').select().eq('project_id', id).order('created_at', ascending: false);
  return Rows.from(r);
});
final expensesProvider = FutureProvider.autoDispose.family<Rows, int>((ref, id) async {
  final r = await ref.watch(supabaseProvider).from('project_expenses').select().eq('project_id', id).order('spent_on', ascending: false).limit(500);
  return Rows.from(r);
});

final _ugx = NumberFormat.decimalPattern();
String ugx(Object? v) => 'UGX ${_ugx.format(num.tryParse('${v ?? 0}') ?? 0)}';

/// The date picker field is "required" for log/expense dates: new records start on today.
Map<String, dynamic> _dropNullDates(Map<String, dynamic> d) => {...d}..removeWhere((k, v) => v == null && (k == 'log_date' || k == 'spent_on'));

// ---------------------------------------------------------------- page

class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(profileProvider).value?.role ?? AppRole.client;
    final ops = role == AppRole.superAdmin || role == AppRole.admin || role == AppRole.projectManager;
    final project = ref.watch(projectProvider(id));

    return AsyncBody<Map<String, dynamic>?>(
      value: project,
      onRetry: () => ref.invalidate(projectProvider(id)),
      builder: (p) {
        if (p == null) return const Center(child: Text('This project was not found.'));
        final tabs = <(String, Widget)>[
          ('Overview', _Overview(project: p, ops: ops)),
          if (ops) ('Schedule', _Schedule(projectId: id)),
          if (ops) ('Site log', _SiteLog(projectId: id)),
          if (ops) ('Documents', _Documents(projectId: id)),
          if (ops) ('Budget', _Budget(projectId: id, budget: p['budget_ugx'])),
        ];
        return DefaultTabController(
          length: tabs.length,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconButton(tooltip: 'Back to projects', onPressed: () => context.go('/projects'), icon: const Icon(Icons.arrow_back)),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p['title']}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    Text('${p['project_type']} · ${p['location']}', style: const TextStyle(color: Colors.black54)),
                  ]),
                ),
                StatusChip(pretty('${p['status']}'), color: statusColor('${p['status']}')),
                if (ops) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (await openProjectForm(context, ref, p)) ref.invalidate(projectProvider(id));
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                ],
              ]),
              const SizedBox(height: 8),
              TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final t in tabs) Tab(text: t.$1)]),
              Expanded(child: TabBarView(children: [for (final t in tabs) t.$2])),
            ]),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- overview

class _Overview extends ConsumerWidget {
  const _Overview({required this.project, required this.ops});
  final Map<String, dynamic> project;
  final bool ops;

  Widget _row(String k, Object? v) => v == null || '$v'.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 150, child: Text(k, style: const TextStyle(color: Colors.black54))),
            Expanded(child: SelectableText('$v')),
          ]),
        );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pct = (project['progress_pct'] as num?)?.toInt() ?? 0;
    final spent = ops
        ? ref.watch(expensesProvider(project['id'] as int)).value?.fold<num>(0, (s, e) => s + (num.tryParse('${e['amount_ugx']}') ?? 0))
        : null;
    return ListView(padding: const EdgeInsets.only(top: 16, bottom: 24), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Progress: $pct%', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: pct / 100, minHeight: 10, borderRadius: BorderRadius.circular(5)),
            const SizedBox(height: 6),
            const Text('This moves by itself when you update the progress of the schedule phases.', style: TextStyle(color: Colors.black54, fontSize: 12)),
            if (project['budget_ugx'] != null && spent != null) ...[
              const SizedBox(height: 16),
              Text('Spent ${ugx(spent)} of ${ugx(project['budget_ugx'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            _row('Client', project['client_name']),
            _row('Starts', project['start_date']),
            _row('Expected end', project['end_date']),
            _row('Budget', project['budget_ugx'] == null ? null : ugx(project['budget_ugx'])),
            _row('On the website', project['is_published'] == true ? 'Yes' : 'No'),
            _row('Summary', project['summary']),
            _row('Description', project['description']),
            _row('Challenge', project['challenge']),
            _row('Solution', project['solution']),
            _row('Result', project['results']),
          ]),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- schedule

class _Schedule extends ConsumerWidget {
  const _Schedule({required this.projectId});
  final int projectId;

  Future<void> _edit(BuildContext context, WidgetRef ref, [Map<String, dynamic>? row]) async {
    List<Map<String, dynamic>> staff = [];
    try {
      staff = (await ref.read(peopleProvider.future)).where((p) => AppRole.parse(p['role'] as String?).isStaff).toList();
    } catch (_) {}
    if (!context.mounted) return;
    final saved = await showRecordForm(
      context,
      title: 'Phase',
      table: 'project_phases',
      initial: row == null ? null : {...row, 'assigned_to': '${row['assigned_to'] ?? ''}'},
      extra: {'project_id': projectId},
      beforeSave: (d) => {...d, 'assigned_to': (d['assigned_to'] == '' ? null : d['assigned_to'])},
      fields: [
        const FieldSpec('name', 'Phase name', required: true, hint: 'e.g. Foundation, Roofing, Finishing'),
        const FieldSpec('description', 'Notes', kind: FieldKind.multiline),
        const FieldSpec('start_date', 'Start', kind: FieldKind.date),
        const FieldSpec('end_date', 'End', kind: FieldKind.date),
        const FieldSpec('status', 'Status', kind: FieldKind.select, required: true, options: [
          Opt('planned', 'Planned'), Opt('in_progress', 'In progress'), Opt('done', 'Done'), Opt('delayed', 'Delayed'),
        ]),
        const FieldSpec('progress_pct', 'How much is done (0 to 100)', kind: FieldKind.number, min: 0, max: 100),
        FieldSpec('assigned_to', 'Responsible person', kind: FieldKind.select, options: [
          const Opt('', 'Nobody yet'),
          for (final p in staff) Opt('${p['id']}', personLabel(p)),
        ]),
        const FieldSpec('sort_order', 'Order in the list (small number first)', kind: FieldKind.number),
      ],
    );
    if (saved) {
      ref.invalidate(phasesProvider(projectId));
      ref.invalidate(projectProvider(projectId)); // progress is rolled up by the database
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => _TabFrame(
        addLabel: 'Add phase',
        onAdd: () => _edit(context, ref),
        child: AsyncBody<Rows>(
          value: ref.watch(phasesProvider(projectId)),
          onRetry: () => ref.invalidate(phasesProvider(projectId)),
          builder: (rows) {
            if (rows.isEmpty) return const _Empty('No schedule yet. Add the phases of the job (foundation, walls, roof...) with dates.');
            final dates = <DateTime>[
              for (final r in rows) ...[
                if (DateTime.tryParse('${r['start_date']}') != null) DateTime.parse('${r['start_date']}'),
                if (DateTime.tryParse('${r['end_date']}') != null) DateTime.parse('${r['end_date']}'),
              ],
            ]..sort();
            final first = dates.isEmpty ? null : dates.first;
            final last = dates.isEmpty ? null : dates.last;
            final span = (first == null || last == null) ? 1 : (last.difference(first).inDays + 1).clamp(1, 100000);
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = rows[i];
                final s = DateTime.tryParse('${r['start_date']}');
                final e = DateTime.tryParse('${r['end_date']}');
                final pct = (r['progress_pct'] as num?)?.toInt() ?? 0;
                final color = statusColor('${r['status']}');
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _edit(context, ref, r),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                          StatusChip(pretty('${r['status']}'), color: color),
                        ]),
                        const SizedBox(height: 4),
                        Text([
                          if (s != null) DateFormat.yMMMd().format(s),
                          if (e != null) DateFormat.yMMMd().format(e),
                        ].join(' to '), style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        const SizedBox(height: 10),
                        // Timeline bar: where this phase sits inside the whole job, filled by progress.
                        LayoutBuilder(builder: (context, c) {
                          if (s == null || e == null || first == null) {
                            return LinearProgressIndicator(value: pct / 100, minHeight: 8, borderRadius: BorderRadius.circular(4));
                          }
                          final left = c.maxWidth * s.difference(first).inDays / span;
                          final width = (c.maxWidth * (e.difference(s).inDays + 1) / span).clamp(8.0, c.maxWidth);
                          return SizedBox(
                            height: 12,
                            child: Stack(children: [
                              Container(decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(6))),
                              Positioned(
                                left: left.clamp(0.0, c.maxWidth - width),
                                width: width,
                                top: 0,
                                bottom: 0,
                                child: Stack(children: [
                                  Container(decoration: BoxDecoration(color: color.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(6))),
                                  FractionallySizedBox(
                                    widthFactor: pct / 100,
                                    child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
                                  ),
                                ]),
                              ),
                            ]),
                          );
                        }),
                        const SizedBox(height: 4),
                        Text('$pct% done', style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}

// ---------------------------------------------------------------- site log

class _SiteLog extends ConsumerWidget {
  const _SiteLog({required this.projectId});
  final int projectId;

  Future<void> _edit(BuildContext context, WidgetRef ref, [Map<String, dynamic>? row]) async {
    final saved = await showRecordForm(
      context,
      title: 'Site log',
      table: 'site_logs',
      initial: row,
      extra: {'project_id': projectId},
      beforeSave: _dropNullDates,
      fields: const [
        FieldSpec('log_date', 'Date', kind: FieldKind.date, required: true),
        FieldSpec('weather', 'Weather', hint: 'e.g. Sunny, light rain'),
        FieldSpec('workers_on_site', 'Workers on site', kind: FieldKind.number, min: 0),
        FieldSpec('work_done', 'Work done today', kind: FieldKind.multiline, required: true),
        FieldSpec('issues', 'Problems or delays', kind: FieldKind.multiline),
        FieldSpec('safety_notes', 'Safety notes', kind: FieldKind.multiline),
        FieldSpec('client_visible', 'Let the client see this entry', kind: FieldKind.toggle),
      ],
    );
    if (saved) ref.invalidate(logsProvider(projectId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => _TabFrame(
        addLabel: 'Add today\'s log',
        onAdd: () => _edit(context, ref),
        child: AsyncBody<Rows>(
          value: ref.watch(logsProvider(projectId)),
          onRetry: () => ref.invalidate(logsProvider(projectId)),
          builder: (rows) => rows.isEmpty
              ? const _Empty('No site logs yet. Write a short note each day: weather, workers, work done, problems.')
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final d = DateTime.tryParse('${r['log_date']}');
                    return Card(
                      child: ListTile(
                        onTap: () => _edit(context, ref, r),
                        title: Text(d == null ? '${r['log_date']}' : DateFormat.yMMMEd().format(d), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text([
                              if (r['weather'] != null) '${r['weather']}',
                              if (r['workers_on_site'] != null) '${r['workers_on_site']} workers',
                            ].join(' · ')),
                            const SizedBox(height: 4),
                            Text('${r['work_done']}', maxLines: 3, overflow: TextOverflow.ellipsis),
                            if (r['issues'] != null) Text('Problem: ${r['issues']}', style: TextStyle(color: Colors.red.shade700)),
                          ]),
                        ),
                        trailing: r['client_visible'] == true ? const StatusChip('Client sees', color: Colors.green) : null,
                      ),
                    );
                  },
                ),
        ),
      );
}

// ---------------------------------------------------------------- documents

const _docCategories = [
  Opt('plan', 'Plan'), Opt('drawing', 'Drawing'), Opt('contract', 'Contract'), Opt('permit', 'Permit'),
  Opt('quotation', 'Quotation'), Opt('invoice', 'Invoice'), Opt('report', 'Report'), Opt('photo', 'Photo'), Opt('other', 'Other'),
];

class _Documents extends ConsumerWidget {
  const _Documents({required this.projectId});
  final int projectId;

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final done = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => _UploadDialog(projectId: projectId));
    if (done == true) ref.invalidate(docsProvider(projectId));
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Map<String, dynamic> r) async {
    try {
      final url = await ref.read(supabaseProvider).storage.from('project-documents').createSignedUrl('${r['storage_path']}', 120);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) showError(context, friendlyError(e));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Map<String, dynamic> r) async {
    if (!await confirmDelete(context, '"${r['title']}"')) return;
    try {
      final c = ref.read(supabaseProvider);
      final res = await c.from('project_documents').delete().eq('id', r['id']).select('id');
      if ((res as List).isEmpty) throw 'denied';
      await c.storage.from('project-documents').remove(['${r['storage_path']}']);
      ref.invalidate(docsProvider(projectId));
    } catch (e) {
      if (context.mounted) showError(context, e is String ? 'Your role is not allowed to delete this.' : friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => _TabFrame(
        addLabel: 'Upload document',
        onAdd: () => _upload(context, ref),
        child: AsyncBody<Rows>(
          value: ref.watch(docsProvider(projectId)),
          onRetry: () => ref.invalidate(docsProvider(projectId)),
          builder: (rows) => rows.isEmpty
              ? const _Empty('No documents yet. Upload plans, drawings, contracts and permits here. They stay private unless you let the client see them.')
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final kb = ((r['size_bytes'] as num?) ?? 0) / 1024;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined),
                        onTap: () => _open(context, ref, r),
                        title: Text('${r['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${pretty('${r['category']}')} · ${r['file_name'] ?? ''}${kb > 0 ? ' · ${kb >= 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '${kb.round()} KB'}' : ''}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (r['client_visible'] == true) const StatusChip('Client sees', color: Colors.green),
                          IconButton(
                            tooltip: 'Change title or visibility',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final saved = await showRecordForm(
                                context,
                                title: 'Document',
                                table: 'project_documents',
                                initial: r,
                                allowDelete: false,
                                fields: const [
                                  FieldSpec('title', 'Title', required: true),
                                  FieldSpec('category', 'Type', kind: FieldKind.select, required: true, options: _docCategories),
                                  FieldSpec('client_visible', 'Let the client see this document', kind: FieldKind.toggle),
                                ],
                              );
                              if (saved) ref.invalidate(docsProvider(projectId));
                            },
                          ),
                          IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, ref, r)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      );
}

class _UploadDialog extends ConsumerStatefulWidget {
  const _UploadDialog({required this.projectId});
  final int projectId;
  @override
  ConsumerState<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends ConsumerState<_UploadDialog> {
  final _title = TextEditingController();
  PlatformFile? _file;
  String _category = 'plan';
  bool _visible = false, _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'doc', 'docx', 'xls', 'xlsx', 'zip'],
    );
    if (f == null) return;
    if ((await f.length() ?? 0) > 25 * 1024 * 1024) {
      if (mounted) showError(context, 'That file is over 25 MB. Please compress it or split it.');
      return;
    }
    setState(() {
      _file = f;
      if (_title.text.trim().isEmpty) _title.text = f.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    });
  }

  Future<void> _save() async {
    final f = _file;
    if (f == null) {
      showError(context, 'Choose a file first.');
      return;
    }
    if (_title.text.trim().isEmpty) {
      showError(context, 'Give the document a title.');
      return;
    }
    setState(() => _busy = true);
    final c = ref.read(supabaseProvider);
    String? path;
    try {
      final bytes = await f.readAsBytes();
      path = await uploadBytes(c, 'project-documents', '${widget.projectId}', f.name, bytes);
      await c.from('project_documents').insert({
        'project_id': widget.projectId,
        'title': _title.text.trim(),
        'category': _category,
        'storage_path': path,
        'file_name': f.name,
        'size_bytes': bytes.length,
        'client_visible': _visible,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // Do not leave a file behind that no record points to.
      if (path != null) {
        try {
          await c.storage.from('project-documents').remove([path]);
        } catch (_) {}
      }
      if (mounted) {
        setState(() => _busy = false);
        showError(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Upload document'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.attach_file),
                label: Text(_file == null ? 'Choose file (PDF, image, Word, Excel, ZIP; max 25 MB)' : _file!.name, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 14),
              TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title *')),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [for (final o in _docCategories) DropdownMenuItem(value: o.value, child: Text(o.label))],
                onChanged: (v) => setState(() => _category = v ?? 'other'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Let the client see this document'),
                value: _visible,
                onChanged: (v) => setState(() => _visible = v),
              ),
              if (_busy) const LinearProgressIndicator(),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Upload')),
        ],
      );
}

// ---------------------------------------------------------------- budget

class _Budget extends ConsumerWidget {
  const _Budget({required this.projectId, required this.budget});
  final int projectId;
  final Object? budget;

  Future<void> _edit(BuildContext context, WidgetRef ref, [Map<String, dynamic>? row]) async {
    final saved = await showRecordForm(
      context,
      title: 'Expense',
      table: 'project_expenses',
      initial: row,
      extra: {'project_id': projectId},
      beforeSave: _dropNullDates,
      fields: const [
        FieldSpec('spent_on', 'Date', kind: FieldKind.date, required: true),
        FieldSpec('description', 'What was bought or paid for', required: true),
        FieldSpec('amount_ugx', 'Amount (UGX)', kind: FieldKind.number, required: true, min: 0),
        FieldSpec('category', 'Type', kind: FieldKind.select, required: true, options: [
          Opt('materials', 'Materials'), Opt('labour', 'Labour'), Opt('equipment', 'Equipment'), Opt('transport', 'Transport'),
          Opt('subcontractor', 'Subcontractor'), Opt('permits', 'Permits'), Opt('other', 'Other'),
        ]),
        FieldSpec('supplier', 'Supplier'),
        FieldSpec('paid', 'Already paid', kind: FieldKind.toggle),
      ],
    );
    if (saved) {
      ref.invalidate(expensesProvider(projectId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => _TabFrame(
        addLabel: 'Add expense',
        onAdd: () => _edit(context, ref),
        child: AsyncBody<Rows>(
          value: ref.watch(expensesProvider(projectId)),
          onRetry: () => ref.invalidate(expensesProvider(projectId)),
          builder: (rows) {
            final spent = rows.fold<num>(0, (s, e) => s + (num.tryParse('${e['amount_ugx']}') ?? 0));
            final b = num.tryParse('${budget ?? ''}');
            final byCat = <String, num>{};
            for (final e in rows) {
              byCat.update('${e['category']}', (v) => v + (num.tryParse('${e['amount_ugx']}') ?? 0), ifAbsent: () => num.tryParse('${e['amount_ugx']}') ?? 0);
            }
            final over = b != null && spent > b;
            return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Spent: ${ugx(spent)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    if (b == null)
                      const Padding(padding: EdgeInsets.only(top: 6), child: Text('No budget set. Add one with Edit on this project.', style: TextStyle(color: Colors.black54)))
                    else ...[
                      const SizedBox(height: 4),
                      Text('Budget: ${ugx(b)} · ${over ? 'OVER by ${ugx(spent - b)}' : 'left: ${ugx(b - spent)}'}',
                          style: TextStyle(color: over ? Colors.red.shade700 : Colors.black87, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: b == 0 ? 1 : (spent / b).clamp(0, 1).toDouble(),
                        minHeight: 10,
                        color: over ? Colors.red.shade700 : null,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                    if (byCat.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final e in byCat.entries) StatusChip('${pretty(e.key)}: ${ugx(e.value)}', color: Colors.blueGrey),
                      ]),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty) const _Empty('No expenses yet. Record what you buy or pay so you always know where the budget stands.'),
              for (final r in rows)
                Card(
                  child: ListTile(
                    onTap: () => _edit(context, ref, r),
                    title: Text('${r['description']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${r['spent_on']} · ${pretty('${r['category']}')}${r['supplier'] != null ? ' · ${r['supplier']}' : ''}'),
                    trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(ugx(r['amount_ugx']), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(r['paid'] == true ? 'Paid' : 'Not paid yet', style: TextStyle(fontSize: 12, color: r['paid'] == true ? Colors.green.shade700 : Colors.orange.shade800)),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      );
}

// ---------------------------------------------------------------- small shared pieces

class _TabFrame extends StatelessWidget {
  const _TabFrame({required this.addLabel, required this.onAdd, required this.child});
  final String addLabel;
  final VoidCallback onAdd;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(addLabel))),
          const SizedBox(height: 12),
          Expanded(child: child),
        ]),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54))),
      );
}
