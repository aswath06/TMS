import 'package:flutter/material.dart';

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
      // TODO: Replace with actual API request logic.
      // Placeholder data:
      driversPresent.value = 12;
      driversAbsent.value = 3;
      totalKilometers.value = 4523.7;
      movingBuses.value = 7;
      servicesCount.value = 15;
    } finally {
      isLoading.value = false;
    }
  }
}

// Global shortcut for easy access throughout the app.
final useAdminDashboardStore = AdminDashboardStore();
