import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username;
  final String email;
  final String photoUrl;
  final bool online;
  final List<String> contacts;
  final Timestamp? lastSeen;
  final bool inRoom;
  final String currentRoom;
  final Timestamp? lastRoomLeave;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    this.photoUrl = '',
    this.online = false,
    this.lastSeen,
    this.inRoom = false,
    this.currentRoom = '',
    this.lastRoomLeave,
    this.contacts = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      online: map['online'] ?? false,
      lastSeen: map['lastSeen'],
      inRoom: map['inRoom'] ?? false,
      currentRoom: map['currentRoom'] ?? '',
      lastRoomLeave: map['lastRoomLeave'],
      contacts: List<String>.from(map['contacts'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'email': email,
      'photoUrl': photoUrl,
      'online': online,
      'lastSeen': lastSeen,
      'inRoom': inRoom,
      'currentRoom': currentRoom,
      'lastRoomLeave': lastRoomLeave,
      'contacts': contacts,
    };
  }

  UserModel copyWith({
    String? uid,
    String? username,
    String? email,
    String? photoUrl,
    bool? online,
    Timestamp? lastSeen,
    bool? inRoom,
    String? currentRoom,
    Timestamp? lastRoomLeave,
    List<String>? contacts,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      online: online ?? this.online,
      lastSeen: lastSeen ?? this.lastSeen,
      inRoom: inRoom ?? this.inRoom,
      currentRoom: currentRoom ?? this.currentRoom,
      lastRoomLeave: lastRoomLeave ?? this.lastRoomLeave,
      contacts: contacts ?? this.contacts,
    );
  }
}
