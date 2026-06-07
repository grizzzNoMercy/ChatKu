import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  String _selectedLanguage = 'English';
  
  final List<String> _languages = [
    'English',
    'Bahasa Indonesia',
    'Español',
    '日本語',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final settings = context.read<SettingsProvider>();
        setState(() {
          _selectedLanguage = settings.localeString;
        });
      }
    });
  }

  Future<void> _setLanguage(String lang) async {
    setState(() => _selectedLanguage = lang);
    await context.read<SettingsProvider>().setLanguage(lang);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Language changed to $lang')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Language'),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _languages.length,
        itemBuilder: (context, index) {
          final lang = _languages[index];
          final isSelected = lang == _selectedLanguage;

          return ListTile(
            title: Text(
              lang,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                : null,
            onTap: () => _setLanguage(lang),
          );
        },
      ),
    );
  }
}
