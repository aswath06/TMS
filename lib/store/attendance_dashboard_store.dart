import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class AttendanceDashboardStore extends ChangeNotifier {
  IO.Socket? _socket;
  bool _isLoading = false;
  String _error = '';

  Map<String, dynamic>? _overallStats;
  List<dynamic> _vehicleStats = [];
  String _lastFetchedDate = '';

  AttendanceDashboardStore() {
    _initSocket();
  }

  void _initSocket() {
    final role = UserStore.role;
    // Only connect WebSocket and fetch data for Super Admin and Transport Admin
    if (role != 'super admin' && role != 'transport admin') {
      return;
    }

    // Assuming backend is on port 4004 based on Server.js
    // Extract base URL without the /api part if needed, or define a specific socket URL.
    final uri = Uri.parse(ApiConstants.baseUrl);
    final socketUrl = '${uri.scheme}://${uri.host}:${uri.port}';

    _socket = IO.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket?.onConnect((_) {
      // Socket connected successfully
    });

    _socket?.on('attendance_dashboard_update', (payload) {
      if (payload != null && payload['data'] != null) {
        final data = payload['data'];
        _overallStats = data['overall_stats'];
        _vehicleStats = data['vehicle_stats'];
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  bool get isLoading => _isLoading;
  String get error => _error;
  Map<String, dynamic>? get overallStats => _overallStats;
  List<dynamic> get vehicleStats => _vehicleStats;

  Future<void> fetchDashboardData(String date) async {
    _isLoading = true;
    _error = '';
    _lastFetchedDate = date;
    notifyListeners();

    try {
      final String? token = UserStore.token;
      if (token == null) {
        throw Exception("Authentication token not found");
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/daily-bus/bus-runs/reports/attendance-dashboard?date=$date');
      final response = await http.get(
        url,
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _overallStats = data['data']['overall_stats'];
          _vehicleStats = data['data']['vehicle_stats'];
        } else {
          _error = data['message'] ?? 'Failed to fetch attendance data';
        }
      } else {
        _error = 'Failed to fetch attendance data (Status: ${response.statusCode})';
      }
    } catch (e) {
      _error = 'An error occurred: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_lastFetchedDate.isNotEmpty) {
      await fetchDashboardData(_lastFetchedDate);
    } else {
      final dateStr = DateTime.now().toIso8601String().split('T')[0];
      await fetchDashboardData(dateStr);
    }
  }
}
