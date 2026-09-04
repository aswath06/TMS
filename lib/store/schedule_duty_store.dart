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
  String get fromDate => _fromDate;
  String get toDate => _toDate;

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

  Future<void> startDirectMasterShift(int shiftId, {List<Map<String, dynamic>>? odometers}) async {
    try {
      bool anySuccess = false;
      dynamic lastData;

      if (odometers != null && odometers.isNotEmpty) {
        // Iterate and hit the new driver-specific endpoint for each vehicle/driver pair
        for (var odo in odometers) {
          final vId = odo['vehicle_id'];
          final startOdo = odo['start_odometer'];
          final driverId = odo['driver_id'] ?? 1; // Fallback driver ID if missing
          
          if (vId != null && startOdo != null) {
            try {
              final dUrl = ApiConstants.startDirectDriverMasterShift(shiftId, driverId);
              final dBody = {
                "vehicle_id": vId,
                "vehicle_number": odo['vehicle_number'],
                "start_odometer": startOdo,
                "start_time": DateTime.now().toUtc().toIso8601String(),
              };
              lastData = await ApiService.post(dUrl, body: dBody);
              anySuccess = true;
            } catch (e) {
              debugPrint("Failed driver direct start for vehicle $vId: $e");
            }
          }
        }
      }

      if (!anySuccess) {
        final url = ApiConstants.startDirectMasterShift(shiftId);
        lastData = await ApiService.post(url, body: {});
      }

      if (lastData != null && (lastData['success'] == true || anySuccess)) {
        await fetchMasterSchedules(isRefresh: true);
      } else {
        throw Exception(lastData?['message'] ?? "Failed to start shift directly.");
      }
    } catch (e) {
      debugPrint("ScheduleDutyStore Error (startDirectMasterShift): $e");
      rethrow;
    }
  }

  Future<void> endDirectMasterShift(int shiftId, {List<Map<String, dynamic>>? odometers}) async {
    try {
      bool anySuccess = false;
      dynamic lastData;

      if (odometers != null && odometers.isNotEmpty) {
        // Iterate and hit the new driver-specific endpoint for each vehicle/driver pair
        for (var odo in odometers) {
          final vId = odo['vehicle_id'];
          final endOdo = odo['end_odometer'];
          final driverId = odo['driver_id'] ?? 1; // Fallback driver ID if missing
          
          if (vId != null && endOdo != null) {
            try {
              final dUrl = ApiConstants.endDirectDriverMasterShift(shiftId, driverId);
              final dBody = {
                "vehicle_id": vId,
                "vehicle_number": odo['vehicle_number'],
                "end_odometer": endOdo,
                "end_time": DateTime.now().toUtc().toIso8601String(),
              };
              lastData = await ApiService.post(dUrl, body: dBody);
              anySuccess = true;
            } catch (e) {
              debugPrint("Failed driver direct end for vehicle $vId: $e");
            }
          }
        }
      }

      if (!anySuccess) {
        final url = ApiConstants.endDirectMasterShift(shiftId);
        lastData = await ApiService.post(url, body: {});
      }

      if (lastData != null && (lastData['success'] == true || anySuccess)) {
        await fetchMasterSchedules(isRefresh: true);
      } else {
        throw Exception(lastData?['message'] ?? "Failed to end shift directly.");
      }
    } catch (e) {
      debugPrint("ScheduleDutyStore Error (endDirectMasterShift): $e");
      rethrow;
    }
  }

  Future<void> editMasterShiftOdometer(
    int shiftId, 
    int vehicleId, {
    required double startOdometer,
    required double endOdometer,
    required String startTime,
    required String endTime,
    required int mistakeOnRoleId,
    required String remark,
  }) async {
    try {
      final url = ApiConstants.editMasterShiftOdometer(shiftId, vehicleId);
      final body = {
        "start_odometer": startOdometer,
        "end_odometer": endOdometer,
        "start_time": startTime,
        "end_time": endTime,
        "mistake_on_role_id": mistakeOnRoleId,
        "remark": remark,
      };
      
      final response = await ApiService.put(url, body: body);
      if (response == null) throw 'Failed to edit odometer';
    } catch (e) {
      debugPrint('Error editing odometer: $e');
      rethrow;
    }
  }

  Future<void> transferDriverMasterShift(int shiftId, {
    required int fromDriverId,
    required int toDriverId,
    required int vehicleId,
    required double endOdometer,
    required String reason,
  }) async {
    try {
      final url = ApiConstants.transferMasterShift(shiftId);
      final body = {
        "from_driver_id": fromDriverId,
        "to_driver_id": toDriverId,
        "vehicle_id": vehicleId,
        "end_odometer_for_from_driver": endOdometer,
        "reason": reason,
      };
      
      final data = await ApiService.post(url, body: body);
      if (data != null && data['success'] == true) {
        await fetchMasterSchedules(isRefresh: true);
      } else {
        throw Exception(data?['message'] ?? "Failed to transfer shift.");
      }
    } catch (e) {
      debugPrint("ScheduleDutyStore Error (transferDriverMasterShift): $e");
      rethrow;
    }
  }
}
