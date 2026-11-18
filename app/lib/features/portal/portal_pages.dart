import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design/tokens.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models/project.dart';
import '../../data/providers.dart';
import '../../data/models/collab.dart';
import '../collab/approvals_view.dart';
import '../collab/chat_view.dart';
import '../collab/collab_providers.dart';
import '../collab/notification_bell.dart';
import '../collab/payments_view.dart';
import '../install/install_card.dart';
import '../projects/project_providers.dart';
import '../projects/tabs/documents_tab.dart' show fileSize, openDocument;
import '../projects/tabs/site_log_tab.dart' show SiteLogBody;

/// What a client sees: a calm, read-only window onto their own projects.
class PortalShell extends ConsumerWidget {
  const PortalShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(profileProvider).value;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const BrandMark(size: 30),
        actions: [
          const NotificationBell(path: '/portal/notifications'),
          TextButton.icon(
            onPressed: () => context.go('/portal'),
            icon: const Icon(Icons.home_outlined, size: 18),
            label: const Text('My projects'),
          ),
          TextButton.icon(
            onPressed: () => context.go('/portal/profile'),
            icon: const Icon(Icons.person_outline, size: 18),
            label: Text(MediaQuery.sizeOf(context).width < 520 ? '' : (me?.displayName ?? 'Profile')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: child,
    );
  }
}

class PortalHome extends ConsumerWidget {
  const PortalHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(profileProvider).value?.displayName.split(' ').first ?? '';
    return PageFrame(
      title: name.isEmpty ? 'Your projects' : 'Welcome, $name',
      subtitle: 'Follow the progress of the work ICON is doing for you.',
      child: AsyncBody<List<Project>>(
        value: ref.watch(myProjectsProvider),
        onRetry: () => ref.invalidate(myProjectsProvider),
        builder: (rows) => Column(children: [const InstallCard(), Expanded(child: _list(rows))]),
      ),
    );
  }

  Widget _list(List<Project> rows) => rows.isEmpty
            ? const EmptyState('No project is linked to your account yet. Your ICON contact will add you to it, and it will appear here. Questions? Call or message us.')
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                itemBuilder: (context, i) {
                  final p = rows[i];
                  return Card(
                    child: ListTile(
                      onTap: () => context.go('/portal/project/${p.id}'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${p.projectType} · ${p.location} · ${p.progressPct}% done'),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: p.progressPct / 100, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                        ]),
                      ),
                      trailing: StatusChip(pretty(p.status), color: statusColor(p.status)),
                    ),
                  );
                },
              );
}

class PortalProjectPage extends ConsumerWidget {
  const PortalProjectPage({super.key, required this.id, this.tab});
  final int id;
  final String? tab; // opens straight onto a tab, e.g. from a notification

  static const _keys = ['overview', 'schedule', 'updates', 'messages', 'approvals', 'payments', 'documents'];

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncBody<Project?>(
        value: ref.watch(projectProvider(id)),
        onRetry: () => ref.invalidate(projectProvider(id)),
        builder: (p) {
          if (p == null) return const EmptyState('This project was not found, or it is not linked to your account.');
          final start = _keys.indexOf(tab ?? '');
          return DefaultTabController(
            length: _keys.length,
            initialIndex: start < 0 ? 0 : start,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  IconButton(tooltip: 'Back', onPressed: () => context.go('/portal'), icon: const Icon(Icons.arrow_back)),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text('${p.projectType} · ${p.location}', style: const TextStyle(color: Colors.black54)),
                    ]),
                  ),
                  StatusChip(pretty(p.status), color: statusColor(p.status)),
                ]),
                const SizedBox(height: 8),
                const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
                  Tab(text: 'Overview'), Tab(text: 'Schedule'), Tab(text: 'Site updates'), Tab(text: 'Messages'),
                  Tab(text: 'Approvals'), Tab(text: 'Payments'), Tab(text: 'Documents'),
                ]),
                Expanded(
                  child: TabBarView(children: [
                    _PortalOverview(project: p),
                    _PortalSchedule(projectId: id),
                    _PortalUpdates(projectId: id),
                    ChatView(projectId: id),
                    ApprovalsView(projectId: id, asClient: true),
                    PaymentsView(projectId: id, canEdit: false),
                    _PortalDocuments(projectId: id),
                  ]),
                ),
              ]),
            ),
          );
        },
      );
}

/// "Where do we stand?" in one screen: progress, what is happening now and next, and what waits on the client.
class _PortalOverview extends ConsumerWidget {
  const _PortalOverview({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = project;
    final phases = ref.watch(phasesProvider(p.id)).value ?? const <Phase>[];
    final waiting = (ref.watch(requestsProvider(p.id)).value ?? const []).where((r) => r.status == RequestStatus.awaitingClient).length;
    final latest = (ref.watch(logsProvider(p.id)).value ?? const <SiteLog>[]).firstOrNull;
    final now = phases.where((x) => x.status == 'in_progress' || x.status == 'delayed').firstOrNull;
    final next = phases.where((x) => x.status == 'planned').firstOrNull;
    void go(int tab) => DefaultTabController.of(context).animateTo(tab);

    Widget row(String k, String? v) => v == null || v.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 130, child: Text(k, style: const TextStyle(color: Colors.black54))),
              Expanded(child: Text(v)),
            ]),
          );

    return ListView(padding: const EdgeInsets.only(top: 16, bottom: 24), children: [
      if (waiting > 0)
        Card(
          color: const Color(0xFFFCEBD3),
          child: ListTile(
            onTap: () => go(4),
            leading: const Icon(Icons.task_alt, color: Color(0xFF8A4B0F)),
            title: Text(waiting == 1 ? '1 thing is waiting for your approval' : '$waiting things are waiting for your approval',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p.progressPct}% complete', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: p.progressPct / 100, minHeight: 10, borderRadius: BorderRadius.circular(5)),
            const SizedBox(height: 14),
            row('Happening now', now == null ? null : '${now.name}${now.status == 'delayed' ? ' (delayed)' : ''}'),
            row('Coming next', next?.name),
            row('Expected finish', p.endDate == null ? null : dateShort(p.endDate)),
          ]),
        ),
      ),
      if (latest != null) ...[
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            onTap: () => go(2),
            title: Text('Latest update · ${dateShort(latest.date)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(latest.workDone, maxLines: 3, overflow: TextOverflow.ellipsis),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ],
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          onTap: () => go(3),
          leading: const Icon(Icons.chat_bubble_outline),
          title: const Text('Message the team', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Questions, photos and quick updates, all in one place.'),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
      if (p.summary != null) ...[
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [row('About', p.summary), row('Starts', p.startDate == null ? null : dateShort(p.startDate))]))),
      ],
    ]);
  }
}

class _PortalSchedule extends ConsumerWidget {
  const _PortalSchedule({required this.projectId});
  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: AsyncBody<List<Phase>>(
          value: ref.watch(phasesProvider(projectId)),
          onRetry: () => ref.invalidate(phasesProvider(projectId)),
          builder: (rows) => rows.isEmpty
              ? const EmptyState('The schedule has not been shared yet.')
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                            StatusChip(pretty(r.status), color: statusColor(r.status)),
                          ]),
                          if (r.start != null || r.end != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text([if (r.start != null) dateShort(r.start), if (r.end != null) dateShort(r.end)].join(' to '), style: const TextStyle(color: Colors.black54, fontSize: 12)),
                            ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(value: r.progressPct / 100, minHeight: 8, color: statusColor(r.status), borderRadius: BorderRadius.circular(4)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      );
}

/// Only entries staff marked "client can see" arrive here; the database filters the rest out.
class _PortalUpdates extends ConsumerWidget {
  const _PortalUpdates({required this.projectId});
  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: AsyncBody<List<SiteLog>>(
          value: ref.watch(logsProvider(projectId)),
          onRetry: () => ref.invalidate(logsProvider(projectId)),
          builder: (rows) => rows.isEmpty
              ? const EmptyState('No site updates have been shared yet.')
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                  itemBuilder: (context, i) => Card(
                    child: ListTile(
                      title: Text(dateLong(rows[i].date), style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: SiteLogBody(log: rows[i]),
                    ),
                  ),
                ),
        ),
      );
}

class _PortalDocuments extends ConsumerWidget {
  const _PortalDocuments({required this.projectId});
  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: AsyncBody<List<ProjectDocument>>(
          value: ref.watch(documentsProvider(projectId)),
          onRetry: () => ref.invalidate(documentsProvider(projectId)),
          builder: (rows) => rows.isEmpty
              ? const EmptyState('No documents have been shared with you yet.')
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
                        subtitle: Text('${pretty(d.category)}${size.isEmpty ? '' : ' · $size'}'),
                        trailing: const Icon(Icons.open_in_new, size: 18),
                      ),
                    );
                  },
                ),
        ),
      );
}
