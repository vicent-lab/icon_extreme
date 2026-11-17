import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers.dart';
import 'widgets.dart';

/// One input in a form. A screen lists its fields; the kit does the rest
/// (validation, saving, friendly errors). New screen = new list, no new form code.
enum FieldKind { text, multiline, number, date, toggle, select, image, slug }

class Opt {
  const Opt(this.value, this.label);
  final String value;
  final String label;
}

class FieldSpec {
  const FieldSpec(
    this.key,
    this.label, {
    this.kind = FieldKind.text,
    this.required = false,
    this.options = const [],
    this.hint,
    this.from,
    this.min,
    this.max,
    this.folder = 'general',
  });
  final String key, label;
  final FieldKind kind;
  final bool required;
  final List<Opt> options; // for select
  final String? hint;
  final String? from; // for slug: which field it is built from
  final num? min, max; // for number
  final String folder; // for image: folder inside the site-media bucket
}

String slugify(String s) {
  final out = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return out.isEmpty ? 'item' : out;
}

/// Turns database errors into plain sentences a site manager understands.
String friendlyError(Object e) {
  if (e is PostgrestException) {
    final m = e.message.toLowerCase();
    if (e.code == '23505') return 'That name/link is already used. Change it a little and try again.';
    if (e.code == '23514') {
      if (m.contains('client_permission') || m.contains('testimonials')) {
        return 'A testimonial can only be published after the client gave permission.';
      }
      if (m.contains('check')) return 'One of the values is not allowed (for example an end date before the start date).';
    }
    if (e.code == '23503') return 'This is still used by something else, so it cannot be removed.';
    if (e.code == '42501' || m.contains('row-level security') || m.contains('permission denied')) {
      return 'Your role is not allowed to do this.';
    }
    return 'Could not save: ${e.message}';
  }
  if (e is StorageException) return 'Upload failed: ${e.message}';
  return 'Something went wrong. Check your internet and try again.';
}

const _mime = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'zip': 'application/zip',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

String _safeName(String name) => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]+'), '-');

/// Uploads bytes and returns the storage path. Throws a readable error if it fails.
Future<String> uploadBytes(SupabaseClient c, String bucket, String folder, String fileName, Uint8List bytes) async {
  final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  final path = '$folder/${DateTime.now().millisecondsSinceEpoch}-${_safeName(fileName)}';
  await c.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: _mime[ext]));
  return path;
}

Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete this?'),
      content: Text('$what will be removed for good. This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ),
  );
  return ok ?? false;
}

/// Opens the add/edit dialog. [initial] == null means "add". Returns true when saved.
/// [extra] is merged into the saved row (used for the project id, etc.).
Future<bool> showRecordForm(
  BuildContext context, {
  required String title,
  required String table,
  required List<FieldSpec> fields,
  Map<String, dynamic>? initial,
  Map<String, dynamic> extra = const {},
  bool allowDelete = true,
  Map<String, dynamic> Function(Map<String, dynamic> data)? beforeSave,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RecordDialog(
      title: title,
      table: table,
      fields: fields,
      initial: initial,
      extra: extra,
      allowDelete: allowDelete,
      beforeSave: beforeSave,
    ),
  );
  return saved ?? false;
}

class _RecordDialog extends ConsumerStatefulWidget {
  const _RecordDialog({
    required this.title,
    required this.table,
    required this.fields,
    required this.initial,
    required this.extra,
    required this.allowDelete,
    this.beforeSave,
  });
  final Map<String, dynamic> Function(Map<String, dynamic> data)? beforeSave;
  final String title, table;
  final List<FieldSpec> fields;
  final Map<String, dynamic>? initial;
  final Map<String, dynamic> extra;
  final bool allowDelete;
  @override
  ConsumerState<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends ConsumerState<_RecordDialog> {
  final _form = GlobalKey<FormState>();
  final _text = <String, TextEditingController>{};
  final _value = <String, dynamic>{}; // toggles, selects, dates, images
  bool _busy = false;
  bool _slugTouched = false;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      final v = widget.initial?[f.key];
      switch (f.kind) {
        case FieldKind.text:
        case FieldKind.multiline:
        case FieldKind.slug:
        case FieldKind.number:
          _text[f.key] = TextEditingController(text: v == null ? '' : '$v');
        case FieldKind.toggle:
          _value[f.key] = v == true;
        case FieldKind.select:
          _value[f.key] = v ?? (f.options.isNotEmpty ? f.options.first.value : null);
        case FieldKind.date:
          // required dates (log date, expense date) start on today for new records
          _value[f.key] = v ?? (f.required && !_editing ? DateFormat('yyyy-MM-dd').format(DateTime.now()) : null);
        case FieldKind.image:
          _value[f.key] = v;
      }
    }
    _slugTouched = _editing; // never rewrite the link of something that already exists
    for (final f in widget.fields.where((f) => f.kind == FieldKind.slug && f.from != null)) {
      _text[f.from]?.addListener(() {
        if (!_slugTouched) _text[f.key]!.text = slugify(_text[f.from]!.text);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _collect() {
    final out = <String, dynamic>{};
    for (final f in widget.fields) {
      switch (f.kind) {
        case FieldKind.text:
        case FieldKind.multiline:
        case FieldKind.slug:
          final t = _text[f.key]!.text.trim();
          out[f.key] = t.isEmpty ? (f.required ? '' : null) : t;
        case FieldKind.number:
          final t = _text[f.key]!.text.trim().replaceAll(',', '');
          out[f.key] = t.isEmpty ? null : num.parse(t);
        default:
          out[f.key] = _value[f.key];
      }
    }
    return out;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final client = ref.read(supabaseProvider);
    try {
      var data = {..._collect(), ...widget.extra};
      if (widget.beforeSave != null) data = widget.beforeSave!(data);
      if (_editing) {
        await client.from(widget.table).update(data).eq('id', widget.initial!['id']);
      } else {
        await client.from(widget.table).insert(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, friendlyError(e));
      }
    }
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'This ${widget.title.toLowerCase()}')) return;
    setState(() => _busy = true);
    try {
      final res = await ref.read(supabaseProvider).from(widget.table).delete().eq('id', widget.initial!['id']).select('id');
      if (!mounted) return;
      if ((res as List).isEmpty) {
        setState(() => _busy = false);
        showError(context, 'Your role is not allowed to delete this.');
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, friendlyError(e));
      }
    }
  }

  Future<void> _pickImage(FieldSpec f) async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp']);
    if (file == null) return;
    if ((await file.length() ?? 0) > 5 * 1024 * 1024) {
      if (mounted) showError(context, 'That picture is over 5 MB. Please choose a smaller one.');
      return;
    }
    setState(() => _busy = true);
    try {
      final c = ref.read(supabaseProvider);
      final path = await uploadBytes(c, 'site-media', f.folder, file.name, await file.readAsBytes());
      // Public bucket: store the full link so the website can show it directly.
      _value[f.key] = c.storage.from('site-media').getPublicUrl(path);
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pickDate(FieldSpec f) async {
    final now = DateTime.now();
    final current = DateTime.tryParse('${_value[f.key] ?? ''}');
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _value[f.key] = DateFormat('yyyy-MM-dd').format(d));
  }

  Widget _field(FieldSpec f) {
    final label = f.required ? '${f.label} *' : f.label;
    switch (f.kind) {
      case FieldKind.text:
      case FieldKind.multiline:
        return TextFormField(
          controller: _text[f.key],
          minLines: f.kind == FieldKind.multiline ? 3 : 1,
          maxLines: f.kind == FieldKind.multiline ? 8 : 1,
          decoration: InputDecoration(labelText: label, hintText: f.hint),
          validator: f.required ? (v) => (v == null || v.trim().isEmpty) ? 'Please fill this in' : null : null,
        );
      case FieldKind.slug:
        return TextFormField(
          controller: _text[f.key],
          onChanged: (_) => _slugTouched = true,
          decoration: InputDecoration(labelText: label, helperText: 'Used in the web address. Letters, numbers and dashes.'),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return 'Please fill this in';
            return RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(t) ? null : 'Use small letters, numbers and dashes only';
          },
        );
      case FieldKind.number:
        return TextFormField(
          controller: _text[f.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, hintText: f.hint),
          validator: (v) {
            final t = (v ?? '').trim().replaceAll(',', '');
            if (t.isEmpty) return f.required ? 'Please fill this in' : null;
            final n = num.tryParse(t);
            if (n == null) return 'Numbers only';
            if (f.min != null && n < f.min!) return 'Must be at least ${f.min}';
            if (f.max != null && n > f.max!) return 'Must be at most ${f.max}';
            return null;
          },
        );
      case FieldKind.toggle:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          subtitle: f.hint == null ? null : Text(f.hint!),
          value: _value[f.key] == true,
          onChanged: (v) => setState(() => _value[f.key] = v),
        );
      case FieldKind.select:
        return DropdownButtonFormField<String>(
          initialValue: _value[f.key] as String?,
          decoration: InputDecoration(labelText: label),
          items: [for (final o in f.options) DropdownMenuItem(value: o.value, child: Text(o.label))],
          onChanged: (v) => setState(() => _value[f.key] = v),
          validator: f.required ? (v) => v == null ? 'Please choose one' : null : null,
        );
      case FieldKind.date:
        final v = _value[f.key] as String?;
        return Row(children: [
          Expanded(child: Text(v == null ? '${f.label}: not set' : '${f.label}: $v')),
          TextButton.icon(onPressed: _busy ? null : () => _pickDate(f), icon: const Icon(Icons.event, size: 18), label: const Text('Choose')),
          if (v != null) IconButton(tooltip: 'Clear', onPressed: () => setState(() => _value[f.key] = null), icon: const Icon(Icons.close, size: 18)),
        ]);
      case FieldKind.image:
        final v = _value[f.key] as String?;
        return Row(children: [
          if (v != null && v.startsWith('http'))
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(v, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported)),
            )
          else
            const Icon(Icons.image_outlined, size: 40),
          const SizedBox(width: 12),
          Expanded(child: Text(v == null ? '${f.label}: none yet (max 5 MB)' : '${f.label}: added')),
          TextButton.icon(onPressed: _busy ? null : () => _pickImage(f), icon: const Icon(Icons.upload, size: 18), label: Text(v == null ? 'Upload' : 'Replace')),
          if (v != null) IconButton(tooltip: 'Remove', onPressed: () => setState(() => _value[f.key] = null), icon: const Icon(Icons.close, size: 18)),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(_editing ? 'Edit ${widget.title}' : 'Add ${widget.title}'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final f in widget.fields) Padding(padding: const EdgeInsets.only(bottom: 14), child: _field(f)),
                if (_busy) const LinearProgressIndicator(),
              ]),
            ),
          ),
        ),
        actions: [
          if (_editing && widget.allowDelete)
            TextButton(
              onPressed: _busy ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Delete'),
            ),
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_editing ? 'Save' : 'Add')),
        ],
      );
}
