import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final settings = context.read<SettingsProvider>();
        final themeStr = settings.themeMode == ThemeMode.light 
          ? 'Light Mode' 
          : settings.themeMode == ThemeMode.dark ? 'Dark Mode' : 'System Default';
        setState(() {
          _selectedTheme = themeStr;
        });
      }
    });
  }

  Future<void> _setTheme(String theme) async {
    setState(() => _selectedTheme = theme);
    await context.read<SettingsProvider>().setTheme(theme);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.colorScheme.onSurface;

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
