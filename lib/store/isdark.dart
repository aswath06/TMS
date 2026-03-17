import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeStore extends ChangeNotifier {
  static bool isDark = false;
  
  // Singleton pattern for use with Provider
  static final ThemeStore _instance = ThemeStore._internal();
  factory ThemeStore() => _instance;
  ThemeStore._internal();

  // Key used to store the value in local storage
  static const String _themeKey = 'isDark';

  /// Loads the saved theme from local storage
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    isDark = prefs.getBool(_themeKey) ?? false;
    notifyListeners();
  }

  /// Sets the theme and persists it to local storage
  Future<void> setTheme(bool value) async {
    isDark = value;

    // Save to local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, value);

    notifyListeners();
  }
}

// Global instance for convenience
final themeStore = ThemeStore();
