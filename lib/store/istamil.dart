import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageStore extends ChangeNotifier {
  // Static variable to store the state globally for backward compatibility
  static bool isTamil = false;

  static const String _languageKey = 'isTamil';

  // Singleton pattern for use with Provider
  static final LanguageStore _instance = LanguageStore._internal();
  factory LanguageStore() => _instance;
  LanguageStore._internal();

  /// Loads the saved language from local storage
  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    isTamil = prefs.getBool(_languageKey) ?? false;
    notifyListeners();
  }

  /// Sets the language and persists it to local storage
  Future<void> setLanguage(String language) async {
    isTamil = (language == "தமிழ்");

    // Save to local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_languageKey, isTamil);

    notifyListeners();
  }
}

// Global instance for convenience
final languageStore = LanguageStore();
