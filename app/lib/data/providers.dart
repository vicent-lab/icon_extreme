import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/forms/record_store.dart';
import 'models/profile.dart';
import 'repositories/content_repository.dart';
import 'repositories/lead_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/project_children.dart';
import 'repositories/project_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/stats_repository.dart';
import 'repositories/storage_repository.dart';
import 'repositories/table_store.dart';

final supabaseProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);

// ---- repositories: the only code that talks to the database -----------------------------
final profileRepoProvider = Provider((ref) => ProfileRepository(ref.watch(supabaseProvider)));
final projectRepoProvider = Provider((ref) => ProjectRepository(ref.watch(supabaseProvider)));
final childrenProvider = Provider((ref) => ProjectChildren(ref.watch(supabaseProvider)));
final storageRepoProvider = Provider((ref) => StorageRepository(ref.watch(supabaseProvider)));
final contentRepoProvider = Provider((ref) => ContentRepository(ref.watch(supabaseProvider)));
final settingsRepoProvider = Provider((ref) => SettingsRepository(ref.watch(supabaseProvider)));
final statsRepoProvider = Provider((ref) => StatsRepository(ref.watch(supabaseProvider)));
final leadRepoProvider = Provider((ref) => LeadRepository(ref.watch(supabaseProvider)));
final tableStoreProvider = Provider.family<RecordStore, String>((ref, table) => TableStore(ref.watch(supabaseProvider), table));

// ---- who is signed in ---------------------------------------------------------------------

/// Emits whenever someone signs in or out.
final authStateProvider = StreamProvider<AuthState>((ref) => ref.watch(supabaseProvider).auth.onAuthStateChange);

/// The signed-in person's profile (null when signed out). It re-checks every 20 seconds,
/// so an approval or role change by an admin reaches the person without signing in again.
final profileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authStateProvider);
  final timer = Timer.periodic(const Duration(seconds: 20), (_) => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  return ref.watch(profileRepoProvider).mine();
});
