import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';
import '../services/contact_service.dart';
import '../widgets/user_tile.dart';
import 'chat_page.dart';
import 'friend_requests_page.dart';
import 'incoming_call_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  StreamSubscription<QuerySnapshot>? _callSub;
  String? _handlingCallId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenForIncomingCalls();
    });
  }

  void _listenForIncomingCalls() {
    final currentUid = context.read<AuthService>().currentUid;
    if (currentUid == null) return;

    _callSub = CallService.incomingCallStream(currentUid).listen((snap) {
      if (snap.docs.isEmpty || !mounted) return;
      final doc = snap.docs.first;
      if (doc.id == _handlingCallId) return;
      _handlingCallId = doc.id;
      final data = doc.data() as Map<String, dynamic>;

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
    _searchController.dispose();
    super.dispose();
  }

  // ── Add Contact Dialog ──────────────────────────────────────────────────
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
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.person_add_rounded,
                      color: Color(0xFF6C63FF), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Tambah Kontak',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Email input
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Masukkan email pengguna',
                        prefixIcon:
                            Icon(Icons.email_outlined, size: 20),
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

                    // Search button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF6C63FF)),
                              )
                            : const Icon(Icons.search_rounded, size: 18),
                        label: Text(isLoading ? 'Mencari...' : 'Cari'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6C63FF),
                          side: const BorderSide(color: Color(0xFF6C63FF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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

                                // Validate: own email
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

                                final user = await ContactService
                                    .searchUserByEmail(email);
                                if (user == null) {
                                  setDialogState(() {
                                    isLoading = false;
                                    errorMsg =
                                        'Email tidak ditemukan.';
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

                    // Error message
                    if (errorMsg != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: Colors.red[400], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMsg!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Found user preview
                    if (foundUser != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F2FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFD9D6FF),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFFEEECFF),
                              backgroundImage:
                                  foundUser!.photoUrl.isNotEmpty
                                      ? NetworkImage(foundUser!.photoUrl)
                                      : null,
                              child: foundUser!.photoUrl.isEmpty
                                  ? Text(
                                      foundUser!.username.isNotEmpty
                                          ? foundUser!.username[0]
                                              .toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Color(0xFF6C63FF),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    foundUser!.username,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    foundUser!.email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Send request button
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
                                ? 'Permintaan Terkirim!'
                                : 'Kirim Permintaan',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: requestSent
                                ? const Color(0xFF48BB78)
                                : const Color(0xFF6C63FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: requestSent
                              ? null
                              : () async {
                                  final err = await ContactService
                                      .sendFriendRequest(
                                    fromUid: currentUid,
                                    toUid: foundUser!.uid,
                                  );
                                  if (err != null) {
                                    setDialogState(
                                        () => errorMsg = err);
                                  } else {
                                    setDialogState(
                                        () => requestSent = true);
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

  // ── Delete Contact Confirmation ─────────────────────────────────────────
  void _showDeleteContactDialog(String currentUid, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus Kontak',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Color(0xFF1A1A2E),
          ),
        ),
        content: Text(
          'Hapus ${user.username} dari daftar kontak?\n'
          'Kontak ini juga akan dihapus dari sisi pengguna lain.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red[400],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
      appBar: AppBar(
        title: const Text('ChatKu'),
        actions: [
          // Friend request badge
          StreamBuilder<int>(
            stream: ContactService.pendingRequestCountStream(currentUid),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(
                    '$count',
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.people_outline_rounded),
                ),
                tooltip: 'Permintaan Pertemanan',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const FriendRequestsPage()),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      // FAB for adding contacts
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () => _showAddContactDialog(currentUid),
        child: const Icon(Icons.person_add_rounded),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Cari kontak...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          // Contact list (filtered by contacts only)
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: ContactService.contactsStream(currentUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6C63FF),
                    ),
                  );
                }

                final users = snapshot.data ?? [];
                final filtered = _searchQuery.isEmpty
                    ? users
                    : users
                        .where((u) =>
                            u.username.toLowerCase().contains(_searchQuery) ||
                            u.email.toLowerCase().contains(_searchQuery))
                        .toList();

                // Sort: online first, then by username
                filtered.sort((a, b) {
                  if (a.online && !b.online) return -1;
                  if (!a.online && b.online) return 1;
                  return a.username.compareTo(b.username);
                });

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.people_outline_rounded
                              : Icons.search_off_rounded,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Belum ada kontak'
                              : 'Tidak ada hasil untuk "$_searchQuery"',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Tambahkan kontak baru dengan tombol +',
                            style: TextStyle(
                                color: Colors.grey[350], fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 80,
                    endIndent: 16,
                  ),
                  itemBuilder: (context, i) {
                    final user = filtered[i];
                    final roomId =
                        ChatService.getRoomId(currentUid, user.uid);
                    return UserTile(
                      user: user,
                      roomId: roomId,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              targetUser: user,
                              currentUid: currentUid,
                            ),
                          ),
                        );
                      },
                      onLongPress: () =>
                          _showDeleteContactDialog(currentUid, user),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
