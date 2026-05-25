import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/contact_service.dart';
import '../services/group_service.dart';
import '../utils/avatar_helper.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _nameController = TextEditingController();
  final Set<String> _selectedUids = {};
  File? _photoFile;
  bool _loading = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _photoFile = File(picked.path));
    }
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama grup tidak boleh kosong'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
      return;
    }
    if (_selectedUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal 1 anggota'),
          backgroundColor: Color(0xFFFF3B30),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    final currentUid = context.read<AuthService>().currentUid!;

    final error = await GroupService.createGroup(
      name: name,
      adminId: currentUid,
      memberIds: _selectedUids.toList(),
      photoFile: _photoFile,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = context.read<AuthService>().currentUid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Grup Baru'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _createGroup,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF111111),
                    ),
                  )
                : const Text(
                    'Buat',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Header info
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: const Color(0xFFF5F5F5),
                        backgroundImage:
                            _photoFile != null ? FileImage(_photoFile!) : null,
                        child: _photoFile == null
                            ? const Icon(Icons.group_outlined,
                                size: 28, color: Color(0xFF999999))
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF111111),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Nama Grup',
                      hintStyle: TextStyle(color: Color(0xFF999999)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111111),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          
          // Search contacts
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Cari kontak...',
                hintStyle: const TextStyle(color: Color(0xFF999999), fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: Color(0xFF999999)),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // Contacts list
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: ContactService.contactsStream(currentUid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF111111)),
                  );
                }

                final users = snapshot.data ?? [];
                final filtered = _searchQuery.isEmpty
                    ? users
                    : users
                        .where((u) => u.username.toLowerCase().contains(_searchQuery))
                        .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'Tidak ada kontak ditemukan',
                      style: TextStyle(color: Color(0xFF999999)),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final user = filtered[i];
                    final isSelected = _selectedUids.contains(user.uid);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: AvatarHelper.backgroundColor(user.username),
                        backgroundImage: user.photoUrl.isNotEmpty
                            ? NetworkImage(user.photoUrl)
                            : null,
                        child: user.photoUrl.isEmpty
                            ? Text(
                                user.username.isNotEmpty
                                    ? user.username[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: AvatarHelper.textColor(user.username),
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        user.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111111),
                        ),
                      ),
                      trailing: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFF111111)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF111111)
                                : const Color(0xFFE5E5E5),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedUids.remove(user.uid);
                          } else {
                            _selectedUids.add(user.uid);
                          }
                        });
                      },
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
