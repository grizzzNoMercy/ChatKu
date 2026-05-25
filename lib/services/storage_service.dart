import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<String> uploadProfilePhoto({
    required String uid,
    required File file,
  }) async {
    final ref = _storage.ref().child('profiles/$uid/avatar.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  static Future<String> uploadChatFile({
    required String roomId,
    required File file,
    required String type,
    String? fileName,
  }) async {
    final name = fileName ?? p.basename(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref().child('chats/$roomId/$type/${timestamp}_$name');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }
}
