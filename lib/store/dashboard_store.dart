import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';

class DashboardState {
  final int totalRoutes;
  final int pendingRoutes;
  final int activeRoutes;
  final bool isLoading;
  final String? error;

  DashboardState({
    this.totalRoutes = 0,
    this.pendingRoutes = 0,
    this.activeRoutes = 0,
    this.isLoading = false,
    this.error,
  });

  DashboardState copyWith({
    int? totalRoutes,
    int? pendingRoutes,
    int? activeRoutes,
    bool? isLoading,
    String? error,
  }) {
    return DashboardState(
      totalRoutes: totalRoutes ?? this.totalRoutes,
      pendingRoutes: pendingRoutes ?? this.pendingRoutes,
      activeRoutes: activeRoutes ?? this.activeRoutes,
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
}

final dashboardStore = DashboardStore();
