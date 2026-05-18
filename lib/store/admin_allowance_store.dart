import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';

class AdminAllowanceStore extends ChangeNotifier {
  static final AdminAllowanceStore _instance = AdminAllowanceStore._internal();
  factory AdminAllowanceStore() => _instance;
  AdminAllowanceStore._internal();

  // Allowances State
  List<Map<String, dynamic>> _allowances = [];
  List<Map<String, dynamic>> get allowances => _allowances;

  // Pending creations state
  List<Map<String, dynamic>> _pendingCreations = [];
  List<Map<String, dynamic>> get pendingCreations => _pendingCreations;
  bool _isLoadingPendingCreations = false;
  bool get isLoadingPendingCreations => _isLoadingPendingCreations;
  
  bool _isLoadingAllowances = false;
  bool get isLoadingAllowances => _isLoadingAllowances;
  
  bool _isFetchingMoreAllowances = false;
  bool get isFetchingMoreAllowances => _isFetchingMoreAllowances;
  
  int _allowancePage = 1;
  bool _hasMoreAllowances = true;
  bool get hasMoreAllowances => _hasMoreAllowances;

  // Filters
  String _searchQuery = "";
  int? _selectedDriverId;
  String? _selectedDate; // Format: YYYY-MM-DD

  // Drivers List for Filter
  List<Map<String, dynamic>> _driversList = [];
  List<Map<String, dynamic>> get driversList => _driversList;

  void setFilters({String? search, int? driverId, String? date}) {
    if (search != null) _searchQuery = search;
    if (driverId != null) _selectedDriverId = driverId == -1 ? null : driverId; // -1 for clear
    if (date != null) _selectedDate = date == "clear" ? null : date;
    fetchAllowances(isRefresh: true);
  }

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
      if (token == null) return;

      // Construct URL
      String url = "${ApiConstants.getDriverAllowances}?page=$_allowancePage&limit=10";
      if (_searchQuery.isNotEmpty) {
        url += "&search=$_searchQuery";
      }
      if (_selectedDriverId != null) {
        url += "&driver_id=$_selectedDriverId";
      }
      if (_selectedDate != null) {
        url += "&date=$_selectedDate";
      }

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
      debugPrint("Error fetching admin allowances: $e");
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

  Future<void> fetchPendingAllowanceCreations() async {
    _isLoadingPendingCreations = true;
    notifyListeners();

    try {
      final token = await UserStore.getToken();
      if (token == null) return;

      final url = "${ApiConstants.getDriverAllowances}?page=1&limit=10&pending_allowance_creation=true";
      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final List<dynamic> items = decoded['data'] ?? [];
          _pendingCreations = items.map((e) => e as Map<String, dynamic>).toList();
        }
      }
    } catch (e) {
      debugPrint("Error fetching pending allowance creations: $e");
    } finally {
      _isLoadingPendingCreations = false;
      notifyListeners();
    }
  }

  Future<void> fetchDriversForFilter() async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return;

      final url = ApiConstants.getAllDriversWithoutPagination;
      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final List<dynamic> items = decoded['data'] ?? [];
          _driversList = items.map((e) => e as Map<String, dynamic>).toList();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error fetching drivers for filter: $e");
    }
  }

  void resetStore() {
    _allowances.clear();
    _pendingCreations.clear();
    _searchQuery = "";
    _selectedDriverId = null;
    _selectedDate = null;
    _allowancePage = 1;
    _hasMoreAllowances = true;
    notifyListeners();
  }
}

final adminAllowanceStore = AdminAllowanceStore();
