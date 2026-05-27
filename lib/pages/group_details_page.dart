import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../services/group_service.dart';
import '../utils/avatar_helper.dart';

class GroupDetailsPage extends StatefulWidget {
  final GroupModel group;
  final String currentUid;

  const GroupDetailsPage({
    super.key,
    required this.group,
    required this.currentUid,
  });

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  List<UserModel> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final groupDoc = await FirebaseFirestore.instance.collection('groups').doc(widget.group.id).get();
    if (!groupDoc.exists) return;
    
    final currentGroupMembers = List<String>.from(groupDoc.data()?['members'] ?? []);
    
    List<UserModel> loaded = [];
    for (String uid in currentGroupMembers) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        loaded.add(UserModel.fromMap(doc.data()!));
      }
    }
    if (mounted) {
      setState(() {
        _members = loaded;
        _loading = false;
      });
    }
  }

  Future<void> _showAddMemberModal() async {
    final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(widget.currentUid).get();
    final currentUserName = currentUserDoc.data()?['username'] ?? 'Seorang anggota';

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _AddMemberModal(
          groupId: widget.group.id,
          currentMembers: _members.map((e) => e.uid).toList(),
          currentUid: widget.currentUid,
          currentUserName: currentUserName,
          onAdded: _loadMembers,
        );
      },
    );
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Keluar Grup', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar dari grup ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Fetch current user name to show in the system message
    final currentUserDoc = await FirebaseFirestore.instance.collection('users').doc(widget.currentUid).get();
    final currentUserName = currentUserDoc.data()?['username'] ?? 'Seorang anggota';
    
    // Send system message
    await GroupService.sendSystemMessage(
      groupId: widget.group.id,
      message: '$currentUserName telah keluar dari grup',
    );

    // Leave group
    await GroupService.leaveGroup(widget.group.id, widget.currentUid);

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111111)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Grup',
          style: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Group Avatar & Name
          CircleAvatar(
            radius: 64,
            backgroundColor: AvatarHelper.backgroundColor(widget.group.name),
            backgroundImage: widget.group.photoUrl.isNotEmpty
                ? NetworkImage(widget.group.photoUrl)
                : null,
            child: widget.group.photoUrl.isEmpty
                ? Text(
                    widget.group.name.isNotEmpty
                        ? widget.group.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: AvatarHelper.textColor(widget.group.name),
                      fontWeight: FontWeight.bold,
                      fontSize: 48,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            widget.group.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.group.members.length} anggota',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Anggota',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111111),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddMemberModal,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 20, color: Color(0xFF0EA5E9)),
                  label: const Text(
                    'Tambah',
                    style: TextStyle(
                      color: Color(0xFF0EA5E9),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AvatarHelper.backgroundColor(member.username),
                          backgroundImage: member.photoUrl.isNotEmpty
                              ? NetworkImage(member.photoUrl)
                              : null,
                          child: member.photoUrl.isEmpty
                              ? Text(
                                  member.username.isNotEmpty
                                      ? member.username[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: AvatarHelper.textColor(member.username),
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          member.uid == widget.currentUid ? 'Anda' : member.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111111),
                          ),
                        ),
                        subtitle: Text(
                          member.email,
                          style: const TextStyle(color: Color(0xFF999999)),
                        ),
                      );
                    },
                  ),
          ),
          // Leave Group Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: _leaveGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                foregroundColor: const Color(0xFFFF3B30),
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Keluar Grup',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMemberModal extends StatefulWidget {
  final String groupId;
  final List<String> currentMembers;
  final String currentUid;
  final String currentUserName;
  final VoidCallback onAdded;

  const _AddMemberModal({
    required this.groupId,
    required this.currentMembers,
    required this.currentUid,
    required this.currentUserName,
    required this.onAdded,
  });

  @override
  State<_AddMemberModal> createState() => _AddMemberModalState();
}

class _AddMemberModalState extends State<_AddMemberModal> {
  List<UserModel> _availableUsers = [];
  Set<String> _selectedUids = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
  }

  Future<void> _loadAvailableUsers() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.currentUid).get();
    final contactUids = List<String>.from(userDoc.data()?['contacts'] ?? []);

    final snap = await FirebaseFirestore.instance.collection('users').get();
    final allUsers = snap.docs.map((doc) => UserModel.fromMap(doc.data())).toList();
    
    if (mounted) {
      setState(() {
        _availableUsers = allUsers.where((u) => 
            contactUids.contains(u.uid) && !widget.currentMembers.contains(u.uid)
        ).toList();
        _loading = false;
      });
    }
  }

  Future<void> _addMembers() async {
    if (_selectedUids.isEmpty) return;
    setState(() => _saving = true);
    
    final selectedUsers = _availableUsers.where((u) => _selectedUids.contains(u.uid)).toList();
    final names = selectedUsers.map((u) => u.username).join(', ');
    
    await GroupService.addMembers(
      groupId: widget.groupId,
      userIds: _selectedUids.toList(),
      adderName: widget.currentUserName,
      newMemberNames: names,
    );
    
    if (mounted) {
      Navigator.pop(context);
      widget.onAdded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5E5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tambah Anggota',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
                : _availableUsers.isEmpty
                    ? const Center(child: Text('Semua kontak sudah ada di dalam grup.'))
                    : ListView.builder(
                        itemCount: _availableUsers.length,
                        itemBuilder: (context, index) {
                          final user = _availableUsers[index];
                          final isSelected = _selectedUids.contains(user.uid);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedUids.add(user.uid);
                                } else {
                                  _selectedUids.remove(user.uid);
                                }
                              });
                            },
                            secondary: CircleAvatar(
                              backgroundColor: AvatarHelper.backgroundColor(user.username),
                              backgroundImage: user.photoUrl.isNotEmpty
                                  ? NetworkImage(user.photoUrl)
                                  : null,
                              child: user.photoUrl.isEmpty
                                  ? Text(
                                      user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        color: AvatarHelper.textColor(user.username),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              user.username,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111111)),
                            ),
                            subtitle: Text(user.email, style: const TextStyle(color: Color(0xFF999999))),
                            activeColor: const Color(0xFF0EA5E9),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: (_selectedUids.isEmpty || _saving) ? null : _addMembers,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Tambah (${_selectedUids.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
