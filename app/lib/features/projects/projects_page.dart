import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets.dart';
import '../leads/leads_page.dart' show pretty;

final projectsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await ref
      .watch(supabaseProvider)
      .from('projects')
      .select('id, title, location, project_type, status, progress_pct, is_published')
      .order('display_order')
      .order('created_at', ascending: false)
      .limit(200);
  return List<Map<String, dynamic>>.from(rows);
});

Color statusColor(String s) => switch (s) {
      'ongoing' => Colors.orange.shade800,
      'completed' => Colors.green.shade700,
      'on_hold' => Colors.red.shade700,
      _ => Colors.blueGrey,
    };

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageFrame(
        title: 'Projects',
        subtitle: 'Progress at a glance. Publish a project to show it on the website.',
        child: AsyncBody<List<Map<String, dynamic>>>(
          value: ref.watch(projectsProvider),
          onRetry: () => ref.invalidate(projectsProvider),
          builder: (rows) => rows.isEmpty
              ? const Center(child: Text('No projects yet.'))
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final pct = (r['progress_pct'] as num?)?.toInt() ?? 0;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text('${r['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${r['project_type']} · ${r['location']}'),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: pct / 100, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                          ]),
                        ),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          StatusChip(pretty('${r['status']}'), color: statusColor('${r['status']}')),
                          const SizedBox(width: 12),
                          Tooltip(
                            message: r['is_published'] == true ? 'Visible on website' : 'Hidden from website',
                            child: Switch(
                              value: r['is_published'] == true,
                              onChanged: (v) async {
                                try {
                                  await ref.read(supabaseProvider).from('projects').update({'is_published': v}).eq('id', r['id']);
                                  ref.invalidate(projectsProvider);
                                } catch (_) {
                                  if (context.mounted) showError(context, 'Could not change visibility.');
                                }
                              },
                            ),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      );
}
