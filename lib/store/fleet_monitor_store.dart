import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';

class FleetMonitorStore extends ChangeNotifier {
  bool _isLoading = false;
  String _error = '';

  int _insideCount = 0;
  int _outsideCount = 0;
  List<dynamic> _insideVehicles = [];
  List<dynamic> _outsideVehicles = [];

  bool get isLoading => _isLoading;
  String get error => _error;
  int get insideCount => _insideCount;
  int get outsideCount => _outsideCount;
  List<dynamic> get insideVehicles => _insideVehicles;
  List<dynamic> get outsideVehicles => _outsideVehicles;

  bool _hasFetchedInitialData = false;

  Future<void> fetchFleetData({bool forceRefresh = false}) async {
    if (_isLoading) return;
    if (_hasFetchedInitialData && !forceRefresh) return;

    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        _error = "Unauthorized";
        return;
      }

      final Uri uri = Uri.parse(
        ApiConstants.getSecurityRoutes(1, 100, 'OUT_CAMPUS'),
      );

      final response = await http.get(
        uri,
        headers: ApiConstants.getHeaders(token),
      );

      debugPrint("--- [DEBUG] FLEET MONITOR CURL ---");
      debugPrint("curl --location '$uri' \\");
      ApiConstants.getHeaders(token).forEach((key, value) {
        debugPrint("--header '$key: $value' \\");
      });
      debugPrint("----------------------------------");

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final vehicleSummary = responseData['data']?['vehicle_summary'] ?? {};

        _insideCount = vehicleSummary['inside_count'] ?? 0;
        _outsideCount = vehicleSummary['outside_count'] ?? 0;
        _insideVehicles = List.from(vehicleSummary['inside_vehicles'] ?? []);
        _outsideVehicles = List.from(vehicleSummary['outside_vehicles'] ?? []);
        _hasFetchedInitialData = true;
      } else if (response.statusCode == 401) {
        await UserStore.forceLogout();
      } else {
        _error = 'Failed to load fleet data';
      }
    } catch (e) {
      _error = 'Error connecting to server';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

final fleetMonitorStore = FleetMonitorStore();
