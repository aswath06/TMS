import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the runtime server base URL selection.
/// Super admins can toggle between Production and Dev tunnel.
class ServerConfig extends ChangeNotifier {
  static const String _keyIsProduction = 'server_is_production';

  static const String productionUrl = "https://2s01cq2n-8055.inc1.devtunnels.ms";
  static const String devTunnelUrl = "https://18x50gz9-8055.inc1.devtunnels.ms";

  // Singleton131432
  static final ServerConfig _instance = ServerConfig._internal();
  factory ServerConfig() => _instance;
  ServerConfig._internal();

  bool _isProduction = true; // default: production ON

  bool get isProduction => _isProduction;

  String get baseUrl => _isProduction ? productionUrl : devTunnelUrl;

  /// Load persisted value on app start.  
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isProduction = prefs.getBool(_keyIsProduction) ?? true;
    notifyListeners();
  }

  /// Toggle production/dev mode and persist.
  Future<void> setProduction(bool value) async {
    _isProduction = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsProduction, value);
    notifyListeners();
  }
}
