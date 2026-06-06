import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class StorageService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _bucketName = 'ChatKu_media'; // Pastikan nama bucket di Supabase adalah 'ChatKu_media'

  static Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
    String extension = '.jpg',
  }) async {
    final path = 'profiles/$uid/avatar$extension';
    await _supabase.storage.from(_bucketName).uploadBinary(
      path, 
      bytes,
      fileOptions: const FileOptions(upsert: true), // overwrite if exists
    );
    return _supabase.storage.from(_bucketName).getPublicUrl(path);
  }

  static Future<String> uploadGroupPhoto({
    required String groupId,
    required Uint8List bytes,
    String extension = '.jpg',
  }) async {
    final path = 'groups/$groupId/avatar$extension';
    await _supabase.storage.from(_bucketName).uploadBinary(
      path, 
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );
    return _supabase.storage.from(_bucketName).getPublicUrl(path);
  }

  static Future<String> uploadChatFile({
    required String roomId,
    required Uint8List bytes,
    required String type,
    required String fileName,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'chats/$roomId/$type/${timestamp}_$fileName';
    await _supabase.storage.from(_bucketName).uploadBinary(
      path, 
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );
    return _supabase.storage.from(_bucketName).getPublicUrl(path);
  }
}
