import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceService extends ChangeNotifier with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _currentRoomId;

  String? get currentRoomId => _currentRoomId;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOnline(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _setOnline(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _setOnline(false);
        if (_currentRoomId != null) {
          leaveRoom(_currentRoomId!);
        }
        break;
      default:
        break;
    }
  }

  Future<void> _setOnline(bool online) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final Map<String, dynamic> data = {'online': online};
      if (!online) {
        data['lastSeen'] = Timestamp.now();
      }
      await _firestore.collection('users').doc(uid).update(data);
    } catch (_) {}
  }

  Future<void> enterRoom(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _currentRoomId = roomId;
    try {
      await _firestore.collection('users').doc(uid).update({
        'inRoom': true,
        'currentRoom': roomId,
      });
    } catch (_) {}
    notifyListeners();
  }

  Future<void> leaveRoom(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _currentRoomId = null;
    try {
      await _firestore.collection('users').doc(uid).update({
        'inRoom': false,
        'currentRoom': '',
        'lastRoomLeave': Timestamp.now(),
      });
    } catch (_) {}
    notifyListeners();
  }

  // Set typing status
  Future<void> setTyping({
    required String roomId,
    required String uid,
    required bool isTyping,
  }) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('typing')
          .doc(uid)
          .set({'isTyping': isTyping, 'timestamp': Timestamp.now()});
    } catch (_) {}
  }

  // Stream typing status of other user
  Stream<bool> typingStream({
    required String roomId,
    required String otherUid,
  }) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('typing')
        .doc(otherUid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return false;
      final data = doc.data()!;
      final isTyping = data['isTyping'] ?? false;
      if (!isTyping) return false;
      // Auto-expire typing after 5s
      final ts = data['timestamp'] as Timestamp?;
      if (ts == null) return false;
      final diff = DateTime.now().difference(ts.toDate()).inSeconds;
      return diff < 5;
    });
  }
}
