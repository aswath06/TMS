import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';

final useRequestStore = RequestStore();

class RequestStore extends ChangeNotifier {
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _leaves = [];
  Map<String, dynamic>? _currentRequest;
  bool _isLoading = false;
  bool _isFetchingDetails = false;
  bool _isLoadingLeaves = false;
  String? _errorMessage;
  String? _leavesErrorMessage;

  // Getters
  List<Map<String, dynamic>> get requests => _requests;
  List<Map<String, dynamic>> get leaves => _leaves;
  Map<String, dynamic>? get currentRequest => _currentRequest;
  bool get isLoading => _isLoading;
  bool get isFetchingDetails => _isFetchingDetails;
  bool get isLoadingLeaves => _isLoadingLeaves;
  String? get errorMessage => _errorMessage;
  String? get leavesErrorMessage => _leavesErrorMessage;

  /// Fetches all requests with optional pagination
  Future<void> fetchRequests({int page = 1, int limit = 10}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final String? token = await UserStore.getToken();

      if (token == null) {
        _errorMessage = "Session expired. Please login again.";
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Using the base URL and endpoint pattern from your constants
      String url =
          "${ApiConstants.baseUrl}/request/get-all?page=$page&limit=$limit";

      // Append user email for faculty requests as per requirement
      final String? role = await UserStore.getRole();
      final String? email = await UserStore.getEmail();

      if (role != 'transport admin' && email != null) {
        url += "&user=$email";
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Handling both possible list formats (direct list or nested in 'items')
        final List<dynamic> items = data['items'] ?? (data is List ? data : []);

        _requests = items.map((req) => _formatRequest(req)).toList();
      } else if (response.statusCode == 401) {
        _errorMessage = "Unauthorized access. Please re-login.";
      } else {
        _errorMessage = "Server Error: ${response.statusCode}";
      }
    } catch (e) {
      _errorMessage = "Connection failed. Please check your network.";
      debugPrint("RequestStore Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches a single request by ID
  Future<void> fetchRequestById(int id) async {
    _isFetchingDetails = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        _errorMessage = "Session expired.";
        return;
      }

      final response = await http.get(
        Uri.parse("${ApiConstants.getRequestById}$id"),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          _currentRequest = data['data'];
        } else {
          _errorMessage = data['message'] ?? "Failed to fetch request details.";
        }
      } else {
        _errorMessage = "Server Error: ${response.statusCode}";
      }
    } catch (e) {
      _errorMessage = "Connection error.";
      debugPrint("fetchRequestById Error: $e");
    } finally {
      _isFetchingDetails = false;
      notifyListeners();
    }
  }

  static const Map<int, String> RouteStatus = {
    1: "Pending",
    2: "Vehicle Assigned",
    3: "Vehicle Reassigned",
    4: "Vehicle Approved",
    5: "Driver Assigned",
    6: "Driver Reassigned",
    7: "Started",
    8: "Completed",
    9: "Cancelled",
  };

  /// Formats raw API data into the UI-friendly Map used by RequestCard
  Map<String, dynamic> _formatRequest(dynamic req) {
    // Determine status for the UI color logic
    int rawStatusInt = 1;
    if (req['status'] is int) {
      rawStatusInt = req['status'];
    } else if (req['status'] != null) {
      rawStatusInt = int.tryParse(req['status'].toString()) ?? 1;
    }

    String statusString = RouteStatus[rawStatusInt] ?? 'Unknown';

    return {
      'id': 'REQ-${req['id']}',
      'dbId': req['id'], // Keeping original ID for API calls
      'faculty': req['createdBy']?['name'] ?? 'Staff Member',
      'date': _formatDate(req['start_datetime']),
      'pickup': _formatAddress(req['startLocation']),
      'drop': _formatAddress(req['destinationLocation']),
      'status': statusString,
      'rawStatus': rawStatusInt,
      'routeName': req['routeName'] ?? 'Unknown Route',
      'vehicle':
          req['assignedVehicle']?['model'] ??
          req['routeName'] ??
          'Not Assigned',
      'passengers': req['passengerCount'] ?? 0,
      'capacity': req['assignedVehicle']?['capacity'] ?? 0,
      'intermediateStops': req['intermediateStops'] ?? [],
    };
  }

  /// Helper to clean up addresses (e.g., "Street Name, City" instead of full string)
  String _formatAddress(String? address) {
    if (address == null || address.isEmpty) return 'TBD';
    List<String> parts = address.split(',');
    return parts.length >= 2
        ? "${parts[0].trim()}, ${parts[1].trim()}"
        : address;
  }

  /// Helper to format ISO dates to readable strings
  String _formatDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return 'No Date';
    try {
      final DateTime dt = DateTime.parse(dateStr.toString());
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (e) {
      return dateStr.toString().split('T')[0];
    }
  }

  /// Fetches all leaves with optional pagination
  Future<void> fetchLeaves({int page = 1, int limit = 10}) async {
    _isLoadingLeaves = true;
    _leavesErrorMessage = null;
    notifyListeners();

    try {
      final String? token = await UserStore.getToken();

      if (token == null) {
        _leavesErrorMessage = "Session expired. Please login again.";
        _isLoadingLeaves = false;
        notifyListeners();
        return;
      }

      String url =
          "${ApiConstants.baseUrl}/api/leaves/get-all?page=$page&limit=$limit";

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true) {
          final List<dynamic> items = data['data'] ?? [];
          _leaves = items.map((leave) => _formatLeave(leave)).toList();
        } else {
          _leavesErrorMessage = "Failed to fetch leaves.";
        }
      } else if (response.statusCode == 401) {
        _leavesErrorMessage = "Unauthorized access. Please re-login.";
      } else {
        _leavesErrorMessage = "Server Error: ${response.statusCode}";
      }
    } catch (e) {
      _leavesErrorMessage = "Connection failed. Please check your network.";
      debugPrint("RequestStore Leaves Error: $e");
    } finally {
      _isLoadingLeaves = false;
      notifyListeners();
    }
  }

  /// Formats raw API leave data into the UI-friendly Map used by LeaveCard
  Map<String, dynamic> _formatLeave(dynamic leave) {
    String status = 'Pending';
    if (leave['status'] is int) {
      switch (leave['status']) {
        case 1:
          status = 'Pending';
          break;
        case 2:
          status = 'Approved';
          break;
        case 3:
          status = 'Rejected';
          break;
        default:
          status = 'Unknown';
      }
    }

    return {
      'id': leave['id'],
      'driver': leave['driver']?['name'] ?? 'Unknown Driver',
      'from': _formatLeaveDate(leave['from_date']),
      'to': _formatLeaveDate(leave['to_date']),
      'days': leave['total_days']?.toString() ?? '0',
      'status': status,
      'reason': leave['reason'] ?? '',
      'leave_type': leave['leave_type'],
      'driver_details': leave['driver_details'],
      'current_assignment': leave['current_assignment'],
    };
  }

  /// Helper to format dates for leave display (e.g., "Mar 09")
  String _formatLeaveDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return 'No Date';
    try {
      final DateTime dt = DateTime.parse(dateStr.toString());
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return "${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateStr.toString().split('T')[0];
    }
  }

  /// Creates a new leave request (Admin or Driver)
  Future<bool> createLeave({
    required int driverId,
    required String fromDate,
    required String toDate,
    required String startTime,
    required String endTime,
    required int leaveType,
    required String reason,
  }) async {
    _isLoadingLeaves = true;
    _leavesErrorMessage = null;
    notifyListeners();

    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        _leavesErrorMessage = "Session expired.";
        return false;
      }

      final response = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/api/leaves/create"),
        headers: ApiConstants.getHeaders(token),
        body: json.encode({
          "driver_id": driverId,
          "from_date": fromDate,
          "to_date": toDate,
          "start_time": startTime,
          "end_time": endTime,
          "leave_type": leaveType,
          "reason": reason,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          // Refresh the leave list after successful creation
          await fetchLeaves();
          return true;
        } else {
          _leavesErrorMessage = data['message'] ?? "Failed to create leave.";
        }
      } else {
        _leavesErrorMessage = "Server error: ${response.statusCode}";
      }
    } catch (e) {
      _leavesErrorMessage = "Connection error.";
      debugPrint("Create Leave Error: $e");
    } finally {
      _isLoadingLeaves = false;
      notifyListeners();
    }
    return false;
  }

  /// Optional: Clear requests and leaves on logout
  void clear() {
    _requests = [];
    _leaves = [];
    _errorMessage = null;
    _leavesErrorMessage = null;
    notifyListeners();
  }
}
