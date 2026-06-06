import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/presence_service.dart';
import '../utils/avatar_helper.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserModel? _userData;
  bool _loading = false;

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
        _loading = false;
      });
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

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fitur ini akan segera hadir!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
              )
            : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: const Color(0xFF0EA5E9),
                    backgroundImage: _userData?.photoUrl.isNotEmpty == true
                        ? NetworkImage(_userData!.photoUrl)
                        : null,
                    child: (_userData?.photoUrl.isEmpty ?? true)
                        ? Text(
                            _userData?.username.isNotEmpty == true
                                ? _userData!.username[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 36,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userData?.username ?? '',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userData?.email ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (_userData == null) return;
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfilePage(userData: _userData!),
                        ),
                      );
                      if (result == true) {
                        _loadUser();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 36, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Edit Profile',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSettingItem(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: 'Manage notification settings',
                    onTap: _showComingSoon,
                  ),
                  const SizedBox(height: 8),
                  _buildSettingItem(
                    icon: Icons.lock_outline_rounded,
                    title: 'Privacy',
                    subtitle: 'Control your privacy settings',
                    onTap: _showComingSoon,
                  ),
                  const SizedBox(height: 8),
                  _buildSettingItem(
                    icon: Icons.shield_outlined,
                    title: 'Security',
                    subtitle: 'Manage security options',
                    onTap: _showComingSoon,
                  ),
                  const SizedBox(height: 8),
                  _buildSettingItem(
                    icon: Icons.palette_outlined,
                    title: 'Appearance',
                    subtitle: 'Customize app theme',
                    onTap: _showComingSoon,
                  ),
                  const SizedBox(height: 8),
                  _buildSettingItem(
                    icon: Icons.language_rounded,
                    title: 'Language',
                    subtitle: 'English',
                    onTap: _showComingSoon,
                  ),
                  const SizedBox(height: 80),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFFF3B30),
                      size: 20,
                    ),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Color(0xFFFF3B30),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      side: const BorderSide(color: Color(0xFFFF3B30)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF111111), size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF111111),
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Color(0xFF999999),
          fontSize: 13,
        ),
      ),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFCCCCCC)),
    );
  }
}
