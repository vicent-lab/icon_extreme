import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

const _mime = {
  'pdf': 'application/pdf',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'zip': 'application/zip',
  'doc': 'application/msword',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

class StorageRepository {
  StorageRepository(this._db);
  final SupabaseClient _db;

  static const privateBucket = 'project-documents'; // plans and contracts, opened with short-lived links
  static const publicBucket = 'site-media'; // website pictures

  String _safe(String name) => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]+'), '-');

  /// Uploads and returns the storage path.
  Future<String> upload(String bucket, String folder, String fileName, Uint8List bytes) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final path = '$folder/${DateTime.now().millisecondsSinceEpoch}-${_safe(fileName)}';
    await _db.storage.from(bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: _mime[ext]));
    return path;
  }

  /// A link that stops working after [seconds], for private files.
  Future<String> signedUrl(String path, {int seconds = 120}) => _db.storage.from(privateBucket).createSignedUrl(path, seconds);

  String publicUrl(String path) => _db.storage.from(publicBucket).getPublicUrl(path);

  Future<void> remove(String bucket, String path) async {
    await _db.storage.from(bucket).remove([path]);
  }
}
