import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/project.dart';

/// Everything that hangs off one project (schedule, site log, documents, expenses) reads the same way.
class ChildRepository<T> {
  ChildRepository(this._db, {required this.table, required this.fromMap, required this.orderBy, this.ascending = true, this.limit = 500});
  final SupabaseClient _db;
  final String table;
  final T Function(Map<String, dynamic>) fromMap;
  final List<String> orderBy;
  final bool ascending;
  final int limit;

  Future<List<T>> list(int projectId) async {
    var q = _db.from(table).select().eq('project_id', projectId);
    var ordered = q.order(orderBy.first, ascending: ascending);
    for (final c in orderBy.skip(1)) {
      ordered = ordered.order(c, ascending: ascending);
    }
    final rows = await ordered.limit(limit);
    return [for (final r in rows) fromMap(r)];
  }
}

class ProjectChildren {
  ProjectChildren(SupabaseClient db)
      : phases = ChildRepository(db, table: 'project_phases', fromMap: Phase.fromMap, orderBy: ['sort_order', 'start_date']),
        logs = ChildRepository(db, table: 'site_logs', fromMap: SiteLog.fromMap, orderBy: ['log_date'], ascending: false),
        documents = ChildRepository(db, table: 'project_documents', fromMap: ProjectDocument.fromMap, orderBy: ['created_at'], ascending: false),
        expenses = ChildRepository(db, table: 'project_expenses', fromMap: Expense.fromMap, orderBy: ['spent_on'], ascending: false);

  final ChildRepository<Phase> phases;
  final ChildRepository<SiteLog> logs;
  final ChildRepository<ProjectDocument> documents;
  final ChildRepository<Expense> expenses;
}
