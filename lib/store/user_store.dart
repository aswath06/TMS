import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripzo/utils/routes.dart';
import 'package:tripzo/services/location_service.dart';

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

  static const String _keyPushNotificationEnabled = 'push_notification_enabled';

  static Future<bool> getPushNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPushNotificationEnabled) ?? true;
  }

  static Future<void> savePushNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPushNotificationEnabled, enabled);
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
    await prefs.remove(_keyToken);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyName);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyDriverId);
    await prefs.remove(_keyLoginDate);
  }

  // Force logout and redirect to login
  static Future<void> forceLogout({bool isBlocked = false}) async {
    try {
      await LocationService().stopTracking();
    } catch (e) {
      debugPrint("Error stopping background service on logout: $e");
    }
    await clear();
    
    if (isBlocked) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('showBlockedAlert', true);
    }
    
    AppRoutes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }
}
