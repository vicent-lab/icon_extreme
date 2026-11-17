import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads for the website-content screens (services, team, testimonials, blog) and the pick-lists their forms need.
class ContentRepository {
  ContentRepository(this._db);
  final SupabaseClient _db;

  Future<List<Map<String, dynamic>>> list(String table) async =>
      List<Map<String, dynamic>>.from(await _db.from(table).select().order('id', ascending: false).limit(500));

  /// (id, label) pairs for a drop-down, e.g. blog categories or projects.
  Future<List<(String, String)>> choices(String table, String labelColumn) async {
    final rows = await _db.from(table).select('id, $labelColumn').order(labelColumn);
    return [for (final r in rows) ('${r['id']}', '${r[labelColumn]}')];
  }

  Future<void> patch(String table, Object id, Map<String, dynamic> values) async => _db.from(table).update(values).eq('id', id);
}
