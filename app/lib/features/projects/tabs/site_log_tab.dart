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

class SiteLogTab extends ConsumerWidget {
  const SiteLogTab({super.key, required this.projectId});
  final int projectId;

  Future<void> _edit(BuildContext context, WidgetRef ref, [SiteLog? log]) async {
    final saved = await showRecordForm(
      context,
      title: 'Site log',
      store: ref.read(tableStoreProvider('site_logs')),
      initial: log?.row,
      extra: {'project_id': projectId},
      beforeSave: dropNullDates,
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
  Widget build(BuildContext context, WidgetRef ref) => TabFrame(
        addLabel: "Add today's log",
        onAdd: () => _edit(context, ref),
        child: AsyncBody<List<SiteLog>>(
          value: ref.watch(logsProvider(projectId)),
          onRetry: () => ref.invalidate(logsProvider(projectId)),
          builder: (rows) => rows.isEmpty
              ? const EmptyState('No site logs yet. Write a short note each day: weather, workers, work done, problems.')
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    return Card(
                      child: ListTile(
                        onTap: () => _edit(context, ref, r),
                        title: Text(dateLong(r.date), style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: SiteLogBody(log: r),
                        trailing: r.clientVisible ? StatusChip('Client sees', color: Tone.done) : null,
                      ),
                    );
                  },
                ),
        ),
      );
}

/// The weather / workers / work done / problem lines, shared by the staff list and the client portal.
class SiteLogBody extends StatelessWidget {
  const SiteLogBody({super.key, required this.log});
  final SiteLog log;

  @override
  Widget build(BuildContext context) {
    final meta = [if (log.weather != null) log.weather!, if (log.workers != null) '${log.workers} workers'].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (meta.isNotEmpty) Text(meta),
        const SizedBox(height: 4),
        Text(log.workDone, maxLines: 4, overflow: TextOverflow.ellipsis),
        if (log.issues != null) Text('Problem: ${log.issues}', style: TextStyle(color: Tone.problem)),
      ]),
    );
  }
}
