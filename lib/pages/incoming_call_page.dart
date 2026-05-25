import 'package:flutter/material.dart';
import '../services/call_service.dart';
import 'call_page.dart';

class IncomingCallPage extends StatefulWidget {
  final String callId;
  final String callerName;
  final String callerPhotoUrl;
  final bool isVideo;
  final String currentUid;

  const IncomingCallPage({
    super.key,
    required this.callId,
    required this.callerName,
    required this.callerPhotoUrl,
    required this.isVideo,
    required this.currentUid,
  });

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _accept() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CallPage(
          currentUid: widget.currentUid,
          targetName: widget.callerName,
          targetPhotoUrl: widget.callerPhotoUrl,
          isVideo: widget.isVideo,
          isCaller: false,
          callId: widget.callId,
        ),
      ),
    );
  }

  void _reject() async {
    await CallService.rejectCall(widget.callId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2D2B55), Color(0xFF1A1A2E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 80),
              // Call type
              Text(
                widget.isVideo
                    ? 'Panggilan Video Masuk'
                    : 'Panggilan Suara Masuk',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              // Pulse avatar
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) {
                  final scale = 1.0 + _pulseController.value * 0.08;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF6C63FF).withValues(
                            alpha: 0.3 + _pulseController.value * 0.3,
                          ),
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 64,
                        backgroundColor: const Color(0xFF3D3B6E),
                        backgroundImage: widget.callerPhotoUrl.isNotEmpty
                            ? NetworkImage(widget.callerPhotoUrl)
                            : null,
                        child: widget.callerPhotoUrl.isEmpty
                            ? Text(
                                widget.callerName.isNotEmpty
                                    ? widget.callerName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontSize: 44,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              // Name
              Text(
                widget.callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isVideo ? '📹 Video Call' : '📞 Voice Call',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              // Accept / Reject buttons
              Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Reject
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _reject,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.call_end_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tolak',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    // Accept
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _accept,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: const BoxDecoration(
                              color: Color(0xFF48BB78),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.isVideo
                                  ? Icons.videocam_rounded
                                  : Icons.call_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Terima',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
