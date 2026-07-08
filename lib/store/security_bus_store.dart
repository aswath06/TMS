import 'package:flutter/material.dart';
import 'package:tripzo/store/user_store.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:intl/intl.dart';

class SecurityBusStore extends ChangeNotifier {
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = false;
  DateTime? _lastFetchTime;
  DateTime _selectedDate = DateTime.now();

  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get currentData => _data;
  DateTime get selectedDate => _selectedDate;

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    fetchBusRuns(force: true);
  }

  Future<void> fetchBusRuns({bool force = false}) async {
    if (_isLoading) return;
    if (!force && _lastFetchTime != null && DateTime.now().difference(_lastFetchTime!).inSeconds < 5) {
      return;
    }
    
    _isLoading = true;
    notifyListeners();

    try {
      final token = await UserStore.getToken();
      
      final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      final url = ApiConstants.getDailyBusRuns(dateString);
      final requestHeaders = ApiConstants.getHeaders(token);
      
      final curlHeadersStr = requestHeaders.entries 
          .map((e) => "-H '${e.key}: ${e.value}'")
          .join(' ');
      final curlCommandStr = "curl --location --request GET '$url' \\\n$curlHeadersStr";
      
      debugPrint("\n--- [SECURITY BUS STORE] SENDING CURL ---");
      debugPrint(curlCommandStr);
      debugPrint("---------------------------------\n");

      final response = await http.get(Uri.parse(url), headers: requestHeaders);
      
      debugPrint("\n--- [SECURITY BUS STORE] RESPONSE RECEIVED ---");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Body: ${response.body}");
      debugPrint("--------------------------------------\n");
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List rawData = [];
        
        if (body is Map<String, dynamic> && body['data'] != null) {
          if (body['data']['runs'] != null) {
            rawData = body['data']['runs'];
          }
        } else if (body is List) {
          rawData = body;
        }

        _data = _mapRawData(rawData);
      }
      _lastFetchTime = DateTime.now();
    } catch (e) {
      debugPrint("Error fetching bus runs: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> _mapRawData(List rawData) {
    return rawData.map((e) {
      return {
        "id": e['id'],
        "runName": e['run_name'] ?? 'Unknown Run',
        "serviceDate": e['service_date'] ?? 'N/A',
        "shiftCode": e['shift_code'] ?? 'N/A',
        "status": e['status'] ?? 'UNKNOWN',
        "startLocation": e['start_location_name'] ?? 'Unknown Start',
        "haltLocation": e['halt_location_name'] ?? 'Unknown Halt',
        "campusInVerifiedBy": e['campusInVerifiedBy']?['name'],
        "campusOutVerifiedBy": e['campusOutVerifiedBy']?['name'],
        "assignments": e['assignment'] ?? [],
      };
    }).toList();
  }

  Future<void> triggerGatePass(BuildContext context, String type, String otpCode, String serviceDate) async {
    try {
      final token = await UserStore.getToken();
      final url = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/verify-campus-in-otp";
      
      final body = {
        "otp_code": otpCode,
        "service_date": serviceDate,
        "type": type
      };

      final requestHeaders = ApiConstants.getHeaders(token);
      final curlHeadersStr = requestHeaders.entries 
          .map((e) => "-H '${e.key}: ${e.value}'")
          .join(' ');
      final curlBodyStr = "-d '${jsonEncode(body)}'";
      final curlCommandStr = "curl --location --request POST '$url' \\\n$curlHeadersStr \\\n$curlBodyStr";
      
      debugPrint("\n--- [SECURITY BUS STORE] GATE PASS CURL ---");
      debugPrint(curlCommandStr);
      debugPrint("---------------------------------\n");

      final response = await http.post(
        Uri.parse(url),
        headers: requestHeaders,
        body: jsonEncode(body),
      );

      debugPrint("\n--- [SECURITY BUS STORE] GATE PASS RESPONSE ---");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Body: ${response.body}");
      debugPrint("--------------------------------------\n");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        bool isSuccess = true;
        String errorMessage = "Verification failed";
        
        if (responseData == false) {
          isSuccess = false;
        } else if (responseData is Map) {
          if (responseData['status'] == false || responseData['success'] == false || responseData['response'] == false) {
            isSuccess = false;
          }
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        }
        
        if (!isSuccess) {
          throw errorMessage;
        }
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Gate pass verified successfully!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
        // Refresh data
        fetchBusRuns(force: true);
      } else {
        final error = jsonDecode(response.body);
        throw error['message'] ?? "Action failed (${response.statusCode})";
      }
    } catch (e) {
      debugPrint("Error in triggerGatePass: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
