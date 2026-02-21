import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tms/utils/api_constants.dart';
import 'package:tms/store/user_store.dart';

class VehicleStore extends ChangeNotifier {
  List<dynamic> _allVehicles = [];
  List<dynamic> _filteredVehicles = [];
  bool _isLoading = false;
  String _searchQuery = "";
  String _selectedCategory = "All";

  // Getters
  List<dynamic> get filteredVehicles => _filteredVehicles;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;
  int get totalVehicles => _allVehicles.length;

  int get totalCapacity => _allVehicles.fold(
    0,
    (sum, item) => sum + (item['capacity'] as int? ?? 0),
  );

  // Fetching Logic
  Future<void> fetchVehicles() async {
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

  void updateCategory(String category) {
    _selectedCategory = category;
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
          _selectedCategory == "All" || type == _selectedCategory.toLowerCase();

      return matchesSearch && matchesCategory;
    }).toList();
    notifyListeners();
  }
}
