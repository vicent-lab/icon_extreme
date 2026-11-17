import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design/tokens.dart';
import '../../../core/forms/form_kit.dart';
import '../../../core/format.dart';
import '../../../core/widgets.dart';
import '../../../data/models/project.dart';
import '../../../data/providers.dart';
import '../project_providers.dart';
import '../widgets/tab_frame.dart';

class BudgetTab extends ConsumerWidget {
  const BudgetTab({super.key, required this.projectId, required this.budget});
  final int projectId;
  final num? budget;

  Future<void> _edit(BuildContext context, WidgetRef ref, [Expense? e]) async {
    final saved = await showRecordForm(
      context,
      title: 'Expense',
      store: ref.read(tableStoreProvider('project_expenses')),
      initial: e?.row,
      extra: {'project_id': projectId},
      beforeSave: dropNullDates,
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
    if (saved) ref.invalidate(expensesProvider(projectId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => TabFrame(
        addLabel: 'Add expense',
        onAdd: () => _edit(context, ref),
        child: AsyncBody<List<Expense>>(
          value: ref.watch(expensesProvider(projectId)),
          onRetry: () => ref.invalidate(expensesProvider(projectId)),
          builder: (rows) {
            final spent = rows.fold<num>(0, (s, e) => s + e.amount);
            final b = budget;
            final byCat = <String, num>{};
            for (final e in rows) {
              byCat.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);
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
                          style: TextStyle(color: over ? Tone.problem : Colors.black87, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: b == 0 ? 1 : (spent / b).clamp(0, 1).toDouble(),
                        minHeight: 10,
                        color: over ? Tone.problem : null,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ],
                    if (byCat.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final e in byCat.entries) StatusChip('${pretty(e.key)}: ${ugx(e.value)}'),
                      ]),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty) const EmptyState('No expenses yet. Record what you buy or pay so you always know where the budget stands.'),
              for (final e in rows)
                Card(
                  child: ListTile(
                    onTap: () => _edit(context, ref, e),
                    title: Text(e.description, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${dateShort(e.date)} · ${pretty(e.category)}${e.supplier != null ? ' · ${e.supplier}' : ''}'),
                    trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(ugx(e.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(e.paid ? 'Paid' : 'Not paid yet', style: TextStyle(fontSize: 12, color: e.paid ? Tone.done : Tone.active)),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      );
}
