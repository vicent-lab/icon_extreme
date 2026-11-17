import 'package:supabase_flutter/supabase_flutter.dart';

/// Counts for the dashboard. The database only counts rows this person may see.
class StatsRepository {
  StatsRepository(this._db);
  final SupabaseClient _db;

  Future<int> count(String table, {String? column, Object? equals}) async {
    var q = _db.from(table).select('id');
    if (column != null) q = q.eq(column, equals!);
    return (await q.count(CountOption.exact)).count;
  }
}
