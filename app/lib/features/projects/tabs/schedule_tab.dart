import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/design/tokens.dart';
import '../../../core/forms/form_kit.dart';
import '../../../core/format.dart';
import '../../../core/widgets.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/project.dart';
import '../../../data/providers.dart';
import '../project_providers.dart';
import '../widgets/tab_frame.dart';

class ScheduleTab extends ConsumerWidget {
  const ScheduleTab({super.key, required this.projectId});
  final int projectId;

  Future<void> _edit(BuildContext context, WidgetRef ref, [Phase? phase]) async {
    var staff = const <Profile>[];
    try {
      staff = (await ref.read(peopleProvider.future)).where((p) => p.role.isStaff && p.isActive).toList();
    } catch (_) {/* the form works without the list */}
    if (!context.mounted) return;
    final saved = await showRecordForm(
      context,
      title: 'Phase',
      store: ref.read(tableStoreProvider('project_phases')),
      initial: phase == null ? null : {...phase.row, 'assigned_to': '${phase.row['assigned_to'] ?? ''}'},
      extra: {'project_id': projectId},
      beforeSave: (d) => {...d, 'assigned_to': d['assigned_to'] == '' ? null : d['assigned_to']},
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
          for (final p in staff) Opt(p.id, p.displayName),
        ]),
        const FieldSpec('sort_order', 'Order in the list (small number first)', kind: FieldKind.number),
      ],
    );
    if (saved) {
      ref.invalidate(phasesProvider(projectId));
      ref.invalidate(projectProvider(projectId)); // the database rolls progress up
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => TabFrame(
        addLabel: 'Add phase',
        onAdd: () => _edit(context, ref),
        child: AsyncBody<List<Phase>>(
          value: ref.watch(phasesProvider(projectId)),
          onRetry: () => ref.invalidate(phasesProvider(projectId)),
          builder: (rows) {
            if (rows.isEmpty) return const EmptyState('No schedule yet. Add the phases of the job (foundation, walls, roof...) with dates.');
            final dates = <DateTime>[for (final r in rows) ...[if (r.start != null) r.start!, if (r.end != null) r.end!]]..sort();
            final first = dates.isEmpty ? null : dates.first;
            final last = dates.isEmpty ? null : dates.last;
            final span = (first == null || last == null) ? 1 : (last.difference(first).inDays + 1).clamp(1, 100000);
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
              itemBuilder: (context, i) => _PhaseCard(phase: rows[i], first: first, span: span, onTap: () => _edit(context, ref, rows[i])),
            );
          },
        ),
      );
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({required this.phase, required this.first, required this.span, required this.onTap});
  final Phase phase;
  final DateTime? first;
  final int span;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = phase;
    final color = statusColor(r.status);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700))),
              StatusChip(pretty(r.status), color: color),
            ]),
            const SizedBox(height: 4),
            Text([if (r.start != null) dateShort(r.start), if (r.end != null) dateShort(r.end)].join(' to '), style: const TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 10),
            // Timeline bar: where this phase sits inside the whole job, filled by progress.
            LayoutBuilder(builder: (context, c) {
              final s = r.start, e = r.end, f = first;
              if (s == null || e == null || f == null) {
                return LinearProgressIndicator(value: r.progressPct / 100, minHeight: 8, borderRadius: BorderRadius.circular(4));
              }
              final left = c.maxWidth * s.difference(f).inDays / span;
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
                        widthFactor: r.progressPct / 100,
                        child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
                      ),
                    ]),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 4),
            Text('${r.progressPct}% done', style: const TextStyle(fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
