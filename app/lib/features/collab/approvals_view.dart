import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design/tokens.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models/collab.dart';
import '../../data/providers.dart';
import 'collab_providers.dart';

/// Approvals and change requests. Every decision is saved with who and when, and can never be edited.
class ApprovalsView extends ConsumerWidget {
  const ApprovalsView({super.key, required this.projectId, required this.asClient});
  final int projectId;
  final bool asClient;

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() job, String done) async {
    try {
      await job();
      ref.invalidate(requestsProvider(projectId));
      if (context.mounted) showOk(context, done);
    } catch (e) {
      if (context.mounted) showError(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(collabRepoProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Align(
          alignment: Alignment.centerRight,
          child: asClient
              ? OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Ask for a change'),
                  onPressed: () async {
                    final r = await _askText(context, title: 'Ask for a change', titleLabel: 'What would you like changed?', detailsLabel: 'More detail (optional)');
                    if (r != null && context.mounted) {
                      await _run(context, ref, () => repo.requestChange(projectId, r.$1, r.$2), 'Sent. The team will reply with any cost or time change.');
                    }
                  },
                )
              : FilledButton.icon(
                  icon: const Icon(Icons.add_task),
                  label: const Text('Ask client to approve'),
                  onPressed: () async {
                    final r = await _askPriced(context, title: 'Ask the client to approve');
                    if (r != null && context.mounted) {
                      await _run(context, ref, () => repo.raise(projectId, title: r.title!, details: r.details, cost: r.cost, days: r.days), 'Sent to the client.');
                    }
                  },
                ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: AsyncBody<List<ProjectRequest>>(
            value: ref.watch(requestsProvider(projectId)),
            onRetry: () => ref.invalidate(requestsProvider(projectId)),
            builder: (rows) {
              if (rows.isEmpty) {
                return EmptyState(asClient
                    ? 'Nothing is waiting for you. When the team needs your decision, it appears here.'
                    : 'No approvals yet. Ask the client to approve designs, materials or changes here, so the decision is on record.');
              }
              final sorted = [...rows]..sort((a, b) => (a.status.open ? 0 : 1).compareTo(b.status.open ? 0 : 1));
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                itemBuilder: (context, i) => _RequestCard(
                  r: sorted[i],
                  asClient: asClient,
                  onApprove: () async {
                    final note = await _askNote(context, approve: true);
                    if (note != null && context.mounted) await _run(context, ref, () => repo.decide(sorted[i].id, approve: true, note: note), 'Approved. The team has been told.');
                  },
                  onReject: () async {
                    final note = await _askNote(context, approve: false);
                    if (note != null && context.mounted) await _run(context, ref, () => repo.decide(sorted[i].id, approve: false, note: note), 'Sent. The team has been told.');
                  },
                  onPrice: () async {
                    final r = await _askPriced(context, title: 'Add cost and time', withTitle: false, initialDetails: sorted[i].details);
                    if (r != null && context.mounted) {
                      await _run(context, ref, () => repo.price(sorted[i].id, cost: r.cost, days: r.days, details: r.details), 'Sent to the client for approval.');
                    }
                  },
                  onWithdraw: () async => _run(context, ref, () => repo.withdraw(sorted[i].id), 'Withdrawn.'),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.r, required this.asClient, required this.onApprove, required this.onReject, required this.onPrice, required this.onWithdraw});
  final ProjectRequest r;
  final bool asClient;
  final VoidCallback onApprove, onReject, onPrice, onWithdraw;

  @override
  Widget build(BuildContext context) {
    final color = switch (r.status) {
      RequestStatus.approved => Tone.done,
      RequestStatus.rejected => Tone.problem,
      RequestStatus.withdrawn => Tone.idle,
      _ => Tone.active,
    };
    final impact = [
      if (r.costImpact != null && r.costImpact != 0) '${r.costImpact! > 0 ? 'Adds' : 'Saves'} ${ugx(r.costImpact!.abs())}',
      if (r.daysImpact != null && r.daysImpact != 0) '${r.daysImpact! > 0 ? 'Adds' : 'Saves'} ${r.daysImpact!.abs()} days',
    ];
    final waitingOnMe = asClient ? r.status == RequestStatus.awaitingClient : r.status == RequestStatus.awaitingTeam;
    return Card(
      shape: waitingOnMe ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card), side: BorderSide(color: Tone.active, width: 1.5)) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            StatusChip(r.isChange ? 'Change request' : 'Decision'),
            StatusChip(asClient && r.status == RequestStatus.awaitingClient ? 'Waiting for you' : r.status.label, color: color),
            Text(dateShort(r.createdAt), style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
          const SizedBox(height: 10),
          Text(r.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (r.details != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.details!)),
          if (impact.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(impact.join(' · '), style: const TextStyle(fontWeight: FontWeight.w700))),
          if (r.decidedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '${r.status == RequestStatus.approved ? 'Approved' : 'Not approved'} by the client on ${dateTime(r.decidedAt)}'
                '${r.decisionNote != null ? '\n"${r.decisionNote}"' : ''}',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          if (r.status.open) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (asClient && r.status == RequestStatus.awaitingClient) ...[
                FilledButton(onPressed: onApprove, child: const Text('Approve')),
                OutlinedButton(onPressed: onReject, child: const Text('Not approved')),
              ],
              if (asClient && r.status == RequestStatus.awaitingTeam) const Text('The team is working out the cost and time.', style: TextStyle(color: Colors.black54)),
              if (!asClient && r.status == RequestStatus.awaitingTeam) FilledButton(onPressed: onPrice, child: const Text('Add cost and time')),
              if (!asClient) TextButton(onPressed: onWithdraw, child: const Text('Withdraw')),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _Priced {
  const _Priced(this.title, this.details, this.cost, this.days);
  final String? title, details;
  final num? cost;
  final int? days;
}

Future<_Priced?> _askPriced(BuildContext context, {required String title, bool withTitle = true, String? initialDetails}) async {
  final t = TextEditingController();
  final d = TextEditingController(text: initialDetails ?? '');
  final c = TextEditingController();
  final n = TextEditingController();
  final out = await showDialog<_Priced>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (withTitle) TextField(controller: t, decoration: const InputDecoration(labelText: 'What needs approval? *', hintText: 'e.g. Roof colour: dark grey')),
            const SizedBox(height: 12),
            TextField(controller: d, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Details (optional)')),
            const SizedBox(height: 12),
            TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Extra cost in UGX (optional, minus for a saving)')),
            const SizedBox(height: 12),
            TextField(controller: n, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Extra days (optional)')),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (withTitle && t.text.trim().isEmpty) return;
            Navigator.pop(ctx, _Priced(t.text.trim(), d.text.trim().isEmpty ? null : d.text.trim(), num.tryParse(c.text.replaceAll(',', '').trim()), int.tryParse(n.text.trim())));
          },
          child: const Text('Send to client'),
        ),
      ],
    ),
  );
  for (final x in [t, d, c, n]) {
    x.dispose();
  }
  return out;
}

Future<(String, String?)?> _askText(BuildContext context, {required String title, required String titleLabel, required String detailsLabel}) async {
  final t = TextEditingController();
  final d = TextEditingController();
  final out = await showDialog<(String, String?)>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: t, decoration: InputDecoration(labelText: '$titleLabel *')),
          const SizedBox(height: 12),
          TextField(controller: d, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: detailsLabel)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => t.text.trim().isEmpty ? null : Navigator.pop(ctx, (t.text.trim(), d.text.trim().isEmpty ? null : d.text.trim())), child: const Text('Send')),
      ],
    ),
  );
  t.dispose();
  d.dispose();
  return out;
}

/// Returns the note ('' when none) or null when cancelled.
Future<String?> _askNote(BuildContext context, {required bool approve}) async {
  final c = TextEditingController();
  final out = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(approve ? 'Approve this?' : 'Not approved'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(approve ? 'Your approval is saved with today\'s date and cannot be changed later.' : 'Tell the team what you would like instead.'),
          const SizedBox(height: 12),
          TextField(controller: c, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: approve ? 'Note (optional)' : 'Your reason (optional)')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(approve ? 'Yes, approve' : 'Send')),
      ],
    ),
  );
  c.dispose();
  return out;
}
