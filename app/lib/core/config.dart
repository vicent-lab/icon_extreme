/// Supabase settings come from build flags, never from source code:
///   flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// The anon/publishable key is safe in an app ONLY because Row Level Security guards the data.
class Config {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

/// Public half of the phone-alert key pair (safe to share; the private half lives only in the send-push function).
const vapidPublicKey = String.fromEnvironment('VAPID_PUBLIC_KEY', defaultValue: 'BCSEx94ANPR4NnAjVuW6d2ZniS_GFuuy-6wawK51ymsIW1-qE96Jn_GT67oaQBjwq_fyHg500iDuYSmM809Aj00');
