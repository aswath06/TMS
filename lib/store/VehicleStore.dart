import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tms/store/user_store.dart';
import 'package:tms/utils/api_constants.dart';

class VehicleStore extends ChangeNotifier {
  List<dynamic> _allVehicles = [];
  List<dynamic> _filteredVehicles = [];
  List<String> _dynamicCategories = ["All"];

  bool _isLoading = false;
  bool _isFetchingNextPage = false;
  String _searchQuery = "";
  Set<String> _selectedCategories = {"All"};

  int _totalRecords = 0;
  int _currentPage = 1;
  bool _hasMore = true;

  // --- Getters ---
  List<dynamic> get filteredVehicles => _filteredVehicles;
  List<String> get categories => _dynamicCategories;
  Set<String> get selectedCategories => _selectedCategories;
  bool get isLoading => _isLoading;
  bool get isFetchingNextPage => _isFetchingNextPage;
  int get totalVehicles => _totalRecords;
  bool get hasMore => _hasMore;

  int get activeTrucks => _allVehicles.where((v) {
    final status = v['status']?.toString().toLowerCase() ?? '';
    return status == 'active';
  }).length;

  // --- Actions ---

  /// Initial Load
  Future<void> fetchVehicles({bool forceRefresh = false}) async {
    if (_isLoading) return;

    _currentPage = 1;
    _hasMore = true;
    _isLoading = true;
    notifyListeners();

    try {
      await _fetchPage(1);
    } catch (e) {
      debugPrint("Initial Fetch Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pagination Trigger
  Future<void> fetchNextPage() async {
    if (_isFetchingNextPage || !_hasMore || _isLoading) return;

    _isFetchingNextPage = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      await _fetchPage(nextPage);
      _currentPage = nextPage;
    } catch (e) {
      debugPrint("Pagination Error: $e");
    } finally {
      _isFetchingNextPage = false;
      notifyListeners();
    }
  }

  /// Core Fetch Logic
  Future<void> _fetchPage(int page) async {
    final String? token = await UserStore.getToken();

    // Dynamically build the URL with the page query parameter
    final Uri uri = Uri.parse(
      ApiConstants.getAllVehicles,
    ).replace(queryParameters: {'page': page.toString()});

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'TMS $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> newData = responseData['data'] ?? [];

        _totalRecords = responseData['totalRecords'] ?? 0;
        final int totalPagesFromApi = responseData['totalPages'] ?? 1;

        if (page == 1) {
          _allVehicles = List.from(newData);
        } else {
          // Add unique items only
          for (var item in newData) {
            if (!_allVehicles.any((v) => v['id'] == item['id'])) {
              _allVehicles.add(item);
            }
          }
        }

        _hasMore = page < totalPagesFromApi && newData.isNotEmpty;
        _syncCategories();
        _applyFilters();
      }
    } catch (e) {
      debugPrint("Fetch Page Request Error: $e");
    }
  }

  /// Add New Vehicle
  Future<bool> addVehicle(Map<String, dynamic> vehicleData) async {
    final String? token = await UserStore.getToken();

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.createVehicle),
        headers: {
          'Authorization': 'TMS $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "vehicles": [vehicleData],
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchVehicles(); // Refresh list after successful add
        return true;
      } else {
        debugPrint("Add Vehicle Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Add Vehicle Error: $e");
      return false;
    }
  }

  // --- Filtering & UI Logic ---

  void _syncCategories() {
    final Set<String> types = {"All"};
    for (var v in _allVehicles) {
      if (v['vehicle_type'] != null) {
        types.add(_capitalize(v['vehicle_type'].toString()));
      }
    }
    _dynamicCategories = types.toList()..sort();
  }

  void updateSearch(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void toggleCategory(String category) {
    if (category == "All") {
      _selectedCategories = {"All"};
    } else {
      _selectedCategories.remove("All");
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
      if (_selectedCategories.isEmpty) _selectedCategories.add("All");
    }
    _applyFilters();
  }

  void _applyFilters() {
    _filteredVehicles = _allVehicles.where((v) {
      final String plate = (v['vehicle_number'] ?? "").toString().toLowerCase();
      final String type = (v['vehicle_type'] ?? "").toString().toLowerCase();

      final matchesSearch =
          plate.contains(_searchQuery.toLowerCase()) ||
          type.contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategories.contains("All") ||
          _selectedCategories.any(
            (cat) => cat.toLowerCase() == type.toLowerCase(),
          );

      return matchesSearch && matchesCategory;
    }).toList();
    notifyListeners();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : "${s[0].toUpperCase()}${s.substring(1)}";
}
