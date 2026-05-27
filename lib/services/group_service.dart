import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../models/message_model.dart';
import 'storage_service.dart';

class GroupService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create group
  static Future<String?> createGroup({
    required String name,
    required String adminId,
    required List<String> memberIds,
    File? photoFile,
  }) async {
    try {
      final docRef = _firestore.collection('groups').doc();
      String photoUrl = '';

      if (photoFile != null) {
        photoUrl = await StorageService.uploadGroupPhoto(
          groupId: docRef.id,
          file: photoFile,
        );
      }

      // Admin is also a member
      final members = Set<String>.from(memberIds);
      members.add(adminId);

      final group = GroupModel(
        id: docRef.id,
        name: name,
        photoUrl: photoUrl,
        adminId: adminId,
        members: members.toList(),
        lastMessage: 'Grup dibuat',
        lastTimestamp: Timestamp.now(),
        createdAt: Timestamp.now(),
      );

      await docRef.set(group.toMap());
      return null;
    } catch (e) {
      return 'Gagal membuat grup: $e';
    }
  }

  // Stream groups for a user
  static Stream<List<GroupModel>> userGroupsStream(String userId) {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get a specific group stream
  static Stream<GroupModel?> groupStream(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .snapshots()
        .map((doc) => doc.exists ? GroupModel.fromMap(doc.data()!, doc.id) : null);
  }

  // Send group text message
  static Future<void> sendTextMessage({
    required String groupId,
    required String senderId,
    required String message,
  }) async {
    await _ensureAndSend(
      groupId: groupId,
      senderId: senderId,
      message: message,
      type: MessageType.text,
    );
  }

  // Send group image
  static Future<void> sendImage({
    required String groupId,
    required String senderId,
    required File file,
  }) async {
    final url = await StorageService.uploadChatFile(
      roomId: groupId,
      file: file,
      type: 'group_images',
    );
    await _ensureAndSend(
      groupId: groupId,
      senderId: senderId,
      message: '📷 Foto',
      type: MessageType.image,
      fileUrl: url,
    );
  }

  // Send group video
  static Future<void> sendVideo({
    required String groupId,
    required String senderId,
    required File file,
  }) async {
    final url = await StorageService.uploadChatFile(
      roomId: groupId,
      file: file,
      type: 'group_videos',
    );
    await _ensureAndSend(
      groupId: groupId,
      senderId: senderId,
      message: '🎬 Video',
      type: MessageType.video,
      fileUrl: url,
    );
  }

  // Send group file
  static Future<void> sendFile({
    required String groupId,
    required String senderId,
    required File file,
    required String fileName,
  }) async {
    final url = await StorageService.uploadChatFile(
      roomId: groupId,
      file: file,
      type: 'group_files',
      fileName: fileName,
    );
    await _ensureAndSend(
      groupId: groupId,
      senderId: senderId,
      message: '📎 $fileName',
      type: MessageType.file,
      fileUrl: url,
      fileName: fileName,
    );
  }

  static Future<void> _ensureAndSend({
    required String groupId,
    required String senderId,
    required String message,
    required MessageType type,
    String fileUrl = '',
    String fileName = '',
  }) async {
    final msgRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc();

    final msg = MessageModel(
      id: msgRef.id,
      senderId: senderId,
      receiverId: groupId, // Using receiverId to store groupId for compatibility
      message: message,
      type: type,
      fileUrl: fileUrl,
      fileName: fileName,
      timestamp: Timestamp.now(),
    );

    final batch = _firestore.batch();
    batch.set(msgRef, msg.toMap());
    
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    final members = List<String>.from(groupDoc.data()?['members'] ?? []);
    
    final updates = <String, dynamic>{
      'lastMessage': message,
      'lastTimestamp': Timestamp.now(),
      'lastSenderId': senderId,
    };
    
    for (var member in members) {
      if (member != senderId) {
        updates['unreadCounts.$member'] = FieldValue.increment(1);
      }
    }

    batch.update(_firestore.collection('groups').doc(groupId), updates);
    await batch.commit();
  }

  // Mark group as read for a specific user
  static Future<void> markGroupAsRead(String groupId, String currentUid) async {
    await _firestore.collection('groups').doc(groupId).update({
      'unreadCounts.$currentUid': 0,
    });
  }

  // Stream group messages
  static Stream<List<MessageModel>> messagesStream(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}
