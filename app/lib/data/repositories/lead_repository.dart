import 'package:supabase_flutter/supabase_flutter.dart';

class LeadRepository {
  LeadRepository(this._db);
  final SupabaseClient _db;

  Future<List<Map<String, dynamic>>> list() async =>
      List<Map<String, dynamic>>.from(await _db.from('leads').select().order('created_at', ascending: false).limit(500));

  Future<void> setStage(Object id, String stage) async => _db.from('leads').update({'stage': stage}).eq('id', id);
}
