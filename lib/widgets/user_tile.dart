import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/user_model.dart';
import '../services/chat_service.dart';

class UserTile extends StatelessWidget {
  final UserModel user;
  final String roomId;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const UserTile({
    super.key,
    required this.user,
    required this.roomId,
    required this.onTap,
    this.onLongPress,
  });

  String _formatLastSeen(Timestamp? ts) {
    if (ts == null) return 'Belum aktif';
    return 'Terakhir ' + timeago.format(ts.toDate(), locale: 'id');
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFEEECFF),
            backgroundImage: user.photoUrl.isNotEmpty
                ? NetworkImage(user.photoUrl)
                : null,
            child: user.photoUrl.isEmpty
                ? Text(
                    user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          // Online indicator
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: user.online
                    ? const Color(0xFF48BB78)
                    : Colors.grey[400],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        user.username,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Color(0xFF1A1A2E),
        ),
      ),
      subtitle: _buildSubtitle(),
      trailing: _buildTrailing(),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _buildSubtitle() {
    // Show typing / room presence / online status / last seen
    if (user.inRoom) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF6C63FF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'Sedang melihat chat',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6C63FF),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    if (user.online) {
      return const Text(
        'Online',
        style: TextStyle(
          fontSize: 13,
          color: Color(0xFF48BB78),
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return Text(
      _formatLastSeen(user.lastSeen),
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildTrailing() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ChatService.roomStream(roomId),
      builder: (context, snapshot) {
        final room = snapshot.data;
        if (room == null) return const SizedBox.shrink();
        final lastMsg = room['lastMessage'] as String? ?? '';
        final lastTs = room['lastTimestamp'] as Timestamp?;
        if (lastMsg.isEmpty) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (lastTs != null)
              Text(
                _shortTime(lastTs),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[400],
                ),
              ),
            const SizedBox(height: 2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                lastMsg,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        );
      },
    );
  }

  String _shortTime(Timestamp ts) {
    final dt = ts.toDate();
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }
}
