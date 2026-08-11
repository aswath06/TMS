import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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

  bool _isLoadingSummary = false;
  bool get isLoadingSummary => _isLoadingSummary;

  Map<String, String> _calendarSummary = {};
  Map<String, String> get calendarSummary => _calendarSummary;

  double _dashboardAbsentCount = 0;
  double get dashboardAbsentCount => _dashboardAbsentCount;

  double _dashboardLeaveCount = 0;
  double get dashboardLeaveCount => _dashboardLeaveCount;

  int _dashboardTotalMappedDays = 180;
  int get dashboardTotalMappedDays => _dashboardTotalMappedDays;

  bool _isLoadingMetrics = false;
  bool get isLoadingMetrics => _isLoadingMetrics;

  List<dynamic> _attendanceLogs = [];
  List<dynamic> get attendanceLogs => _attendanceLogs;

  int _attendanceLogsCurrentPage = 1;
  bool _attendanceLogsHasMore = true;
  bool get attendanceLogsHasMore => _attendanceLogsHasMore;

  bool _isFetchingMoreLogs = false;
  bool get isFetchingMoreLogs => _isFetchingMoreLogs;

  Future<void> fetchCalendarSummary(int year, int month) async {
    _isLoadingSummary = true;
    notifyListeners();
    try {
      final token = await UserStore.getToken();
      if (token == null) return;
      final url = "${ApiConstants.getPassengerCalendarSummary}?year=$year&month=$month";
      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));
      debugPrint("Calendar Summary API Response: ${response.statusCode} - ${response.body}");
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success']) {
          _calendarSummary = Map<String, String>.from(decoded['data']);
        }
      } else {
        debugPrint("Calendar Summary failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error fetching passenger calendar summary: $e");
    } finally {
      _isLoadingSummary = false;
      notifyListeners();
    }
  }

  Future<void> fetchDashboardMetrics() async {
    _isLoadingMetrics = true;
    notifyListeners();
    try {
      final token = await UserStore.getToken();
      if (token == null) return;
      final url = ApiConstants.getPassengerDashboardMetrics;
      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));
      debugPrint("Dashboard Metrics API Response: ${response.statusCode} - ${response.body}");
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success']) {
          final data = decoded['data'];
          _dashboardAbsentCount = (data['absentCount'] ?? 0).toDouble();
          _dashboardLeaveCount = (data['leaveCount'] ?? 0).toDouble();
          _dashboardTotalMappedDays = (data['totalMappedDays'] ?? 180).toInt();
        }
      } else {
        debugPrint("Dashboard Metrics failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error fetching dashboard metrics: $e");
    } finally {
      _isLoadingMetrics = false;
      notifyListeners();
    }
  }

  Future<void> fetchAttendanceLogs({bool isLoadMore = false, DateTime? filterDate, String statusFilter = 'All'}) async {
    if (isLoadMore) {
      if (!_attendanceLogsHasMore || _isFetchingMoreLogs) return;
      _isFetchingMoreLogs = true;
      _attendanceLogsCurrentPage++;
    } else {
      _isLoadingMetrics = true; // reusing loading state for simplicity or use separate
      _attendanceLogsCurrentPage = 1;
      _attendanceLogsHasMore = true;
      _attendanceLogs = [];
    }
    notifyListeners();

    try {
      final token = await UserStore.getToken();
      if (token == null) return;
      
      String url = "${ApiConstants.getPassengerAttendanceLogs}?page=$_attendanceLogsCurrentPage&limit=10";
      if (filterDate != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(filterDate);
        url += "&date=$dateStr";
      }
      if (statusFilter != 'All') {
        url += "&status=$statusFilter";
      }

      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));
      debugPrint("API URL: $url");
      debugPrint("API Response: ${response.statusCode} - ${response.body}");
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success']) {
          final data = decoded['data'];
          final List<dynamic> logs = data['logs'] ?? [];
          
          if (isLoadMore) {
            _attendanceLogs.addAll(logs);
          } else {
            _attendanceLogs = logs;
          }
          
          final int totalPages = data['totalPages'] ?? 1;
          _attendanceLogsHasMore = _attendanceLogsCurrentPage < totalPages;
        }
      }
    } catch (e) {
      debugPrint("Error fetching attendance logs: $e");
    } finally {
      if (isLoadMore) {
        _isFetchingMoreLogs = false;
      } else {
        _isLoadingMetrics = false;
      }
      notifyListeners();
    }
  }

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

  Future<bool> revokeLeave(dynamic idOrIds) async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return false;

      final idParam = idOrIds is List ? idOrIds.join(',') : idOrIds.toString();
      final url = "${ApiConstants.baseUrl}/transport-leaves/revoke/$idParam";
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
