import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/utils/api_error_parser.dart';

final useStudentLeaveStore = StudentLeaveStore();

class StudentLeaveStore extends ChangeNotifier {
  static final StudentLeaveStore _instance = StudentLeaveStore._internal();
  factory StudentLeaveStore() => _instance;
  StudentLeaveStore._internal();

  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> get leaves => _leaves;
  
  bool _isLoadingLeaves = false;
  bool get isLoadingLeaves => _isLoadingLeaves;
  
  String? _leavesError;
  String? get leavesError => _leavesError;
  
  bool _isApplying = false;
  bool get isApplying => _isApplying;

  Future<void> fetchLeaves() async {
    _isLoadingLeaves = true;
    _leavesError = null;
    notifyListeners();

    try {
      final token = await UserStore.getToken();
      if (token == null) {
        _leavesError = "Session expired.";
        return;
      }

      final url = "${ApiConstants.baseUrl}/transport-leaves/get-all";
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final List<dynamic> items = decoded['data'] ?? [];
          _leaves = items.map((e) => e as Map<String, dynamic>).toList();
        } else {
          _leavesError = "Failed to load leaves";
        }
      } else {
        _leavesError = ApiErrorParser.parse(response, fallback: "Error");
      }
    } catch (e) {
      _leavesError = "Network error: $e";
    } finally {
      _isLoadingLeaves = false;
      notifyListeners();
    }
  }

  Future<bool> createLeave({
    required String fromDate,
    required String toDate,
    String? shiftType,
    String? fromShiftType,
    String? toShiftType,
    required String reason,
  }) async {
    _isApplying = true;
    _leavesError = null;
    notifyListeners();

    try {
      final token = await UserStore.getToken();
      if (token == null) {
        _leavesError = "Session expired.";
        _isApplying = false;
        notifyListeners();
        return false;
      }

      final url = "${ApiConstants.baseUrl}/transport-leaves/apply";
      
      final Map<String, dynamic> body = {
        "from_date": fromDate,
        "to_date": toDate,
        "reason": reason,
      };

      if (fromDate == toDate && shiftType != null) {
        body["shift_type"] = shiftType;
      } else if (fromShiftType != null && toShiftType != null) {
        body["from_shift_type"] = fromShiftType;
        body["to_shift_type"] = toShiftType;
      }

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          await fetchLeaves();
          return true;
        } else {
          _leavesError = decoded['message'] ?? "Failed to apply leave";
        }
      } else {
        try {
          final decoded = json.decode(response.body);
          _leavesError = decoded['message'] ?? ApiErrorParser.parse(response, fallback: "Failed with status");
        } catch (_) {
          _leavesError = ApiErrorParser.parse(response, fallback: "Failed with status");
        }
      }
    } catch (e) {
      _leavesError = "Network error: $e";
    } finally {
      _isApplying = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> revokeLeave(int id) async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return false;

      final url = "${ApiConstants.baseUrl}/transport-leaves/revoke/$id";
      final response = await http.delete(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchLeaves();
        return true;
      }
    } catch (e) {
      debugPrint("Error revoking: $e");
    }
    return false;
  }

  void resetLeavesError() {
    _leavesError = null;
    notifyListeners();
  }
}
