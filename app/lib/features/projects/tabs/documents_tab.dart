import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/tokens.dart';
import '../../../core/errors.dart';
import '../../../core/forms/form_kit.dart';
import '../../../core/format.dart';
import '../../../core/widgets.dart';
import '../../../data/models/project.dart';
import '../../../data/providers.dart';
import '../../../data/repositories/storage_repository.dart';
import '../project_providers.dart';
import '../widgets/tab_frame.dart';

const docCategories = [
  Opt('plan', 'Plan'), Opt('drawing', 'Drawing'), Opt('contract', 'Contract'), Opt('permit', 'Permit'),
  Opt('quotation', 'Quotation'), Opt('invoice', 'Invoice'), Opt('report', 'Report'), Opt('photo', 'Photo'), Opt('other', 'Other'),
];

String fileSize(int? bytes) {
  final kb = (bytes ?? 0) / 1024;
  if (kb <= 0) return '';
  return kb >= 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '${kb.round()} KB';
}

/// Opens a private document through a short-lived signed link.
Future<void> openDocument(BuildContext context, WidgetRef ref, ProjectDocument d) async {
  try {
    final url = await ref.read(storageRepoProvider).signedUrl(d.storagePath);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    if (context.mounted) showError(context, friendlyError(e));
  }
}

class DocumentsTab extends ConsumerWidget {
  const DocumentsTab({super.key, required this.projectId});
  final int projectId;

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final done = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => _UploadDialog(projectId: projectId));
    if (done == true) ref.invalidate(documentsProvider(projectId));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, ProjectDocument d) async {
    if (!await confirmDelete(context, '"${d.title}"')) return;
    try {
      final removed = await ref.read(tableStoreProvider('project_documents')).delete(d.id);
      if (!removed) throw const _Denied();
      await ref.read(storageRepoProvider).remove(StorageRepository.privateBucket, d.storagePath);
      ref.invalidate(documentsProvider(projectId));
    } catch (e) {
      if (context.mounted) showError(context, e is _Denied ? 'Your role is not allowed to delete this.' : friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => TabFrame(
        addLabel: 'Upload document',
        onAdd: () => _upload(context, ref),
        child: AsyncBody<List<ProjectDocument>>(
          value: ref.watch(documentsProvider(projectId)),
          onRetry: () => ref.invalidate(documentsProvider(projectId)),
          builder: (rows) => rows.isEmpty
              ? const EmptyState('No documents yet. Upload plans, drawings, contracts and permits here. They stay private unless you let the client see them.')
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                  itemBuilder: (context, i) {
                    final d = rows[i];
                    final size = fileSize(d.sizeBytes);
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined),
                        onTap: () => openDocument(context, ref, d),
                        title: Text(d.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${pretty(d.category)} · ${d.fileName ?? ''}${size.isEmpty ? '' : ' · $size'}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (d.clientVisible) StatusChip('Client sees', color: Tone.done),
                          IconButton(
                            tooltip: 'Change title or visibility',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              final saved = await showRecordForm(
                                context,
                                title: 'Document',
                                store: ref.read(tableStoreProvider('project_documents')),
                                initial: d.row,
                                allowDelete: false,
                                fields: const [
                                  FieldSpec('title', 'Title', required: true),
                                  FieldSpec('category', 'Type', kind: FieldKind.select, required: true, options: docCategories),
                                  FieldSpec('client_visible', 'Let the client see this document', kind: FieldKind.toggle),
                                ],
                              );
                              if (saved) ref.invalidate(documentsProvider(projectId));
                            },
                          ),
                          IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context, ref, d)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      );
}

class _Denied implements Exception {
  const _Denied();
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
    if (f == null) return showError(context, 'Choose a file first.');
    if (_title.text.trim().isEmpty) return showError(context, 'Give the document a title.');
    setState(() => _busy = true);
    final storage = ref.read(storageRepoProvider);
    String? path;
    try {
      final bytes = await f.readAsBytes();
      path = await storage.upload(StorageRepository.privateBucket, '${widget.projectId}', f.name, bytes);
      await ref.read(tableStoreProvider('project_documents')).insert({
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
      // Never leave a file behind that no record points to.
      if (path != null) {
        try {
          await storage.remove(StorageRepository.privateBucket, path);
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
                items: [for (final o in docCategories) DropdownMenuItem(value: o.value, child: Text(o.label))],
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
