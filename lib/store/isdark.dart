import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeStore {
  static bool isDark = false;
  static VoidCallback? onThemeChanged;

  // Key used to store the value in local storage
  static const String _themeKey = 'isDark';

  /// Loads the saved theme from local storage
  static Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    isDark = prefs.getBool(_themeKey) ?? false;
    if (onThemeChanged != null) onThemeChanged!();
  }

  /// Sets the theme and persists it to local storage
  static Future<void> setTheme(bool value) async {
    isDark = value;

    // Save to local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, value);

    if (onThemeChanged != null) {
      onThemeChanged!();
    }
  }
}
