import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/services/api_service.dart';

class ScheduleDutyStore extends ChangeNotifier {
  List<Map<String, dynamic>> _masterSchedules = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentSearch = "";
  String _statusFilter = "";
  String _fromDate = "";
  String _toDate = "";

  List<Map<String, dynamic>> get masterSchedules => _masterSchedules;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchMasterSchedules({
    bool isRefresh = false,
    String? search,
    String? status,
    String? fromDate,
    String? toDate,
  }) async {
    if (search != null) _currentSearch = search;
    if (status != null) _statusFilter = status;
    if (fromDate != null) _fromDate = fromDate;
    if (toDate != null) _toDate = toDate;

    _isLoading = true;
    _errorMessage = null;
    if (isRefresh) {
      _masterSchedules = [];
    }
    notifyListeners();

    try {
      String url = ApiConstants.getMasterSchedules;
      List<String> queryParams = [];
      if (_statusFilter.isNotEmpty) queryParams.add("status=${Uri.encodeComponent(_statusFilter)}");
      if (_fromDate.isNotEmpty) queryParams.add("from_date=${Uri.encodeComponent(_fromDate)}");
      if (_toDate.isNotEmpty) queryParams.add("to_date=${Uri.encodeComponent(_toDate)}");
      if (_currentSearch.isNotEmpty) queryParams.add("search=${Uri.encodeComponent(_currentSearch)}");

      if (queryParams.isNotEmpty) {
        url += "?${queryParams.join('&')}";
      }

      debugPrint("🔗 URL: $url");
      final data = await ApiService.get(url);

      if (data != null && data['success'] == true) {
        final List<dynamic> schedulesList = data['schedules'] ?? data['data'] ?? [];
        _masterSchedules = schedulesList.map((s) => Map<String, dynamic>.from(s)).toList();
      } else {
        _errorMessage = data?['message'] ?? "Failed to load master schedules.";
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("ScheduleDutyStore Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
