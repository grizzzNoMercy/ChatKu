import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/presence_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/presence_widget.dart';
import 'call_page.dart';

class ChatPage extends StatefulWidget {
  final UserModel targetUser;
  final String currentUid;

  const ChatPage({
    super.key,
    required this.targetUser,
    required this.currentUid,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final String _roomId;
  bool _sending = false;
  bool _showAttachMenu = false;

  @override
  void initState() {
    super.initState();
    _roomId = ChatService.getRoomId(widget.currentUid, widget.targetUser.uid);
    _initRoom();
  }

  Future<void> _initRoom() async {
    await ChatService.ensureRoom(
      _roomId,
      widget.currentUid,
      widget.targetUser.uid,
    );
    if (mounted) {
      context.read<PresenceService>().enterRoom(_roomId);
    }
  }

  @override
  void dispose() {
    context.read<PresenceService>().leaveRoom(_roomId);
    context.read<PresenceService>().setTyping(
      roomId: _roomId,
      uid: widget.currentUid,
      isTyping: false,
    );
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    _messageController.clear();
    setState(() => _sending = true);
    await context.read<PresenceService>().setTyping(
      roomId: _roomId,
      uid: widget.currentUid,
      isTyping: false,
    );
    await ChatService.sendTextMessage(
      roomId: _roomId,
      senderId: widget.currentUid,
      receiverId: widget.targetUser.uid,
      message: text,
    );
    setState(() => _sending = false);
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    setState(() => _showAttachMenu = false);
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    setState(() => _sending = true);
    await ChatService.sendImage(
      roomId: _roomId,
      senderId: widget.currentUid,
      receiverId: widget.targetUser.uid,
      file: File(picked.path),
    );
    setState(() => _sending = false);
    _scrollToBottom();
  }

  Future<void> _sendVideo() async {
    setState(() => _showAttachMenu = false);
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _sending = true);
    await ChatService.sendVideo(
      roomId: _roomId,
      senderId: widget.currentUid,
      receiverId: widget.targetUser.uid,
      file: File(picked.path),
    );
    setState(() => _sending = false);
    _scrollToBottom();
  }

  Future<void> _sendFile() async {
    setState(() => _showAttachMenu = false);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'zip', 'txt'],
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.first;
    if (file.path == null) return;
    setState(() => _sending = true);
    await ChatService.sendFile(
      roomId: _roomId,
      senderId: widget.currentUid,
      receiverId: widget.targetUser.uid,
      file: File(file.path!),
      fileName: file.name,
    );
    setState(() => _sending = false);
    _scrollToBottom();
  }

  void _onTypingChanged(String value) {
    context.read<PresenceService>().setTyping(
      roomId: _roomId,
      uid: widget.currentUid,
      isTyping: value.isNotEmpty,
    );
  }

  Future<void> _startCall(bool isVideo) async {
    final authService = context.read<AuthService>();
    final currentUser = await authService.getCurrentUserData();
    if (!mounted || currentUser == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallPage(
          currentUid: widget.currentUid,
          targetName: widget.targetUser.username,
          targetPhotoUrl: widget.targetUser.photoUrl,
          isVideo: isVideo,
          isCaller: true,
          targetUid: widget.targetUser.uid,
          currentUserName: currentUser.username,
          currentUserPhotoUrl: currentUser.photoUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: const BackButton(),
        title: StreamBuilder<UserModel?>(
          stream: ChatService.userStream(widget.targetUser.uid),
          builder: (context, snapshot) {
            final user = snapshot.data ?? widget.targetUser;
            return Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 18,
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
                                fontSize: 14,
                              ),
                            )
                          : null,
                    ),
                    if (user.online)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: const Color(0xFF48BB78),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    PresenceWidget(
                      user: user,
                      roomId: _roomId,
                      currentUid: widget.currentUid,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded, size: 22),
            tooltip: 'Panggilan Suara',
            onPressed: () => _startCall(false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded, size: 22),
            tooltip: 'Panggilan Video',
            onPressed: () => _startCall(true),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: ChatService.messagesStream(_roomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  );
                }
                final messages = snapshot.data ?? [];
                if (messages.isNotEmpty) {
                  _scrollToBottom();
                }
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Mulai percakapan',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == widget.currentUid;
                    final showDate = i == 0 ||
                        messages[i].timestamp.toDate().day !=
                            messages[i - 1].timestamp.toDate().day;
                    return Column(
                      children: [
                        if (showDate) _DateDivider(msg.timestamp.toDate()),
                        ChatBubble(message: msg, isMe: isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Typing indicator
          StreamBuilder<bool>(
            stream: context.read<PresenceService>().typingStream(
              roomId: _roomId,
              otherUid: widget.targetUser.uid,
            ),
            builder: (context, snapshot) {
              final isTyping = snapshot.data ?? false;
              if (!isTyping) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 4),
                child: Row(
                  children: [
                    Text(
                      '${widget.targetUser.username} sedang mengetik',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _TypingDots(),
                  ],
                ),
              );
            },
          ),

          // Attach menu
          if (_showAttachMenu) _AttachMenu(
            onImage: _sendImage,
            onVideo: _sendVideo,
            onFile: _sendFile,
          ),

          // Input bar
          _InputBar(
            controller: _messageController,
            sending: _sending,
            onChanged: _onTypingChanged,
            onSend: _sendMessage,
            onAttach: () => setState(() => _showAttachMenu = !_showAttachMenu),
          ),
        ],
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider(this.date);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = 'Hari ini';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Kemarin';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) c.repeat(reverse: true);
      });
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _controllers.map((c) {
        return AnimatedBuilder(
          animation: c,
          builder: (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            width: 4,
            height: 4 + c.value * 3,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AttachMenu extends StatelessWidget {
  final VoidCallback onImage;
  final VoidCallback onVideo;
  final VoidCallback onFile;

  const _AttachMenu({
    required this.onImage,
    required this.onVideo,
    required this.onFile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _AttachItem(
            icon: Icons.image_rounded,
            label: 'Foto',
            color: const Color(0xFF4CAF50),
            onTap: onImage,
          ),
          _AttachItem(
            icon: Icons.videocam_rounded,
            label: 'Video',
            color: const Color(0xFFE91E63),
            onTap: onVideo,
          ),
          _AttachItem(
            icon: Icons.attach_file_rounded,
            label: 'File',
            color: const Color(0xFF2196F3),
            onTap: onFile,
          ),
        ],
      ),
    );
  }
}

class _AttachItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onChanged,
    required this.onSend,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: const Color(0xFF6C63FF),
              onPressed: onAttach,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Tulis pesan...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FE),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: sending ? null : onSend,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: sending
                      ? Colors.grey[300]
                      : const Color(0xFF6C63FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  sending
                      ? Icons.hourglass_empty_rounded
                      : Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
