import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class ContactService {
  static final _firestore = FirebaseFirestore.instance;

  // ── Search user by email ──────────────────────────────────────────────
  static Future<UserModel?> searchUserByEmail(String email) async {
    final snap = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return UserModel.fromMap(snap.docs.first.data());
  }

  // ── Send friend request ───────────────────────────────────────────────
  /// Returns error message on failure, null on success.
  static Future<String?> sendFriendRequest({
    required String fromUid,
    required String toUid,
  }) async {
    // Already contacts?
    final userDoc = await _firestore.collection('users').doc(fromUid).get();
    final contacts = List<String>.from(userDoc.data()?['contacts'] ?? []);
    if (contacts.contains(toUid)) {
      return 'Pengguna sudah ada di daftar kontak Anda.';
    }

    // Already sent?
    final existingSent = await _firestore
        .collection('friend_requests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .limit(1)
        .get();
    if (existingSent.docs.isNotEmpty) {
      return 'Permintaan pertemanan sudah dikirim sebelumnya.';
    }

    // Incoming request from that user? → auto-accept
    final existingReceived = await _firestore
        .collection('friend_requests')
        .where('fromUid', isEqualTo: toUid)
        .where('toUid', isEqualTo: fromUid)
        .limit(1)
        .get();
    if (existingReceived.docs.isNotEmpty) {
      await acceptFriendRequest(
        requestId: existingReceived.docs.first.id,
        fromUid: toUid,
        toUid: fromUid,
      );
      return null;
    }

    // Create request
    await _firestore.collection('friend_requests').add({
      'fromUid': fromUid,
      'toUid': toUid,
      'timestamp': Timestamp.now(),
    });
    return null;
  }

  // ── Accept friend request ─────────────────────────────────────────────
  static Future<void> acceptFriendRequest({
    required String requestId,
    required String fromUid,
    required String toUid,
  }) async {
    final batch = _firestore.batch();

    // Add to both users' contacts
    batch.update(_firestore.collection('users').doc(fromUid), {
      'contacts': FieldValue.arrayUnion([toUid]),
    });
    batch.update(_firestore.collection('users').doc(toUid), {
      'contacts': FieldValue.arrayUnion([fromUid]),
    });

    // Delete request
    batch.delete(_firestore.collection('friend_requests').doc(requestId));
    await batch.commit();
  }

  // ── Reject friend request ─────────────────────────────────────────────
  static Future<void> rejectFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).delete();
  }

  // ── Remove contact (both ways) ────────────────────────────────────────
  static Future<void> removeContact({
    required String currentUid,
    required String targetUid,
  }) async {
    final batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(currentUid), {
      'contacts': FieldValue.arrayRemove([targetUid]),
    });
    batch.update(_firestore.collection('users').doc(targetUid), {
      'contacts': FieldValue.arrayRemove([currentUid]),
    });
    await batch.commit();
  }

  // ── Stream contacts as UserModel list ─────────────────────────────────
  /// Listens to the entire users collection and filters by the current
  /// user's contacts array. This gives real-time updates for online status
  /// and contact list changes in a single stream.
  static Stream<List<UserModel>> contactsStream(String currentUid) {
    return _firestore.collection('users').snapshots().map((snap) {
      final allUsers =
          snap.docs.map((d) => UserModel.fromMap(d.data())).toList();
      final currentUser = allUsers.firstWhere(
        (u) => u.uid == currentUid,
        orElse: () => UserModel(uid: '', username: '', email: ''),
      );
      final contactUids = currentUser.contacts;
      return allUsers
          .where((u) => u.uid != currentUid && contactUids.contains(u.uid))
          .toList();
    });
  }

  // ── Stream incoming friend requests ───────────────────────────────────
  static Stream<List<Map<String, dynamic>>> pendingRequestsStream(
      String currentUid) {
    return _firestore
        .collection('friend_requests')
        .where('toUid', isEqualTo: currentUid)
        .snapshots()
        .asyncMap((snap) async {
      final requests = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final fromDoc =
            await _firestore.collection('users').doc(data['fromUid']).get();
        if (fromDoc.exists) {
          requests.add({
            'id': doc.id,
            'fromUid': data['fromUid'],
            'toUid': data['toUid'],
            'timestamp': data['timestamp'],
            'fromUser': UserModel.fromMap(fromDoc.data()!),
          });
        }
      }
      // Sort client-side: newest first
      requests.sort((a, b) {
        final tsA = a['timestamp'] as Timestamp?;
        final tsB = b['timestamp'] as Timestamp?;
        if (tsA == null || tsB == null) return 0;
        return tsB.compareTo(tsA);
      });
      return requests;
    });
  }

  // ── Pending request count (for badge) ─────────────────────────────────
  static Stream<int> pendingRequestCountStream(String currentUid) {
    return _firestore
        .collection('friend_requests')
        .where('toUid', isEqualTo: currentUid)
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}
