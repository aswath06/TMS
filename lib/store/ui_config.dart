import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UIConfig extends ChangeNotifier {
  static const String _keyUIEnhancement = 'ui_enhancement_enabled';

  static final UIConfig _instance = UIConfig._internal();
  factory UIConfig() => _instance;
  UIConfig._internal();

  bool _isUIEnhancementEnabled = true;

  bool get isUIEnhancementEnabled => _isUIEnhancementEnabled;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isUIEnhancementEnabled = prefs.getBool(_keyUIEnhancement) ?? true;
    notifyListeners();
  }

  Future<void> setUIEnhancement(bool value) async {
    _isUIEnhancementEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUIEnhancement, value);
    notifyListeners();
  }
}
