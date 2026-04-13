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

// Current session cache for the background isolate
String? _cachedToken;
int? _cachedTripId;

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_notification');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  print("[BackgroundService] Isolate initialized successfully");

  service.on('stopService').listen((event) {
    print("[BackgroundService] Stopping service...");
    service.stopSelf();
  });

  service.on('updateConfig').listen((event) {
    if (event != null) {
      _cachedToken = event['token'];
      _cachedTripId = event['tripId'];
      print("[BackgroundService] Isolate Config Sync: Trip #$_cachedTripId");
    }
  });

  // Track if GPS is currently disabled to avoid spamming notifications
  bool isGpsDisabled = false;

  // 0. Monitor GPS Status changes
  Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
    if (status == ServiceStatus.disabled) {
      isGpsDisabled = true;
      _updateNotificationUI(
        flutterLocalNotificationsPlugin, 
        "⚠️ GPS DISABLED! Please turn on GPS.",
        isCritical: true,
      );
    } else {
      isGpsDisabled = false;
      _updateNotificationUI(
        flutterLocalNotificationsPlugin, 
        "GPS Restored. Resuming tracking...",
        isCritical: false,
      );
    }
  });

  int secondsToNextSync = 300;

  // Perform initial update immediately
  _performUpdate(service, flutterLocalNotificationsPlugin);

  // 1. Countdown Timer (Updates UI every second)
  Timer.periodic(const Duration(seconds: 1), (timer) {
    secondsToNextSync--;
    if (secondsToNextSync < 0) secondsToNextSync = 300;
    
    // Update notification with countdown (only if GPS is active)
    if (!isGpsDisabled) {
      _updateNotificationUI(flutterLocalNotificationsPlugin, "Next sync in: ${secondsToNextSync}s");
    }
  });

  // 2. Sync Timer (Polls GPS and sends data every 5 minutes)
  Timer.periodic(const Duration(seconds: 300), (timer) async {
    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) return;
    }
    await _performUpdate(service, flutterLocalNotificationsPlugin);
    secondsToNextSync = 300; // Reset countdown after sync
  });
}

// Helper to update notification without full GPS poll
void _updateNotificationUI(FlutterLocalNotificationsPlugin notifications, String subText, {bool isCritical = false}) {
  notifications.show(
    888,
    'TripZo Tracking',
    subText,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'location_tracking_channel',
        'TripZo Tracking',
        ongoing: true,
        icon: 'ic_notification',
        importance: isCritical ? Importance.max : Importance.low,
        priority: isCritical ? Priority.high : Priority.low,
        showWhen: false,
        color: isCritical ? Colors.red : null,
      ),
    ),
  );
}

Future<void> _performUpdate(
    ServiceInstance service, FlutterLocalNotificationsPlugin notifications) async {
  try {
    print("[BackgroundService] Polling GPS...");
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    );
    print("[BackgroundService] GPS Fix: ${position.latitude}, ${position.longitude}");

    final prefs = await SharedPreferences.getInstance();
    double? lastLat = prefs.getDouble('last_lat');
    double? lastLon = prefs.getDouble('last_lon');

    bool shouldSend = true;
    if (lastLat != null && lastLon != null) {
      double distance = Geolocator.distanceBetween(
          lastLat, lastLon, position.latitude, position.longitude);
      if (distance < 2.0) {
        shouldSend = false;
        print("[BackgroundService] Moved only $distance m. Skipping API sync.");
      }
    }

    if (shouldSend) {
      final timeStr = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}";
      notifications.show(
        888,
        'TripZo Tracking',
        'Last Sync: $timeStr',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'location_tracking_channel',
            'TripZo Tracking',
            ongoing: true,
            icon: 'ic_notification',
            importance: Importance.low,
            priority: Priority.low,
          ),
        ),
      );

      // Backend Sync
      await _syncLocation(position.latitude, position.longitude);

      // Save Last State
      await prefs.setDouble('last_lat', position.latitude);
      await prefs.setDouble('last_lon', position.longitude);
    }
  } catch (e) {
    print("[BackgroundService] System Error: $e");
    if (e.toString().contains("LocationServiceDisabledException") || 
        e.toString().contains("location services are disabled")) {
       _updateNotificationUI(
        notifications, 
        "⚠️ GPS OFF - Tracking Paused!", 
        isCritical: true
      );
    }
  }
}

Future<void> _syncLocation(double lat, double lon) async {
  try {
    final token = _cachedToken ?? await UserStore.getToken();
    final prefs = await SharedPreferences.getInstance();
    final tripId = _cachedTripId ?? prefs.getInt('active_trip_instance_id');

    if (token == null || tripId == null) {
      print("[BackgroundService] Missing Token or TripID (TripID: $tripId, Token: ${token != null ? 'Exists' : 'Null'})");
      return;
    }

    final body = {
      "latitude": lat,
      "longitude": lon,
      "recorded_at": DateTime.now().toIso8601String().split('.')[0], // Format: YYYY-MM-DDTHH:MM:SS
    };

    final url = ApiConstants.locationPing(tripId);
    final headers = ApiConstants.getHeaders(token);

    final timeStamp = "[${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}]";
    print("--- $timeStamp BACKGROUND LOCATION PING ---");
    print("URL: $url");
    String curl = "curl --location --request POST '$url' \\\n";
    headers.forEach((k, v) => curl += "--header '$k: $v' \\\n");
    curl += "--data '${jsonEncode(body)}'";
    print(curl);

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    );

    print("--- RESPONSE ---");
    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");
    print("------------------------------------------");
  } catch (e) {
    print("[BackgroundService] API Error: $e");
  }
}
