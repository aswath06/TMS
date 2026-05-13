class ApiConstants {
  static const String baseUrl = "https://18x50gz9-8055.inc1.devtunnels.ms";

  // DevTunnels bypass header
  static const String bypassHeaderKey = "X-Tunnel-Skip-Anti-Phishing-Page";
  static const String bypassHeaderValue = "true";

  // Auth
  static const String googleLogin = "$baseUrl/auth/google-login";
  static const String login = "$baseUrl/auth/login-by-username";
  static const String forgotPassword = "$baseUrl/auth/forgot-password";
  static const String userMe = "$baseUrl/auth/user/me";
  static const String logoutMe = "$baseUrl/auth/logout-me";

  // Vehicles
  static const String getAllVehicles = "$baseUrl/api/vehicles/get-all";
  static const String createVehicle = "$baseUrl/api/vehicles/create";
  static const String vehicleDashboard =
      "$baseUrl/api/vehicles/vehicle-dashboard/";
  static const String getVehicleById = "$baseUrl/api/vehicles/vehicles-by-id/";
  static const String serviceTypes = "$baseUrl/api/vehicles/service-types";
  static const String serviceShops = "$baseUrl/api/vehicles/shops";
  static const String vehicleMaintenance =
      "$baseUrl/api/vehicles/vehicle-maintenance";
  static const String fuelBunks = "$baseUrl/api/vehicles/fuel-bunk";
  static const String fuelLog = "$baseUrl/api/vehicles/fuel-log";

  // Requests (Added these for your RequestStore)
  static const String getAllRequests = "$baseUrl/request/get-all";
  static const String createRequest = "$baseUrl/request/create";
  static const String createTransportRequest =
      "$baseUrl/request/create-transport-request";
  static const String updateStatus = "$baseUrl/request/update-status";
  static const String getRequestById = "$baseUrl/request/get-by-id/";
  static const String getRouteById = "$baseUrl/request/get-by-id/";
  static const String createAllowance = "$baseUrl/request/create-allowance";
  static const String startRoute = "$baseUrl/request/start-route";
  static const String completeRouteOtp = "$baseUrl/request/complete-route-otp";
  static const String generateStartOtp = "$baseUrl/request/generate-start-otp";
  static const String generateEndOtp = "$baseUrl/request/generate-end-otp";
  static const String adminCreateFull = "$baseUrl/request/admin-create-full";
  static const String facultyCreate = "$baseUrl/request/faculty-create";
  static String deleteRoute(dynamic id) => "$baseUrl/request/delete/$id";
  static const String getAvailableVehicles =
      "$baseUrl/request/route-requests/available-vehicles";
  static const String getAvailableDrivers =
      "$baseUrl/request/route-requests/available-drivers";
  static String adminFinalize(dynamic id) =>
      "$baseUrl/request/route-requests/$id/admin-finalize";
  static String markAllowanceReceived(dynamic id) =>
      "$baseUrl/request/mark-received/$id/receive";
  static String startTrip(dynamic tripId) =>
      "$baseUrl/request/trips/$tripId/start";
  static String startRegister(dynamic tripId) =>
      "$baseUrl/request/trips/$tripId/start-register";
  static String endRegister(dynamic tripId) =>
      "$baseUrl/request/trips/$tripId/end-register";
  static String endLeg(dynamic tripId) => "$baseUrl/request/trips/$tripId/end";
  static String endTripLeg(dynamic legId) =>
      "$baseUrl/request/trips/$legId/end";

  // Trip actions
  static String getStartOtp(dynamic tripId) =>
      "$baseUrl/request/trips/$tripId/start-otp";
  static String getEndOtp(dynamic tripId) =>
      "$baseUrl/request/trips/$tripId/end-otp";
  static String tripAction(dynamic tripId) =>
      "$baseUrl/request/trips/$tripId/action";
  static String updateStopStatus(dynamic tripId, dynamic stopId) =>
      "$baseUrl/request/trips/$tripId/stops/$stopId/update-status";
  static String locationPing(dynamic tripId) =>
      "$baseUrl/request/trips/$tripId/location-ping";
  static const String updateAssignedVehicles =
      "$baseUrl/request/update-assigned-vehicles";

  // Leaves
  static const String getAllLeaves = "$baseUrl/api/leaves/get-all";
  static const String getLeaveTypes = "$baseUrl/api/leaves/leave-types";
  static const String createLeave = "$baseUrl/api/leaves/create";
  static const String updateLeaveStatus = "$baseUrl/api/leaves/status/";
  static const String getTodayDriverCount =
      "$baseUrl/api/leaves/today-driver-count";

  // OCR
  static const String licenseCheck = "$baseUrl/api/drivers/license-check";
  static const String getDriverMissions = "$baseUrl/api/drivers/drive-routes";
  static const String driverDashboard =
      "$baseUrl/api/drivers/driver-dashboard/";
  static const String driverVehicles = "$baseUrl/api/drivers/drive-vehicles";
  static String rewardPoints(dynamic userId) => "$baseUrl/api/drivers/reward-points?user_id=$userId";
  static const String verifyFuelBill = "$baseUrl/api/vehicles/verify-fuel-bill";
  // Maintenance
  static const String fuelEntry = "$baseUrl/api/maintenance/fuel-entry";
  static const String serviceEntry = "$baseUrl/api/maintenance/service-entry";
  static const String accidentEntry = "$baseUrl/api/vehicles/incidents/create";
  static const String getVehicleBunks = "$baseUrl/api/maintenance/get-bunks";
  static const String getServiceShops = "$baseUrl/api/maintenance/get-shops";

  // Notifications
  static const String myNotifications = "$baseUrl/api/notifications/my";
  static const String unreadCount = "$baseUrl/api/notifications/unread-count";
  static String markNotificationRead(dynamic id) => "$baseUrl/api/notifications/$id/read";
  static const String markAllRead = "$baseUrl/api/notifications/read-all";

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
