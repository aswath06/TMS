import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/utils/crypto_utils.dart';
import 'package:tripzo/services/location_service.dart';

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

  // Leave Types State
  List<Map<String, dynamic>> _leaveTypes = [];
  List<Map<String, dynamic>> get leaveTypes => _leaveTypes;
  bool _isLoadingLeaveTypes = false;
  bool get isLoadingLeaveTypes => _isLoadingLeaveTypes;

  // Maintenance Data
  List<Map<String, dynamic>> _fuelBunks = [];
  List<Map<String, dynamic>> get fuelBunks => _fuelBunks;

  List<Map<String, dynamic>> _serviceShops = [];
  List<Map<String, dynamic>> get serviceShops => _serviceShops;

  bool _isLoadingMaintenance = false;
  bool get isLoadingMaintenance => _isLoadingMaintenance;

  // Reward Points State
  int _totalPoints = 0;
  int get totalPoints => _totalPoints;
  List<Map<String, dynamic>> _rewardHistory = [];
  List<Map<String, dynamic>> get rewardHistory => _rewardHistory;
  bool _isLoadingRewards = false;
  bool get isLoadingRewards => _isLoadingRewards;
  String? _rewardError;
  String? get rewardError => _rewardError;

  // Pending Fuel Entries
  List<Map<String, dynamic>> _pendingFuelEntries = [];
  List<Map<String, dynamic>> get pendingFuelEntries => _pendingFuelEntries;
  bool _isLoadingPendingFuel = false;
  bool get isLoadingPendingFuel => _isLoadingPendingFuel;

  // Active Routes To Complete
  List<Map<String, dynamic>> _activeRoutesToComplete = [];
  List<Map<String, dynamic>> get activeRoutesToComplete => _activeRoutesToComplete;
  bool _isLoadingActiveRoutes = false;
  bool get isLoadingActiveRoutes => _isLoadingActiveRoutes;

  // Pending Allowances
  int _pendingAllowanceCount = 0;
  int get pendingAllowanceCount => _pendingAllowanceCount;

  Future<void> fetchPendingAllowanceCount() async {
    try {
      final token = await UserStore.getToken();
      final driverId = await UserStore.getDriverId();
      if (token == null || driverId == null) return;
      
      final url = "${ApiConstants.getDriverAllowances}?page=1&limit=1&driver_id=$driverId&payment_status=Assigned";
      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));
      
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          _pendingAllowanceCount = decoded['pagination']?['totalItems'] ?? 0;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error fetching allowance count: $e");
    }
  }

  // Allowances List State
  List<Map<String, dynamic>> _allowances = [];
  List<Map<String, dynamic>> get allowances => _allowances;
  
  bool _isLoadingAllowances = false;
  bool get isLoadingAllowances => _isLoadingAllowances;
  
  bool _isFetchingMoreAllowances = false;
  bool get isFetchingMoreAllowances => _isFetchingMoreAllowances;
  
  int _allowancePage = 1;
  bool _hasMoreAllowances = true;
  bool get hasMoreAllowances => _hasMoreAllowances;

  Future<void> fetchAllowances({bool isRefresh = false}) async {
    if (isRefresh) {
      _allowancePage = 1;
      _hasMoreAllowances = true;
    }
    
    if (_allowancePage == 1) {
      _isLoadingAllowances = true;
    } else {
      _isFetchingMoreAllowances = true;
    }
    notifyListeners();

    try {
      final token = await UserStore.getToken();
      final driverId = await UserStore.getDriverId();
      if (token == null || driverId == null) return;

      final url = "${ApiConstants.getDriverAllowances}?page=$_allowancePage&limit=10&driver_id=$driverId";
      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final List<dynamic> items = decoded['data'] ?? [];
          final newAllowances = items.map((e) => e as Map<String, dynamic>).toList();
          
          if (isRefresh || _allowancePage == 1) {
            _allowances = newAllowances;
          } else {
            _allowances.addAll(newAllowances);
          }
          
          final pagination = decoded['pagination'];
          if (pagination != null) {
            _hasMoreAllowances = _allowancePage < (pagination['totalPages'] ?? 1);
          } else {
             _hasMoreAllowances = false;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching allowances: $e");
    } finally {
      _isLoadingAllowances = false;
      _isFetchingMoreAllowances = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreAllowances() async {
    if (_isFetchingMoreAllowances || !_hasMoreAllowances) return;
    _allowancePage++;
    await fetchAllowances();
  }

  Future<Map<String, dynamic>> markAllowanceSeen(int allowanceId) async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return {"success": false, "message": "Session expired"};

      final uri = Uri.parse(ApiConstants.allowanceSeen(allowanceId));
      final headers = ApiConstants.getHeaders(token);
      
      debugPrint("--- [DEBUG] ALLOWANCE CONFIRM CURL ---");
      debugPrint("curl --location --request PATCH '$uri' \\");
      headers.forEach((key, value) {
        debugPrint("--header '$key: $value' \\");
      });
      debugPrint("--------------------------------------");

      final response = await http.patch(
        uri,
        headers: headers,
      );

      debugPrint("--- [DEBUG] ALLOWANCE CONFIRM RESPONSE ---");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Body: ${response.body}");
      debugPrint("------------------------------------------");

      try {
        final decoded = json.decode(response.body);
        if (response.statusCode == 200 || response.statusCode == 201) {
          await fetchAllowances();
          await fetchPendingAllowanceCount();
          return {"success": true, "message": decoded['message'] ?? "Allowance marked as seen"};
        } else {
          return {"success": false, "message": decoded['message'] ?? "Failed to mark as seen"};
        }
      } catch (e) {
        debugPrint("JSON Decode Error: $e");
        return {"success": false, "message": "Invalid response format: $e"};
      }
    } catch (e) {
      return {"success": false, "message": "Network error: $e"};
    }
  }

  Future<Map<String, dynamic>> requestAllowanceRecheck(int allowanceId, String reason) async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return {"success": false, "message": "Session expired"};

      final response = await http.patch(
        Uri.parse(ApiConstants.allowanceRecheck(allowanceId)),
        headers: ApiConstants.getHeaders(token),
        body: json.encode({"recheck_reason": reason}),
      );

      final decoded = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchAllowances();
        await fetchPendingAllowanceCount();
        return {"success": true, "message": decoded['message'] ?? "Recheck requested successfully"};
      } else {
        return {"success": false, "message": decoded['message'] ?? "Failed to request recheck"};
      }
    } catch (e) {
      return {"success": false, "message": "Network error: $e"};
    }
  }

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
  int _totalDrivers = 0;
  int get totalDrivers => _totalDrivers;

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

      String url =
          "${ApiConstants.baseUrl}/api/drivers/all-drivers?page=$_currentPage&limit=10";
      if (_driverSearchQuery.isNotEmpty) {
        url += "&search=${Uri.encodeComponent(_driverSearchQuery)}";
      }
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        _totalDrivers = decoded['total_records'] ?? 0;
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
      } else if (response.statusCode == 401) {
        await UserStore.forceLogout();
        _driversError = "Session expired. Please login again.";
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

  Future<Map<String, dynamic>> updateDriver(Map<String, dynamic> driverData) async {
    try {
      final token = await UserStore.getToken();
      if (token == null) {
        return {"success": false, "message": "Session expired"};
      }

      final url = "${ApiConstants.baseUrl}/auth/user";
      
      final response = await http.put(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(driverData),
      );

      Map<String, dynamic> decoded = {};
      if (response.body.isNotEmpty) {
        try {
          decoded = json.decode(response.body);
        } catch (e) {
          debugPrint("Failed to decode update response: $e");
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchDrivers(forceRefresh: true);
        return {
          "success": true,
          "message": decoded['message'] ?? "Driver Updated Successfully!"
        };
      }

      return {
        "success": false,
        "message": decoded['message'] ?? "Failed to update driver",
        "statusCode": response.statusCode
      };
    } catch (e) {
      return {"success": false, "message": "Network error: Connection failed."};
    }
  }

  // Sort state
  String _sortType = 'Default';
  String get sortType => _sortType;

  void setSortType(String newSort) {
    _sortType = newSort;
    notifyListeners();
  }

  String _driverSearchQuery = '';
  String get driverSearchQuery => _driverSearchQuery;

  void setDriverSearchQuery(String query) {
    _driverSearchQuery = query;
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
      } else if (response.statusCode == 401) {
        await UserStore.forceLogout();
        _profileError = "Session expired.";
        return;
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
          
          // Auto-start tracking if any mission is already STARTED
          int? startedTripId;
          bool hasStartedMission = _missions.any((m) {
            final status = m['route_status']?.toString().toUpperCase() ?? '';
            final isStarted = status == 'STARTED' || status == 'ONGOING';
            if (isStarted && m['trip_instances'] != null && (m['trip_instances'] as List).isNotEmpty) {
              startedTripId = m['trip_instances'][0]['id'];
            }
            return isStarted;
          });
          
          if (hasStartedMission && startedTripId != null) {
             final role = await UserStore.getRole();
             if (role == 'driver') {
               LocationService().startTracking(startedTripId!);
             }
          }
        } else {
          _missionsError = decoded['message'] ?? "Failed to fetch missions";
        }
      } else if (response.statusCode == 401) {
        await UserStore.forceLogout();
        _missionsError = "Session expired. Please login again.";
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
      } else if (response.statusCode == 401) {
        await UserStore.forceLogout();
        _leavesError = "Session expired. Please login again.";
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

  /// Fetches dynamic leave types from the backend
  Future<void> fetchLeaveTypes() async {
    if (_leaveTypes.isNotEmpty) return; // Already loaded
    _isLoadingLeaveTypes = true;
    notifyListeners();
    try {
      final token = await UserStore.getToken();
      if (token == null) return;
      final response = await http.get(
        Uri.parse(ApiConstants.getLeaveTypes),
        headers: ApiConstants.getHeaders(token),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> items = data['data'] ?? [];
          _leaveTypes = items.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
      debugPrint('[DriverStore] leaveTypes: $_leaveTypes');
    } catch (e) {
      debugPrint('[DriverStore] fetchLeaveTypes error: $e');
    } finally {
      _isLoadingLeaveTypes = false;
      notifyListeners();
    }
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

  Future<void> fetchRewardPoints() async {
    _isLoadingRewards = true;
    _rewardError = null;
    notifyListeners();

    try {
      final token = await UserStore.getToken();
      final userId = await UserStore.getUserId();

      if (token == null || userId == null) {
        _rewardError = "Session expired or User ID missing.";
        return;
      }

      final url = ApiConstants.rewardPoints(userId);
      
      debugPrint("--- [DEBUG] FETCH REWARD POINTS CURL ---");
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

      debugPrint("--- [DEBUG] FETCH REWARD POINTS RESPONSE ---");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Body: ${response.body}");
      debugPrint("---------------------------------------");

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final data = decoded['data'];
          _totalPoints = data['total_points'] ?? 0;
          final List<dynamic> history = data['history'] ?? [];
          _rewardHistory = history.map((e) => e as Map<String, dynamic>).toList();
        } else {
          _rewardError = decoded['message'] ?? "Failed to fetch reward points";
        }
      } else if (response.statusCode == 401) {
        await UserStore.forceLogout();
        _rewardError = "Session expired. Please login again.";
      } else {
        _rewardError = "Server error: ${response.statusCode}";
      }
    } catch (e) {
      _rewardError = "Connection error: $e";
    } finally {
      _isLoadingRewards = false;
      notifyListeners();
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
      debugPrint("Mode: OTP");
      debugPrint("Value: $otp");
      
      // Log decryption attempt if it looks encrypted (e.g. hex string longer than 6)
      if (otp.length > 6 || !RegExp(r'^\d+$').hasMatch(otp)) {
        try {
          final decrypted = CryptoUtils.decryptOTP(otp);
          debugPrint("Decrypted Value: $decrypted");
        } catch (_) {}
      }

      debugPrint("URL: $url");
      debugPrint("------------------------------------------");
      debugPrint("CURL COMMAND:");
      final headers = ApiConstants.getHeaders(token);
      String curl = "curl --location --request POST '$url' \\\n";
      headers.forEach((key, value) {
        curl += "--header '$key: $value' \\\n";
      });
      curl += "--data '${jsonEncode(body)}'";
      debugPrint(curl);
      debugPrint("------------------------------------------");

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode(body),
      );

      debugPrint("--- [DEBUG] OTP VERIFICATION RESPONSE ---");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Response Body: ${response.body}");
      debugPrint("------------------------------------------");

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        // 🚀 Start or Stop Tracking (Only for Drivers)
        final role = await UserStore.getRole();
        if (role == 'driver') {
          if (isStart) {
            LocationService().startTracking(routeId);
          } else {
            LocationService().stopTracking();
          }
        }
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

  Future<Map<String, dynamic>> submitAccidentEntry(Map<String, dynamic> data, String? proofPath) async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return {"success": false, "message": "Session expired"};

      final url = Uri.parse(ApiConstants.accidentEntry);
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(ApiConstants.getHeaders(token));

      data.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      if (proofPath != null) {
        request.files.add(await http.MultipartFile.fromPath('proof_file', proofPath));
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
        "message": errorMessage ?? (response.statusCode == 200 ? "Success" : "Failed to log accident entry")
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

  Future<void> fetchPendingFuelEntries() async {
    _isLoadingPendingFuel = true;
    notifyListeners();

    try {
      final token = await UserStore.getToken();
      if (token == null) return;

      final url = ApiConstants.pendingFuelEntries;
      
      debugPrint("--- [DEBUG] FETCH PENDING FUEL ENTRIES CURL ---");
      debugPrint("curl --location '$url' \\");
      final headers = ApiConstants.getHeaders(token);
      headers.forEach((key, value) {
        debugPrint("--header '$key: $value' \\");
      });
      debugPrint("----------------------------------------------");

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint("--- [DEBUG] FETCH PENDING FUEL ENTRIES RESPONSE ---");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Body: ${response.body}");
      debugPrint("--------------------------------------------------");

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final List<dynamic> items = decoded['data'] ?? [];
          _pendingFuelEntries = items.map((e) => e as Map<String, dynamic>).toList();
        }
      }
    } catch (e) {
      debugPrint("Error fetching pending fuel entries: $e");
    } finally {
      _isLoadingPendingFuel = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> completeFuelEntry({
    required int fuelLogId,
    required int vehicleId,
    required int driverId,
    required String currentOdometer,
    required String filledVolume,
    required String billAmount,
    required String filledAt,
    String? billFilePath,
  }) async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return {"success": false, "message": "Session expired"};

      final url = Uri.parse(ApiConstants.driverComplete);
      final request = http.MultipartRequest('PATCH', url);
      
      request.headers.addAll(ApiConstants.getHeaders(token));

      request.fields['fuel_log_id'] = fuelLogId.toString();
      request.fields['vehicle_id'] = vehicleId.toString();
      request.fields['driver_id'] = driverId.toString();
      request.fields['current_odometer'] = currentOdometer;
      request.fields['filled_volume'] = filledVolume;
      request.fields['bill_amount'] = billAmount;
      request.fields['filled_at'] = filledAt;

      if (billFilePath != null) {
        request.files.add(await http.MultipartFile.fromPath('bill_file', billFilePath));
      }

      // Log CURL for debugging
      debugPrint("--- [DEBUG] COMPLETE FUEL ENTRY CURL ---");
      StringBuffer curl = StringBuffer("curl --location --request PATCH '$url' \\\n");
      request.headers.forEach((key, value) => curl.write("--header '$key: $value' \\\n"));
      request.fields.forEach((key, value) => curl.write("--form '$key=\"$value\"' \\\n"));
      if (billFilePath != null) curl.write("--form 'bill_file=@\"$billFilePath\"'");
      debugPrint(curl.toString());
      debugPrint("---------------------------------------");

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint("--- [DEBUG] COMPLETE FUEL ENTRY RESPONSE ---");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Body: ${response.body}");
      debugPrint("-------------------------------------------");

      try {
        final decoded = json.decode(response.body);
        if (response.statusCode == 200 || response.statusCode == 201) {
          fetchPendingFuelEntries(); // Refresh pending list
          return {
            "success": true,
            "message": decoded['message'] ?? "Fuel log completed successfully",
            "mileage_data": decoded['mileage_data']
          };
        } else {
          return {
            "success": false,
            "message": decoded['message'] ?? "Failed to complete fuel log"
          };
        }
      } catch (e) {
        debugPrint("JSON Decode Error in completeFuelEntry: $e");
        return {"success": false, "message": "Invalid response format: $e"};
      }
    } catch (e) {
      debugPrint("Error completing fuel entry: $e");
      return {"success": false, "message": "Network error: $e"};
    }
  }

  Future<void> fetchActiveRoutesToComplete() async {
    _isLoadingActiveRoutes = true;
    notifyListeners();

    try {
      final token = await UserStore.getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse(ApiConstants.pendingRoutesToComplete),
        headers: ApiConstants.getHeaders(token),
      );

      debugPrint("--- [DEBUG] FETCH ACTIVE ROUTES TO COMPLETE ---");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Body: ${response.body}");
      debugPrint("-----------------------------------------------");

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          _activeRoutesToComplete = List<Map<String, dynamic>>.from(decoded['data']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching active routes to complete: $e");
    } finally {
      _isLoadingActiveRoutes = false;
      notifyListeners();
    }
  }
}


