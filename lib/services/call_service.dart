import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallService {
  static final _firestore = FirebaseFirestore.instance;

  static const _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  String? _currentCallId;
  StreamSubscription? _candidateSub;
  StreamSubscription? _statusSub;

  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(String)? onCallStateChanged;

  // ── Start call (caller) ───────────────────────────────────────────────
  Future<String> startCall({
    required String callerId,
    required String callerName,
    required String callerPhotoUrl,
    required String receiverId,
    required String receiverName,
    required bool isVideo,
  }) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': isVideo ? {'facingMode': 'user'} : false,
    });
    onLocalStream?.call(_localStream!);

    _pc = await createPeerConnection(_config);
    _localStream!.getTracks().forEach((t) => _pc!.addTrack(t, _localStream!));

    final callRef = _firestore.collection('calls').doc();
    _currentCallId = callRef.id;

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) onRemoteStream?.call(event.streams[0]);
    };

    _pc!.onIceCandidate = (c) {
      callRef.collection('candidates').add({
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
        'fromUid': callerId,
      });
    };

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    await callRef.set({
      'callerId': callerId,
      'callerName': callerName,
      'callerPhotoUrl': callerPhotoUrl,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'type': isVideo ? 'video' : 'audio',
      'status': 'ringing',
      'offer': {'sdp': offer.sdp, 'type': offer.type},
      'answer': null,
      'timestamp': Timestamp.now(),
    });

    // Listen for answer / status changes
    _statusSub = callRef.snapshots().listen((snap) async {
      final data = snap.data();
      if (data == null) return;
      final status = data['status'] as String? ?? '';
      onCallStateChanged?.call(status);

      if (status == 'answered' && data['answer'] != null) {
        final answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        await _pc?.setRemoteDescription(answer);
      }
      if (status == 'ended' || status == 'rejected') {
        await cleanup();
      }
    });

    // Listen for remote ICE candidates (filter client-side)
    _candidateSub = callRef
        .collection('candidates')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final d = change.doc.data()!;
          if (d['fromUid'] != callerId) {
            _pc?.addCandidate(RTCIceCandidate(
              d['candidate'],
              d['sdpMid'],
              d['sdpMLineIndex'],
            ));
          }
        }
      }
    });

    return callRef.id;
  }

  // ── Answer call (receiver) ────────────────────────────────────────────
  Future<void> answerCall({
    required String callId,
    required String receiverUid,
    required bool isVideo,
  }) async {
    _currentCallId = callId;
    final callRef = _firestore.collection('calls').doc(callId);
    final callData = (await callRef.get()).data()!;

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': isVideo ? {'facingMode': 'user'} : false,
    });
    onLocalStream?.call(_localStream!);

    _pc = await createPeerConnection(_config);
    _localStream!.getTracks().forEach((t) => _pc!.addTrack(t, _localStream!));

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) onRemoteStream?.call(event.streams[0]);
    };

    _pc!.onIceCandidate = (c) {
      callRef.collection('candidates').add({
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
        'fromUid': receiverUid,
      });
    };

    // Set offer → create answer
    await _pc!.setRemoteDescription(RTCSessionDescription(
      callData['offer']['sdp'],
      callData['offer']['type'],
    ));
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);

    await callRef.update({
      'answer': {'sdp': answer.sdp, 'type': answer.type},
      'status': 'answered',
    });

    // Listen status
    _statusSub = callRef.snapshots().listen((snap) {
      final status = snap.data()?['status'] as String? ?? '';
      onCallStateChanged?.call(status);
      if (status == 'ended') cleanup();
    });

    // Listen remote candidates
    _candidateSub = callRef.collection('candidates').snapshots().listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final d = change.doc.data()!;
          if (d['fromUid'] != receiverUid) {
            _pc?.addCandidate(RTCIceCandidate(
              d['candidate'],
              d['sdpMid'],
              d['sdpMLineIndex'],
            ));
          }
        }
      }
    });
  }

  // ── End / Reject ──────────────────────────────────────────────────────
  Future<void> endCall() async {
    if (_currentCallId != null) {
      await _firestore
          .collection('calls')
          .doc(_currentCallId)
          .update({'status': 'ended'});
    }
    await cleanup();
  }

  static Future<void> rejectCall(String callId) async {
    await _firestore.collection('calls').doc(callId).update({
      'status': 'rejected',
    });
  }

  // ── Media controls ────────────────────────────────────────────────────
  void toggleMute(bool muted) {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !muted);
  }

  void toggleCamera(bool off) {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !off);
  }

  Future<void> switchCamera() async {
    final track = _localStream?.getVideoTracks().firstOrNull;
    if (track != null) Helper.switchCamera(track);
  }

  // ── Incoming call stream ──────────────────────────────────────────────
  static Stream<QuerySnapshot> incomingCallStream(String currentUid) {
    return _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: currentUid)
        .where('status', isEqualTo: 'ringing')
        .snapshots();
  }

  // ── Cleanup ───────────────────────────────────────────────────────────
  Future<void> cleanup() async {
    _candidateSub?.cancel();
    _statusSub?.cancel();
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    await _pc?.close();
    _pc = null;
    _localStream = null;
    _currentCallId = null;
  }
}
