import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
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
  bool _showEmojiPicker = false;
  bool _isRecording = false;
  final AudioRecorder _recorder = AudioRecorder();
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
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
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
    _recorder.dispose();
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

  Future<void> _startRecording() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Izin mikrofon diperlukan')),
            );
          }
          return;
        }
      }

      if (await _recorder.hasPermission()) {
        String path = '';
        if (!kIsWeb && Platform.isAndroid) {
          final dir = await getTemporaryDirectory();
          path =
              '${dir.path}/group_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            numChannels: 1,
            sampleRate: 16000,
          ),
          path: path,
        );
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint('Recording error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memulai rekaman: $e')),
        );
      }
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;
    try {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path == null || !mounted) return;

      // Read the recorded file as bytes (supports both Web blob URLs and Native paths)
      final bytes = await XFile(path).readAsBytes();
      if (bytes.isEmpty) return;

      setState(() => _sending = true);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await GroupService.sendVoice(
        groupId: widget.initialGroup.id,
        senderId: widget.currentUid,
        bytes: bytes,
        fileName: 'group_voice_$timestamp.m4a',
      );
      setState(() => _sending = false);
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isRecording = false;
        _sending = false;
      });
      debugPrint('Stop recording error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim rekaman: $e')),
        );
      }
    }
  }

  void _cancelRecording() async {
    if (!_isRecording) return;
    await _recorder.stop();
    setState(() => _isRecording = false);
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final start = selection.baseOffset < 0 ? text.length : selection.baseOffset;
    final newText =
        text.substring(0, start) + emoji.emoji + text.substring(start);
    _messageController.text = newText;
    _messageController.selection = TextSelection.collapsed(
      offset: start + emoji.emoji.length,
    );
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
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${group.members.length} anggota',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
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
                  return Center(
                    child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary),
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
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 56,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF555555)
                              : const Color(0xFFE5E5E5),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Mulai obrolan grup',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: reversedMessages.length,
                  itemBuilder: (context, i) {
                    final msg = reversedMessages[i];
                    final isMe = msg.senderId == widget.currentUid;
                    final showDate = i == reversedMessages.length - 1 ||
                        reversedMessages[i].timestamp.toDate().day !=
                            reversedMessages[i + 1].timestamp.toDate().day;

                    final senderName =
                        _membersMap[msg.senderId]?.username ?? 'Anggota';

                    if (msg.type == MessageType.system) {
                      final isDarkSys =
                          Theme.of(context).brightness == Brightness.dark;
                      return Column(
                        children: [
                          if (showDate) _DateDivider(msg.timestamp.toDate()),
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDarkSys
                                    ? const Color(0xFF2C2C2C)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                msg.message,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (showDate) _DateDivider(msg.timestamp.toDate()),
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 12, bottom: 4, top: 8),
                            child: Text(
                              senderName,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
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

          // Recording indicator
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF3D1F1F)
                  : const Color(0xFFFFF3F3),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Merekam... Lepas untuk kirim',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelRecording,
                    child: const Icon(Icons.close, color: Colors.red, size: 20),
                  ),
                ],
              ),
            ),

          // Input bar
          _InputBar(
            controller: _messageController,
            sending: _sending,
            isRecording: _isRecording,
            onSend: _sendMessage,
            onAttach: () => setState(() => _showAttachMenu = !_showAttachMenu),
            onMicDown: _startRecording,
            onMicUp: _stopAndSendRecording,
            onEmojiTap: () {
              setState(() => _showEmojiPicker = !_showEmojiPicker);
              if (_showEmojiPicker) {
                FocusScope.of(context).unfocus();
              }
            },
            showEmojiPicker: _showEmojiPicker,
          ),

          // Emoji picker
          if (_showEmojiPicker)
            SizedBox(
              height: 260,
              child: EmojiPicker(
                onEmojiSelected: _onEmojiSelected,
                config: const Config(
                  height: 260,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    emojiSizeMax: 28,
                    columns: 8,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    initCategory: Category.SMILEYS,
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(enabled: false),
                  searchViewConfig: SearchViewConfig(
                    hintText: 'Cari emoji...',
                  ),
                ),
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFF0F0F0),
            width: 0.5,
          ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: theme.colorScheme.onSurface, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
  final bool isRecording;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onMicDown;
  final VoidCallback onMicUp;
  final VoidCallback onEmojiTap;
  final bool showEmojiPicker;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.isRecording,
    required this.onSend,
    required this.onAttach,
    required this.onMicDown,
    required this.onMicUp,
    required this.onEmojiTap,
    required this.showEmojiPicker,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF333333) : const Color(0xFFF0F0F0),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                showEmojiPicker
                    ? Icons.keyboard_rounded
                    : Icons.emoji_emotions_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              onPressed: onEmojiTap,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onTap: () {
                  // Handle keyboard interaction
                },
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style:
                    TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 14),
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
                  fillColor:
                      isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              onPressed: onAttach,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                if (hasText) {
                  // Send button
                  return GestureDetector(
                    onTap: sending ? null : onSend,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0EA5E9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        sending
                            ? Icons.hourglass_empty_rounded
                            : Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  );
                } else {
                  // Mic button (press & hold)
                  return GestureDetector(
                    onLongPressStart: (_) => onMicDown(),
                    onLongPressEnd: (_) => onMicUp(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                            isRecording ? Colors.red : const Color(0xFF0EA5E9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isRecording
                            ? Icons.mic_rounded
                            : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
