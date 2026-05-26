import 'package:cloud_firestore/cloud_firestore.dart';

enum CallLogType { audio, video }

enum CallLogStatus { outgoing, incoming, missed }

class CallLogModel {
  final String id;
  final String callerId;
  final String callerName;
  final String callerPhotoUrl;
  final String receiverId;
  final String receiverName;
  final String receiverPhotoUrl;
  final CallLogType type;
  final CallLogStatus status;
  final int durationSeconds; // 0 if missed/rejected
  final Timestamp timestamp;

  CallLogModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.callerPhotoUrl,
    required this.receiverId,
    required this.receiverName,
    required this.receiverPhotoUrl,
    required this.type,
    required this.status,
    required this.durationSeconds,
    required this.timestamp,
  });

  factory CallLogModel.fromMap(String id, Map<String, dynamic> map) {
    return CallLogModel(
      id: id,
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? '',
      callerPhotoUrl: map['callerPhotoUrl'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? '',
      receiverPhotoUrl: map['receiverPhotoUrl'] ?? '',
      type: (map['type'] as String?) == 'video'
          ? CallLogType.video
          : CallLogType.audio,
      status: _parseStatus(map['status'] as String? ?? ''),
      durationSeconds: (map['durationSeconds'] as int?) ?? 0,
      timestamp: map['timestamp'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerPhotoUrl': callerPhotoUrl,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPhotoUrl': receiverPhotoUrl,
      'type': type == CallLogType.video ? 'video' : 'audio',
      'status': _statusToString(status),
      'durationSeconds': durationSeconds,
      'timestamp': timestamp,
      // For easy querying: participants array
      'participants': [callerId, receiverId],
    };
  }

  static CallLogStatus _parseStatus(String s) {
    switch (s) {
      case 'outgoing':
        return CallLogStatus.outgoing;
      case 'incoming':
        return CallLogStatus.incoming;
      case 'missed':
        return CallLogStatus.missed;
      default:
        return CallLogStatus.missed;
    }
  }

  static String _statusToString(CallLogStatus s) {
    switch (s) {
      case CallLogStatus.outgoing:
        return 'outgoing';
      case CallLogStatus.incoming:
        return 'incoming';
      case CallLogStatus.missed:
        return 'missed';
    }
  }

  /// Returns the "other" party name from the perspective of [currentUid]
  String otherName(String currentUid) =>
      currentUid == callerId ? receiverName : callerName;

  /// Returns the "other" party photoUrl from the perspective of [currentUid]
  String otherPhotoUrl(String currentUid) =>
      currentUid == callerId ? receiverPhotoUrl : callerPhotoUrl;

  /// Returns the "other" party uid from the perspective of [currentUid]
  String otherUid(String currentUid) =>
      currentUid == callerId ? receiverId : callerId;

  /// Duration formatted as mm:ss
  String get durationText {
    if (durationSeconds == 0) return '';
    final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
