import 'package:flutter_test/flutter_test.dart';
import 'package:icon_extreme/core/roles.dart';

void main() {
  test('unknown or missing role falls back to client (least power)', () {
    expect(AppRole.parse(null), AppRole.client);
    expect(AppRole.parse('hacker'), AppRole.client);
  });

  test('clients can open nothing in the staff app', () {
    for (final s in Section.values) {
      expect(canOpen(AppRole.client, s), isFalse, reason: '$s');
    }
  });

  test('only admins open Users & roles', () {
    for (final r in AppRole.values) {
      expect(canOpen(r, Section.users), r.isAdmin, reason: r.db);
    }
  });

  test('support sees leads but not website content; editor the reverse', () {
    expect(canOpen(AppRole.support, Section.leads), isTrue);
    expect(canOpen(AppRole.support, Section.blog), isFalse);
    expect(canOpen(AppRole.editor, Section.blog), isTrue);
    expect(canOpen(AppRole.editor, Section.leads), isFalse);
  });

  test('db names match the Postgres enum', () {
    expect(AppRole.values.map((r) => r.db).toList(),
        ['super_admin', 'admin', 'project_manager', 'editor', 'support', 'client']);
  });
}
