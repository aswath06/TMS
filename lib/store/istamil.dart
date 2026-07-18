import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';

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

    // Call backend API if user is logged in
    try {
      final token = await UserStore.getToken();
      if (token != null && token.isNotEmpty) {
        final url = Uri.parse("\${ApiConstants.baseUrl}/user/language");
        await http.put(
          url,
          headers: ApiConstants.getHeaders(token),
          body: jsonEncode({"language": isTamil ? "tamil" : "english"}),
        );
      }
    } catch (e) {
      debugPrint("Failed to update language on backend: \$e");
    }
  }
}

// Global instance for convenience
final languageStore = LanguageStore();
