class ApiConstants {
  static const String baseUrl = "https://18x50gz9-8055.inc1.devtunnels.ms";
  static const String googleLogin = "$baseUrl/auth/google-login";
  static const String login = "$baseUrl/auth/login-by-username";
  static const String forgotPassword = "$baseUrl/auth/forgot-password";
  static const String userMe = "$baseUrl/auth/user/me";
  static const String getAllVehicles = "$baseUrl/api/vehicles/get-all?";
  // Updated to match the curl path provided
  static const String createVehicle = "$baseUrl/api/vehicles/create";
}
