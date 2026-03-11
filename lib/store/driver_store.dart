import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';

class DriverStore extends ChangeNotifier {
  // Singleton
  static final DriverStore _instance = DriverStore._internal();
  factory DriverStore() => _instance;
  DriverStore._internal();

  // Observable state for original profile endpoint
  final ValueNotifier<Map<String, dynamic>?> profileData = ValueNotifier(null);

  // List state
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> get drivers => _drivers;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isFetchingNextPage = false;
  bool get isFetchingNextPage => _isFetchingNextPage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _currentPage = 1;
  bool _hasMore = true;

  Future<void> fetchDrivers({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _currentPage = 1;
      _hasMore = true;
      _drivers.clear();
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    } else {
      if (!_hasMore || _isFetchingNextPage || _isLoading) return;
      _isFetchingNextPage = true;
      notifyListeners();
    }

    try {
      final token = await UserStore.getToken();
      if (token == null) {
        _errorMessage = "Session expired. Please login again.";
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
        _errorMessage = "Failed to load drivers.";
      }
    } catch (e) {
      _errorMessage = "Network error: $e";
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

  Future<bool> addDriver(Map<String, dynamic> driverData) async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return false;

      final url = "${ApiConstants.baseUrl}/auth/register";
      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(driverData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Refresh the list after successful add
        await fetchDrivers(forceRefresh: true);
        return true;
      }
      return false;
    } catch (e) {
      return false;
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
    _errorMessage = null;

    try {
      final token = await UserStore.getToken();
      if (token == null) {
        _errorMessage = "Session expired.";
        return;
      }

      final response = await http.get(
        Uri.parse(ApiConstants.userMe),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        profileData.value = decoded['data'];
      }
    } catch (e) {
      _errorMessage = "Network connection failed.";
    } finally {
      _isLoading = false;
    }
  }

  void reset() {
    profileData.value = null;
    _isLoading = false;
    _errorMessage = null;
    _drivers.clear();
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();
  }

  // --- Status Helpers ---
  String getStatusLabel(int status) {
    switch (status) {
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

  Color getStatusColor(int status) {
    switch (status) {
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

  IconData getStatusIcon(int status) {
    switch (status) {
      case 1:
        return Icons.check_circle_outline_rounded;
      case 2:
        return Icons.directions_bus_rounded; // Getting into/on bus surrogate
      case 3:
        return Icons
            .settings_input_component_rounded; // Steering wheel surrogate
      case 4:
        return Icons.home_work_rounded; // On leave / Home
      default:
        return Icons.help_outline_rounded;
    }
  }
}

// Global singleton shortcut
final useDriverStore = DriverStore();
