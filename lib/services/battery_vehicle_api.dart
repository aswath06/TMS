import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';

class BatteryVehicleApi {
  dynamic _extractData(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is List) return decoded;
      if (decoded is Map) {
        if (decoded.containsKey('data')) {
          if (decoded['data'] is List) return decoded['data'];
          if (decoded['data'] is Map && decoded['data'].containsKey('trips'))
            return decoded['data']['trips'];
        }
        if (decoded.containsKey('bookings') && decoded['bookings'] is List)
          return decoded['bookings'];
        if (decoded.containsKey('driver_bookings') &&
            decoded['driver_bookings'] is List)
          return decoded['driver_bookings'];
      }
      return decoded;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await UserStore.getToken();
    return {'Content-Type': 'application/json', 'Authorization': 'TMS $token'};
  }

  Future<void> addEvLocation(
    String name,
    double lat,
    double lng,
    String status,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/api/master/ev-locations'),
      headers: await _getHeaders(),
      body: jsonEncode({
        "name": name,
        "latitude": lat,
        "longitude": lng,
        "status": status,
      }),
    );
    if (response.statusCode >= 400)
      throw Exception(
        'Failed to add EV location: ${response.statusCode} ${response.body}',
      );
  }

  Future<List<dynamic>> getEvLocations() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/master/ev-locations'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return _extractData(response.body);
    }
    throw Exception(
      'Failed to fetch EV locations: ${response.statusCode} ${response.body}',
    );
  }

  Future<void> configureBookingPermissions(Map<String, bool> config) async {
    final response = await http.patch(
      Uri.parse('${ApiConstants.baseUrl}/api/battery-vehicle-booking/config'),
      headers: await _getHeaders(),
      body: jsonEncode(config),
    );
    if (response.statusCode >= 400)
      throw Exception(
        'Failed to configure permissions: ${response.statusCode} ${response.body}',
      );
  }

  Future<Map<String, dynamic>> checkBookingConfig() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/battery-vehicle-booking/config'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('data') && decoded['data'] is Map) {
          return decoded['data'] as Map<String, dynamic>;
        }
        return decoded;
      }
      return {};
    }
    throw Exception(
      'Failed to fetch booking config: ${response.statusCode} ${response.body}',
    );
  }

  Future<List<dynamic>> getLocations() async {
    final response = await http.get(
      Uri.parse(
        '${ApiConstants.baseUrl}/api/battery-vehicle-booking/locations',
      ),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return _extractData(response.body);
    }
    throw Exception(
      'Failed to fetch locations: ${response.statusCode} ${response.body}',
    );
  }

  Future<void> adminBookBatteryVehicle(
    int fromId,
    int toId,
    String reason,
    String passengerName,
  ) async {
    // We append the passenger name to the reason since the standard /book curl
    // does not explicitly have a passenger_name field.
    final combinedReason = passengerName.isNotEmpty
        ? "For $passengerName - $reason"
        : reason;

    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/api/battery-vehicle-booking/bookings'),
      headers: await _getHeaders(),
      body: jsonEncode({
        "from_location_id": fromId,
        "to_location_id": toId,
        "reason": combinedReason,
        // Passing it anyway just in case the backend supports it now or later
        "passenger_name": passengerName,
      }),
    );
    if (response.statusCode >= 400) {
      throw Exception(
        'Failed to book vehicle: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> bookBatteryVehicle(int fromId, int toId, String reason) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/api/battery-vehicle-booking/bookings'),
      headers: await _getHeaders(),
      body: jsonEncode({
        "from_location_id": fromId,
        "to_location_id": toId,
        "reason": reason,
      }),
    );
    if (response.statusCode >= 400)
      throw Exception(
        'Failed to book vehicle: ${response.statusCode} ${response.body}',
      );
  }

  Future<void> driverStartTrip(
    String bookingId,
    int driverId, {
    String? otp,
    String? qrCodeData,
  }) async {
    final Map<String, dynamic> body = {"driverId": driverId};
    if (otp != null && otp.isNotEmpty) body["otp"] = otp;
    if (qrCodeData != null && qrCodeData.isNotEmpty)
      body["qr_code_data"] = qrCodeData;

    final response = await http.post(
      Uri.parse(
        '${ApiConstants.baseUrl}/api/battery-vehicle-booking/$bookingId/start-scan',
      ),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
    if (response.statusCode >= 400) {
      try {
        final data = jsonDecode(response.body);
        throw Exception(
          'Failed to start trip: ${response.statusCode} ${data["message"] ?? response.body}',
        );
      } catch (e) {
        if (e is FormatException) {
          throw Exception(
            'Failed to start trip: ${response.statusCode} ${response.body}',
          );
        }
        rethrow;
      }
    }
  }

  Future<void> scanDriverQr(String bookingId, String qrCodeData) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConstants.baseUrl}/api/battery-vehicle-booking/$bookingId/start',
      ),
      headers: await _getHeaders(),
      body: jsonEncode({"qr_code_data": qrCodeData}),
    );
    if (response.statusCode >= 400)
      throw Exception(
        'Failed to scan QR code: ${response.statusCode} ${response.body}',
      );
  }

  Future<List<dynamic>> getDriverBookings(String scheduleId) async {
    final headers = await _getHeaders();
    final url = '${ApiConstants.baseUrl}/api/battery-vehicle-booking/bookings';

    try {
      print("FETCHING FROM: $url");
      final response = await http.get(Uri.parse(url), headers: headers);
      print("RESPONSE CODE: ${response.statusCode}");
      print("RESPONSE BODY: ${response.body}");
      if (response.statusCode == 200) {
        final data = _extractData(response.body);
        print("EXTRACTED DATA: $data");
        if (data is List) return data;
      }
    } catch (e) {
      print("ERROR IN GETDRIVERBOOKINGS: $e");
    }
    return [];
  }

  Future<List<dynamic>> getPendingDriverBookingsForDashboard() async {
    final date = DateTime.now().toIso8601String().split('T')[0];
    final url = '${ApiConstants.baseUrl}/api/battery-vehicle-booking/bookings?date=$date&status=PENDING';
    try {
      final response = await http.get(Uri.parse(url), headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = _extractData(response.body);
        if (data is List) return data;
      }
    } catch (e) {
      print("ERROR IN getPendingDriverBookingsForDashboard: $e");
    }
    return [];
  }

  Future<List<dynamic>> getMyBookings() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/battery-vehicle-booking/bookings'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      final data = _extractData(response.body);
      if (data is List) {
        return data;
      }
      if (data is Map) {
        if (data.containsKey('bookings'))
          return data['bookings'] is List ? data['bookings'] : [];
        if (data.containsKey('data'))
          return data['data'] is List ? data['data'] : [];
        // Just find the first list in the map if the key is weird
        for (var value in data.values) {
          if (value is List) return value;
        }
      }
      return [];
    }
    throw Exception(
      'Failed to fetch my bookings: ${response.statusCode} ${response.body}',
    );
  }

  Future<List<dynamic>> getBookings() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/battery-vehicle-booking/bookings'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return _extractData(response.body);
    }
    throw Exception(
      'Failed to fetch bookings: ${response.statusCode} ${response.body}',
    );
  }

  Future<void> acceptRide(String bookingId) async {
    final driverId = await UserStore.getDriverId();
    final response = await http.post(
      Uri.parse(
        '${ApiConstants.baseUrl}/api/battery-vehicle-booking/$bookingId/accept',
      ),
      headers: await _getHeaders(),
      body: jsonEncode({
        "driver_id": driverId,
      }),
    );
    if (response.statusCode >= 400)
      throw Exception(
        'Failed to accept ride: ${response.statusCode} ${response.body}',
      );
  }

  Future<void> rejectRide(String bookingId) async {
    final driverId = await UserStore.getDriverId();
    final response = await http.post(
      Uri.parse(
        '${ApiConstants.baseUrl}/api/battery-vehicle-booking/respond-driver',
      ),
      headers: await _getHeaders(),
      body: jsonEncode({
         "request_id": int.tryParse(bookingId) ?? 0,
         "driver_id": driverId,
         "response_status": "EXPIRED"
      }),
    );
    if (response.statusCode >= 400)
      throw Exception(
        'Failed to reject ride: ${response.statusCode} ${response.body}',
      );
  }

  Future<void> completeRide(String bookingId, int driverId) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConstants.baseUrl}/api/battery-vehicle-booking/$bookingId/complete',
      ),
      headers: await _getHeaders(),
      body: jsonEncode({"driverId": driverId}),
    );
    if (response.statusCode >= 400)
      throw Exception(
        'Failed to complete ride: ${response.statusCode} ${response.body}',
      );
  }

  Future<void> assignDriver(String bookingId, int driverId) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConstants.baseUrl}/api/battery-vehicle-booking/$bookingId/accept',
      ),
      headers: await _getHeaders(),
      body: jsonEncode({'driver_id': driverId}),
    );
    if (response.statusCode >= 400) {
      throw Exception(
        'Failed to assign driver: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<void> cancelBooking(String bookingId) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConstants.baseUrl}/api/battery-vehicle-booking/$bookingId/cancel',
      ),
      headers: await _getHeaders(),
    );
    if (response.statusCode >= 400)
      throw Exception(
        'Failed to cancel booking: ${response.statusCode} ${response.body}',
      );
  }

  Future<void> deleteBooking(String bookingId) async {
    final response = await http.delete(
      Uri.parse(
        '${ApiConstants.baseUrl}/api/battery-vehicle-booking/$bookingId',
      ),
      headers: await _getHeaders(),
    );
    if (response.statusCode >= 400)
      throw Exception(
        'Failed to delete booking: ${response.statusCode} ${response.body}',
      );
  }

  Future<List<dynamic>> getDutyVehicles(String dutyId) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/duties/$dutyId/vehicles'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return _extractData(response.body);
    }
    throw Exception(
      'Failed to fetch duty vehicles: ${response.statusCode} ${response.body}',
    );
  }

  Future<void> startDutyVehicle(
    String dutyId,
    String vehicleId,
    int driverId,
    int odometerStart,
  ) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConstants.baseUrl}/api/duties/$dutyId/vehicles/$vehicleId/start',
      ),
      headers: await _getHeaders(),
      body: jsonEncode({"driverId": driverId, "odometerStart": odometerStart}),
    );
    if (response.statusCode >= 400)
      throw Exception(
        'Failed to start duty vehicle: ${response.statusCode} ${response.body}',
      );
  }

  Future<List<dynamic>> getEvSchedules(String driverId) async {
    final url =
        '${ApiConstants.baseUrl}/api/battery-vehicles/schedules?driverId=$driverId';
    final headers = await _getHeaders();
    print("====== CURL SCHEDULES ======\ncurl -X GET \"$url\" \\");
    headers.forEach((k, v) => print("  -H \"$k: $v\" \\"));

    final response = await http.get(Uri.parse(url), headers: headers);
    print(
      "====== RESPONSE SCHEDULES ======\nStatus: ${response.statusCode}\nBody: ${response.body}\n=====================",
    );

    if (response.statusCode == 200) {
      List<dynamic> result = [];
      final data = _extractData(response.body);
      if (data is List) {
        result = data;
      } else if (data is Map) {
        if (data.containsKey('schedules') && data['schedules'] is List) {
          result = data['schedules'];
        } else if (data.containsKey('data') && data['data'] is List) {
          result = data['data'];
        } else {
          result = [data];
        }
      }
      return result;
    } else {
      throw Exception(
        'Failed to load EV schedules: ${response.statusCode} ${response.body}',
      );
    }
  }

  Future<Map<String, dynamic>> getEvScheduleDetails(String assignmentId) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConstants.baseUrl}/api/battery-vehicles/schedules/$assignmentId',
      ),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load EV schedule details');
    }
  }

  Future<void> startEvDuty(
    String shiftId,
    String vehicleId,
    double startOdo,
    double batteryStart,
  ) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConstants.baseUrl}/api/battery-vehicles/schedules/$shiftId/start',
      ),
      headers: await _getHeaders(),
      body: jsonEncode({
        'vehicle_id': vehicleId,
        'start_odometer': startOdo,
        'battery_start': batteryStart,
      }),
    );
    if (response.statusCode >= 400) {
      throw Exception(
        'Failed to start EV duty: ${response.statusCode} ${response.body}',
      );
    }
  }
}
