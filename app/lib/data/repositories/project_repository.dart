import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/forms/record_store.dart';
import '../models/project.dart';

/// Projects plus their private budget (kept in a separate, operations-only table).
class ProjectRepository {
  ProjectRepository(this._db);
  final SupabaseClient _db;

  static const _select = '*, project_finance(budget_ugx)';

  Future<List<Project>> list() async {
    final rows = await _db.from('projects').select(_select).order('display_order').order('created_at', ascending: false).limit(500);
    return [for (final r in rows) Project.fromMap(r)];
  }

  Future<Project?> get(int id) async {
    final row = await _db.from('projects').select(_select).eq('id', id).maybeSingle();
    return row == null ? null : Project.fromMap(row);
  }

  /// Projects linked to this client account (a client can also see published ones, so we filter).
  Future<List<Project>> mine(String userId) async {
    final rows = await _db.from('projects').select('*').eq('client_id', userId).order('created_at', ascending: false);
    return [for (final r in rows) Project.fromMap(r)];
  }

  RecordStore store() => _ProjectStore(_db);
}

class _ProjectStore implements RecordStore {
  _ProjectStore(this._db);
  final SupabaseClient _db;

  Future<void> _saveBudget(int id, Object? budget) async {
    if (budget == null) {
      await _db.from('project_finance').delete().eq('project_id', id);
    } else {
      await _db.from('project_finance').upsert({'project_id': id, 'budget_ugx': budget}, onConflict: 'project_id');
    }
  }

  @override
  Future<void> insert(Map<String, dynamic> data) async {
    final d = {...data};
    final hasBudget = d.containsKey('budget_ugx');
    final budget = d.remove('budget_ugx');
    final row = await _db.from('projects').insert(d).select('id').single();
    if (hasBudget && budget != null) await _saveBudget(row['id'] as int, budget);
  }

  @override
  Future<void> update(Object id, Map<String, dynamic> data) async {
    final d = {...data};
    final hasBudget = d.containsKey('budget_ugx');
    final budget = d.remove('budget_ugx');
    await _db.from('projects').update(d).eq('id', id);
    if (hasBudget) await _saveBudget(id as int, budget);
  }

  /// Projects are never deleted. Hide them or put them on hold instead.
  @override
  Future<bool> delete(Object id) async => false;
}
