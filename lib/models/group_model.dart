import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String photoUrl;
  final String adminId;
  final List<String> members;
  final String lastMessage;
  final Timestamp lastTimestamp;
  final Timestamp createdAt;

  GroupModel({
    required this.id,
    required this.name,
    this.photoUrl = '',
    required this.adminId,
    required this.members,
    this.lastMessage = '',
    required this.lastTimestamp,
    required this.createdAt,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupModel(
      id: id,
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      adminId: map['adminId'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastTimestamp: map['lastTimestamp'] ?? Timestamp.now(),
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'adminId': adminId,
      'members': members,
      'lastMessage': lastMessage,
      'lastTimestamp': lastTimestamp,
      'createdAt': createdAt,
    };
  }
}
