import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class PresenceWidget extends StatelessWidget {
  final UserModel user;
  final String roomId;
  final String currentUid;

  const PresenceWidget({
    super.key,
    required this.user,
    required this.roomId,
    required this.currentUid,
  });

  @override
  Widget build(BuildContext context) {
    // Priority 1: In this specific room
    if (user.inRoom && user.currentRoom == roomId) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: const Color(0xFF6C63FF)),
          const SizedBox(width: 4),
          const Text(
            'Sedang melihat chat',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6C63FF),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    // Priority 2: Online
    if (user.online) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF48BB78),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'Online',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF48BB78),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    // Priority 3: Last seen
    String lastSeenText = 'Offline';
    if (user.lastRoomLeave != null) {
      lastSeenText =
          'Meninggalkan room ${timeago.format(user.lastRoomLeave!.toDate(), locale: 'id')}';
    } else if (user.lastSeen != null) {
      lastSeenText =
          'Terakhir ${timeago.format(user.lastSeen!.toDate(), locale: 'id')}';
    }

    return Text(
      lastSeenText,
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[500],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
