import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tms/store/user_store.dart';
import 'package:tms/utils/api_constants.dart';

class RequestStore extends ChangeNotifier {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Map<String, dynamic>> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  /// Formats raw API data into the UI-friendly Map used by RequestCard
  Map<String, dynamic> _formatRequest(dynamic req) {
    // Determine status for the UI color logic
    // The API returns status as an integer (e.g., 4, 6)
    dynamic rawStatusValue = req['status'];
    String rawStatus = 'Pending';

    // Simple mapping of status codes if they are integers
    if (rawStatusValue is int) {
      switch (rawStatusValue) {
        case 4:
          rawStatus = 'Approved';
          break;
        case 6:
          rawStatus = 'Completed';
          break;
        default:
          rawStatus = 'Status $rawStatusValue';
      }
    } else if (rawStatusValue != null) {
      rawStatus = rawStatusValue.toString();
    }

    // If a vehicle/driver is attached, we might want to update status label
    if ((req['assignedVehicle'] != null || req['vehicleAssigned'] != null) &&
        rawStatus.toLowerCase() == 'approved') {
      rawStatus = 'Vehicle Assigned';
    }

    return {
      'id': 'REQ-${req['id']}',
      'dbId': req['id'], // Keeping original ID for API calls
      'faculty': req['createdBy']?['name'] ?? 'Staff Member',
      'date': _formatDate(req['start_datetime']),
      'pickup': _formatAddress(req['startLocation']),
      'drop': _formatAddress(req['destinationLocation']),
      'status': rawStatus,
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

  /// Optional: Clear requests on logout
  void clear() {
    _requests = [];
    _errorMessage = null;
    notifyListeners();
  }
}
