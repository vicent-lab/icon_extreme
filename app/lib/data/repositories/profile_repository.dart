import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/roles.dart';
import '../models/profile.dart';

class InviteResult {
  const InviteResult({required this.email, required this.existing, required this.link, required this.message});
  final String email, message;
  final bool existing;
  final String? link; // null when the person already had an account
}

class ProfileRepository {
  ProfileRepository(this._db);
  final SupabaseClient _db;

  static const _cols = 'id, full_name, email, phone, role, is_active, approved_at';

  Future<Profile?> mine() async {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    final row = await _db.from('profiles').select(_cols).eq('id', user.id).maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  /// Staff only: the database hides other people's profiles from everyone else.
  Future<List<Profile>> all() async {
    final rows = await _db.from('profiles').select(_cols).order('created_at', ascending: false);
    return [for (final r in rows) Profile.fromMap(r)];
  }

  Future<void> updateMine({required String fullName, required String? phone}) async {
    final id = _db.auth.currentUser!.id;
    await _db.from('profiles').update({'full_name': fullName.trim(), 'phone': (phone ?? '').trim().isEmpty ? null : phone!.trim()}).eq('id', id);
  }

  /// Changes role / on-off. The database refuses anything the caller may not do.
  Future<void> setRole(String target, AppRole role, bool active) =>
      _db.rpc('set_user_role', params: {'target': target, 'new_role': role.db, 'active': active});

  Future<InviteResult> invite({required String email, required String fullName, required AppRole role, int? projectId}) async {
    final res = await _db.functions.invoke('invite-user', body: {
      'email': email.trim(),
      'full_name': fullName.trim(),
      'role': role.db,
      'project_id': projectId,
    });
    final d = res.data as Map;
    return InviteResult(
      email: '${d['email']}',
      existing: d['existing'] == true,
      link: d['link'] as String?,
      message: '${d['message']}',
    );
  }
}
