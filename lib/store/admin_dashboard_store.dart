import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tms/store/user_store.dart';
import 'package:tms/utils/api_constants.dart';

/// Store for Admin Dashboard statistics.
/// Provides reactive ValueNotifiers that the UI can listen to.
class AdminDashboardStore {
  // Singleton pattern
  static final AdminDashboardStore _instance = AdminDashboardStore._internal();
  factory AdminDashboardStore() => _instance;
  AdminDashboardStore._internal();

  // Loading flag
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  // Statistics notifiers
  final ValueNotifier<int> driversPresent = ValueNotifier<int>(0);
  final ValueNotifier<int> driversAbsent = ValueNotifier<int>(0);
  final ValueNotifier<double> totalKilometers = ValueNotifier<double>(0.0);
  final ValueNotifier<int> movingBuses = ValueNotifier<int>(0);
  final ValueNotifier<int> servicesCount = ValueNotifier<int>(0);

  /// Fetch statistics from backend.
  /// Currently populates with placeholder data; replace with real API calls later.
  Future<void> fetchStats() async {
    if (isLoading.value) return; // Prevent duplicate calls
    isLoading.value = true;
    try {
      final String? token = await UserStore.getToken();

      // Fetch requests to get real-time operational data
      final String url =
          "${ApiConstants.baseUrl}/request/get-all?page=1&limit=100";
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> items = data['items'] ?? [];

        // Compute real statistics from fetched requests
        servicesCount.value = items.length;
        movingBuses.value = items
            .where(
              (req) =>
                  req['status'] == 4 ||
                  req['status'] == 6 ||
                  (req['status'] ?? '').toString().toLowerCase() == 'approved',
            )
            .length;

        // Still keep some placeholders for things not yet in requests API
        driversPresent.value = 12;
        driversAbsent.value = 3;
        totalKilometers.value = 4523.7;
      }
    } catch (e) {
      debugPrint("AdminDashboardStore Stats Fetch Error: $e");
    } finally {
      isLoading.value = false;
    }
  }
}

// Global shortcut for easy access throughout the app.
final useAdminDashboardStore = AdminDashboardStore();
