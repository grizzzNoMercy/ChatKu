import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/group_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/group_service.dart';
import '../utils/avatar_helper.dart';
import '../widgets/chat_bubble.dart';
import 'group_details_page.dart';

class GroupChatPage extends StatefulWidget {
  final GroupModel initialGroup;
  final String currentUid;

  const GroupChatPage({
    super.key,
    required this.initialGroup,
    required this.currentUid,
  });

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _showAttachMenu = false;
  Map<String, UserModel> _membersMap = {};

  int _previousMessageCount = -1;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    // Mark as read when entering the room
    GroupService.markGroupAsRead(widget.initialGroup.id, widget.currentUid);
  }

  Future<void> _loadMembers() async {
    for (String uid in widget.initialGroup.members) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _membersMap[uid] = UserModel.fromMap(doc.data()!);
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToBottomIfNear() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (_scrollController.position.pixels < 150) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    _messageController.clear();
    setState(() => _sending = true);
    await GroupService.sendTextMessage(
      groupId: widget.initialGroup.id,
      senderId: widget.currentUid,
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
    final bytes = await picked.readAsBytes();
    await GroupService.sendImage(
      groupId: widget.initialGroup.id,
      senderId: widget.currentUid,
      bytes: bytes,
      fileName: picked.name,
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
    final bytes = await picked.readAsBytes();
    await GroupService.sendVideo(
      groupId: widget.initialGroup.id,
      senderId: widget.currentUid,
      bytes: bytes,
      fileName: picked.name,
    );
    setState(() => _sending = false);
    _scrollToBottom();
  }

  Future<void> _sendFile() async {
    setState(() => _showAttachMenu = false);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'zip', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() => _sending = true);
    await GroupService.sendFile(
      groupId: widget.initialGroup.id,
      senderId: widget.currentUid,
      bytes: file.bytes!,
      fileName: file.name,
    );
    setState(() => _sending = false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: const BackButton(),
        title: StreamBuilder<GroupModel?>(
          stream: GroupService.groupStream(widget.initialGroup.id),
          builder: (context, snapshot) {
            final group = snapshot.data ?? widget.initialGroup;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupDetailsPage(
                      group: group,
                      currentUid: widget.currentUid,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AvatarHelper.backgroundColor(group.name),
                    backgroundImage: group.photoUrl.isNotEmpty
                        ? NetworkImage(group.photoUrl)
                        : null,
                    child: group.photoUrl.isEmpty
                        ? Text(
                            group.name.isNotEmpty
                                ? group.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: AvatarHelper.textColor(group.name),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111111),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${group.members.length} anggota',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: GroupService.messagesStream(widget.initialGroup.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF111111)),
                  );
                }
                final messages = snapshot.data ?? [];

                final bool hasNewMessages = _previousMessageCount >= 0 &&
                    messages.length > _previousMessageCount;

                if (messages.isNotEmpty) {
                  if (_previousMessageCount != -1 && hasNewMessages) {
                    GroupService.markGroupAsRead(
                        widget.initialGroup.id, widget.currentUid);
                    _scrollToBottomIfNear();
                  }
                }
                _previousMessageCount = messages.length;

                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 56,
                          color: Color(0xFFE5E5E5),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Mulai obrolan grup',
                          style: TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final reversedMessages = messages.reversed.toList();
                
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: reversedMessages.length,
                  itemBuilder: (context, i) {
                    final msg = reversedMessages[i];
                    final isMe = msg.senderId == widget.currentUid;
                    final showDate = i == reversedMessages.length - 1 ||
                        reversedMessages[i].timestamp.toDate().day !=
                            reversedMessages[i + 1].timestamp.toDate().day;
                    
                    final senderName = _membersMap[msg.senderId]?.username ?? 'Anggota';

                    if (msg.type == MessageType.system) {
                      return Column(
                        children: [
                          if (showDate) _DateDivider(msg.timestamp.toDate()),
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                msg.message,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF999999),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment:
                          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (showDate) _DateDivider(msg.timestamp.toDate()),
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsets.only(left: 12, bottom: 4, top: 8),
                            child: Text(
                              senderName,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF999999),
                              ),
                            ),
                          ),
                        ChatBubble(message: msg, isMe: isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Attach menu
          if (_showAttachMenu)
            _AttachMenu(
              onImage: _sendImage,
              onVideo: _sendVideo,
              onFile: _sendFile,
            ),

          // Input bar
          _InputBar(
            controller: _messageController,
            sending: _sending,
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
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      label = 'Hari ini';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Kemarin';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF999999),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF0F0F0), width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _AttachItem(
            icon: Icons.image_outlined,
            label: 'Foto',
            onTap: onImage,
          ),
          _AttachItem(
            icon: Icons.videocam_outlined,
            label: 'Video',
            onTap: onVideo,
          ),
          _AttachItem(
            icon: Icons.attach_file_rounded,
            label: 'File',
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
  final VoidCallback onTap;

  const _AttachItem({
    required this.icon,
    required this.label,
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
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF111111), size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF999999),
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
  final VoidCallback onSend;
  final VoidCallback onAttach;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFF0F0F0), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onAttach,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded,
                    color: Color(0xFF111111), size: 20),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Tulis pesan...',
                  hintStyle: const TextStyle(
                      color: Color(0xFF999999), fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return GestureDetector(
                  onTap: hasText ? (sending ? null : onSend) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFF111111),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      sending
                          ? Icons.hourglass_empty_rounded
                          : (hasText
                              ? Icons.send_rounded
                              : Icons.mic_none_rounded), // fallback to mic or similar
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
