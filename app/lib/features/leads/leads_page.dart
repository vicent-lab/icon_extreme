import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/form_kit.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';

const leadStages = ['new', 'contacted', 'site_visit', 'quoted', 'won', 'lost', 'spam'];

String pretty(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');

final leadsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref.watch(supabaseProvider).from('leads').select().order('created_at', ascending: false).limit(200);
  return List<Map<String, dynamic>>.from(rows);
});

class LeadsPage extends ConsumerWidget {
  const LeadsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageFrame(
        title: 'Leads',
        subtitle: 'Messages and quote requests from the website, as one pipeline.',
        actions: [
          FilledButton.icon(
            onPressed: () async {
              final saved = await showRecordForm(
                context,
                title: 'Lead',
                table: 'leads',
                extra: const {'source': 'manual', 'kind': 'contact'},
                fields: const [
                  FieldSpec('full_name', 'Name', required: true),
                  FieldSpec('phone', 'Phone'),
                  FieldSpec('email', 'Email', required: true),
                  FieldSpec('project_type', 'Type of work wanted'),
                  FieldSpec('location', 'Where is the site?'),
                  FieldSpec('budget_ugx', 'Budget (UGX)', kind: FieldKind.number, min: 0),
                  FieldSpec('message', 'What they asked for (phone call, walk-in...)', kind: FieldKind.multiline, required: true),
                ],
              );
              if (saved) ref.invalidate(leadsProvider);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add lead'),
          ),
        ],
        child: AsyncBody<List<Map<String, dynamic>>>(
          value: ref.watch(leadsProvider),
          onRetry: () => ref.invalidate(leadsProvider),
          builder: (rows) => rows.isEmpty
              ? const Center(child: Text('No leads yet.'))
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _LeadTile(row: rows[i]),
                ),
        ),
      );
}

class _LeadTile extends ConsumerWidget {
  const _LeadTile({required this.row});
  final Map<String, dynamic> row;

  Future<void> _setStage(BuildContext context, WidgetRef ref, String stage) async {
    try {
      await ref.read(supabaseProvider).from('leads').update({'stage': stage}).eq('id', row['id']);
      ref.invalidate(leadsProvider);
    } catch (_) {
      if (context.mounted) showError(context, 'Could not change the stage. You may not have permission.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final created = DateTime.tryParse('${row['created_at']}')?.toLocal();
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        title: Text('${row['full_name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          pretty('${row['kind']}'),
          if (row['project_type'] != null) '${row['project_type']}',
          if (created != null) DateFormat.yMMMd().add_jm().format(created),
        ].join(' · ')),
        trailing: DropdownButton<String>(
          value: row['stage'] as String,
          underline: const SizedBox.shrink(),
          items: [for (final s in leadStages) DropdownMenuItem(value: s, child: Text(pretty(s)))],
          onChanged: (v) => v == null ? null : _setStage(context, ref, v),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText('${row['message']}'),
          const SizedBox(height: 12),
          Wrap(spacing: 16, children: [
            SelectableText('Email: ${row['email']}'),
            if (row['phone'] != null) SelectableText('Phone: ${row['phone']}'),
            if (row['location'] != null) Text('Location: ${row['location']}'),
            if (row['budget_ugx'] != null) Text('Budget: UGX ${NumberFormat.decimalPattern().format(num.parse('${row['budget_ugx']}'))}'),
          ]),
        ],
      ),
    );
  }
}
