import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'call_log_service.dart';

class CallService {
  static final _firestore = FirebaseFirestore.instance;

  static const _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      }
    ],
    'sdpSemantics': 'unified-plan',
  };

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  String? _currentCallId;
  StreamSubscription? _candidateSub;
  StreamSubscription? _statusSub;

  // For call log
  String? _callerId;
  String? _callerName;
  String? _callerPhotoUrl;
  String? _receiverId;
  String? _receiverName;
  String? _receiverPhotoUrl;
  bool? _isVideo;
  bool _wasAnswered = false;
  DateTime? _answerTime;
  bool _logSaved = false;

  // Callbacks
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(String)? onCallStateChanged;

  /// Request camera and microphone permissions at runtime (required on Android).
  static Future<bool> requestPermissions({required bool isVideo}) async {
    if (kIsWeb) return true; // Web handles its own permission prompts

    final permissions = <Permission>[Permission.microphone];
    if (isVideo) permissions.add(Permission.camera);

    final statuses = await permissions.request();

    final micGranted = statuses[Permission.microphone]?.isGranted ?? false;
    final camGranted = isVideo
        ? (statuses[Permission.camera]?.isGranted ?? false)
        : true;

    if (!micGranted) {
      debugPrint('[CallService] Microphone permission DENIED');
    }
    if (isVideo && !camGranted) {
      debugPrint('[CallService] Camera permission DENIED');
    }

    return micGranted && camGranted;
  }

  // ── Start call (caller) ───────────────────────────────────────────────
  Future<String> startCall({
    required String callerId,
    required String callerName,
    required String callerPhotoUrl,
    required String receiverId,
    required String receiverName,
    required bool isVideo,
  }) async {
    // Request runtime permissions first
    final granted = await requestPermissions(isVideo: isVideo);
    if (!granted) {
      throw Exception('Permissions not granted for ${isVideo ? "video" : "audio"} call');
    }

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
    
    _pc!.onAddStream = (stream) {
      onRemoteStream?.call(stream);
    };

    _pc!.onIceCandidate = (c) {
      if (c.candidate != null && c.candidate!.isNotEmpty) {
        callRef.collection('candidates').add({
          'candidate': c.candidate,
          'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
          'fromUid': callerId,
        });
      }
    };

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);

    // Track metadata for log
    _callerId = callerId;
    _callerName = callerName;
    _callerPhotoUrl = callerPhotoUrl;
    _receiverId = receiverId;
    _receiverName = receiverName;
    _isVideo = isVideo;
    _wasAnswered = false;
    _answerTime = null;
    _logSaved = false;

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
        if (!_wasAnswered) {
          _wasAnswered = true;
          _answerTime = DateTime.now();
          _receiverPhotoUrl = data['receiverPhotoUrl'] as String? ?? '';
        }
        final answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );
        await _pc?.setRemoteDescription(answer);
      }
      if (status == 'ended' || status == 'rejected') {
        await _saveLog();
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
    String receiverName = '',
    String receiverPhotoUrl = '',
  }) async {
    // Request runtime permissions first
    final granted = await requestPermissions(isVideo: isVideo);
    if (!granted) {
      debugPrint('[CallService] Permissions denied for answering call');
    }

    _currentCallId = callId;
    _wasAnswered = true;
    _answerTime = DateTime.now();
    _isVideo = isVideo;
    _logSaved = false;
    final callRef = _firestore.collection('calls').doc(callId);
    final callData = (await callRef.get()).data()!;

    // Track metadata for receiver side
    _callerId = callData['callerId'] as String? ?? '';
    _callerName = callData['callerName'] as String? ?? '';
    _callerPhotoUrl = callData['callerPhotoUrl'] as String? ?? '';
    _receiverId = receiverUid;
    _receiverName = receiverName.isNotEmpty
        ? receiverName
        : callData['receiverName'] as String? ?? '';
    _receiverPhotoUrl = receiverPhotoUrl.isNotEmpty
        ? receiverPhotoUrl
        : callData['receiverPhotoUrl'] as String? ?? '';

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
    
    _pc!.onAddStream = (stream) {
      onRemoteStream?.call(stream);
    };

    _pc!.onIceCandidate = (c) {
      if (c.candidate != null && c.candidate!.isNotEmpty) {
        callRef.collection('candidates').add({
          'candidate': c.candidate,
          'sdpMid': c.sdpMid,
          'sdpMLineIndex': c.sdpMLineIndex,
          'fromUid': receiverUid,
        });
      }
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
    _statusSub = callRef.snapshots().listen((snap) async {
      final status = snap.data()?['status'] as String? ?? '';
      onCallStateChanged?.call(status);
      if (status == 'ended') {
        await _saveLog();
        await cleanup();
      }
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
    await _saveLog();
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

  // ── Save call log ─────────────────────────────────────────────────────
  Future<void> _saveLog() async {
    if (_logSaved) return;
    if (_callerId == null || _receiverId == null) {
      debugPrint('[CallService] _saveLog skipped: callerId=$_callerId, receiverId=$_receiverId');
      return;
    }
    _logSaved = true;

    final duration = (_wasAnswered && _answerTime != null)
        ? DateTime.now().difference(_answerTime!).inSeconds
        : 0;

    try {
      await CallLogService.saveLog(
        callerId: _callerId!,
        callerName: _callerName ?? '',
        callerPhotoUrl: _callerPhotoUrl ?? '',
        receiverId: _receiverId!,
        receiverName: _receiverName ?? '',
        receiverPhotoUrl: _receiverPhotoUrl ?? '',
        isVideo: _isVideo ?? false,
        wasAnswered: _wasAnswered,
        durationSeconds: duration,
      );
      debugPrint('[CallService] Call log saved successfully');
    } catch (e) {
      debugPrint('[CallService] Failed to save call log: $e');
      _logSaved = false; // Allow retry
    }
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
