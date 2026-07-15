import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
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

  // Purposes & Types
  List<Map<String, dynamic>> _purposes = [];
  List<Map<String, dynamic>> get purposes => _purposes;
  
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> get types => _types;

  void setFilters({String? search, int? driverId, String? date}) {
    if (search != null) _searchQuery = search;
    if (driverId != null) _selectedDriverId = driverId == -1 ? null : driverId; // -1 for clear
    if (date != null) _selectedDate = date == "clear" ? null : date;
    fetchAllowances(isRefresh: true);
  }

  Future<bool> rejectRouteRequest(int routeRequestId, String reason) async {
    try {
      final token = await UserStore.getToken();
      final res = await http.post(
        Uri.parse(ApiConstants.rejectRouteRequest(routeRequestId)),
        headers: ApiConstants.getHeaders(token),
        body: json.encode({"rejection_reason": reason}),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        // Optionally refetch pending routes
        fetchPendingAllowanceCreations();
        return true;
      }
    } catch (e) {
      debugPrint("Error rejecting route request: \$e");
    }
    return false;
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
          if (_pendingCreations.isNotEmpty) {
            try {
              File('C:/Tripzo/TMS/scratch.json').writeAsStringSync(jsonEncode(_pendingCreations.first));
            } catch (_) {}
          }
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
    _purposes.clear();
    _types.clear();
    _searchQuery = "";
    _selectedDriverId = null;
    _selectedDate = null;
    _allowancePage = 1;
    _hasMoreAllowances = true;
    notifyListeners();
  }

  Future<void> fetchPurposes() async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return;
      final response = await http.get(Uri.parse(ApiConstants.getAllowancePurposes), headers: ApiConstants.getHeaders(token));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          _purposes = (decoded['data'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error fetching purposes: $e");
    }
  }

  Future<bool> createPurpose(String name) async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return false;
      final response = await http.post(
        Uri.parse(ApiConstants.getAllowancePurposes),
        headers: ApiConstants.getHeaders(token),
        body: json.encode({"name": name}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          await fetchPurposes();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("Error creating purpose: $e");
      return false;
    }
  }

  Future<void> fetchTypes() async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return;
      final response = await http.get(Uri.parse(ApiConstants.getAllowanceTypes), headers: ApiConstants.getHeaders(token));
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          _types = (decoded['data'] as List?)?.map((e) => e as Map<String, dynamic>).toList() ?? [];
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error fetching types: $e");
    }
  }

  Future<bool> createAllowance(Map<String, dynamic> data) async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return false;
      final response = await http.post(
        Uri.parse(ApiConstants.createAllowance),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(data),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        debugPrint("Create failed: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Error creating allowance: $e");
      return false;
    }
  }

  Future<bool> updateAllowance(int id, Map<String, dynamic> data) async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return false;
      final response = await http.patch(
        Uri.parse(ApiConstants.updateAllowance(id)),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint("Update failed: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Error updating allowance: $e");
      return false;
    }
  }

  Future<bool> deleteAllowance(int id) async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return false;
      final response = await http.delete(
        Uri.parse(ApiConstants.deleteAllowance(id)),
        headers: ApiConstants.getHeaders(token),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint("Delete failed: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Error deleting allowance: $e");
      return false;
    }
  }
}

final adminAllowanceStore = AdminAllowanceStore();
