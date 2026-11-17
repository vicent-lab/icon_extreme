import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets.dart';

/// One screen definition per kind of website content. Adding a new content type = one new spec.
class ContentSpec {
  const ContentSpec({
    required this.title, required this.table, required this.titleColumn,
    required this.subtitleColumn, required this.toggleColumn, required this.toggleLabel,
    this.toggleIsStatus = false,
  });
  final String title, table, titleColumn, subtitleColumn, toggleColumn, toggleLabel;
  final bool toggleIsStatus; // blog_posts uses status text ('draft'/'published') not a boolean

  static const services = ContentSpec(title: 'Services', table: 'services', titleColumn: 'name', subtitleColumn: 'short_description', toggleColumn: 'is_active', toggleLabel: 'Visible');
  static const team = ContentSpec(title: 'Team', table: 'team_members', titleColumn: 'name', subtitleColumn: 'job_title', toggleColumn: 'is_active', toggleLabel: 'Visible');
  static const testimonials = ContentSpec(title: 'Testimonials', table: 'testimonials', titleColumn: 'client_name', subtitleColumn: 'quote', toggleColumn: 'is_published', toggleLabel: 'Published');
  static const blog = ContentSpec(title: 'Blog', table: 'blog_posts', titleColumn: 'title', subtitleColumn: 'excerpt', toggleColumn: 'status', toggleLabel: 'Published', toggleIsStatus: true);
}

final contentProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, ContentSpec>((ref, spec) async {
  final rows = await ref.watch(supabaseProvider).from(spec.table).select().order('id', ascending: false).limit(200);
  return List<Map<String, dynamic>>.from(rows);
});

class ContentPage extends ConsumerWidget {
  const ContentPage({super.key, required this.spec});
  final ContentSpec spec;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageFrame(
        title: spec.title,
        child: AsyncBody<List<Map<String, dynamic>>>(
          value: ref.watch(contentProvider(spec)),
          onRetry: () => ref.invalidate(contentProvider(spec)),
          builder: (rows) => rows.isEmpty
              ? Center(child: Text('No ${spec.title.toLowerCase()} yet.'))
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final on = spec.toggleIsStatus ? r[spec.toggleColumn] == 'published' : r[spec.toggleColumn] == true;
                    return Card(
                      child: ListTile(
                        title: Text('${r[spec.titleColumn]}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${r[spec.subtitleColumn] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(spec.toggleLabel),
                          Switch(
                            value: on,
                            onChanged: (v) async {
                              final value = spec.toggleIsStatus ? (v ? 'published' : 'draft') : v;
                              final patch = <String, dynamic>{spec.toggleColumn: value};
                              if (spec.table == 'blog_posts' && v && r['published_at'] == null) {
                                patch['published_at'] = DateTime.now().toUtc().toIso8601String();
                              }
                              try {
                                await ref.read(supabaseProvider).from(spec.table).update(patch).eq('id', r['id']);
                                ref.invalidate(contentProvider(spec));
                              } catch (_) {
                                if (context.mounted) {
                                  showError(context, spec.table == 'testimonials'
                                      ? 'Could not publish. A testimonial needs the client\'s permission first.'
                                      : 'Could not save the change.');
                                }
                              }
                            },
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      );
}
