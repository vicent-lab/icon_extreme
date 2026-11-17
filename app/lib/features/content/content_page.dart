import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/form_kit.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';

/// One screen definition per kind of website content. Adding a new content type = one new spec.
class ContentSpec {
  const ContentSpec({
    required this.title, required this.noun, required this.table, required this.titleColumn,
    required this.subtitleColumn, required this.toggleColumn, required this.toggleLabel,
    required this.fields,
    this.toggleIsStatus = false,
  });
  final String title, noun, table, titleColumn, subtitleColumn, toggleColumn, toggleLabel;
  final bool toggleIsStatus; // blog_posts uses status text ('draft'/'published') not a boolean
  final List<FieldSpec> fields;

  static const services = ContentSpec(
    title: 'Services', noun: 'Service', table: 'services', titleColumn: 'name', subtitleColumn: 'short_description',
    toggleColumn: 'is_active', toggleLabel: 'Visible',
    fields: [
      FieldSpec('name', 'Service name', required: true),
      FieldSpec('slug', 'Web address', kind: FieldKind.slug, from: 'name'),
      FieldSpec('short_description', 'Short description', kind: FieldKind.multiline, required: true, hint: 'One or two lines shown on cards'),
      FieldSpec('full_description', 'Full description', kind: FieldKind.multiline),
      FieldSpec('image_path', 'Picture', kind: FieldKind.image, folder: 'services'),
      FieldSpec('display_order', 'Order on the website (small number first)', kind: FieldKind.number),
      FieldSpec('is_featured', 'Show on the home page', kind: FieldKind.toggle),
      FieldSpec('is_active', 'Visible on the website', kind: FieldKind.toggle),
    ],
  );

  static const team = ContentSpec(
    title: 'Team', noun: 'Team member', table: 'team_members', titleColumn: 'name', subtitleColumn: 'job_title',
    toggleColumn: 'is_active', toggleLabel: 'Visible',
    fields: [
      FieldSpec('name', 'Full name', required: true),
      FieldSpec('job_title', 'Job title', required: true),
      FieldSpec('bio', 'Short bio', kind: FieldKind.multiline),
      FieldSpec('image_path', 'Photo', kind: FieldKind.image, folder: 'team'),
      FieldSpec('display_order', 'Order on the website (small number first)', kind: FieldKind.number),
      FieldSpec('is_active', 'Visible on the website', kind: FieldKind.toggle),
    ],
  );

  static const testimonials = ContentSpec(
    title: 'Testimonials', noun: 'Testimonial', table: 'testimonials', titleColumn: 'client_name', subtitleColumn: 'quote',
    toggleColumn: 'is_published', toggleLabel: 'Published',
    fields: [
      FieldSpec('client_name', 'Client name', required: true),
      FieldSpec('client_role', 'Client role'),
      FieldSpec('company', 'Company'),
      FieldSpec('quote', 'What they said', kind: FieldKind.multiline, required: true),
      FieldSpec('rating', 'Rating (1 to 5)', kind: FieldKind.number, min: 1, max: 5),
      FieldSpec('photo_path', 'Photo', kind: FieldKind.image, folder: 'testimonials'),
      FieldSpec('client_permission', 'The client allowed us to publish this', kind: FieldKind.toggle, hint: 'Required before you can publish it'),
      FieldSpec('is_published', 'Published on the website', kind: FieldKind.toggle),
    ],
  );

  static const blog = ContentSpec(
    title: 'Blog', noun: 'Blog post', table: 'blog_posts', titleColumn: 'title', subtitleColumn: 'excerpt',
    toggleColumn: 'status', toggleLabel: 'Published', toggleIsStatus: true,
    fields: [
      FieldSpec('title', 'Title', required: true),
      FieldSpec('slug', 'Web address', kind: FieldKind.slug, from: 'title'),
      FieldSpec('excerpt', 'Short summary', kind: FieldKind.multiline),
      FieldSpec('content', 'Article', kind: FieldKind.multiline, required: true),
      FieldSpec('featured_image', 'Cover picture', kind: FieldKind.image, folder: 'blog'),
      FieldSpec('author', 'Author'),
      FieldSpec('seo_title', 'Google title (optional)'),
      FieldSpec('seo_description', 'Google description (optional)', kind: FieldKind.multiline),
      FieldSpec('status', 'Status', kind: FieldKind.select, required: true,
          options: [Opt('draft', 'Draft (hidden)'), Opt('published', 'Published')]),
    ],
  );
}

final contentProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, ContentSpec>((ref, spec) async {
  final rows = await ref.watch(supabaseProvider).from(spec.table).select().order('id', ascending: false).limit(200);
  return List<Map<String, dynamic>>.from(rows);
});

class ContentPage extends ConsumerWidget {
  const ContentPage({super.key, required this.spec});
  final ContentSpec spec;

  /// Adds the choices that come from other tables (blog category, testimonial project).
  Future<List<FieldSpec>> _fields(WidgetRef ref) async {
    final c = ref.read(supabaseProvider);
    final f = [...spec.fields];
    try {
      if (spec.table == 'blog_posts') {
        final cats = await c.from('blog_categories').select('id, name').order('name');
        f.insert(
          4,
          FieldSpec('category_id', 'Category', kind: FieldKind.select, options: [
            const Opt('', 'No category'),
            for (final r in cats) Opt('${r['id']}', '${r['name']}'),
          ]),
        );
      } else if (spec.table == 'testimonials') {
        final projects = await c.from('projects').select('id, title').order('title');
        f.insert(
          3,
          FieldSpec('project_id', 'Related project', kind: FieldKind.select, options: [
            const Opt('', 'None'),
            for (final r in projects) Opt('${r['id']}', '${r['title']}'),
          ]),
        );
      }
    } catch (_) {/* the form still works without the extra list */}
    return f;
  }

  Map<String, dynamic> _prepare(Map<String, dynamic> data, Map<String, dynamic>? old) {
    final d = {...data};
    for (final k in ['category_id', 'project_id']) {
      if (d.containsKey(k)) d[k] = (d[k] == null || d[k] == '') ? null : int.parse('${d[k]}');
    }
    if (spec.table == 'blog_posts') {
      final words = '${d['content'] ?? ''}'.trim().split(RegExp(r'\s+')).length;
      d['reading_time'] = (words / 200).ceil().clamp(1, 120);
      if (d['status'] == 'published' && old?['published_at'] == null) {
        d['published_at'] = DateTime.now().toUtc().toIso8601String();
      }
    }
    return d;
  }

  Future<void> _open(BuildContext context, WidgetRef ref, [Map<String, dynamic>? row]) async {
    final fields = await _fields(ref);
    if (!context.mounted) return;
    final saved = await showRecordForm(
      context,
      title: spec.noun,
      table: spec.table,
      fields: fields,
      initial: row == null ? null : {...row, 'category_id': '${row['category_id'] ?? ''}', 'project_id': '${row['project_id'] ?? ''}'},
      beforeSave: (d) => _prepare(d, row),
    );
    if (saved) ref.invalidate(contentProvider(spec));
  }

  Future<void> _newCategory(BuildContext context, WidgetRef ref) async {
    final saved = await showRecordForm(context, title: 'Category', table: 'blog_categories', fields: const [
      FieldSpec('name', 'Category name', required: true),
      FieldSpec('slug', 'Web address', kind: FieldKind.slug, from: 'name'),
      FieldSpec('description', 'Description', kind: FieldKind.multiline),
    ]);
    if (saved && context.mounted) showOk(context, 'Category added. You can now pick it in a post.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageFrame(
        title: spec.title,
        subtitle: 'Tap a row to edit it. Use the switch to show or hide it on the website.',
        actions: [
          if (spec.table == 'blog_posts')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton(onPressed: () => _newCategory(context, ref), child: const Text('New category')),
            ),
          FilledButton.icon(onPressed: () => _open(context, ref), icon: const Icon(Icons.add), label: Text('Add ${spec.noun.toLowerCase()}')),
        ],
        child: AsyncBody<List<Map<String, dynamic>>>(
          value: ref.watch(contentProvider(spec)),
          onRetry: () => ref.invalidate(contentProvider(spec)),
          builder: (rows) => rows.isEmpty
              ? Center(child: Text('No ${spec.title.toLowerCase()} yet. Press "Add ${spec.noun.toLowerCase()}" to create the first one.'))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    final on = spec.toggleIsStatus ? r[spec.toggleColumn] == 'published' : r[spec.toggleColumn] == true;
                    return Card(
                      child: ListTile(
                        onTap: () => _open(context, ref, r),
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
                              } catch (e) {
                                if (context.mounted) showError(context, friendlyError(e));
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
