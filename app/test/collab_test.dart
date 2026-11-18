import 'package:flutter_test/flutter_test.dart';
import 'package:icon_extreme/data/models/collab.dart';

void main() {
  test('a message can be fixed by its author for 5 minutes only', () {
    final t = DateTime(2026, 11, 18, 10);
    final m = ChatMessage(id: 1, projectId: 1, authorId: 'me', body: 'Helo', createdAt: t);
    expect(m.canEdit('me', t.add(const Duration(minutes: 4))), isTrue);
    expect(m.canEdit('me', t.add(const Duration(minutes: 6))), isFalse);
    expect(m.canEdit('someone else', t), isFalse);
  });

  test('a payment is overdue only when unpaid and past its due date', () {
    final today = DateTime(2026, 11, 18);
    Payment p(String? due, String? paid) => Payment.fromMap({'id': 1, 'label': 'Deposit', 'amount_ugx': '1000', 'due_date': due, 'paid_on': paid});
    expect(p('2026-11-10', null).overdue(today), isTrue);
    expect(p('2026-11-10', '2026-11-09').overdue(today), isFalse);
    expect(p('2026-11-18', null).overdue(today), isFalse);
    expect(p(null, null).overdue(today), isFalse);
    expect(p(null, null).amount, 1000);
  });

  test('request status reads database values and knows which are still open', () {
    expect(RequestStatus.parse('awaiting_team'), RequestStatus.awaitingTeam);
    expect(RequestStatus.parse('approved').open, isFalse);
    expect(RequestStatus.parse('awaiting_client').open, isTrue);
    expect(RequestStatus.parse('nonsense'), RequestStatus.awaitingClient);
  });
}
