import 'package:shared_preferences/shared_preferences.dart';

class UserStore {
  // Keys
  static const String _keyToken = 'jwt_token';
  static const String _keyRole = 'user_role';
  static const String _keyEmail = 'user_email';
  static const String _keyLoginDate = 'login_date';

  // Save all user data at once
  static Future<void> saveUserData({
    required String token,
    required String role,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyRole, role.toLowerCase());
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyLoginDate, DateTime.now().toIso8601String());
  }

  // Getters
  static Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString(_keyToken);

  static Future<String?> getRole() async =>
      (await SharedPreferences.getInstance()).getString(_keyRole);

  // Clear data on logout
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
