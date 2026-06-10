import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/call_log_service.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';
import '../services/contact_service.dart';
import '../services/group_service.dart';
import '../utils/avatar_helper.dart';
import '../widgets/user_tile.dart';
import 'call_log_page.dart';
import 'chat_page.dart';
import 'create_group_page.dart';
import 'friend_requests_page.dart';
import 'group_chat_page.dart';
import 'incoming_call_page.dart';
import 'profile_page.dart';
import '../services/sound_service.dart';
import '../services/presence_service.dart';
import '../utils/app_localizations.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PageController _pageController;
  int _currentPage = 0;
  StreamSubscription<QuerySnapshot>? _callSub;
  StreamSubscription<QuerySnapshot>? _roomsSub;
  StreamSubscription<QuerySnapshot>? _groupsSub;
  String? _handlingCallId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenForIncomingCalls();
      _listenForNewMessages();
    });
  }

  void _listenForNewMessages() {
    final currentUid = context.read<AuthService>().currentUid;
    if (currentUid == null) return;

    final presence = context.read<PresenceService>();

    // Listen for new messages in Private Chats
    bool isInitialRooms = true;
    final Map<String, Timestamp> roomLastTimestamps = {};

    _roomsSub = FirebaseFirestore.instance
        .collection('chat_rooms')
        .where('participants', arrayContains: currentUid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;

      for (var doc in snap.docs) {
        final roomId = doc.id;
        final lastTs = doc.data()['lastTimestamp'] as Timestamp?;
        final lastSenderId = doc.data()['lastSenderId'] as String?;

        if (lastTs != null) {
          if (!isInitialRooms) {
            final oldTs = roomLastTimestamps[roomId];
            if (oldTs == null || lastTs.compareTo(oldTs) > 0) {
              if (lastSenderId != null && lastSenderId != currentUid) {
                // If user is already looking at this specific room, skip home screen sound
                if (presence.currentRoomId != roomId) {
                  SoundService.instance.playNotification();
                }
              }
            }
          }
          roomLastTimestamps[roomId] = lastTs;
        }
      }
      isInitialRooms = false;
    });

    // Listen for new messages in Groups
    bool isInitialGroups = true;
    final Map<String, Timestamp> groupLastTimestamps = {};

    _groupsSub = FirebaseFirestore.instance
        .collection('groups')
        .where('members', arrayContains: currentUid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;

      for (var doc in snap.docs) {
        final groupId = doc.id;
        final lastTs = doc.data()['lastTimestamp'] as Timestamp?;
        final lastSenderId = doc.data()['lastSenderId'] as String?;

        if (lastTs != null) {
          if (!isInitialGroups) {
            final oldTs = groupLastTimestamps[groupId];
            if (oldTs == null || lastTs.compareTo(oldTs) > 0) {
              if (lastSenderId != null && lastSenderId != currentUid) {
                // If user is already looking at this specific group room, skip home screen sound
                if (presence.currentRoomId != groupId) {
                  SoundService.instance.playNotification();
                }
              }
            }
          }
          groupLastTimestamps[groupId] = lastTs;
        }
      }
      isInitialGroups = false;
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    if (index == 1) {
      final currentUid = context.read<AuthService>().currentUid;
      if (currentUid != null) {
        CallLogService.markMissedCallsAsRead(currentUid);
      }
    }
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _listenForIncomingCalls() {
    final currentUid = context.read<AuthService>().currentUid;
    if (currentUid == null) return;

    _callSub = CallService.incomingCallStream(currentUid).listen((snap) {
      if (snap.docs.isEmpty || !mounted) return;
      final doc = snap.docs.first;
      if (doc.id == _handlingCallId) return;

      // Skip incoming call if already in an active call
      if (CallService.currentState != CallState.idle) {
        debugPrint('[HomePage] Skipping incoming call — already in a call');
        return;
      }

      _handlingCallId = doc.id;
      final data = doc.data() as Map<String, dynamic>;

      // Skip stale calls (older than 60 seconds)
      final timestamp = data['timestamp'] as Timestamp?;
      if (timestamp != null) {
        final age = DateTime.now().difference(timestamp.toDate());
        if (age.inSeconds > 60) {
          debugPrint('[HomePage] Skipping stale call (${age.inSeconds}s old)');
          // Mark as ended to prevent future triggering
          FirebaseFirestore.instance
              .collection('calls')
              .doc(doc.id)
              .update({'status': 'ended'})
              .catchError((_) {});
          _handlingCallId = null;
          return;
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IncomingCallPage(
            callId: doc.id,
            callerName: data['callerName'] ?? '',
            callerPhotoUrl: data['callerPhotoUrl'] ?? '',
            isVideo: data['type'] == 'video',
            currentUid: currentUid,
          ),
        ),
      ).then((_) => _handlingCallId = null);
    });
  }

  @override
  void dispose() {
    _callSub?.cancel();
    _pageController.dispose();
    _roomsSub?.cancel();
    _groupsSub?.cancel();
    super.dispose();
  }

  // ── FAB Popup Menu ────────────────────────────────────────────────────
  void _showNewChatMenu(String currentUid) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF555555) : const Color(0xFFE5E5E5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Buat Baru',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _MenuOption(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                  subtitle: 'Mulai percakapan baru',
                  onTap: () => Navigator.pop(ctx),
                ),
                _MenuOption(
                  icon: Icons.person_add_outlined,
                  label: 'Kontak',
                  subtitle: 'Tambahkan kontak baru',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddContactDialog(currentUid);
                  },
                ),
                _MenuOption(
                  icon: Icons.group_outlined,
                  label: 'Grup',
                  subtitle: 'Buat grup chat',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CreateGroupPage()),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Add Contact Dialog ──────────────────────────────────────────────
  void _showAddContactDialog(String currentUid) {
    final emailController = TextEditingController();
    UserModel? foundUser;
    bool isLoading = false;
    String? errorMsg;
    bool requestSent = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Row(
                children: [
                  Icon(Icons.person_add_outlined,
                      color: Color(0xFF111111), size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Tambah Kontak',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111111),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Masukkan email pengguna',
                        hintStyle: TextStyle(color: Color(0xFF999999)),
                        prefixIcon: Icon(Icons.email_outlined, size: 20),
                      ),
                      onChanged: (_) {
                        if (foundUser != null || errorMsg != null) {
                          setDialogState(() {
                            foundUser = null;
                            errorMsg = null;
                            requestSent = false;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF111111)),
                              )
                            : const Icon(Icons.search_rounded, size: 18),
                        label: Text(isLoading ? 'Mencari...' : 'Cari'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF111111),
                          side: const BorderSide(color: Color(0xFFE5E5E5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                final email = emailController.text.trim();
                                if (email.isEmpty) return;

                                setDialogState(() {
                                  isLoading = true;
                                  errorMsg = null;
                                  foundUser = null;
                                  requestSent = false;
                                });

                                final currentEmail = context
                                    .read<AuthService>()
                                    .currentUser
                                    ?.email;
                                if (email.toLowerCase() ==
                                    currentEmail?.toLowerCase()) {
                                  setDialogState(() {
                                    isLoading = false;
                                    errorMsg =
                                        'Tidak dapat menambahkan diri sendiri.';
                                  });
                                  return;
                                }

                                final user =
                                    await ContactService.searchUserByEmail(
                                        email);
                                if (user == null) {
                                  setDialogState(() {
                                    isLoading = false;
                                    errorMsg = 'Email tidak ditemukan.';
                                  });
                                  return;
                                }

                                setDialogState(() {
                                  isLoading = false;
                                  foundUser = user;
                                });
                              },
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F0),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Color(0xFFFF3B30), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMsg!,
                                style: const TextStyle(
                                  color: Color(0xFFFF3B30),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (foundUser != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AvatarHelper.backgroundColor(
                                  foundUser!.username),
                              backgroundImage: foundUser!.photoUrl.isNotEmpty
                                  ? NetworkImage(foundUser!.photoUrl)
                                  : null,
                              child: foundUser!.photoUrl.isEmpty
                                  ? Text(
                                      foundUser!.username.isNotEmpty
                                          ? foundUser!.username[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: AvatarHelper.textColor(
                                            foundUser!.username),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    foundUser!.username,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Color(0xFF111111),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    foundUser!.email,
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
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: Icon(
                            requestSent
                                ? Icons.check_rounded
                                : Icons.person_add_rounded,
                            size: 18,
                          ),
                          label: Text(
                            requestSent
                                ? 'Permintaan Terkirim'
                                : 'Kirim Permintaan',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: requestSent
                                ? const Color(0xFF34C759)
                                : const Color(0xFF111111),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: requestSent
                              ? null
                              : () async {
                                  final err =
                                      await ContactService.sendFriendRequest(
                                    fromUid: currentUid,
                                    toUid: foundUser!.uid,
                                  );
                                  if (err != null) {
                                    setDialogState(() => errorMsg = err);
                                  } else {
                                    setDialogState(() => requestSent = true);
                                  }
                                },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Delete Contact ──────────────────────────────────────────────────
  void _showDeleteContactDialog(String currentUid, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Hapus Kontak',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Color(0xFF111111),
          ),
        ),
        content: Text(
          'Hapus ${user.username} dari daftar kontak?\n'
          'Kontak ini juga akan dihapus dari sisi pengguna lain.',
          style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ContactService.removeContact(
                currentUid: currentUid,
                targetUid: user.uid,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${user.username} dihapus dari kontak'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = context.read<AuthService>().currentUid ?? '';

    return Scaffold(
      appBar: _currentPage == 0
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () {},
              ),
              title: const Text('ChatKu'),
              centerTitle: true,
              actions: [
                ..._chatActions(currentUid),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showNewChatMenu(currentUid),
                ),
              ],
            )
          : null,
      floatingActionButton: _currentPage == 0
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
              elevation: 0,
              highlightElevation: 0,
              shape: const CircleBorder(),
              onPressed: () => _showNewChatMenu(currentUid),
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
      bottomNavigationBar: StreamBuilder<int>(
        stream: CallLogService.missedCallCountStream(
          currentUid,
          DateTime.now().subtract(const Duration(days: 7)),
        ),
        builder: (context, missedSnap) {
          return _BottomNavBar(
            currentIndex: _currentPage,
            missedCallCount: missedSnap.data ?? 0,
            onTap: _goToPage,
          );
        },
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [
          _ChatTab(
            currentUid: currentUid,
            onShowNewChatMenu: () => _showNewChatMenu(currentUid),
            onShowAddContact: () => _showAddContactDialog(currentUid),
            onDeleteContact: (u) => _showDeleteContactDialog(currentUid, u),
          ),
          const CallLogPage(),
          const ProfilePage(),
        ],
      ),
    );
  }

  List<Widget> _chatActions(String currentUid) {
    return [
      StreamBuilder<int>(
        stream: ContactService.pendingRequestCountStream(currentUid),
        builder: (context, snapshot) {
          final count = snapshot.data ?? 0;
          return IconButton(
            icon: Badge(
              isLabelVisible: count > 0,
              backgroundColor: const Color(0xFF0EA5E9),
              label: Text(
                '$count',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              child: const Icon(Icons.people_outline_rounded),
            ),
            tooltip: 'Permintaan Pertemanan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FriendRequestsPage()),
              );
            },
          );
        },
      ),
      const SizedBox(width: 4),
    ];
  }
}

// ── Group Tile ────────────────────────────────────────────────────────
class _GroupTile extends StatelessWidget {
  final GroupModel group;
  final String currentUid;
  final VoidCallback onTap;

  const _GroupTile({
    required this.group,
    required this.currentUid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AvatarHelper.backgroundColor(group.name),
            backgroundImage:
                group.photoUrl.isNotEmpty ? NetworkImage(group.photoUrl) : null,
            child: group.photoUrl.isEmpty
                ? Text(
                    group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: AvatarHelper.textColor(group.name),
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          // Small badge indicating it's a group
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFF0EA5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_rounded,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      title: Text(
        group.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        group.lastMessage.isEmpty ? 'Grup dibuat' : group.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: 14,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(group.lastTimestamp.toDate()),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFBBBBBB),
            ),
          ),
          if ((group.unreadCounts[currentUid] ?? 0) > 0) ...[
            const SizedBox(height: 6),
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFF0EA5E9),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                (group.unreadCounts[currentUid] ?? 0) > 99
                    ? '99'
                    : '${group.unreadCounts[currentUid]}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}';
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────────────
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final int missedCallCount;
  final ValueChanged<int> onTap;

  const _BottomNavBar({
    required this.currentIndex,
    required this.onTap,
    this.missedCallCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tabWidth = screenWidth / 3;
    const double dotSize = 5.0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Stack(
            children: [
              Row(
                children: [
                  _BounceTabItem(
                    icon: currentIndex == 0
                        ? Icons.chat_bubble_rounded
                        : Icons.chat_bubble_outline_rounded,
                    isActive: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  _BounceTabItem(
                    icon: currentIndex == 1
                        ? Icons.phone_rounded
                        : Icons.phone_outlined,
                    isActive: currentIndex == 1,
                    badgeCount: missedCallCount,
                    onTap: () => onTap(1),
                  ),
                  _BounceTabItem(
                    icon: currentIndex == 2
                        ? Icons.person_rounded
                        : Icons.person_outline_rounded,
                    isActive: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                ],
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                bottom: 8,
                left: (tabWidth * currentIndex) + (tabWidth / 2) - (dotSize / 2),
                child: Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0EA5E9),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _BounceTabItem extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  const _BounceTabItem({
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  State<_BounceTabItem> createState() => _BounceTabItemState();
}

class _BounceTabItemState extends State<_BounceTabItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
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
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: Center(
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            offset: widget.isActive ? const Offset(0, -0.2) : Offset.zero,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: widget.badgeCount > 0
                  ? Badge(
                      backgroundColor: const Color(0xFFFF3B30),
                      label: Text(
                        '${widget.badgeCount}',
                        style: const TextStyle(fontSize: 9, color: Colors.white),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                        size: 26,
                      ),
                    )
                  : Icon(
                      widget.icon,
                      color: widget.isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      size: 26,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bottom Sheet Menu Option ──────────────────────────────────────────
class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: theme.colorScheme.onSurface, size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      onTap: onTap,
    );
  }
}

// ── Chat Tab (dengan state preservation) ─────────────────────────────────
class _ChatTab extends StatefulWidget {
  final String currentUid;
  final VoidCallback onShowNewChatMenu;
  final VoidCallback onShowAddContact;
  final void Function(UserModel) onDeleteContact;

  const _ChatTab({
    required this.currentUid,
    required this.onShowNewChatMenu,
    required this.onShowAddContact,
    required this.onDeleteContact,
  });

  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Map<String, Timestamp> _userLastMessageTimes = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchUserLastMessages();
  }

  void _fetchUserLastMessages() {
    FirebaseFirestore.instance
        .collection('chat_rooms')
        .where('participants', arrayContains: widget.currentUid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final newTimes = <String, Timestamp>{};
      for (var doc in snap.docs) {
        final participants = List<String>.from(doc['participants'] ?? []);
        participants.remove(widget.currentUid);
        if (participants.isNotEmpty) {
          newTimes[participants.first] =
              doc['lastTimestamp'] ?? Timestamp(0, 0);
        }
      }
      setState(() => _userLastMessageTimes = newTimes);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUid = widget.currentUid;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Cari kontak atau grup...',
              hintStyle:
                  const TextStyle(color: Color(0xFF999999), fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 20, color: Color(0xFF999999)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          size: 18, color: Color(0xFF999999)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: ContactService.contactsStream(currentUid),
            builder: (context, userSnap) {
              return StreamBuilder<List<GroupModel>>(
                stream: GroupService.userGroupsStream(currentUid),
                builder: (context, groupSnap) {
                  if (userSnap.connectionState == ConnectionState.waiting &&
                      groupSnap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF111111),
                        strokeWidth: 2,
                      ),
                    );
                  }

                  final users = userSnap.data ?? [];
                  final groups = groupSnap.data ?? [];
                  List<dynamic> mixedList = [...users, ...groups];

                  final filtered = _searchQuery.isEmpty
                      ? mixedList
                      : mixedList.where((item) {
                          if (item is UserModel) {
                            return item.username
                                    .toLowerCase()
                                    .contains(_searchQuery) ||
                                item.email.toLowerCase().contains(_searchQuery);
                          } else if (item is GroupModel) {
                            return item.name
                                .toLowerCase()
                                .contains(_searchQuery);
                          }
                          return false;
                        }).toList();

                  filtered.sort((a, b) {
                    Timestamp timeA = Timestamp(0, 0);
                    Timestamp timeB = Timestamp(0, 0);
                    if (a is GroupModel) {
                      timeA = a.lastTimestamp;
                    } else if (a is UserModel) {
                      timeA = _userLastMessageTimes[a.uid] ?? Timestamp(0, 0);
                    }
                    if (b is GroupModel) {
                      timeB = b.lastTimestamp;
                    } else if (b is UserModel) {
                      timeB = _userLastMessageTimes[b.uid] ?? Timestamp(0, 0);
                    }
                    final cmp = timeB.compareTo(timeA);
                    if (cmp != 0) return cmp;
                    final nameA =
                        a is GroupModel ? a.name : (a as UserModel).username;
                    final nameB =
                        b is GroupModel ? b.name : (b as UserModel).username;
                    return nameA.compareTo(nameB);
                  });

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _searchQuery.isEmpty
                                ? Icons.chat_bubble_outline_rounded
                                : Icons.search_off_rounded,
                            size: 56,
                            color: const Color(0xFFE5E5E5),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Belum ada obrolan'
                                : 'Tidak ada hasil',
                            style: const TextStyle(
                              color: Color(0xFF999999),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_searchQuery.isEmpty) ...[
                            const SizedBox(height: 6),
                            const Text(
                              'Gunakan tombol + untuk memulai',
                              style: TextStyle(
                                color: Color(0xFFBBBBBB),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(
                      indent: 80,
                      endIndent: 20,
                    ),
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      if (item is UserModel) {
                        final roomId =
                            ChatService.getRoomId(currentUid, item.uid);
                        return UserTile(
                          user: item,
                          roomId: roomId,
                          currentUid: currentUid,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  targetUser: item,
                                  currentUid: currentUid,
                                ),
                              ),
                            );
                          },
                          onLongPress: () => widget.onDeleteContact(item),
                        );
                      } else if (item is GroupModel) {
                        return _GroupTile(
                          group: item,
                          currentUid: currentUid,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupChatPage(
                                  initialGroup: item,
                                  currentUid: currentUid,
                                ),
                              ),
                            );
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
