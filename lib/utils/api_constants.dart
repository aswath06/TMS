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
  static const String getAllRequests = "$baseUrl/api/routes/get-all";
  static const String createRequest = "$baseUrl/request/create";
  static const String createTransportRequest =
      "$baseUrl/request/create-transport-request";
  static const String updateStatus = "$baseUrl/request/update-status";
  static const String getRequestById = "$baseUrl/request/get-by-id/";
  static const String getRouteById = "$baseUrl/api/routes/get-by-id/";
  static const String createAllowance = "$baseUrl/api/routes/create-allowance";
  static const String startRoute = "$baseUrl/request/start-route";
  static const String completeRouteOtp = "$baseUrl/request/complete-route-otp";
  static const String generateStartOtp = "$baseUrl/request/generate-start-otp";
  static const String generateEndOtp = "$baseUrl/request/generate-end-otp";
  static const String adminCreateFull = "$baseUrl/api/routes/admin-create-full";
  static const String facultyCreate = "$baseUrl/api/routes/faculty-create";
  static const String getAvailableVehicles = "$baseUrl/api/routes/route-requests/available-vehicles";
  static const String getAvailableDrivers = "$baseUrl/api/routes/route-requests/available-drivers";
  static String adminFinalize(dynamic id) => "$baseUrl/api/routes/route-requests/$id/admin-finalize";
  static String markAllowanceReceived(dynamic id) => "$baseUrl/api/routes/mark-received/$id/receive";
  static String startTrip(dynamic tripId) => "$baseUrl/api/routes/trips/$tripId/start";
  static String endLeg(dynamic legId) => "$baseUrl/api/routes/trips/legs/$legId/end";
  
  // Trip actions
  static String getStartOtp(dynamic tripId) => "$baseUrl/api/routes/trips/$tripId/start-otp";
  static String getEndOtp(dynamic tripId) => "$baseUrl/api/routes/trips/$tripId/end-otp";
  static String updateStopStatus(dynamic tripId, dynamic stopId) => "$baseUrl/api/routes/trips/$tripId/stops/$stopId/update-status";
  static const String updateAssignedVehicles = "$baseUrl/request/update-assigned-vehicles";

  // Leaves
  static const String getAllLeaves = "$baseUrl/api/leaves/get-all";
  static const String createLeave = "$baseUrl/api/leaves/create";
  static const String updateLeaveStatus = "$baseUrl/api/leaves/status/";
  static const String getTodayDriverCount = "$baseUrl/api/leaves/today-driver-count";

  // OCR
  static const String licenseCheck = "$baseUrl/api/drivers/license-check";
  static const String getDriverMissions = "$baseUrl/api/drivers/drive-routes";
  static const String driverDashboard = "$baseUrl/api/drivers/driver-dashboard/";
  static const String driverVehicles = "$baseUrl/api/drivers/drive-vehicles";
  static const String verifyFuelBill = "$baseUrl/api/vehicles/verify-fuel-bill";
   // Maintenance
   static const String fuelEntry = "$baseUrl/api/maintenance/fuel-entry";
   static const String serviceEntry = "$baseUrl/api/maintenance/service-entry";
   static const String getVehicleBunks = "$baseUrl/api/maintenance/get-bunks";
  static const String getServiceShops = "$baseUrl/api/maintenance/get-shops";

  // Centralized headers for DevTunnels and common requirements
  static Map<String, String> getHeaders(String? token) {
    return {
      'Authorization': token != null ? 'TMS $token' : '',
      'Content-Type': 'application/json',
      'User-Agent': 'insomnia/12.3.0',
      bypassHeaderKey: bypassHeaderValue,
    };
  }

  static const Map<String, int> DRIVER_STATUS = {
    'AVAILABLE': 1,
    'ASSIGNED': 2,
    'ON_TRIP': 3,
    'ON_LEAVE': 4,
  };
}
