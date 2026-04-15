import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripzo/utils/routes.dart';

class UserStore {
  // Keys
  static const String _keyToken = 'jwt_token';
  static const String _keyRole = 'user_role';
  static const String _keyEmail = 'user_email';
  static const String _keyName = 'user_name';
  static const String _keyLoginDate = 'login_date';
  static const String _keyUserId = 'user_id';
  static const String _keyDriverId = 'driver_id';

  // Save all user data at once
  static Future<void> saveUserData({
    required String token,
    required String role,
    required String email,
    required int id,
    String? name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyRole, role.toLowerCase());
    await prefs.setString(_keyEmail, email);
    await prefs.setInt(_keyUserId, id);
    if (name != null) await prefs.setString(_keyName, name);
    await prefs.setString(_keyLoginDate, DateTime.now().toIso8601String());
  }

  // Getters
  static Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString(_keyToken);
  
  static Future<int?> getUserId() async =>
      (await SharedPreferences.getInstance()).getInt(_keyUserId);

  static Future<int?> getDriverId() async =>
      (await SharedPreferences.getInstance()).getInt(_keyDriverId);

  static Future<void> saveDriverId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDriverId, id);
  }

  static Future<void> saveUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, id);
  }

  static Future<String?> getRole() async =>
      (await SharedPreferences.getInstance()).getString(_keyRole);

  static Future<String?> getEmail() async =>
      (await SharedPreferences.getInstance()).getString(_keyEmail);

  static Future<String?> getName() async =>
      (await SharedPreferences.getInstance()).getString(_keyName);

  static Future<void> saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
  }

  // Clear data on logout
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Force logout and redirect to login
  static Future<void> forceLogout() async {
    await clear();
    AppRoutes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }
}
