import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});

  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  String _selectedTheme = 'Light Mode';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTheme = prefs.getString('app_theme') ?? 'Light Mode';
    });
  }

  Future<void> _setTheme(String theme) async {
    setState(() => _selectedTheme = theme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', theme);
  }

  @override
  Widget build(BuildContext context) {
    // Demo background color based on selection
    final bgColor = _selectedTheme == 'Dark Mode' ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = _selectedTheme == 'Dark Mode' ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Appearance', style: TextStyle(color: textColor)),
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'App Theme',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          _buildThemeOption('Light Mode', textColor),
          _buildThemeOption('Dark Mode', textColor),
          _buildThemeOption('System Default', textColor),
        ],
      ),
    );
  }

  Widget _buildThemeOption(String themeName, Color textColor) {
    return RadioListTile<String>(
      title: Text(themeName, style: TextStyle(color: textColor)),
      value: themeName,
      groupValue: _selectedTheme,
      activeColor: const Color(0xFF0EA5E9),
      onChanged: (value) {
        if (value != null) _setTheme(value);
      },
    );
  }
}
