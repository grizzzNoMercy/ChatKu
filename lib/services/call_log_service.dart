import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/call_log_model.dart';

class CallLogService {
  static final _firestore = FirebaseFirestore.instance;
  static const _collection = 'call_logs';

  /// Save a log entry after a call ends.
  /// Called internally by [CallService].
  static Future<void> saveLog({
    required String callerId,
    required String callerName,
    required String callerPhotoUrl,
    required String receiverId,
    required String receiverName,
    required String receiverPhotoUrl,
    required bool isVideo,
    required bool wasAnswered,
    required int durationSeconds,
  }) async {
    debugPrint('[CallLogService] saveLog called: caller=$callerId, receiver=$receiverId, answered=$wasAnswered');

    final data = CallLogModel(
      id: '',
      callerId: callerId,
      callerName: callerName,
      callerPhotoUrl: callerPhotoUrl,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverPhotoUrl: receiverPhotoUrl,
      type: isVideo ? CallLogType.video : CallLogType.audio,
      status: wasAnswered ? CallLogStatus.outgoing : CallLogStatus.missed,
      durationSeconds: wasAnswered ? durationSeconds : 0,
      timestamp: Timestamp.now(),
    ).toMap();

    try {
      await _firestore.collection(_collection).add(data);
      debugPrint('[CallLogService] Log saved to Firestore successfully');
    } catch (e) {
      debugPrint('[CallLogService] ERROR saving log: $e');
      rethrow;
    }
  }

  /// Stream of call logs for [currentUid], newest first.
  static Stream<List<CallLogModel>> logsStream(String currentUid) {
    return _firestore
        .collection(_collection)
        .where('participants', arrayContains: currentUid)
        .limit(100)
        .snapshots()
        .map((snap) {
      final logs = snap.docs
          .map((d) => CallLogModel.fromMap(d.id, d.data()))
          .toList();
      // Sort client-side to avoid needing a composite Firestore index
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs;
    });
  }

  /// Count of missed calls for [currentUid] since [since].
  static Stream<int> missedCallCountStream(
      String currentUid, DateTime since) {
    final sinceTs = Timestamp.fromDate(since);
    return _firestore
        .collection(_collection)
        .where('participants', arrayContains: currentUid)
        .snapshots()
        .map((s) => s.docs.where((doc) {
              final data = doc.data();
              return data['receiverId'] == currentUid &&
                  data['status'] == 'missed' &&
                  (data['timestamp'] as Timestamp?)
                          ?.compareTo(sinceTs) ==
                      1;
            }).length);
  }

  /// Delete a single log entry.
  static Future<void> deleteLog(String logId) async {
    await _firestore.collection(_collection).doc(logId).delete();
  }

  /// Delete ALL log entries for [currentUid] (clear history).
  static Future<void> clearAllLogs(String currentUid) async {
    final snap = await _firestore
        .collection(_collection)
        .where('participants', arrayContains: currentUid)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
