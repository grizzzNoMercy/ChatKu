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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Privacy'),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: Text(
              'Show Online Status',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              'Tampilkan apakah Anda sedang "Online" ke pengguna lain',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
            ),
            value: _showOnlineStatus,
            activeColor: theme.colorScheme.primary,
            onChanged: _toggleOnlineStatus,
          ),
        ],
      ),
    );
  }
}
