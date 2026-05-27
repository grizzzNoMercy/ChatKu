import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/call_service.dart';
import '../services/sound_service.dart';

class CallPage extends StatefulWidget {
  final String currentUid;
  final String targetName;
  final String targetPhotoUrl;
  final bool isVideo;
  final bool isCaller;

  // Caller-specific
  final String? targetUid;
  final String? currentUserName;
  final String? currentUserPhotoUrl;

  // Receiver-specific
  final String? callId;

  const CallPage({
    super.key,
    required this.currentUid,
    required this.targetName,
    required this.targetPhotoUrl,
    required this.isVideo,
    required this.isCaller,
    this.targetUid,
    this.currentUserName,
    this.currentUserPhotoUrl,
    this.callId,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  final CallService _callService = CallService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = true;
  String _callStatus = 'ringing';
  Timer? _timer;
  int _seconds = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    _callService.onLocalStream = (stream) {
      if (!_disposed) setState(() => _localRenderer.srcObject = stream);
    };
    _callService.onRemoteStream = (stream) {
      if (!_disposed) setState(() => _remoteRenderer.srcObject = stream);
    };
    _callService.onCallStateChanged = (status) {
      if (_disposed) return;
      setState(() => _callStatus = status);
      if (status == 'answered') {
        // Stop ringback tone when call is answered
        SoundService.instance.stopRingback();
        if (_timer == null) _startTimer();
      }
      if (status == 'ended' || status == 'rejected') {
        SoundService.instance.stopRingback();
        _timer?.cancel();
        if (mounted) Navigator.pop(context);
      }
    };

    if (widget.isCaller) {
      // Play ringback tone while waiting for answer
      SoundService.instance.playRingback();
      await _callService.startCall(
        callerId: widget.currentUid,
        callerName: widget.currentUserName ?? '',
        callerPhotoUrl: widget.currentUserPhotoUrl ?? '',
        receiverId: widget.targetUid!,
        receiverName: widget.targetName,
        isVideo: widget.isVideo,
      );
    } else {
      await _callService.answerCall(
        callId: widget.callId!,
        receiverUid: widget.currentUid,
        isVideo: widget.isVideo,
      );
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_disposed) setState(() => _seconds++);
    });
  }

  String get _duration {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _statusText {
    switch (_callStatus) {
      case 'ringing':
        return widget.isCaller ? 'Memanggil...' : 'Menghubungkan...';
      case 'answered':
        return _duration;
      case 'ended':
        return 'Panggilan selesai';
      case 'rejected':
        return 'Panggilan ditolak';
      default:
        return 'Menghubungkan...';
    }
  }

  Future<void> _endCall() async {
    await SoundService.instance.stopRingback();
    await _callService.endCall();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    SoundService.instance.stopRingback();
    // Use endCall to ensure log is saved before cleanup
    _callService.endCall();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: widget.isVideo ? _buildVideoCall() : _buildAudioCall(),
    );
  }

  // ── Audio Call UI ─────────────────────────────────────────────────────
  Widget _buildAudioCall() {
    return Container(
      color: const Color(0xFF111111),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            // Avatar
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color(0xFF333333),
              backgroundImage: widget.targetPhotoUrl.isNotEmpty
                  ? NetworkImage(widget.targetPhotoUrl)
                  : null,
              child: widget.targetPhotoUrl.isEmpty
                  ? Text(
                      widget.targetName.isNotEmpty
                          ? widget.targetName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 24),
            // Name
            Text(
              widget.targetName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            // Status
            Text(
              _statusText,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const Spacer(),
            // Controls
            _buildAudioControls(),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ControlButton(
          icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: _isMuted ? 'Unmute' : 'Mute',
          color: _isMuted
              ? const Color(0xFFFF3B30)
              : Colors.white.withValues(alpha: 0.15),
          onTap: () {
            setState(() => _isMuted = !_isMuted);
            _callService.toggleMute(_isMuted);
          },
        ),
        _ControlButton(
          icon: Icons.call_end_rounded,
          label: 'Akhiri',
          color: const Color(0xFFFF3B30),
          size: 68,
          onTap: _endCall,
        ),
        _ControlButton(
          icon: Icons.volume_up_rounded,
          label: 'Speaker',
          color: Colors.white.withValues(alpha: 0.15),
          onTap: () {},
        ),
      ],
    );
  }

  // ── Video Call UI ─────────────────────────────────────────────────────
  Widget _buildVideoCall() {
    return Stack(
      children: [
        // Remote video (full screen)
        Positioned.fill(
          child: _remoteRenderer.srcObject != null
              ? RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              : Container(
                  color: const Color(0xFF111111),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF333333),
                          backgroundImage:
                              widget.targetPhotoUrl.isNotEmpty
                                  ? NetworkImage(widget.targetPhotoUrl)
                                  : null,
                          child: widget.targetPhotoUrl.isEmpty
                              ? Text(
                                  widget.targetName.isNotEmpty
                                      ? widget.targetName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.targetName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _statusText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),

        // Top bar: status + timer
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusText,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Local video (small, top-right)
        if (_localRenderer.srcObject != null && !_isCameraOff)
          Positioned(
            top: MediaQuery.of(context).padding.top + 50,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 110,
                height: 150,
                child: RTCVideoView(
                  _localRenderer,
                  mirror: _isFrontCamera,
                  objectFit:
                      RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),

        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: _isMuted
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    label: 'Mute',
                    color: _isMuted
                        ? const Color(0xFFFF3B30)
                        : Colors.white.withValues(alpha: 0.15),
                    onTap: () {
                      setState(() => _isMuted = !_isMuted);
                      _callService.toggleMute(_isMuted);
                    },
                  ),
                  _ControlButton(
                    icon: _isCameraOff
                        ? Icons.videocam_off_rounded
                        : Icons.videocam_rounded,
                    label: 'Kamera',
                    color: _isCameraOff
                        ? const Color(0xFFFF3B30)
                        : Colors.white.withValues(alpha: 0.15),
                    onTap: () {
                      setState(() => _isCameraOff = !_isCameraOff);
                      _callService.toggleCamera(_isCameraOff);
                    },
                  ),
                  _ControlButton(
                    icon: Icons.cameraswitch_rounded,
                    label: 'Flip',
                    color: Colors.white.withValues(alpha: 0.15),
                    onTap: () {
                      setState(() => _isFrontCamera = !_isFrontCamera);
                      _callService.switchCamera();
                    },
                  ),
                  _ControlButton(
                    icon: Icons.call_end_rounded,
                    label: 'Akhiri',
                    color: const Color(0xFFFF3B30),
                    size: 62,
                    onTap: _endCall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Control Button ────────────────────────────────────────────────────────
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double size;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
