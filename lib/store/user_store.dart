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
  static const String _keyPushNotificationEnabled = 'push_notification_enabled';

  // Static memory cache (Zero-delay synchronous access)
  static String? _token;
  static String? _role;
  static String? _email;
  static String? _name;
  static int? _userId;
  static int? _driverId;
  static bool? _pushNotificationEnabled;

  /// Call this once in main.dart to initialize the static cache
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_keyToken);
    _role = prefs.getString(_keyRole);
    _email = prefs.getString(_keyEmail);
    _name = prefs.getString(_keyName);
    _userId = prefs.getInt(_keyUserId);
    _driverId = prefs.getInt(_keyDriverId);
    _pushNotificationEnabled = prefs.getBool(_keyPushNotificationEnabled);
  }

  // --- Synchronous Getters (Zero-delay) ---
  static String? get token => _token;
  static String? get role => _role;
  static String? get email => _email;
  static String? get name => _name;
  static int? get userId => _userId;
  static int? get driverId => _driverId;
  static bool get pushNotificationEnabled => _pushNotificationEnabled ?? true;

  // --- Asynchronous Getters (Legacy - Keep for compatibility) ---
  static Future<String?> getToken() async => _token ?? (await SharedPreferences.getInstance()).getString(_keyToken);
  static Future<int?> getUserId() async => _userId ?? (await SharedPreferences.getInstance()).getInt(_keyUserId);
  static Future<int?> getDriverId() async => _driverId ?? (await SharedPreferences.getInstance()).getInt(_keyDriverId);
  static Future<String?> getRole() async => _role ?? (await SharedPreferences.getInstance()).getString(_keyRole);
  static Future<String?> getEmail() async => _email ?? (await SharedPreferences.getInstance()).getString(_keyEmail);
  static Future<String?> getName() async => _name ?? (await SharedPreferences.getInstance()).getString(_keyName);
  static Future<bool> getPushNotificationEnabled() async => _pushNotificationEnabled ?? (await SharedPreferences.getInstance()).getBool(_keyPushNotificationEnabled) ?? true;

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

    // Update memory cache
    _token = token;
    _role = role.toLowerCase();
    _email = email;
    _userId = id;
    if (name != null) _name = name;
  }

  static Future<void> savePushNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPushNotificationEnabled, enabled);
    _pushNotificationEnabled = enabled; // Update cache
  }

  static Future<void> saveDriverId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDriverId, id);
    _driverId = id; // Update cache
  }

  static Future<void> saveUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, id);
    _userId = id; // Update cache
  }

  static Future<void> saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    _name = name; // Update cache
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

    // Clear memory cache
    _token = null;
    _role = null;
    _email = null;
    _name = null;
    _userId = null;
    _driverId = null;
    _pushNotificationEnabled = null;
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
