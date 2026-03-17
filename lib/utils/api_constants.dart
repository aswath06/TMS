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

  // Requests (Added these for your RequestStore)
  static const String getAllRequests = "$baseUrl/request/get-all";
  static const String createRequest = "$baseUrl/request/create";
  static const String createTransportRequest =
      "$baseUrl/request/create-transport-request";
  static const String updateStatus = "$baseUrl/request/update-status";
  static const String getRequestById = "$baseUrl/request/get-by-id/";
  static const String startRoute = "$baseUrl/request/start-route";
  static const String completeRouteOtp = "$baseUrl/request/complete-route-otp";

  // Leaves
  static const String getAllLeaves = "$baseUrl/api/leaves/get-all";
  static const String createLeave = "$baseUrl/api/leaves/create";
  static const String getTodayDriverCount = "$baseUrl/api/leaves/today-driver-count";

  // OCR
  static const String licenseCheck = "$baseUrl/api/drivers/license-check";
  static const String getDriverMissions = "$baseUrl/api/drivers/drive-routes";
  static const String driverDashboard = "$baseUrl/api/drivers/driver-dashboard/";

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
