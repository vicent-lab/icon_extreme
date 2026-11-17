import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsRepository {
  SettingsRepository(this._db);
  final SupabaseClient _db;

  Future<Map<String, String>> all() async {
    final rows = await _db.from('company_settings').select('key, value');
    return {for (final r in rows) '${r['key']}': '${r['value']}'};
  }

  Future<void> save(Map<String, String> changed) async {
    if (changed.isEmpty) return;
    await _db.from('company_settings').upsert([
      for (final e in changed.entries) {'key': e.key, 'value': e.value, 'is_public': true},
    ], onConflict: 'key');
  }
}
