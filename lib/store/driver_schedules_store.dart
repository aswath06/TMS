import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tripzo/services/api_service.dart';
import 'package:tripzo/utils/api_constants.dart';

class DriverSchedulesStore extends ChangeNotifier {
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _startedSchedules = [];
  List<Map<String, dynamic>> _todaySchedules = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedDate = "";

  List<Map<String, dynamic>> get schedules => _schedules;
  List<Map<String, dynamic>> get startedSchedules => _startedSchedules;
  List<Map<String, dynamic>> get todaySchedules => _todaySchedules;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedDate => _selectedDate;

  Future<void> fetchStartedSchedules() async {
    try {
      String url = "${ApiConstants.baseUrl}/schedule-duty/master-driver/schedules?status=STARTED";
      final data = await ApiService.get(url);
      if (data != null && data['success'] == true) {
        final List<dynamic> list = data['data'] ?? [];
        _startedSchedules = list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      debugPrint("fetchStartedSchedules Error: $e");
    }
  }

  Future<void> fetchTodaySchedules() async {
    try {
      final now = DateTime.now();
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      final String todayStr = "${now.year}-$month-$day";

      String url = "${ApiConstants.baseUrl}/schedule-duty/master-driver/schedules?duty_date=$todayStr";
      final data = await ApiService.get(url);
      if (data != null && data['success'] == true) {
        final List<dynamic> list = data['data'] ?? [];
        _todaySchedules = list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      debugPrint("fetchTodaySchedules Error: $e");
    }
  }

  Future<void> fetchSchedules({
    bool isRefresh = false,
    String? date,
  }) async {
    if (date != null) {
      _selectedDate = date;
    }

    if (isRefresh) {
      _schedules = [];
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String url = "${ApiConstants.baseUrl}/schedule-duty/master-driver/schedules";
      if (_selectedDate.isNotEmpty && _selectedDate != 'ALL') {
        url += "?duty_date=${Uri.encodeComponent(_selectedDate)}";
      }

      debugPrint("🌟 FETCHING DRIVER SCHEDULES 🌟");
      debugPrint("🔗 URL: $url");
      final data = await ApiService.get(url);
      debugPrint("📦 Schedules Response: $data");

      if (data != null && data['success'] == true) {
        final List<dynamic> list = data['data'] ?? [];
        _schedules = list.map((item) => Map<String, dynamic>.from(item)).toList();
      } else {
        _errorMessage = data?['message'] ?? "Failed to load schedules.";
      }

      await fetchStartedSchedules();
      await fetchTodaySchedules();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("DriverSchedulesStore Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
