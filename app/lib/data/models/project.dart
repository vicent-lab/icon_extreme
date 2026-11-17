import 'parse.dart';

class Project {
  const Project({
    required this.id,
    required this.title,
    required this.slug,
    required this.location,
    required this.projectType,
    required this.status,
    required this.progressPct,
    required this.isPublished,
    required this.row,
    this.budgetUgx,
    this.startDate,
    this.endDate,
    this.clientName,
    this.summary,
  });

  final int id, progressPct;
  final String title, slug, location, projectType, status;
  final bool isPublished;
  final num? budgetUgx; // only operations staff can read it; null for everyone else
  final DateTime? startDate, endDate;
  final String? clientName, summary;

  /// The raw row, kept so the edit form can show every field without a second query.
  final Map<String, dynamic> row;

  factory Project.fromMap(Map<String, dynamic> m) {
    final fin = m['project_finance'];
    final budget = fin is Map ? fin['budget_ugx'] : (fin is List && fin.isNotEmpty ? (fin.first as Map)['budget_ugx'] : null);
    final row = {...m}..remove('project_finance');
    if (budget != null) row['budget_ugx'] = budget;
    return Project(
      id: intOf(m['id']),
      title: str(m['title']),
      slug: str(m['slug']),
      location: str(m['location']),
      projectType: str(m['project_type']),
      status: str(m['status'], 'upcoming'),
      progressPct: intOf(m['progress_pct']),
      isPublished: boolOf(m['is_published']),
      budgetUgx: numOrNull(budget),
      startDate: dateOrNull(m['start_date']),
      endDate: dateOrNull(m['end_date']),
      clientName: strOrNull(m['client_name']),
      summary: strOrNull(m['summary']),
      row: row,
    );
  }
}

class Phase {
  const Phase({
    required this.id,
    required this.name,
    required this.status,
    required this.progressPct,
    required this.row,
    this.start,
    this.end,
    this.description,
  });
  final int id, progressPct;
  final String name, status;
  final DateTime? start, end;
  final String? description;
  final Map<String, dynamic> row;

  factory Phase.fromMap(Map<String, dynamic> m) => Phase(
        id: intOf(m['id']),
        name: str(m['name']),
        status: str(m['status'], 'planned'),
        progressPct: intOf(m['progress_pct']),
        start: dateOrNull(m['start_date']),
        end: dateOrNull(m['end_date']),
        description: strOrNull(m['description']),
        row: m,
      );
}

class SiteLog {
  const SiteLog({
    required this.id,
    required this.date,
    required this.workDone,
    required this.clientVisible,
    required this.row,
    this.weather,
    this.workers,
    this.issues,
  });
  final int id;
  final DateTime? date;
  final String workDone;
  final bool clientVisible;
  final String? weather, issues;
  final int? workers;
  final Map<String, dynamic> row;

  factory SiteLog.fromMap(Map<String, dynamic> m) => SiteLog(
        id: intOf(m['id']),
        date: dateOrNull(m['log_date']),
        workDone: str(m['work_done']),
        clientVisible: boolOf(m['client_visible']),
        weather: strOrNull(m['weather']),
        workers: intOrNull(m['workers_on_site']),
        issues: strOrNull(m['issues']),
        row: m,
      );
}

class ProjectDocument {
  const ProjectDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.storagePath,
    required this.clientVisible,
    required this.row,
    this.fileName,
    this.sizeBytes,
  });
  final int id;
  final String title, category, storagePath;
  final bool clientVisible;
  final String? fileName;
  final int? sizeBytes;
  final Map<String, dynamic> row;

  factory ProjectDocument.fromMap(Map<String, dynamic> m) => ProjectDocument(
        id: intOf(m['id']),
        title: str(m['title']),
        category: str(m['category'], 'other'),
        storagePath: str(m['storage_path']),
        clientVisible: boolOf(m['client_visible']),
        fileName: strOrNull(m['file_name']),
        sizeBytes: intOrNull(m['size_bytes']),
        row: m,
      );
}

class Expense {
  const Expense({
    required this.id,
    required this.date,
    required this.category,
    required this.description,
    required this.amount,
    required this.paid,
    required this.row,
    this.supplier,
  });
  final int id;
  final DateTime? date;
  final String category, description;
  final num amount;
  final bool paid;
  final String? supplier;
  final Map<String, dynamic> row;

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: intOf(m['id']),
        date: dateOrNull(m['spent_on']),
        category: str(m['category'], 'other'),
        description: str(m['description']),
        amount: numOf(m['amount_ugx']),
        paid: boolOf(m['paid']),
        supplier: strOrNull(m['supplier']),
        row: m,
      );
}
