import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, video, file }

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final MessageType type;
  final String fileUrl;
  final String fileName;
  final Timestamp timestamp;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.type = MessageType.text,
    this.fileUrl = '',
    this.fileName = '',
    required this.timestamp,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      message: map['message'] ?? '',
      type: _typeFromString(map['type'] ?? 'text'),
      fileUrl: map['fileUrl'] ?? '',
      fileName: map['fileName'] ?? '',
      timestamp: map['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'type': type.name,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'timestamp': timestamp,
    };
  }

  static MessageType _typeFromString(String type) {
    switch (type) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'file':
        return MessageType.file;
      default:
        return MessageType.text;
    }
  }
}
