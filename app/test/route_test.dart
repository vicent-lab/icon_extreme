import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icon_extreme/app/router.dart';
import 'package:icon_extreme/core/roles.dart';
import 'package:icon_extreme/data/models/profile.dart';

Profile person(AppRole role, {bool active = true, DateTime? approved}) => Profile(
      id: 'u1',
      fullName: 'Test',
      email: 't@example.com',
      phone: null,
      role: role,
      isActive: active,
      approvedAt: approved ?? (active ? DateTime(2026) : null),
    );

String? route(String location, {bool configured = true, bool signedIn = true, AsyncValue<Profile?> profile = const AsyncLoading()}) =>
    decideRoute(configured: configured, signedIn: signedIn, profile: profile, location: location);

void main() {
  test('app without keys shows the setup screen', () => expect(route('/', configured: false), '/setup'));

  test('signed-out visitors go to login, but may open public pages', () {
    expect(route('/projects', signedIn: false), '/login');
    expect(route('/login', signedIn: false), isNull);
    expect(route('/accept', signedIn: false), isNull);
    expect(route('/forgot', signedIn: false), isNull);
  });

  test('a brand new sign-up waits for approval and never sees data screens', () {
    final p = AsyncData<Profile?>(person(AppRole.client, active: false));
    expect(route('/', profile: p), '/waiting');
    expect(route('/portal', profile: p), '/waiting');
    expect(route('/waiting', profile: p), isNull);
  });

  test('a suspended person lands on the suspended screen', () {
    final p = AsyncData<Profile?>(person(AppRole.admin, active: false, approved: DateTime(2026)));
    expect(route('/', profile: p), '/suspended');
  });

  test('an approved client always lands in the portal, never in staff screens', () {
    final p = AsyncData<Profile?>(person(AppRole.client));
    expect(route('/', profile: p), '/portal');
    expect(route('/projects', profile: p), '/portal');
    expect(route('/users', profile: p), '/portal');
    expect(route('/login', profile: p), '/portal');
    expect(route('/portal/project/3', profile: p), isNull);
  });

  test('staff land on the dashboard and are kept out of the client portal', () {
    final p = AsyncData<Profile?>(person(AppRole.projectManager));
    expect(route('/login', profile: p), '/');
    expect(route('/portal', profile: p), '/');
    expect(route('/projects', profile: p), isNull);
  });

  test('while the profile is loading nobody is bounced around', () => expect(route('/projects'), isNull));

  test('password setup is reachable by anyone signed in', () {
    expect(route('/set-password', profile: AsyncData<Profile?>(person(AppRole.client, active: false))), isNull);
  });
}
