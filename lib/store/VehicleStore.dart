import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';

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
    return status == 'active' || status == 'available';
  }).length;

  // --- Actions ---

  /// Initial Load or Refresh
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

  /// Core Fetch Logic with Server-Side Search
  Future<void> _fetchPage(int page) async {
    final String? token = await UserStore.getToken();

    // Matching your curl: get-all?search={query}&page={page}
    final Uri uri = Uri.parse(ApiConstants.getAllVehicles).replace(
      queryParameters: {
        'search': _searchQuery, // Server-side search support
        'page': page.toString(),
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> newData = responseData['data'] ?? [];

        _totalRecords = responseData['total_records'] ?? responseData['totalRecords'] ?? 0;
        final int totalPagesFromApi = responseData['total_pages'] ?? responseData['totalPages'] ?? 1;

        if (page == 1) {
          _allVehicles = List.from(newData);
        } else {
          // Prevent duplicates during infinite scroll
          for (var item in newData) {
            if (!_allVehicles.any((v) => v['id'] == item['id'])) {
              _allVehicles.add(item);
            }
          }
        }

        _hasMore = page < totalPagesFromApi && newData.isNotEmpty;
        _syncCategories();
        _applyFilters(); // Apply local category filtering on top of server results
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
        headers: ApiConstants.getHeaders(token),
        body: json.encode({
          "vehicles": [vehicleData],
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchVehicles();
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
      final name = v['vehicle_type_name'] ?? v['vehicle_type'];
      if (name != null) {
        types.add(_capitalize(name.toString()));
      }
    }
    _dynamicCategories = types.toList()..sort();
  }

  /// Triggered when typing in search bar
  void updateSearch(String query) {
    _searchQuery = query;
    // We fetch from page 1 again because the results set has changed
    fetchVehicles();
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
      final String type = (v['vehicle_type_name'] ?? v['vehicle_type'] ?? "").toString().toLowerCase();

      // Category filter remains client-side for immediate UI response
      final matchesCategory =
          _selectedCategories.contains("All") ||
          _selectedCategories.any(
            (cat) => cat.toLowerCase() == type.toLowerCase(),
          );

      return matchesCategory;
    }).toList();
    notifyListeners();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : "${s[0].toUpperCase()}${s.substring(1)}";
}
