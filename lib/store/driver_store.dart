import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tms/store/user_store.dart';
import 'package:tms/utils/api_constants.dart';

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
        headers: {
          'Authorization': 'TMS $token',
          'Content-Type': 'application/json',
        },
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

  Future<bool> addDriver(Map<String, dynamic> driverData) async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return false;

      final url = "${ApiConstants.baseUrl}/auth/register";
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'TMS $token',
          'Content-Type': 'application/json',
        },
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
        headers: {
          'Authorization': 'TMS $token',
          'Content-Type': 'application/json',
        },
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
}

// Global singleton shortcut
final useDriverStore = DriverStore();
