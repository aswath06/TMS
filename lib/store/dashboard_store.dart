import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';

class DashboardState {
  final int totalRoutes;
  final int pendingRoutes;
  final int activeRoutes;
  final List<Map<String, dynamic>> history;
  final bool isLoading;
  final String? error;

  DashboardState({
    this.totalRoutes = 0,
    this.pendingRoutes = 0,
    this.activeRoutes = 0,
    this.history = const [],
    this.isLoading = false,
    this.error,
  });

  DashboardState copyWith({
    int? totalRoutes,
    int? pendingRoutes,
    int? activeRoutes,
    List<Map<String, dynamic>>? history,
    bool? isLoading,
    String? error,
  }) {
    return DashboardState(
      totalRoutes: totalRoutes ?? this.totalRoutes,
      pendingRoutes: pendingRoutes ?? this.pendingRoutes,
      activeRoutes: activeRoutes ?? this.activeRoutes,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DashboardStore extends ChangeNotifier {
  DashboardState _state = DashboardState();
  DashboardState get state => _state;

  Future<void> fetchStats() async {
    if (_state.isLoading) return;

    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final String? token = await UserStore.getToken();
      
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 7)).toIso8601String().split('T')[0];
      final endDate = now.add(const Duration(days: 7)).toIso8601String().split('T')[0];

      final response = await http.get(
        Uri.parse("${ApiConstants.baseUrl}/request/route-starts/2?start_date=$startDate&end_date=$endDate"),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _state = _state.copyWith(
          totalRoutes: data['total_routes'] ?? 0,
          pendingRoutes: data['pending_routes'] ?? 0,
          activeRoutes: data['active_routes'] ?? 0,
          isLoading: false,
        );
      } else {
        _state = _state.copyWith(
          isLoading: false,
          error: "Failed to fetch dashboard stats",
        );
      }
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: "Network error. Please try again.",
      );
    }
    notifyListeners();
  }

  Future<void> fetchHistory({int page = 1, int limit = 10}) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final String? token = await UserStore.getToken();
      final String? email = await UserStore.getEmail();
      
      // status=8 is Completed
      String url = "${ApiConstants.baseUrl}/request/get-all?page=$page&limit=$limit&status=8";
      if (email != null) {
        url += "&user=$email";
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['items'] ?? [];
        
        final formattedHistory = items.map((req) => _formatHistoryItem(req)).toList();
        
        _state = _state.copyWith(
          history: page == 1 ? formattedHistory : [..._state.history, ...formattedHistory],
          isLoading: false,
        );
      } else {
        _state = _state.copyWith(isLoading: false, error: "Failed to fetch history");
      }
    } catch (e) {
      _state = _state.copyWith(isLoading: false, error: "Network error fetching history");
    }
    notifyListeners();
  }

  Map<String, dynamic> _formatHistoryItem(dynamic req) {
    return {
      'id': 'REQ-${req['id']}',
      'dbId': req['id'],
      'routeName': req['routeName'] ?? 'Unknown Route',
      'date': req['start_datetime']?.toString().split('T')[0] ?? 'No Date',
      'pickup': req['startLocation'] ?? 'Unknown',
      'drop': req['destinationLocation'] ?? 'Unknown',
      'passengers': req['passengerCount'] ?? 0,
      'status': 'Completed',
      'rawStatus': 8,
      'vehicle': req['assignedVehicle']?['model'] ?? 'N/A',
      'intermediateStops': req['intermediateStops'] ?? [],
    };
  }
}

final dashboardStore = DashboardStore();
