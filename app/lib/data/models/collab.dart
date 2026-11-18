import 'parse.dart';

class AppNotification {
  const AppNotification({required this.id, required this.kind, required this.title, required this.createdAt, this.body, this.link, this.readAt});
  final int id;
  final String kind, title;
  final String? body, link;
  final DateTime? createdAt, readAt;
  bool get unread => readAt == null;

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: intOf(m['id']),
        kind: str(m['kind']),
        title: str(m['title']),
        body: strOrNull(m['body']),
        link: strOrNull(m['link']),
        createdAt: dateOrNull(m['created_at']),
        readAt: dateOrNull(m['read_at']),
      );
}

class ChatMessage {
  const ChatMessage({required this.id, required this.projectId, required this.authorId, required this.body, required this.createdAt, this.photoPath, this.editedAt});
  final int id, projectId;
  final String authorId, body;
  final String? photoPath;
  final DateTime createdAt;
  final DateTime? editedAt;

  /// Messages can be corrected for 5 minutes, then they are part of the permanent record.
  bool canEdit(String me, DateTime now) => authorId == me && now.difference(createdAt) < const Duration(minutes: 5) && body.isNotEmpty;

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: intOf(m['id']),
        projectId: intOf(m['project_id']),
        authorId: str(m['author_id']),
        body: str(m['body']),
        photoPath: strOrNull(m['photo_path']),
        createdAt: dateOrNull(m['created_at']) ?? DateTime.now(),
        editedAt: dateOrNull(m['edited_at']),
      );
}

enum RequestStatus {
  awaitingTeam('awaiting_team', 'Team is pricing it'),
  awaitingClient('awaiting_client', 'Waiting for client'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Not approved'),
  withdrawn('withdrawn', 'Withdrawn');

  const RequestStatus(this.db, this.label);
  final String db, label;
  static RequestStatus parse(String? v) => values.firstWhere((s) => s.db == v, orElse: () => awaitingClient);
  bool get open => this == awaitingTeam || this == awaitingClient;
}

class ProjectRequest {
  const ProjectRequest({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.row,
    this.details,
    this.costImpact,
    this.daysImpact,
    this.decidedAt,
    this.decidedBy,
    this.decisionNote,
  });
  final int id, projectId;
  final String kind, title; // kind: decision | change
  final RequestStatus status;
  final String? details, decisionNote, decidedBy;
  final num? costImpact;
  final int? daysImpact;
  final DateTime? createdAt, decidedAt;
  final Map<String, dynamic> row;

  bool get isChange => kind == 'change';

  factory ProjectRequest.fromMap(Map<String, dynamic> m) => ProjectRequest(
        id: intOf(m['id']),
        projectId: intOf(m['project_id']),
        kind: str(m['kind'], 'decision'),
        title: str(m['title']),
        status: RequestStatus.parse(strOrNull(m['status'])),
        details: strOrNull(m['details']),
        costImpact: numOrNull(m['cost_impact_ugx']),
        daysImpact: intOrNull(m['days_impact']),
        createdAt: dateOrNull(m['created_at']),
        decidedAt: dateOrNull(m['decided_at']),
        decidedBy: strOrNull(m['decided_by']),
        decisionNote: strOrNull(m['decision_note']),
        row: m,
      );
}

class Payment {
  const Payment({required this.id, required this.label, required this.amount, required this.row, this.dueDate, this.paidOn});
  final int id;
  final String label;
  final num amount;
  final DateTime? dueDate, paidOn;
  final Map<String, dynamic> row;
  bool get paid => paidOn != null;
  bool overdue(DateTime today) => !paid && dueDate != null && dueDate!.isBefore(DateTime(today.year, today.month, today.day));

  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
        id: intOf(m['id']),
        label: str(m['label']),
        amount: numOf(m['amount_ugx']),
        dueDate: dateOrNull(m['due_date']),
        paidOn: dateOrNull(m['paid_on']),
        row: m,
      );
}
