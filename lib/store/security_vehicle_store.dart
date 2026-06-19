import 'package:flutter/material.dart';
import 'package:tripzo/store/user_store.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';

class SecurityVehicleStore extends ChangeNotifier {
  // Store data per tab to avoid frequent loading
  // 0: Outbound, 1: Inbound, 2: Pending
  final Map<int, List<Map<String, dynamic>>> _dataMap = {
    0: [], 1: [], 2: []
  };
  final Map<int, int> _pageMap = {
    0: 1, 1: 1, 2: 1
  };
  final Map<int, bool> _hasMoreMap = {
    0: true, 1: true, 2: true
  };
  
  int _selectedIndex = 0;
  bool _isLoading = false;
  bool _isFetchingMore = false;
  final Map<int, DateTime> _lastFetchTimeMap = {};

  int get selectedIndex => _selectedIndex;
  bool get isLoading => _isLoading;
  bool get isFetchingMore => _isFetchingMore;
  List<Map<String, dynamic>> get currentData => _dataMap[_selectedIndex] ?? [];
  bool get hasMore => _hasMoreMap[_selectedIndex] ?? true;

  void setSelectedIndex(int index) {
    if (_selectedIndex == index) return;
    _selectedIndex = index;
    notifyListeners();
    // If no data or force fetch, we fetch
    if ((_dataMap[index] ?? []).isEmpty) {
      fetchRoutes();
    }
  }

  Future<void> fetchRoutes({bool force = false}) async {
    if (_isLoading) return;
    // Debounce rapid fetches per tab
    final lastFetchTime = _lastFetchTimeMap[_selectedIndex];
    if (!force && lastFetchTime != null && DateTime.now().difference(lastFetchTime).inSeconds < 5) {
      return;
    }
    
    _isLoading = true;
    _pageMap[_selectedIndex] = 1;
    _hasMoreMap[_selectedIndex] = true;
    notifyListeners();

    try {
      final token = await UserStore.getToken();
      final types = ['OUT_CAMPUS', 'IN_CAMPUS', 'PENDING'];
      final type = types[_selectedIndex];
      final url = ApiConstants.getSecurityRoutes(1, 10, type);
      
      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List rawData = body['data']['data'] ?? [];
          final pagination = body['data']['pagination'] ?? {};
          final totalPages = pagination['totalPages'] ?? 1;

          if (_pageMap[_selectedIndex]! >= totalPages) {
            _hasMoreMap[_selectedIndex] = false;
          }

          _dataMap[_selectedIndex] = _mapRawData(rawData, _selectedIndex);
        }
      }
      _lastFetchTimeMap[_selectedIndex] = DateTime.now();
    } catch (e) {
      debugPrint("Error fetching routes: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreRoutes() async {
    if (_isFetchingMore || !_hasMoreMap[_selectedIndex]!) return;
    
    _isFetchingMore = true;
    _pageMap[_selectedIndex] = (_pageMap[_selectedIndex] ?? 1) + 1;
    notifyListeners();

    try {
      final token = await UserStore.getToken();
      final types = ['OUT_CAMPUS', 'IN_CAMPUS', 'PENDING'];
      final type = types[_selectedIndex];
      final url = ApiConstants.getSecurityRoutes(_pageMap[_selectedIndex]!, 10, type);
      
      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List rawData = body['data']['data'] ?? [];
          final pagination = body['data']['pagination'] ?? {};
          final totalPages = pagination['totalPages'] ?? 1;

          if (_pageMap[_selectedIndex]! >= totalPages) {
            _hasMoreMap[_selectedIndex] = false;
          }

          _dataMap[_selectedIndex]!.addAll(_mapRawData(rawData, _selectedIndex));
        }
      }
    } catch (e) {
      debugPrint("Error fetching more routes: $e");
    } finally {
      _isFetchingMore = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> _mapRawData(List rawData, int index) {
    return rawData.map((e) {
      final List vehicles = e['vehicles'] ?? [];
      final List drivers = e['drivers'] ?? [];
      
      String vNum = 'N/A';
      if (vehicles.isNotEmpty) vNum = vehicles.first['vehicle_number'] ?? 'N/A';
      
      String dName = 'N/A';
      if (drivers.isNotEmpty) dName = drivers.first['name'] ?? drivers.first['driver_name'] ?? 'N/A';

      return {
        "id": e['trip_instance_id']?.toString() ?? e['id']?.toString() ?? '',
        "status": ["Outbound", "Inbound", "Pending"][index],
        "routeName": e['route_name'] ?? 'Unknown Route',
        "purpose": e['purpose'] ?? 'No Purpose',
        "vehicleNumber": vNum,
        "driverName": dName,
        "startLocation": e['start_destination'] ?? 'Unknown',
        "endLocation": e['end_destination'] ?? 'Unknown',
        "intermediateStop": e['intermediateStop'],
        "startedBy": e['started_by'],
        "startedByRole": e['started_by_role'],
        "startedAt": e['started_at'],
        "endedBy": e['ended_by'],
        "endedByRole": e['ended_by_role'],
        "endedAt": e['ended_at'],
        "tripType": e['trip_type'],
      };
    }).toList();
  }
}
