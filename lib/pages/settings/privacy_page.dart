import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool _showOnlineStatus = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showOnlineStatus = prefs.getBool('show_online_status') ?? true;
    });
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    setState(() => _showOnlineStatus = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_online_status', value);
    
    // Nanti PresenceService akan mengecek 'show_online_status' 
    // sebelum update ke Firestore.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Privacy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text(
              'Show Online Status',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: const Text(
              'Tampilkan apakah Anda sedang "Online" ke pengguna lain',
              style: TextStyle(color: Color(0xFF999999), fontSize: 13),
            ),
            value: _showOnlineStatus,
            activeColor: const Color(0xFF0EA5E9),
            onChanged: _toggleOnlineStatus,
          ),
        ],
      ),
    );
  }
}
