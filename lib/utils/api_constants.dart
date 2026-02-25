class ApiConstants {
  static const String baseUrl = "https://18x50gz9-8055.inc1.devtunnels.ms";

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
}
