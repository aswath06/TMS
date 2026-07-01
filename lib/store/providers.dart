import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/security_vehicle_store.dart';
// Import all existing stores
import 'package:tripzo/store/VehicleStore.dart';
import 'package:tripzo/store/request_store.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/dashboard_store.dart';
import 'package:tripzo/store/isdark.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/store/admin_allowance_store.dart';
import 'package:tripzo/store/fleet_monitor_store.dart';
import 'package:tripzo/providers/notification_provider.dart';
import 'package:tripzo/services/notification_api_service.dart';
import 'package:tripzo/services/notification_firebase_service.dart';
import 'package:tripzo/store/expiration_store.dart';
import 'package:tripzo/store/daily_routines_store.dart';

/// ExpirationStore Provider
final expirationStoreProvider = ChangeNotifierProvider<ExpirationStore>((ref) {
  return ExpirationStore();
});

/// VehicleStore Provider
final vehicleStoreProvider = ChangeNotifierProvider<VehicleStore>((ref) {
  return VehicleStore();
});

/// RequestStore Provider (uses global instance to keep state)
final requestStoreProvider = ChangeNotifierProvider<RequestStore>((ref) {
  return useRequestStore;
});

/// DriverStore Provider
final driverStoreProvider = ChangeNotifierProvider<DriverStore>((ref) {
  return useDriverStore;
});

/// DashboardStore Provider
final dashboardStoreProvider = ChangeNotifierProvider<DashboardStore>((ref) {
  return dashboardStore;
});

/// ThemeStore Provider
final themeStoreProvider = ChangeNotifierProvider<ThemeStore>((ref) {
  return themeStore;
});

/// LanguageStore Provider
final languageStoreProvider = ChangeNotifierProvider<LanguageStore>((ref) {
  return languageStore;
});

/// AdminAllowanceStore Provider
final adminAllowanceStoreProvider = ChangeNotifierProvider<AdminAllowanceStore>((ref) {
  return adminAllowanceStore;
});

/// FleetMonitorStore Provider
final fleetMonitorStoreProvider = ChangeNotifierProvider<FleetMonitorStore>((ref) {
  return fleetMonitorStore;
});

/// NotificationProvider
final notificationProviderFamily = ChangeNotifierProvider<NotificationProvider>((ref) {
  return NotificationProvider(
    apiService: NotificationApiService(baseUrl: "", token: ""),
    firebaseService: NotificationFirebaseService(),
  );
});
/// SecurityVehicleStore Provider
final securityVehicleStoreProvider = ChangeNotifierProvider<SecurityVehicleStore>((ref) {
  return SecurityVehicleStore();
});

/// DailyRoutinesStore Provider
final dailyRoutinesStoreProvider = ChangeNotifierProvider<DailyRoutinesStore>((ref) {
  return DailyRoutinesStore();
});
