import 'package:cloud_firestore/cloud_firestore.dart';
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
    final batch = _firestore.batch();
    final ref = _firestore.collection(_collection).doc();

    // Outgoing log (from caller's perspective)
    final outgoingData = CallLogModel(
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

    // We store ONE document per call with both sides' info.
    // Each user queries where participants arrayContains their uid.
    batch.set(ref, outgoingData);
    await batch.commit();
  }

  /// Stream of call logs for [currentUid], newest first.
  static Stream<List<CallLogModel>> logsStream(String currentUid) {
    return _firestore
        .collection(_collection)
        .where('participants', arrayContains: currentUid)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => CallLogModel.fromMap(d.id, d.data()))
              .toList();
          // Sort client-side (newest first) to avoid requiring a composite index in Firestore
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list.take(100).toList();
        });
  }

  /// Count of missed calls for [currentUid] since [since].
  static Stream<int> missedCallCountStream(
      String currentUid, DateTime since) {
    return _firestore
        .collection(_collection)
        .where('participants', arrayContains: currentUid)
        .snapshots()
        .map((snap) {
          final sinceTs = Timestamp.fromDate(since);
          return snap.docs.where((doc) {
            final data = doc.data();
            final receiverId = data['receiverId'] as String? ?? '';
            final status = data['status'] as String? ?? '';
            final ts = data['timestamp'] as Timestamp?;
            
            return receiverId == currentUid &&
                status == 'missed' &&
                ts != null &&
                ts.compareTo(sinceTs) > 0;
          }).length;
        });
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
