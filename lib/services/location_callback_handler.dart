import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    bool isGpsDisabled = false;

    // 1. Setup Service Listeners
    service.on('stopService').listen((event) {
      debugPrint("[BackgroundService] Stopping service...");
      service.stopSelf();
    });

    // 2. Initialize Notification Plugin
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    debugPrint("[BackgroundService] Isolate initialized successfully");
    _updateNotificationUI(flutterLocalNotificationsPlugin, "GPS Service Active. Polling...");

    // 3. Start UI Timer immediately
    int secondsToNextSync = 120;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      secondsToNextSync--;
      if (secondsToNextSync < 0) secondsToNextSync = 120;
      if (!isGpsDisabled) {
        _updateNotificationUI(flutterLocalNotificationsPlugin, "Next update in: ${secondsToNextSync}s");
      }
    });

    // 4. Monitor GPS Status
    Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      isGpsDisabled = status == ServiceStatus.disabled;
      if (isGpsDisabled) {
        _updateNotificationUI(flutterLocalNotificationsPlugin, "⚠️ GPS DISABLED! Please turn on GPS.", isHighPriority: true);
      }
    });

    // 5. Initial Update (Non-blocking)
    _performUpdate(service, flutterLocalNotificationsPlugin).catchError((e) => debugPrint("Init update error: $e"));

    // 6. Sync Timer
    Timer.periodic(const Duration(seconds: 120), (timer) async {
      await _performUpdate(service, flutterLocalNotificationsPlugin).catchError((e) => debugPrint("Sync Error: $e"));
      secondsToNextSync = 120;
    });
  } catch (e, stack) {
    debugPrint("[BackgroundService] CRITICAL ISOLATE ERROR: $e");
    debugPrint(stack.toString());
    try {
      final notifications = FlutterLocalNotificationsPlugin();
      notifications.show(
        888,
        'TripZo Service Crash',
        'Error: ${e.toString().split('\n')[0]}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'location_tracking_channel',
            'TripZo Tracking',
            ongoing: false,
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {}
  }
}

// Helper to update notification without full GPS poll
void _updateNotificationUI(FlutterLocalNotificationsPlugin notifications, String subText, {bool isHighPriority = false}) {
  notifications.show(
    888,
    'TripZo Tracking',
    subText,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'location_tracking_channel',
        'TripZo Tracking',
        ongoing: true,
        icon: 'ic_launcher',
        importance: isHighPriority ? Importance.high : Importance.low,
        priority: isHighPriority ? Priority.high : Priority.low,
        showWhen: false,
        color: isHighPriority ? Colors.red : null,
      ),
    ),
  );
}

Future<void> _performUpdate(
    ServiceInstance service, FlutterLocalNotificationsPlugin notifications) async {
  try {
    // 0. Verify Trip State BEFORE polling GPS
    final prefs = await SharedPreferences.getInstance();
    final tripId = prefs.getInt('active_trip_instance_id');
    final token = await UserStore.getToken();

    if (tripId == null || token == null) {
      debugPrint("[BackgroundService] No active trip or token. Stopping service.");
      service.stopSelf();
      return;
    }

    _updateNotificationUI(notifications, "Syncing current position...");
    debugPrint("[BackgroundService] Polling GPS...");
    
    Position? position;
    
    // Try last known first for speed
    position = await Geolocator.getLastKnownPosition();
    if (position != null) {
      debugPrint("[BackgroundService] Quick fix from LastKnown.");
    }

    // Attempt high accuracy fix if quick fix is old or missing
    try {
      final highAccPosition = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          forceLocationManager: true,
        ),
      ).timeout(const Duration(seconds: 25));
      position = highAccPosition;
      debugPrint("[BackgroundService] High accuracy fix obtained.");
    } catch (e) {
      debugPrint("[BackgroundService] High accuracy failed/timeout. Using best available.");
    }

    if (position == null) {
      debugPrint("[BackgroundService] Total GPS Fail.");
      _updateNotificationUI(notifications, "⚠️ GPS FIX FAILED! Check signals.", isHighPriority: true);
      return;
    }

    debugPrint("[BackgroundService] GPS Fix: ${position.latitude}, ${position.longitude}");

    final lastLat = prefs.getDouble('last_lat');
    final lastLon = prefs.getDouble('last_lon');

    bool shouldSend = true;
    if (lastLat != null && lastLon != null) {
      double distance = Geolocator.distanceBetween(
          lastLat, lastLon, position.latitude, position.longitude);
      if (distance < 2.0) {
        shouldSend = false;
        debugPrint("[BackgroundService] Moved only $distance m. Skipping API sync.");
      }
    }

    if (shouldSend) {
      final timeStr = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}";
      
      // Update Notification
      _updateNotificationUI(notifications, 'Last Sync: $timeStr');

      // Backend Sync
      await _syncLocation(position.latitude, position.longitude, tripId, token);

      // Save Last State
      await prefs.setDouble('last_lat', position.latitude);
      await prefs.setDouble('last_lon', position.longitude);
    }
  } catch (e) {
    debugPrint("[BackgroundService] System Error: $e");
    String errorMsg = "⚠️ System Error - Retrying...";
    if (e.toString().contains("LocationServiceDisabledException") || 
        e.toString().contains("location services are disabled")) {
      errorMsg = "⚠️ GPS OFF - Tracking Paused!";
    } else if (e is TimeoutException) {
      errorMsg = "⚠️ GPS Search Timeout - Retrying...";
    }
    
    _updateNotificationUI(
      notifications, 
      errorMsg, 
      isHighPriority: true
    );
  }
}

Future<void> _syncLocation(double lat, double lon, int tripId, String token) async {
  try {
    final body = {
      "latitude": lat,
      "longitude": lon,
      "recorded_at": DateTime.now().toIso8601String().split('.')[0], // Format: YYYY-MM-DDTHH:MM:SS
    };

    final url = ApiConstants.locationPing(tripId);
    final headers = ApiConstants.getHeaders(token);

    final timeStamp = "[${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}]";
    debugPrint("--- $timeStamp BACKGROUND LOCATION PING ---");
    debugPrint("URL: $url");
    String curl = "curl --location --request POST '$url' \\\n";
    headers.forEach((k, v) => curl += "--header '$k: $v' \\\n");
    curl += "--data '${jsonEncode(body)}'";
    debugPrint(curl);

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );

    debugPrint("--- RESPONSE ---");
    debugPrint("Status: ${response.statusCode}");
    debugPrint("Body: ${response.body}");
    debugPrint("------------------------------------------");
  } catch (e) {
    debugPrint("[BackgroundService] API Error: $e");
  }
}
