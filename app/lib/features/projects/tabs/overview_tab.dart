import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format.dart';
import '../../../data/models/project.dart';
import '../project_providers.dart';

class OverviewTab extends ConsumerWidget {
  const OverviewTab({super.key, required this.project, required this.ops});
  final Project project;
  final bool ops;

  Widget _row(String k, String? v) => v == null || v.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 150, child: Text(k, style: const TextStyle(color: Colors.black54))),
            Expanded(child: SelectableText(v)),
          ]),
        );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = project;
    final spent = ops ? ref.watch(expensesProvider(p.id)).value?.fold<num>(0, (s, e) => s + e.amount) : null;
    String? text(String k) => p.row[k] == null ? null : '${p.row[k]}';
    return ListView(padding: const EdgeInsets.only(top: 16, bottom: 24), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Progress: ${p.progressPct}%', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: p.progressPct / 100, minHeight: 10, borderRadius: BorderRadius.circular(5)),
            const SizedBox(height: 6),
            const Text('This moves by itself when the schedule phases are updated.', style: TextStyle(color: Colors.black54, fontSize: 12)),
            if (p.budgetUgx != null && spent != null) ...[
              const SizedBox(height: 16),
              Text('Spent ${ugx(spent)} of ${ugx(p.budgetUgx)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            _row('Client', p.clientName),
            _row('Starts', p.startDate == null ? null : dateShort(p.startDate)),
            _row('Expected end', p.endDate == null ? null : dateShort(p.endDate)),
            if (ops) _row('Budget', p.budgetUgx == null ? null : ugx(p.budgetUgx)),
            if (ops) _row('On the website', p.isPublished ? 'Yes' : 'No'),
            _row('Summary', p.summary),
            _row('Description', text('description')),
            _row('Challenge', text('challenge')),
            _row('Solution', text('solution')),
            _row('Result', text('results')),
          ]),
        ),
      ),
    ]);
  }
}
