import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/presence_service.dart';
import '../utils/avatar_helper.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  File? _newPhoto;
  UserModel? _userData;
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    final user = await context.read<AuthService>().getCurrentUserData();
    if (mounted) {
      setState(() {
        _userData = user;
        _usernameController.text = user?.username ?? '';
        _loading = false;
      });
    }
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
      setState(() => _newPhoto = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final error = await context.read<AuthService>().updateProfile(
      username: _usernameController.text.trim(),
      photoFile: _newPhoto,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFFF3B30),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profil berhasil diperbarui'),
          backgroundColor: const Color(0xFF34C759),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      );
      _loadUser();
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Keluar',
          style: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text('Apakah kamu yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Keluar',
              style: TextStyle(color: Color(0xFFFF3B30)),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    context.read<PresenceService>().leaveRoom('');
    await context.read<AuthService>().logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF111111),
                    ),
                  )
                : const Text(
                    'Simpan',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF111111)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: AvatarHelper.backgroundColor(
                                _userData?.username ?? ''),
                            backgroundImage: _newPhoto != null
                                ? FileImage(_newPhoto!)
                                : (_userData?.photoUrl.isNotEmpty == true
                                    ? NetworkImage(_userData!.photoUrl)
                                        as ImageProvider
                                    : null),
                            child: (_newPhoto == null &&
                                    (_userData?.photoUrl.isEmpty ?? true))
                                ? Text(
                                    _userData?.username.isNotEmpty == true
                                        ? _userData!.username[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: AvatarHelper.textColor(
                                          _userData?.username ?? ''),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 36,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                color: Color(0xFF111111),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _pickPhoto,
                      child: const Text(
                        'Ganti foto',
                        style: TextStyle(color: Color(0xFF999999)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Username field
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        hintText: 'Username',
                        hintStyle: TextStyle(color: Color(0xFF999999)),
                        prefixIcon: Icon(Icons.person_outline_rounded,
                            size: 20, color: Color(0xFF999999)),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Username wajib diisi';
                        if (v.length < 3) return 'Username minimal 3 karakter';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Email (read-only)
                    TextFormField(
                      initialValue: _userData?.email ?? '',
                      readOnly: true,
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        hintStyle: TextStyle(color: Color(0xFF999999)),
                        prefixIcon: Icon(Icons.mail_outline_rounded,
                            size: 20, color: Color(0xFF999999)),
                        filled: true,
                        fillColor: Color(0xFFF5F5F5),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Logout button
                    OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFFF3B30),
                        size: 18,
                      ),
                      label: const Text(
                        'Keluar',
                        style: TextStyle(
                          color: Color(0xFFFF3B30),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54),
                        side: const BorderSide(color: Color(0xFFFF3B30)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
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
