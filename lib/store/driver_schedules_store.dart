import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tripzo/services/api_service.dart';
import 'package:tripzo/utils/api_constants.dart';

class DriverSchedulesStore extends ChangeNotifier {
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedDate = "";

  List<Map<String, dynamic>> get schedules => _schedules;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedDate => _selectedDate;

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
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("DriverSchedulesStore Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
