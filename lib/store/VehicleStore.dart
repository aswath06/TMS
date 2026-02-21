import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tms/utils/api_constants.dart';
import 'package:tms/store/user_store.dart';

class VehicleStore extends ChangeNotifier {
  List<dynamic> _allVehicles = [];
  List<dynamic> _filteredVehicles = [];
  List<String> _dynamicCategories = ["All"];
  bool _isLoading = false;
  String _searchQuery = "";

  // Changed to Set for multi-select support
  Set<String> _selectedCategories = {"All"};

  // Cache management
  DateTime? _lastFetchTime;

  // Getters
  List<dynamic> get filteredVehicles => _filteredVehicles;
  List<String> get categories => _dynamicCategories;
  bool get isLoading => _isLoading;
  Set<String> get selectedCategories => _selectedCategories;
  int get totalVehicles => _allVehicles.length;

  int get activeTrucks => _allVehicles.where((v) {
    final type = v['vehicle_type']?.toString().toLowerCase() ?? '';
    final status = v['status']?.toString().toLowerCase() ?? '';
    return type.contains('truck') && (status == 'active' || status == 'live');
  }).length;

  /// Fetches vehicles with built-in caching logic
  Future<void> fetchVehicles({bool forceRefresh = false}) async {
    // Cache Check: If data exists and is less than 5 mins old, don't hit API
    if (_allVehicles.isNotEmpty && !forceRefresh) {
      if (_lastFetchTime != null &&
          DateTime.now().difference(_lastFetchTime!).inMinutes < 5) {
        debugPrint("TMS: Serving from local cache");
        return;
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final String? token = await UserStore.getToken();
      if (token == null) throw Exception('Unauthorized');

      final response = await http.get(
        Uri.parse(ApiConstants.getAllVehicles),
        headers: {
          'Authorization': 'TMS $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        _allVehicles = responseData['data'] ?? [];
        _lastFetchTime = DateTime.now();

        // Build unique categories from live data
        final Set<String> types = {"All"};
        for (var v in _allVehicles) {
          if (v['vehicle_type'] != null) {
            types.add(_capitalize(v['vehicle_type'].toString()));
          }
        }
        _dynamicCategories = types.toList()..sort();

        _applyFilters();
      }
    } catch (e) {
      debugPrint("Store Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateSearch(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  /// Multi-select toggle logic
  void toggleCategory(String category) {
    if (category == "All") {
      _selectedCategories = {"All"};
    } else {
      // If selecting a specific type, remove 'All'
      _selectedCategories.remove("All");

      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }

      // If nothing is selected, default back to 'All'
      if (_selectedCategories.isEmpty) {
        _selectedCategories.add("All");
      }
    }
    _applyFilters();
  }

  /// Logic to filter the list based on search and multi-selected categories
  void _applyFilters() {
    _filteredVehicles = _allVehicles.where((v) {
      final String plate = (v['vehicle_number'] ?? "").toString().toLowerCase();
      final String type = (v['vehicle_type'] ?? "").toString().toLowerCase();

      // Search check
      final matchesSearch =
          plate.contains(_searchQuery.toLowerCase()) ||
          type.contains(_searchQuery.toLowerCase());

      // Multi-category check
      final matchesCategory =
          _selectedCategories.contains("All") ||
          _selectedCategories.any((cat) => cat.toLowerCase() == type);

      return matchesSearch && matchesCategory;
    }).toList();
    notifyListeners();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : "${s[0].toUpperCase()}${s.substring(1)}";

  void clearCache() {
    _allVehicles = [];
    _filteredVehicles = [];
    _selectedCategories = {"All"};
    _lastFetchTime = null;
    notifyListeners();
  }
}
