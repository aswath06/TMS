import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';

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
  final ValueNotifier<int> driversOnLeave = ValueNotifier<int>(0);
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

      // Fetch driver counts independently
      await fetchTodayDriverCount();

      // Fetch other stats
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
        totalKilometers.value = 4523.7;
      } else {
        debugPrint(
          "AdminDashboardStore FetchStats failed: ${response.statusCode}",
        );
      }
    } catch (e) {
      debugPrint("AdminDashboardStore Stats Fetch Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchTodayDriverCount() async {
    try {
      final String? token = await UserStore.getToken();
      final String dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Sending GET with body via http.Request
      final request = http.Request(
        'GET',
        Uri.parse(ApiConstants.getTodayDriverCount),
      );
      request.headers.addAll(ApiConstants.getHeaders(token));
      request.body = json.encode({"date": dateStr});

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        debugPrint("TodayDriverCount Response: ${response.body}");
        if (data['success'] == true) {
          driversPresent.value = data['present_drivers'] ?? 0;
          driversOnLeave.value = data['drivers_on_leave'] ?? 0;
        } else {
          debugPrint("TodayDriverCount failed in body: ${data['message']}");
        }
      } else {
        debugPrint("TodayDriverCount API error: ${response.statusCode}");
        debugPrint("Body: ${response.body}");
      }
    } catch (e) {
      debugPrint("AdminDashboardStore Today Driver Count Error: $e");
    }
  }
}

// Global shortcut for easy access throughout the app.
final useAdminDashboardStore = AdminDashboardStore();
