import 'package:tripzo/store/server_config.dart';

class ApiConstants {
  // Dynamic base URL driven by ServerConfig (super admin togglable at runtime)
  static String get baseUrl => ServerConfig().baseUrl;

  // DevTunnels bypass header
  static const String bypassHeaderKey = "X-Tunnel-Skip-Anti-Phishing-Page";
  static const String bypassHeaderValue = "true";

  // Auth
  static String get googleLogin => "$baseUrl/auth/google-login";
  static String get login => "$baseUrl/auth/login-by-username";
  static String get forgotPassword => "$baseUrl/auth/forgot-password";
  static String get userMe => "$baseUrl/auth/user/me";
  static String get logoutMe => "$baseUrl/auth/logout-me";

  // Vehicles
  static String get getAllVehicles => "$baseUrl/api/vehicles/get-all";
  static String get getAllVehiclesWithoutPagination => "$baseUrl/api/vehicles/get-all-without-pagination";
  static String get createVehicle => "$baseUrl/api/vehicles/create";
  static String get vehicleDashboard => "$baseUrl/api/vehicles/vehicle-dashboard/";
  static String get getVehicleById => "$baseUrl/api/vehicles/vehicles-by-id/";
  static String vehicleExpirations(int page, int limit, String type, String search) => "$baseUrl/api/vehicles/expirations?page=$page&limit=$limit&type=$type&search=$search";
  static String get serviceTypes => "$baseUrl/api/vehicles/service-types";
  static String get serviceShops => "$baseUrl/api/vehicles/shops";
  static String get vehicleMaintenance => "$baseUrl/api/vehicles/vehicle-maintenance";
  static String get fuelBunks => "$baseUrl/api/vehicles/fuel-bunk";
  static String get fuelLog => "$baseUrl/api/vehicles/fuel-log";
  static String get driverComplete => "$baseUrl/api/vehicles/driver-complete";
  static String deleteFuelLog(dynamic id) => "$baseUrl/api/vehicles/fuel-log/$id";
  static String updateBunkPrice(dynamic id) => "$baseUrl/api/vehicles/fuel-bunk/$id/price";

  // Requests
  static String get getAllRequests => "$baseUrl/request/get-all";
  static String get createRequest => "$baseUrl/request/create";
  static String get createTransportRequest => "$baseUrl/request/create-transport-request";
  static String get updateStatus => "$baseUrl/request/update-status";
  static String get getRequestById => "$baseUrl/request/getth-by-id/";
  static String get getRouteById => "$baseUrl/request/get-by-id/";
  static String get getDriverAllowances => "$baseUrl/request/allowances-all";
  static String allowanceSeen(dynamic id) => "$baseUrl/request/allowances/$id/seen";
  static String allowanceRecheck(dynamic id) => "$baseUrl/request/allowances/$id/recheck";
  static String getAllowanceReport(String start, String end, String format) => "$baseUrl/request/allowances-report?start_date=$start&end_date=$end&format=$format";
  static String get createAllowance => "$baseUrl/request/create-allowance";
  static String get startRoute => "$baseUrl/request/start-route";
  static String get completeRouteOtp => "$baseUrl/request/complete-route-otp";
  static String get generateStartOtp => "$baseUrl/request/generate-start-otp";
  static String get generateEndOtp => "$baseUrl/request/generate-end-otp";
  static String get adminCreateFull => "$baseUrl/request/admin-create-full";
  static String get facultyCreate => "$baseUrl/request/faculty-create";
  static String deleteRoute(dynamic id) => "$baseUrl/request/delete/$id";
  static String get getAvailableVehicles => "$baseUrl/request/route-requests/available-vehicles";
  static String get getAvailableDrivers => "$baseUrl/request/route-requests/available-drivers";
  static String adminFinalize(dynamic id) => "$baseUrl/request/route-requests/$id/admin-finalize";
  static String markAllowanceReceived(dynamic id) => "$baseUrl/request/mark-received/$id/receive";
  static String startTrip(dynamic tripId) => "$baseUrl/request/trips/$tripId/start";
  static String startRegister(dynamic tripId) => "$baseUrl/request/trips/$tripId/start-register";
  static String endRegister(dynamic tripId) => "$baseUrl/request/trips/$tripId/end-register";
  static String endLeg(dynamic tripId) => "$baseUrl/request/trips/$tripId/end";
  static String endTripLeg(dynamic legId) => "$baseUrl/request/trips/$legId/end";
  static String getSecurityRoutes(int page, int limit, String type) => "$baseUrl/request/security/get-routes?page=$page&limit=$limit&type=$type";

  // Trip actions
  static String getStartOtp(dynamic tripId) => "$baseUrl/request/trips/$tripId/start-otp";
  static String getEndOtp(dynamic tripId) => "$baseUrl/request/trips/$tripId/end-otp";
  static String tripAction(dynamic tripId) => "$baseUrl/request/trips/$tripId/action";
  static String updateStopStatus(dynamic tripId, dynamic stopId) => "$baseUrl/request/trips/$tripId/stops/$stopId/update-status";
  static String locationPing(dynamic tripId) => "$baseUrl/request/trips/$tripId/location-ping";
  static String get updateAssignedVehicles => "$baseUrl/request/update-assigned-vehicles";

  // Leaves
  static String get getAllLeaves => "$baseUrl/api/leaves/get-all";
  static String get getLeaveTypes => "$baseUrl/api/leaves/leave-types";
  static String get createLeave => "$baseUrl/api/leaves/create";
  static String get updateLeaveStatus => "$baseUrl/api/leaves/status/";
  static String get getTodayDriverCount => "$baseUrl/api/leaves/today-driver-count";

  // OCR / Drivers
  static String get licenseCheck => "$baseUrl/api/drivers/license-check";
  static String get getAllDriversWithoutPagination => "$baseUrl/api/drivers/get-all-without-pagination";
  static String get getDriverMissions => "$baseUrl/api/drivers/drive-routes";
  static String get driverDashboard => "$baseUrl/api/drivers/driver-dashboard/";
  static String get driverVehicles => "$baseUrl/api/drivers/drive-vehicles";
  static String rewardPoints(dynamic userId) => "$baseUrl/api/drivers/reward-points?user_id=$userId";
  static String get verifyFuelBill => "$baseUrl/api/vehicles/verify-fuel-bill";
  static String get pendingFuelEntries => "$baseUrl/api/vehicles/fuel-log/pending-driver";
  static String get pendingAdminApprovalFuelLogs => "$baseUrl/api/vehicles/fuel-log?fuel_entry_status=PENDING_DRIVER_FILL&page=1&limit=50&sortBy=filled_at&sortOrder=DESC&status=PENDING_ADMIN_APPROVAL";
  static String approveFuelLog(dynamic id) => "$baseUrl/api/vehicles/fuel-log/$id/approve";
  static String get pendingRoutesToComplete => "$baseUrl/request/driver/pending-routes-to-complete";
  static String getFuelReport(String start, String end, String format) => "$baseUrl/api/vehicles/fuel-reports/date-wise?start_date=$start&end_date=$end&format=$format";

  // Maintenance
  static String get fuelEntry => "$baseUrl/api/maintenance/fuel-entry";
  static String get serviceEntry => "$baseUrl/api/maintenance/service-entry";
  static String get accidentEntry => "$baseUrl/api/vehicles/incidents/create";
  static String get getVehicleBunks => "$baseUrl/api/maintenance/get-bunks";
  static String get getServiceShops => "$baseUrl/api/maintenance/get-shops";

  static String get myNotifications => "$baseUrl/api/notifications/my";
  static String get unreadCount => "$baseUrl/api/notifications/unread-count";
  static String markNotificationRead(dynamic id) => "$baseUrl/api/notifications/$id/read";
  static String get markAllRead => "$baseUrl/api/notifications/read-all";

  // Support
  static String get createSupport => "$baseUrl/api/support/create";
  static String get getAllSupport => "$baseUrl/api/support/get-all";
  static String completeSupport(dynamic id) => "$baseUrl/api/support/complete/$id";

  // Centralized headers for DevTunnels and common requirements
  static Map<String, String> getHeaders(String? token) {
    return {
      'Authorization': token != null ? 'TMS $token' : '',
      'Content-Type': 'application/json',
      'User-Agent': 'insomnia/12.3.0',
      bypassHeaderKey: bypassHeaderValue
    };
  }

  static const Map<String, int> DRIVER_STATUS = {
    'AVAILABLE': 1,
    'ASSIGNED': 2,
    'ON_TRIP': 3,
    'ON_LEAVE': 4,
  };

  static const Map<String, dynamic> bitLocation = {
    'display_name': 'Bannari Amman Institute of Technology',
    'lat': 11.49518076229493,
    'lon': 77.27954948427481,
  };
}
