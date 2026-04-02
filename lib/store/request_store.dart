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
  
  // Pagination State
  int _currentPage = 1;
  bool _hasMore = true;
  int _totalItems = 0;

  String? _errorMessage;
  String? _leavesErrorMessage;

  // Getters
  List<Map<String, dynamic>> get requests => _requests;
  List<Map<String, dynamic>> get leaves => _leaves;
  Map<String, dynamic>? get currentRequest => _currentRequest;
  bool get isLoading => _isLoading;
  bool get isFetchingDetails => _isFetchingDetails;
  bool get isLoadingLeaves => _isLoadingLeaves;
  bool get hasMore => _hasMore;
  int get currentPage => _currentPage;
  String? get errorMessage => _errorMessage;
  String? get leavesErrorMessage => _leavesErrorMessage;

  /// Fetches all requests with optional pagination
  Future<void> fetchRequests({int page = 1, int limit = 10, bool isRefresh = false}) async {
    if (isRefresh) {
      _currentPage = 1;
      _hasMore = true;
      _requests = [];
    }

    if (!_hasMore && !isRefresh) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        _errorMessage = "Session expired.";
        _isLoading = false;
        notifyListeners();
        return;
      }

      String url = "${ApiConstants.getAllRequests}?page=$page&limit=$limit";

      // Append user email for faculty requests
      final String? role = await UserStore.getRole();
      final String? email = await UserStore.getEmail();
      if (role != null && !role.toLowerCase().contains('admin') && email != null) {
        url += "&user=$email";
      }

      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        final List<dynamic> items = data['data'] ?? [];
        final List<Map<String, dynamic>> formattedItems = items.map((req) => _formatRequest(req)).toList();

        if (page == 1) {
          _requests = formattedItems;
        } else {
          _requests.addAll(formattedItems);
        }

        // Parse pagination metadata
        if (data['pagination'] != null) {
          final p = data['pagination'];
          _currentPage = p['page'] ?? page;
          _totalItems = p['totalItems'] ?? 0;
          _hasMore = _requests.length < _totalItems;
        } else {
          _hasMore = formattedItems.length >= limit;
        }
      } else {
        _errorMessage = "Server Error: ${response.statusCode}";
      }
    } catch (e) {
      _errorMessage = "Connection failed.";
      debugPrint("RequestStore Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Helper to fetch the next page for infinite scroll
  Future<void> fetchNextPage() async {
    if (_isLoading || !_hasMore) return;
    await fetchRequests(page: _currentPage + 1);
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
    String statusString = 'Pending';
    int rawStatusInt = 1;

    if (req['status'] is String) {
      statusString = req['status'].toString().toUpperCase();
      // Map string status back to a reasonable integer for existing UI code if needed
      final reverseMap = {
        'PENDING': 1,
        'DRAFT': 10,
        'SUBMITTED': 11,
        'PLANNED': 12,
        'APPROVED': 2,
        'REJECTED': 3,
        'STARTED': 7,
        'ONGOING': 4,
        'COMPLETED': 8,
        'CANCELLED': 9,
      };
      rawStatusInt = reverseMap[statusString] ?? 1;
    } else if (req['status'] is int) {
      rawStatusInt = req['status'];
      statusString = RouteStatus[rawStatusInt] ?? 'Unknown';
    } else if (req['status'] != null) {
      rawStatusInt = int.tryParse(req['status'].toString()) ?? 1;
      statusString = RouteStatus[rawStatusInt] ?? 'Unknown';
    }

    return {
      'id': 'REQ-${req['id']}',
      'dbId': req['id'],
      'faculty': req['createdBy']?['name'] ?? 'Staff Member',
      'date': _formatDate(req['start_datetime']),
      'pickup': _formatAddress(req['startLocation']),
      'drop': _formatAddress(req['destinationLocation']),
      'status': statusString,
      'rawStatus': rawStatusInt,
      'routeName': req['routeName'] ?? 'Unknown Route',
      'travelType': req['travelType'] ?? 'One Way',
      'approx_duration': req['approx_duration'] ?? 0,
      'vehicle': req['assignedVehicle']?['model'] ??
          req['routeName'] ??
          'Not Assigned',
      'passengers': req['passengerCount'] ?? 0,
      'capacity': req['assignedVehicle']?['capacity'] ?? 0,
      'intermediateStops': req['intermediateStops'] ?? [],
      'drivers': (req['drivers'] as List?)?.map((d) => {
        'id': d['driver_id'],
        'name': d['name'],
        'phone': d['phone'],
        'status': d['status'],
      }).toList() ?? [],
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
      'driver_full': leave['driver'], // Full driver object (id, name, email)
      'from': _formatLeaveDate(leave['from_date']),
      'to': _formatLeaveDate(leave['to_date']),
      'from_raw': leave['from_date'],
      'to_raw': leave['to_date'],
      'days': leave['total_days']?.toString() ?? '0',
      'status': status,
      'rawStatus': leave['status'],
      'reason': leave['reason'] ?? '',
      'leave_type': leave['leave_type'],
      'driver_details': leave['driver_details'],
      'approver': leave['approver'], // Full approver object (id, name)
      'approved_at': leave['approved_at'],
      'created_at': leave['created_at'],
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

  /// Updates the status of a leave request (Approve/Reject)
  Future<bool> updateLeaveStatus(int leaveId, int status) async {
    _isLoadingLeaves = true;
    _leavesErrorMessage = null;
    notifyListeners();

    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        _leavesErrorMessage = "Session expired.";
        return false;
      }

      final response = await http.put(
        Uri.parse("${ApiConstants.updateLeaveStatus}$leaveId"),
        headers: ApiConstants.getHeaders(token),
        body: json.encode({"status": status}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          // Update the local list to reflect the change immediately
          final index = _leaves.indexWhere((l) => l['id'] == leaveId);
          if (index != -1) {
            String statusStr = 'Pending';
            if (status == 2) statusStr = 'Approved';
            else if (status == 3) statusStr = 'Rejected';
            
            _leaves[index]['status'] = statusStr;
            _leaves[index]['rawStatus'] = status;
          }
          notifyListeners();
          return true;
        } else {
          _leavesErrorMessage = data['message'] ?? "Failed to update status.";
        }
      } else {
        _leavesErrorMessage = "Server error: ${response.statusCode}";
      }
    } catch (e) {
      _leavesErrorMessage = "Connection error.";
      debugPrint("Update Leave Status Error: $e");
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
