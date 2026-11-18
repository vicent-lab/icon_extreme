import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/collab.dart';

/// Bell notifications, project chat, approvals and the payment schedule.
/// The database decides who may see or do what; this class only asks.
class CollabRepository {
  CollabRepository(this._db);
  final SupabaseClient _db;

  static const chatBucket = 'project-chat';

  // ---- notifications ----
  Stream<List<AppNotification>> notifications(String userId) => _db
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(60)
      .map((rows) => [for (final r in rows) AppNotification.fromMap(r)]);

  Future<void> markRead(int id) async => _db.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);

  Future<void> markAllRead(String userId) async =>
      _db.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('user_id', userId).isFilter('read_at', null);

  // ---- chat ----
  Stream<List<ChatMessage>> messages(int projectId) => _db
      .from('project_messages')
      .stream(primaryKey: ['id'])
      .eq('project_id', projectId)
      .order('created_at')
      .map((rows) => [for (final r in rows) ChatMessage.fromMap(r)]);

  Future<void> send(int projectId, String body, {String? photoPath}) async =>
      _db.from('project_messages').insert({'project_id': projectId, 'body': body.trim(), 'photo_path': photoPath});

  Future<void> edit(int messageId, String body) async => _db.from('project_messages').update({'body': body.trim()}).eq('id', messageId);

  Future<String> uploadPhoto(int projectId, String fileName, Uint8List bytes) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final type = switch (ext) { 'png' => 'image/png', 'webp' => 'image/webp', _ => 'image/jpeg' };
    final path = '$projectId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from(chatBucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: type));
    return path;
  }

  Future<String> photoUrl(String path) => _db.storage.from(chatBucket).createSignedUrl(path, 3600);

  Future<void> markSeen(int projectId) async => _db.from('message_reads').upsert(
        {'project_id': projectId, 'user_id': _db.auth.currentUser!.id, 'last_read_at': DateTime.now().toUtc().toIso8601String()},
        onConflict: 'project_id,user_id',
      );

  /// When each other person last opened this chat.
  Future<Map<String, DateTime>> seenBy(int projectId) async {
    final rows = await _db.from('message_reads').select('user_id, last_read_at').eq('project_id', projectId);
    return {for (final r in rows) '${r['user_id']}': DateTime.parse('${r['last_read_at']}')};
  }

  /// Names of the people in a chat (the database only returns the ones this person may see).
  Future<Map<String, String>> names(Iterable<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _db.from('profiles').select('id, full_name, email').inFilter('id', ids.toList());
    return {
      for (final r in rows) '${r['id']}': ('${r['full_name'] ?? ''}'.trim().isNotEmpty ? '${r['full_name']}' : '${r['email'] ?? 'ICON team'}'),
    };
  }

  // ---- approvals and change requests ----
  Future<List<ProjectRequest>> requests(int projectId) async {
    final rows = await _db.from('project_requests').select().eq('project_id', projectId).order('created_at', ascending: false);
    return [for (final r in rows) ProjectRequest.fromMap(r)];
  }

  Future<void> raise(int projectId, {required String title, String? details, num? cost, int? days}) async => _db.from('project_requests').insert({
        'project_id': projectId,
        'kind': 'decision',
        'title': title.trim(),
        'details': details,
        'cost_impact_ugx': cost,
        'days_impact': days,
        'status': 'awaiting_client',
      });

  /// Team adds cost/time to a client's change request and sends it back for approval.
  Future<void> price(int requestId, {num? cost, int? days, String? details}) async => _db.from('project_requests').update({
        'cost_impact_ugx': cost,
        'days_impact': days,
        'details': ?details,
        'status': 'awaiting_client',
      }).eq('id', requestId);

  Future<void> withdraw(int requestId) async => _db.from('project_requests').update({'status': 'withdrawn'}).eq('id', requestId);

  Future<void> decide(int requestId, {required bool approve, String? note}) async =>
      _db.rpc('decide_request', params: {'request_id': requestId, 'approve': approve, 'note': (note ?? '').trim().isEmpty ? null : note!.trim()});

  Future<void> requestChange(int projectId, String title, String? details) async =>
      _db.rpc('request_change', params: {'pid': projectId, 'title': title.trim(), 'details': details});

  // ---- payment schedule ----
  Future<List<Payment>> payments(int projectId) async {
    final rows = await _db.from('project_payments').select().eq('project_id', projectId).order('sort_order').order('due_date');
    return [for (final r in rows) Payment.fromMap(r)];
  }

  // ---- phone alerts ----
  /// Saves this device so alerts can reach it. [subscriptionJson] comes from the browser.
  Future<void> saveDevice(String subscriptionJson) async {
    final m = jsonDecode(subscriptionJson) as Map<String, dynamic>;
    final keys = (m['keys'] as Map?) ?? const {};
    await _db.from('push_subscriptions').upsert({
      'endpoint': m['endpoint'],
      'p256dh': keys['p256dh'],
      'auth': keys['auth'],
    }, onConflict: 'endpoint');
  }

  Future<void> forgetDevice(String endpoint) async => _db.from('push_subscriptions').delete().eq('endpoint', endpoint);

  Future<void> setQuietHours(int? from, int? to) async =>
      _db.from('profiles').update({'quiet_from': from, 'quiet_to': to}).eq('id', _db.auth.currentUser!.id);

  Future<(int?, int?)> quietHours() async {
    final r = await _db.from('profiles').select('quiet_from, quiet_to').eq('id', _db.auth.currentUser!.id).single();
    return (r['quiet_from'] as int?, r['quiet_to'] as int?);
  }

  Future<void> testAlert() async => _db.rpc('test_my_alerts');
}
