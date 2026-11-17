import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns database and network errors into plain sentences a site manager understands.
/// Screens never show raw error text.
String friendlyError(Object e) {
  if (e is PostgrestException) {
    final m = e.message.toLowerCase();
    if (e.code == '23505') return 'That name or link is already used. Change it a little and try again.';
    if (e.code == '23514') {
      if (m.contains('testimonials')) return 'A testimonial can only be published after the client gave permission.';
      return 'One of the values is not allowed (for example an end date before the start date).';
    }
    if (e.code == '23503') return 'This is still used by something else, so it cannot be removed.';
    if (e.code == '42501' || m.contains('row-level security') || m.contains('permission denied')) {
      return 'Your role is not allowed to do this.';
    }
    if (m.contains('not allowed')) return 'Your role is not allowed to do this.';
    return 'Could not save: ${e.message}';
  }
  if (e is StorageException) return 'Upload failed: ${e.message}';
  if (e is AuthException) return e.message;
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] is String) return d['error'] as String;
    return 'The server could not do that. Try again.';
  }
  return 'Something went wrong. Check your internet and try again.';
}
