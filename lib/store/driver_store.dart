import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/utils/crypto_utils.dart';

final useDriverStore = DriverStore();

class DriverStore extends ChangeNotifier {
  // Singleton
  static final DriverStore _instance = DriverStore._internal();
  factory DriverStore() => _instance;
  DriverStore._internal();

  // Observable state for original profile endpoint
  final ValueNotifier<Map<String, dynamic>?> profileData = ValueNotifier(null);
  final ValueNotifier<Map<String, dynamic>?> ongoingTask = ValueNotifier(null);
  final ValueNotifier<List<dynamic>> upcomingRoutes = ValueNotifier([]);

  // List state
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> get drivers => _drivers;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isFetchingNextPage = false;
  bool get isFetchingNextPage => _isFetchingNextPage;

  // Mission State
  List<Map<String, dynamic>> _missions = [];
  List<Map<String, dynamic>> get missions => _missions;
  bool _isLoadingMissions = false;
  bool get isLoadingMissions => _isLoadingMissions;

  String _searchQuery = "";
  String get searchQuery => _searchQuery;


  // Leave State
  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> get leaves => _leaves;
  bool _isLoadingLeaves = false;
  bool get isLoadingLeaves => _isLoadingLeaves;

  // Maintenance Data
  List<Map<String, dynamic>> _fuelBunks = [];
  List<Map<String, dynamic>> get fuelBunks => _fuelBunks;

  List<Map<String, dynamic>> _serviceShops = [];
  List<Map<String, dynamic>> get serviceShops => _serviceShops;

  bool _isLoadingMaintenance = false;
  bool get isLoadingMaintenance => _isLoadingMaintenance;

  static const Map<int, String> LEAVE_TYPE = {
    1: "Sick",
    2: "Casual",
    3: "Emergency",
    4: "Other",
  };

  String? _profileError;
  String? get profileError => _profileError;

  String? _missionsError;
  String? get missionsError => _missionsError;

  String? _leavesError;
  String? get leavesError => _leavesError;

  String? _driversError;
  String? get driversError => _driversError;

  @Deprecated('Use domain-specific error getters')
  String? get errorMessage =>
      _profileError ?? _missionsError ?? _leavesError ?? _driversError;

  int _currentPage = 1;
  bool _hasMore = true;

  Future<void> fetchDrivers({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _currentPage = 1;
      _hasMore = true;
      _drivers.clear();
      _isLoading = true;
      _driversError = null;
      notifyListeners();
    } else {
      if (!_hasMore || _isFetchingNextPage || _isLoading) return;
      _isFetchingNextPage = true;
      notifyListeners();
    }

    try {
      final token = await UserStore.getToken();
      if (token == null) {
        _driversError = "Session expired. Please login again.";
        return;
      }

      final url =
          "${ApiConstants.baseUrl}/api/drivers/all-drivers?page=$_currentPage&limit=10";
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> data = decoded['data'] ?? [];

        if (data.length < 10) {
          _hasMore = false;
        } else {
          _currentPage++;
        }

        final List<Map<String, dynamic>> newDrivers = data
            .map((item) => item as Map<String, dynamic>)
            .toList();

        _drivers.addAll(newDrivers);
      } else {
        _driversError = "Failed to load drivers.";
      }
    } catch (e) {
      _driversError = "Network error: $e";
    } finally {
      _isLoading = false;
      _isFetchingNextPage = false;
      notifyListeners();
    }
  }

  Future<void> fetchNextPage() async {
    await fetchDrivers();
  }

  Future<Map<String, dynamic>?> checkLicense({
    required String driverName,
    required String frontPath,
    required String backPath,
  }) async {
    try {
      final token = await UserStore.getToken();
      final url = Uri.parse(ApiConstants.licenseCheck);
      final request = http.MultipartRequest('POST', url);

      request.headers.addAll(ApiConstants.getHeaders(token));
      request.fields['driver_name'] = driverName;

      request.files.add(
        await http.MultipartFile.fromPath('license_front', frontPath),
      );
      request.files.add(
        await http.MultipartFile.fromPath('license_back', backPath),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint("License check failed: ${response.statusCode}");
        debugPrint("Body: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("License check error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>> addDriver(Map<String, dynamic> driverData) async {
    try {
      final token = await UserStore.getToken();
      if (token == null) {
        return {"success": false, "message": "Session expired"};
      }

      final url = "${ApiConstants.baseUrl}/auth/register";
      debugPrint("--- [DEBUG] REGISTER DRIVER ---");
      debugPrint("URL: $url");
      debugPrint("Payload: ${json.encode(driverData)}");

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(driverData),
      );

      debugPrint("Response Code: ${response.statusCode}");
      debugPrint("Response Body: ${response.body}");

      Map<String, dynamic> decoded = {};
      if (response.body.isNotEmpty) {
        try {
          decoded = json.decode(response.body);
        } catch (e) {
          debugPrint("Failed to decode response: $e");
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchDrivers(forceRefresh: true);
        return {
          "success": true,
          "message": decoded['message'] ?? "Driver Registered Successfully!"
        };
      }

      // Handle common status codes with specific messages
      String errorMsg = decoded['message'] ?? "Failed to Register Driver.";
      if (response.statusCode == 502) {
        errorMsg = "Server is currently unavailable (502 Bad Gateway).";
      } else if (response.statusCode == 500) {
        errorMsg = "Internal Server Error (500). Please contact support.";
      } else if (response.statusCode == 404) {
        errorMsg = "Registration endpoint not found (404).";
      }

      return {
        "success": false,
        "message": errorMsg,
        "statusCode": response.statusCode
      };
    } catch (e) {
      debugPrint("Network error in addDriver: $e");
      return {"success": false, "message": "Network error: Connection failed."};
    }
  }

  // Sort state
  String _sortType = 'A to Z';
  String get sortType => _sortType;

  void setSortType(String newSort) {
    _sortType = newSort;
    notifyListeners();
  }

  // --- Original logic below ---

  Future<void> fetchProfile() async {
    _isLoading = true;
    _profileError = null;
    notifyListeners();

    try {
      final token = await UserStore.getToken();
      if (token == null) {
        _profileError = "Session expired.";
        return;
      }

      // Fetch Full User Profile (Includes roles, driverProfile, etc.)
      final response = await http.get(
        Uri.parse(ApiConstants.userMe),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final data = decoded['data'];
          profileData.value = data;

          // Repair missing IDs in UserStore if found
          if (data['id'] != null) {
            await UserStore.saveUserId(data['id']);
          }
          if (data['driverProfile'] != null && data['driverProfile']['id'] != null) {
            await UserStore.saveDriverId(data['driverProfile']['id']);
          }

          // Optional: Fetch dashboard specifics if still needed for routes/tasks
          await _fetchDashboardExtra(token, data['id']);
          return;
        }
      }
      _profileError = "Failed to load profile data.";
    } catch (e) {
      _profileError = "Network connection failed: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchDashboardExtra(String token, dynamic userId) async {
    if (userId == null) return;
    try {
      final url = "${ApiConstants.driverDashboard}$userId";
      final dashResponse = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (dashResponse.statusCode == 200) {
        final decoded = json.decode(dashResponse.body);
        if (decoded['success'] == true) {
          // We keep the profileData from auth/user/me as it's more standard
          // but we grab the tasks/routes from here
          ongoingTask.value = decoded['ongoingTask'];
          upcomingRoutes.value = decoded['upcomingRoutes'] ?? [];
        }
      }
    } catch (e) {
      debugPrint("Extra dashboard fetch failed: $e");
    }
  }

  Future<void> fetchMissions() async {
    _isLoadingMissions = true;
    _missionsError = null;
    notifyListeners();

    try {
      final token = await UserStore.getToken();
      final driverId = await UserStore.getDriverId();
      
      if (token == null) {
        _missionsError = "Session expired.";
        return;
      }

      final url = "${ApiConstants.getDriverMissions}?driver_id=${driverId ?? 1}&page=1&limit=20&search=$_searchQuery";

      
      // Print CURL for debugging
      debugPrint("--- [DEBUG] FETCH MISSIONS CURL ---");
      debugPrint("curl --location '$url' \\");
      final headers = ApiConstants.getHeaders(token);
      headers.forEach((key, value) {
        debugPrint("--header '$key: $value' \\");
      });
      debugPrint("------------------------------------");

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      // Print Response for debugging
      debugPrint("--- [DEBUG] FETCH MISSIONS RESPONSE ---");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Body: ${response.body}");
      debugPrint("---------------------------------------");

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final List<dynamic> items = decoded['data'] ?? [];
          _missions = items.map((e) => e as Map<String, dynamic>).toList();
        } else {
          _missionsError = decoded['message'] ?? "Failed to fetch missions";
        }
      } else {
        _missionsError = "Server error: ${response.statusCode}";
      }
    } catch (e) {
      _missionsError = "Connection error: $e";
    } finally {
      _isLoadingMissions = false;
      notifyListeners();
    }
  }

  Future<void> fetchLeaves() async {
    _isLoadingLeaves = true;
    _leavesError = null;
    notifyListeners();

    try {
      final token = await UserStore.getToken();
      final userId = await UserStore.getUserId();
      
      if (token == null) {
        _leavesError = "Session expired.";
        return;
      }

      String url = "${ApiConstants.baseUrl}/api/leaves/get-all?page=1&limit=10";
      if (userId != null) {
        url += "&user_id=$userId";
      }

      debugPrint("--- Fetching Leave History ---");
      debugPrint("URL: $url");
      debugPrint("Headers: ${ApiConstants.getHeaders(token)}");

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      debugPrint("Response Status: ${response.statusCode}");
      debugPrint("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final List<dynamic> data = decoded['data'] ?? [];
          _leaves = data.map((e) => e as Map<String, dynamic>).toList();
        } else {
          _leavesError = decoded['message'] ?? "Failed to fetch leaves";
        }
      } else {
        _leavesError = "Server error: ${response.statusCode}";
      }
    } catch (e) {
      _leavesError = "Connection error: $e";
    } finally {
      _isLoadingLeaves = false;
      notifyListeners();
    }
  }

  void resetLeavesError() {
    _leavesError = null;
    notifyListeners();
  }

  void reset() {
    profileData.value = null;
    _isLoading = false;
    _profileError = null;
    _missionsError = null;
    _leavesError = null;
    _driversError = null;
    _drivers.clear();
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();
  }

  // --- Status Helpers ---
  int normalizeStatus(dynamic status) {
    if (status is int) return status;
    if (status is String) {
      final String upper = status.toUpperCase();
      if (ApiConstants.DRIVER_STATUS.containsKey(upper)) {
        return ApiConstants.DRIVER_STATUS[upper]!;
      }
    }
    return 1; // Default to Available
  }

  String getStatusLabel(dynamic status) {
    final int s = normalizeStatus(status);
    switch (s) {
      case 1:
        return 'Available';
      case 2:
        return 'Assigned';
      case 3:
        return 'On Trip';
      case 4:
        return 'On Leave';
      default:
        return 'Unknown';
    }
  }

  Color getStatusColor(dynamic status) {
    final int s = normalizeStatus(status);
    switch (s) {
      case 1:
        return const Color(0xFF10B981); // Emerald
      case 2:
        return const Color(0xFF6366F1); // Indigo
      case 3:
        return const Color(0xFFF59E0B); // Amber
      case 4:
        return const Color(0xFFEF4444); // Red
      default:
        return Colors.grey;
    }
  }

  IconData getStatusIcon(dynamic status) {
    final int s = normalizeStatus(status);
    switch (s) {
      case 1:
        return Icons.check_circle_outline_rounded;
      case 2:
        return Icons.directions_bus_rounded;
      case 3:
        return Icons.settings_input_component_rounded;
      case 4:
        return Icons.home_work_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Future<bool> createLeave({
    required String fromDate,
    required String toDate,
    required int leaveType,
    required String reason,
  }) async {
    _isLoadingLeaves = true;
    _leavesError = null;
    notifyListeners();

    try {
      final token = await UserStore.getToken();
      if (token == null) {
        _leavesError = "Session expired.";
        return false;
      }

      final payload = {
        "from_date": fromDate,
        "to_date": toDate,
        "leave_type": leaveType,
        "reason": reason,
      };

      debugPrint("API Request: ${ApiConstants.createLeave}");
      debugPrint("Payload: ${json.encode(payload)}");

      final response = await http.post(
        Uri.parse(ApiConstants.createLeave),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(payload),
      );

      debugPrint("API Response Status: ${response.statusCode}");
      debugPrint("API Response Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          fetchLeaves(); // Refresh list after creation
          return true;
        } else {
          _leavesError = decoded['message'] ?? "Failed to create leave";
          return false;
        }
      } else {
        try {
          final decoded = json.decode(response.body);
          _leavesError = decoded['message'] ?? "Server Error: ${response.statusCode}";
        } catch (_) {
          _leavesError = "Server Error: ${response.statusCode}";
        }
        return false;
      }
    } catch (e) {
      _leavesError = "Network error: $e";
      return false;
    } finally {
      _isLoadingLeaves = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> verifyRouteOtp({
    required int routeId,
    required String otp,
    required bool isStart,
  }) async {
    try {
      final token = await UserStore.getToken();
      final driverId = await UserStore.getDriverId();
      
      if (token == null || driverId == null) {
        return {"success": false, "message": "Session expired or Driver ID missing"};
      }

      // final encryptedOtp = CryptoUtils.encryptOTP(otp);
      final url = isStart ? ApiConstants.startTrip(routeId) : ApiConstants.endLeg(routeId);

      final body = {
        "mode": "OTP",
        "otp": otp,
      };

      debugPrint("--- [DEBUG] STARTING OTP VERIFICATION ---");
      debugPrint("URL: $url");
      debugPrint("Payload: ${jsonEncode(body)}");
      debugPrint("CURL: curl --location '$url' \\");
      final headers = ApiConstants.getHeaders(token);
      headers.forEach((key, value) {
        debugPrint("--header '$key: $value' \\");
      });
      debugPrint("--data '${jsonEncode(body)}'");
      debugPrint("------------------------------------------");

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode(body),
      );

      debugPrint("OTP Verification - Status Code: ${response.statusCode}");
      debugPrint("OTP Verification - Response: ${response.body}");

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "message": decoded['message'] ?? "Operation successful"};
      } else {
        return {"success": false, "message": decoded['message'] ?? "Verification failed"};
      }
    } catch (e) {
      return {"success": false, "message": "Network error: $e"};
    }
  }

  // Maintenance Submissions
  Future<Map<String, dynamic>> submitFuelEntry(Map<String, dynamic> data, String? proofPath) async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return {"success": false, "message": "Session expired"};

      final url = Uri.parse(ApiConstants.fuelEntry);
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(ApiConstants.getHeaders(token));

      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      if (proofPath != null) {
        request.files.add(await http.MultipartFile.fromPath('proof', proofPath));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      String? errorMessage;
      try {
        final decoded = json.decode(response.body);
        errorMessage = decoded['message'];
      } catch (_) {}

      return {
        "success": response.statusCode == 200 || response.statusCode == 201,
        "message": errorMessage ?? (response.statusCode == 200 ? "Success" : "Failed to log fuel entry")
      };
    } catch (e) {
      return {"success": false, "message": "Error: $e"};
    }
  }

  Future<Map<String, dynamic>> submitServiceEntry(Map<String, dynamic> data, String? proofPath) async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return {"success": false, "message": "Session expired"};

      final url = Uri.parse(ApiConstants.serviceEntry);
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(ApiConstants.getHeaders(token));

      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      if (proofPath != null) {
        request.files.add(await http.MultipartFile.fromPath('proof', proofPath));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      String? errorMessage;
      try {
        final decoded = json.decode(response.body);
        errorMessage = decoded['message'];
      } catch (_) {}

      return {
        "success": response.statusCode == 200 || response.statusCode == 201,
        "message": errorMessage ?? (response.statusCode == 200 ? "Success" : "Failed to log service entry")
      };
    } catch (e) {
      return {"success": false, "message": "Error: $e"};
    }
  }

  Future<void> fetchFuelBunks() async {
    _isLoadingMaintenance = true;
    notifyListeners();
    try {
      final token = await UserStore.getToken();
      final response = await http.get(Uri.parse(ApiConstants.getVehicleBunks), headers: ApiConstants.getHeaders(token));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        _fuelBunks = List<Map<String, dynamic>>.from(decoded['data'] ?? []);
      }
    } catch (e) {
      debugPrint("Fetch Bunks Error: $e");
    } finally {
      _isLoadingMaintenance = false;
      notifyListeners();
    }
  }

  Future<void> fetchServiceShops() async {
    _isLoadingMaintenance = true;
    notifyListeners();
    try {
      final token = await UserStore.getToken();
      final response = await http.get(Uri.parse(ApiConstants.getServiceShops), headers: ApiConstants.getHeaders(token));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        _serviceShops = List<Map<String, dynamic>>.from(decoded['data'] ?? []);
      }
    } catch (e) {
      debugPrint("Fetch Shops Error: $e");
    } finally {
      _isLoadingMaintenance = false;
      notifyListeners();
    }
  }

  void updateSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }
}


