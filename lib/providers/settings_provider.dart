import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _localeString = 'English';

  ThemeMode get themeMode => _themeMode;
  String get localeString => _localeString;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final themeStr = prefs.getString('app_theme') ?? 'System Default';
    _themeMode = _getThemeModeFromString(themeStr);

    _localeString = prefs.getString('app_language') ?? 'English';
    notifyListeners();
  }

  Future<void> setTheme(String themeStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', themeStr);
    _themeMode = _getThemeModeFromString(themeStr);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', lang);
    _localeString = lang;
    notifyListeners();
  }

  ThemeMode _getThemeModeFromString(String themeStr) {
    if (themeStr == 'Light Mode') return ThemeMode.light;
    if (themeStr == 'Dark Mode') return ThemeMode.dark;
    return ThemeMode.system;
  }
}
