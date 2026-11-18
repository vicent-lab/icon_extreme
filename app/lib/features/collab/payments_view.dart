import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design/tokens.dart';
import '../../core/errors.dart';
import '../../core/forms/form_kit.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models/collab.dart';
import '../../data/providers.dart';
import 'collab_providers.dart';

/// The payment schedule the client agreed to: what is due and what is paid. Internal costs stay in Budget.
class PaymentsView extends ConsumerWidget {
  const PaymentsView({super.key, required this.projectId, required this.canEdit});
  final int projectId;
  final bool canEdit;

  Future<void> _edit(BuildContext context, WidgetRef ref, [Payment? p]) async {
    final saved = await showRecordForm(
      context,
      title: 'Payment',
      store: ref.read(tableStoreProvider('project_payments')),
      initial: p?.row,
      extra: {'project_id': projectId},
      fields: const [
        FieldSpec('label', 'What it is for', required: true, hint: 'e.g. Deposit, After roofing, Final payment'),
        FieldSpec('amount_ugx', 'Amount (UGX)', kind: FieldKind.number, required: true, min: 0),
        FieldSpec('due_date', 'Due date', kind: FieldKind.date),
        FieldSpec('paid_on', 'Paid on (leave empty if not paid yet)', kind: FieldKind.date),
        FieldSpec('sort_order', 'Order in the list (small number first)', kind: FieldKind.number),
      ],
    );
    if (saved) ref.invalidate(paymentsProvider(projectId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (canEdit)
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(onPressed: () => _edit(context, ref), icon: const Icon(Icons.add), label: const Text('Add payment')),
            ),
          if (canEdit) const SizedBox(height: 12),
          Expanded(
            child: AsyncBody<List<Payment>>(
              value: ref.watch(paymentsProvider(projectId)),
              onRetry: () => ref.invalidate(paymentsProvider(projectId)),
              builder: (rows) {
                if (rows.isEmpty) {
                  return EmptyState(canEdit
                      ? 'No payment schedule yet. Add the agreed payments (deposit, stages, final) so the client always knows what is due.'
                      : 'The payment schedule has not been shared yet.');
                }
                final today = DateTime.now();
                final total = rows.fold<num>(0, (s, p) => s + p.amount);
                final paid = rows.where((p) => p.paid).fold<num>(0, (s, p) => s + p.amount);
                final next = rows.where((p) => !p.paid).toList()..sort((a, b) => (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999)));
                return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Paid ${ugx(paid)} of ${ugx(total)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(value: total == 0 ? 0 : (paid / total).toDouble(), minHeight: 10, color: Tone.done, borderRadius: BorderRadius.circular(5)),
                        if (next.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text('Next: ${next.first.label}, ${ugx(next.first.amount)}${next.first.dueDate != null ? ', due ${dateShort(next.first.dueDate)}' : ''}',
                              style: TextStyle(fontWeight: FontWeight.w600, color: next.first.overdue(today) ? Tone.problem : null)),
                        ],
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final p in rows)
                    Card(
                      child: ListTile(
                        onTap: canEdit ? () => _edit(context, ref, p) : null,
                        title: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(p.paid ? 'Paid on ${dateShort(p.paidOn)}' : (p.dueDate != null ? 'Due ${dateShort(p.dueDate)}' : 'Date to be agreed')),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(ugx(p.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 10),
                          StatusChip(p.paid ? 'Paid' : (p.overdue(today) ? 'Overdue' : 'Not paid'),
                              color: p.paid ? Tone.done : (p.overdue(today) ? Tone.problem : Tone.idle)),
                          if (canEdit && !p.paid) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Mark as paid today',
                              icon: const Icon(Icons.check_circle_outline),
                              onPressed: () async {
                                try {
                                  await ref.read(tableStoreProvider('project_payments')).update(p.id, {'paid_on': isoDay(DateTime.now())});
                                  ref.invalidate(paymentsProvider(projectId));
                                } catch (e) {
                                  if (context.mounted) showError(context, friendlyError(e));
                                }
                              },
                            ),
                          ],
                        ]),
                      ),
                    ),
                ]);
              },
            ),
          ),
        ]),
      );
}
