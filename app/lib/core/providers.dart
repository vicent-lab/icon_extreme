import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'roles.dart';

final supabaseProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);

/// Emits whenever someone signs in or out.
final authStateProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseProvider).auth.onAuthStateChange,
);

class Profile {
  Profile({required this.id, required this.fullName, required this.role, required this.isActive});
  final String id;
  final String fullName;
  final AppRole role;
  final bool isActive;
}

/// The signed-in user's profile row (null when signed out).
final profileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseProvider);
  final user = client.auth.currentUser;
  if (user == null) return null;
  final row = await client
      .from('profiles')
      .select('id, full_name, role, is_active')
      .eq('id', user.id)
      .maybeSingle();
  if (row == null) return null;
  return Profile(
    id: row['id'] as String,
    fullName: (row['full_name'] as String?) ?? '',
    role: AppRole.parse(row['role'] as String?),
    isActive: row['is_active'] as bool? ?? false,
  );
});
