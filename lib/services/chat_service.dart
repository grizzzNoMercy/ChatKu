import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'storage_service.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate consistent room ID from two UIDs
  static String getRoomId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // Ensure chat room exists
  static Future<void> ensureRoom(String roomId, String uid1, String uid2) async {
    final ref = _firestore.collection('chat_rooms').doc(roomId);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'roomId': roomId,
        'participants': [uid1, uid2],
        'lastMessage': '',
        'lastTimestamp': Timestamp.now(),
      });
    }
  }

  // Send text message
  static Future<void> sendTextMessage({
    required String roomId,
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    await _ensureAndSend(
      roomId: roomId,
      senderId: senderId,
      receiverId: receiverId,
      message: message,
      type: MessageType.text,
    );
  }

  // Send image
  static Future<void> sendImage({
    required String roomId,
    required String senderId,
    required String receiverId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final url = await StorageService.uploadChatFile(
      roomId: roomId,
      bytes: bytes,
      type: 'images',
      fileName: fileName,
    );
    await _ensureAndSend(
      roomId: roomId,
      senderId: senderId,
      receiverId: receiverId,
      message: '📷 Foto',
      type: MessageType.image,
      fileUrl: url,
    );
  }

  // Send video
  static Future<void> sendVideo({
    required String roomId,
    required String senderId,
    required String receiverId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final url = await StorageService.uploadChatFile(
      roomId: roomId,
      bytes: bytes,
      type: 'videos',
      fileName: fileName,
    );
    await _ensureAndSend(
      roomId: roomId,
      senderId: senderId,
      receiverId: receiverId,
      message: '🎬 Video',
      type: MessageType.video,
      fileUrl: url,
    );
  }

  // Send file
  static Future<void> sendFile({
    required String roomId,
    required String senderId,
    required String receiverId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final url = await StorageService.uploadChatFile(
      roomId: roomId,
      bytes: bytes,
      type: 'files',
      fileName: fileName,
    );
    await _ensureAndSend(
      roomId: roomId,
      senderId: senderId,
      receiverId: receiverId,
      message: '📎 $fileName',
      type: MessageType.file,
      fileUrl: url,
      fileName: fileName,
    );
  }

  static Future<void> _ensureAndSend({
    required String roomId,
    required String senderId,
    required String receiverId,
    required String message,
    required MessageType type,
    String fileUrl = '',
    String fileName = '',
  }) async {
    final msgRef = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc();

    final msg = MessageModel(
      id: msgRef.id,
      senderId: senderId,
      receiverId: receiverId,
      message: message,
      type: type,
      fileUrl: fileUrl,
      fileName: fileName,
      timestamp: Timestamp.now(),
    );

    final batch = _firestore.batch();
    batch.set(msgRef, msg.toMap());
    batch.update(_firestore.collection('chat_rooms').doc(roomId), {
      'lastMessage': message,
      'lastTimestamp': Timestamp.now(),
      'lastSenderId': senderId,
      'unreadCounts.$receiverId': FieldValue.increment(1),
    });
    await batch.commit();
  }

  // Mark room as read for a specific user
  static Future<void> markRoomAsRead(String roomId, String currentUid) async {
    await _firestore.collection('chat_rooms').doc(roomId).update({
      'unreadCounts.$currentUid': 0,
    });
  }

  // Stream messages
  static Stream<List<MessageModel>> messagesStream(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Stream all users except current
  static Stream<List<UserModel>> usersStream(String currentUid) {
    return _firestore
        .collection('users')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => UserModel.fromMap(doc.data()))
            .where((u) => u.uid != currentUid)
            .toList());
  }

  // Stream single user
  static Stream<UserModel?> userStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromMap(doc.data()!) : null);
  }

  // Get last message for a room
  static Stream<Map<String, dynamic>?> roomStream(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }
}
