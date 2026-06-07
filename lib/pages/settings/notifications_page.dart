import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/sound_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _inAppSounds = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _inAppSounds = prefs.getBool('in_app_sounds') ?? true;
    });
  }

  Future<void> _toggleSounds(bool value) async {
    setState(() => _inAppSounds = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('in_app_sounds', value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: Text(
              'In-App Sounds',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              "Bunyi 'ting' saat mengirim atau menerima pesan",
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
            ),
            value: _inAppSounds,
            activeColor: theme.colorScheme.primary,
            onChanged: _toggleSounds,
          ),
        ],
      ),
    );
  }
}
