import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/forms/record_store.dart';

/// The default store: one table, rows found by `id`.
class TableStore implements RecordStore {
  TableStore(this._db, this.table);
  final SupabaseClient _db;
  final String table;

  @override
  Future<void> insert(Map<String, dynamic> data) async => _db.from(table).insert(data);

  @override
  Future<void> update(Object id, Map<String, dynamic> data) async => _db.from(table).update(data).eq('id', id);

  @override
  Future<bool> delete(Object id) async => (await _db.from(table).delete().eq('id', id).select('id')).isNotEmpty;
}
