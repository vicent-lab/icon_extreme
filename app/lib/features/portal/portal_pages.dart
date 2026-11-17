import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/design/tokens.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models/project.dart';
import '../../data/providers.dart';
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
        builder: (rows) => rows.isEmpty
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
              ),
      ),
    );
  }
}

class PortalProjectPage extends ConsumerWidget {
  const PortalProjectPage({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncBody<Project?>(
        value: ref.watch(projectProvider(id)),
        onRetry: () => ref.invalidate(projectProvider(id)),
        builder: (p) {
          if (p == null) return const EmptyState('This project was not found, or it is not linked to your account.');
          return DefaultTabController(
            length: 4,
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
                  Tab(text: 'Overview'), Tab(text: 'Schedule'), Tab(text: 'Site updates'), Tab(text: 'Documents'),
                ]),
                Expanded(
                  child: TabBarView(children: [
                    _PortalOverview(project: p),
                    _PortalSchedule(projectId: id),
                    _PortalUpdates(projectId: id),
                    _PortalDocuments(projectId: id),
                  ]),
                ),
              ]),
            ),
          );
        },
      );
}

class _PortalOverview extends StatelessWidget {
  const _PortalOverview({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final p = project;
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
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p.progressPct}% complete', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: p.progressPct / 100, minHeight: 10, borderRadius: BorderRadius.circular(5)),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            row('Starts', p.startDate == null ? null : dateShort(p.startDate)),
            row('Expected finish', p.endDate == null ? null : dateShort(p.endDate)),
            row('About', p.summary),
          ]),
        ),
      ),
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
