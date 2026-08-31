import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/services/battery_vehicle_api.dart';
import 'package:tripzo/store/user_store.dart';

class BatteryVehicleStore extends ChangeNotifier {
  IO.Socket? _socket;

  void initWebSocket() {
    if (_socket != null && _socket!.connected) return;
    final socketUrl = ApiConstants.baseUrl;
    _socket = IO.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'path': '/tms-socket/',
      'extraHeaders': {
        ApiConstants.bypassHeaderKey: ApiConstants.bypassHeaderValue,
      },
    });
    _socket?.onConnect((_) {
      debugPrint('EV WebSocket connected');
    });
    _socket?.on('ev_booking_update', (payload) {
      debugPrint('Received EV booking update: $payload');
      fetchDriverBookings();
      fetchPassengerBookings();
    });
    _socket?.connect();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  final BatteryVehicleApi _api = BatteryVehicleApi();

  bool isLoading = false;
  String? error;

  List<dynamic> evLocations = [];
  Map<String, dynamic> bookingConfig = {};
  List<dynamic> locations = [];
  List<dynamic> passengerBookings = [];
  List<dynamic> driverBookings = [];
  List<dynamic> pendingDashboardBookings = [];
  List<dynamic> allBookings = [];
  List<dynamic> evSchedules = [];
  String? lastDriverRawResponse;
  String debugLog = '';

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void _setError(String? e) {
    error = e;
    notifyListeners();
  }

  void clearError() {
    _setError(null);
  }

  Future<void> fetchEvLocations() async {
    _setLoading(true);
    _setError(null);
    try {
      evLocations = await _api.getEvLocations();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addEvLocation(
    String name,
    double lat,
    double lng,
    String status,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.addEvLocation(name, lat, lng, status);
      await fetchEvLocations();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchBookingConfig() async {
    _setLoading(true);
    _setError(null);
    try {
      bookingConfig = await _api.checkBookingConfig();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateBookingConfig(Map<String, bool> config) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.configureBookingPermissions(config);
      await fetchBookingConfig();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchLocations() async {
    _setLoading(true);
    _setError(null);
    try {
      locations = await _api.getLocations();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> adminBookBatteryVehicle(
    int fromId,
    int toId,
    String reason,
    String passengerName,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.adminBookBatteryVehicle(fromId, toId, reason, passengerName);
      await fetchAllBookings();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<String> bookVehicle(
    dynamic fromId,
    dynamic toId,
    double lat,
    double lng,
    String reason,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      final config = await _api.checkBookingConfig();
      final role = await UserStore.getRole();
      if (role != null) {
        final lowerRole = role.toLowerCase();
        if (lowerRole == 'faculty' &&
            config['is_faculty_booking_enabled'] == false) {
          throw Exception("Faculty booking is currently disabled by Admin.");
        }
        if (lowerRole == 'student' &&
            config['is_student_booking_enabled'] == false) {
          throw Exception("Student booking is currently disabled by Admin.");
        }
        if ((lowerRole == 'non_teaching' || lowerRole == 'nonteaching') &&
            config['is_non_teaching_booking_enabled'] == false) {
          throw Exception(
            "Non-Teaching booking is currently disabled by Admin.",
          );
        }
        if (lowerRole == 'intern' &&
            config['is_intern_booking_enabled'] == false) {
          throw Exception("Intern booking is currently disabled by Admin.");
        }
      }

      final message = await _api.bookBatteryVehicle(
        int.tryParse(fromId.toString()) ?? 0,
        int.tryParse(toId.toString()) ?? 0,
        reason,
      );
      await fetchPassengerBookings();
      return message;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> scanDriverQr(String bookingId, String qrCodeData) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.scanDriverQr(bookingId, qrCodeData);
      await fetchPassengerBookings();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchPassengerBookings() async {
    _setLoading(true);
    _setError(null);
    try {
      List<dynamic> raw = await _api.getMyBookings();
      if (raw.isEmpty) {
        try {
          final userId = await UserStore.getUserId();
          final all = await _api.getBookings();
          raw = all.where((b) {
            if (b['user_id']?.toString() == userId?.toString()) return true;
            final reqUser = b['requestUser'];
            if (reqUser is Map) {
              return reqUser['id']?.toString() == userId?.toString();
            }
            return false;
          }).toList();
        } catch (_) {}
      }
      
      final uniqueMap = <String, dynamic>{};
      for (var b in raw) {
        final id = b['id'] ?? b['booking_id'];
        if (id != null) uniqueMap[id.toString()] = b;
      }
      passengerBookings = uniqueMap.values.toList();
    } catch (e) {
      debugPrint("FETCH PASSENGER BOOKINGS ERROR: $e");
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchEvSchedules() async {
    _setLoading(true);
    _setError(null);
    try {
      final driverId = await UserStore.getDriverId();
      if (driverId != null) {
        evSchedules = await _api.getEvSchedules(driverId.toString());
      } else {
        evSchedules = [];
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> fetchEvScheduleDetails(
    String assignmentId,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      return await _api.getEvScheduleDetails(assignmentId);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> startEvDuty(
    String shiftId,
    String vehicleId,
    double startOdo,
    double batteryStart,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.startEvDuty(shiftId, vehicleId, startOdo, batteryStart);
      await fetchEvSchedules();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  List<dynamic> activeEvDrivers = [];

  Future<void> fetchActiveEvDrivers() async {
    _setLoading(true);
    _setError(null);
    try {
      activeEvDrivers = await _api.getActiveEvDrivers();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchAllBookings() async {
    _setLoading(true);
    _setError(null);
    try {
      final rawBookings = await _api.getBookings();
      final uniqueMap = <String, dynamic>{};
      for (var b in rawBookings) {
        final id = b['id'] ?? b['booking_id'];
        if (id != null) {
          uniqueMap[id.toString()] = b;
        }
      }
      allBookings = uniqueMap.values.where((b) {
        final s = (b['status'] ?? '').toString().toUpperCase();
        return s != 'DELETED';
      }).toList();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchPendingDashboardBookings() async {
    _setLoading(true);
    _setError(null);
    try {
      final raw = await _api.getPendingDriverBookingsForDashboard();
      final uniqueMap = <String, dynamic>{};
      for (var b in raw) {
        final id = b['id'] ?? b['booking_id'];
        if (id != null) uniqueMap[id.toString()] = b;
      }
      pendingDashboardBookings = uniqueMap.values.toList();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchDriverBookings({String? date}) async {
    _setLoading(true);
    _setError(null);
    debugLog = 'Starting fetch...\n';
    try {
      List<dynamic> allRawBookings = [];

      debugLog += 'Found ${evSchedules.length} schedules.\n';
      // 1. Fetch for every schedule the driver has
      for (var s in evSchedules) {
        final sid = s['id']?.toString();
        debugLog += 'Checking schedule $sid...\n';
        if (sid != null && sid.isNotEmpty) {
          final b = await _api.getDriverBookings(sid, date: date);
          debugLog += 'Got ${b.length} from $sid.\n';
          allRawBookings.addAll(b);
        }
      }

      final bFallback = await _api.getDriverBookings('', date: date);
      debugLog += 'Got ${bFallback.length} from fallback.\n';
      allRawBookings.addAll(bFallback);

      // HARDCODE 101 to see if it's the missing link
      try {
        final b101 = await _api.getDriverBookings('101', date: date);
        debugLog += 'Got ${b101.length} from 101.\n';
        allRawBookings.addAll(b101);
      } catch (e) {
        debugLog += 'Error 101: $e\n';
      }

      final uniqueMap = <String, dynamic>{};
      print("ALL RAW BOOKINGS LENGTH: ${allRawBookings.length}");
      for (var b in allRawBookings) {
        final id = b['id'] ?? b['booking_id'];
        print("PROCESSING BOOKING: id=$id, status=${b['status']}");
        if (id != null) {
          b['id'] = id; // Normalize for UI
          uniqueMap[id.toString()] = b;
        }
      }

      driverBookings = uniqueMap.values.where((b) {
        final s = (b['status'] ?? '').toString().toUpperCase();
        print("FILTERING BOOKING: id=${b['id']}, status=$s");
        return s != 'DELETED' && s != 'CANCELLED';
      }).toList();
      print("FINAL DRIVER BOOKINGS LENGTH: ${driverBookings.length}");
      debugLog += 'Total unique valid: ${driverBookings.length}\n';
    } catch (e) {
      debugLog += 'Error: $e';
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  void expireBookingLocally(String bookingId) {
    for (var b in driverBookings) {
      final id = (b['id'] ?? b['booking_id'])?.toString();
      if (id == bookingId) {
        b['status'] = 'EXPIRED';
        break;
      }
    }
    notifyListeners();
  }

  Future<String> acceptRide(String bookingId) async {
    _setLoading(true);
    try {
      final msg = await _api.acceptRide(bookingId);
      await fetchPendingDashboardBookings();
      await fetchDriverBookings();
      return msg;
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> rejectRide(String bookingId) async {
    _setLoading(true);
    try {
      await _api.rejectRide(bookingId);
      await fetchDriverBookings();
    } catch (e) {
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Faculty submits OTP to start the ride (moves status STARTED → ONGOING)
  Future<void> submitOtp(String bookingId, String otp) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.sendOtpForRide(bookingId, otp);
      await fetchPassengerBookings();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> driverStartTrip(
    String bookingId, {
    String? otp,
    String? qrCodeData,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final driverId = await UserStore.getDriverId();
      if (driverId != null) {
        await _api.driverStartTrip(
          bookingId,
          driverId,
          otp: otp,
          qrCodeData: qrCodeData,
        );
        await fetchPendingDashboardBookings();
        await fetchDriverBookings();
      }
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> completeRide(String bookingId) async {
    _setLoading(true);
    _setError(null);
    try {
      final driverId = await UserStore.getDriverId();
      if (driverId != null) {
        await _api.completeRide(bookingId, driverId);
        await fetchPendingDashboardBookings();
        await fetchDriverBookings();
      }
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> assignDriver(String bookingId, int driverId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.assignDriver(bookingId, driverId);
      await fetchAllBookings();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> cancelBooking(String bookingId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.cancelBooking(bookingId);
      await fetchAllBookings();
      await fetchPassengerBookings();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteBooking(String bookingId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.deleteBooking(bookingId);
      await fetchAllBookings();
      await fetchPassengerBookings();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<dynamic>> getDutyVehicles(String dutyId) async {
    _setLoading(true);
    _setError(null);
    try {
      return await _api.getDutyVehicles(dutyId);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> startDutyVehicle(
    String dutyId,
    String vehicleId,
    int driverId,
    int odometerStart,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      await _api.startDutyVehicle(dutyId, vehicleId, driverId, odometerStart);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
}
