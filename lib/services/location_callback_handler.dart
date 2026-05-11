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
import 'package:tripzo/services/notification_socket_service.dart';
import 'package:tripzo/models/notification_model.dart';

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // 1. Setup Service Listeners
    service.on('stopService').listen((event) {
      debugPrint("[BackgroundService] Stopping service...");
      service.stopSelf();
    });

    service.on('updateConfig').listen((event) async {
      // Config updates handle socket refreshes if needed
      _initializeSocket(service, flutterLocalNotificationsPlugin);
    });

    // 2. Initialize Notification Plugin
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    debugPrint("[BackgroundService] Isolate initialized successfully");
    _updateNotificationUI(flutterLocalNotificationsPlugin, "Listening for real-time notifications...");

    // 3. Initialize Notification Socket (PERSISTENT SOCKET LOGIC)
    _initializeSocket(service, flutterLocalNotificationsPlugin);

    // 4. Robustness: Periodically check/reconnect socket connection to keep it alive
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      _initializeSocket(service, flutterLocalNotificationsPlugin);
    });
  } catch (e, stack) {
    debugPrint("[BackgroundService] CRITICAL ISOLATE ERROR: $e");
    debugPrint(stack.toString());
  }
}

// Helper to update background persistent service indicator
void _updateNotificationUI(FlutterLocalNotificationsPlugin notifications, String subText, {bool isHighPriority = false}) {
  notifications.show(
    888,
    'TripZo Service',
    subText,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'notification_channel',
        'TripZo Service',
        ongoing: true,
        icon: 'ic_launcher',
        importance: Importance.low,
        priority: Priority.low,
        showWhen: false,
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

    if (token == null) {
      debugPrint("[BackgroundService] No token found. Stopping service.");
      service.stopSelf();
      return;
    }

    if (tripId == null) {
      debugPrint("[BackgroundService] No active trip. Skipping GPS poll, but keeping service alive for notifications.");
      _updateNotificationUI(notifications, "Ready for next mission");
      return;
    }

    _updateNotificationUI(notifications, "Syncing current position...");
    debugPrint("[BackgroundService] Attempting to acquire GPS fix for Trip #$tripId...");
    
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
      
      // If movement is very small (< 2m), check when we last synced
      if (distance < 2.0) {
        final lastSyncTimeStr = prefs.getString('last_sync_timestamp');
        if (lastSyncTimeStr != null) {
          final lastSync = DateTime.parse(lastSyncTimeStr);
          final minutesSinceLastSync = DateTime.now().difference(lastSync).inMinutes;
          
          // Force a heartbeat every 10 minutes even if no movement
          if (minutesSinceLastSync < 10) {
            shouldSend = false;
            debugPrint("[BackgroundService] Minimal movement ($distance m) and last sync was only $minutesSinceLastSync mins ago. Skipping sync.");
          } else {
            debugPrint("[BackgroundService] Minimal movement ($distance m) but forcing heartbeat sync after $minutesSinceLastSync mins.");
          }
        }
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
      await prefs.setString('last_sync_timestamp', DateTime.now().toIso8601String());
      
      // Notify timer to reset
      service.invoke('sync_triggered');
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

// Global reference for socket persistence in isolate
NotificationSocketService? _globalSocketService;

Future<void> _initializeSocket(ServiceInstance service, FlutterLocalNotificationsPlugin notifications) async {
  try {
    final token = await UserStore.getToken();
    if (token == null) return;

    if (_globalSocketService != null && _globalSocketService!.socket?.connected == true) {
      debugPrint("[BackgroundService] Socket already connected. Skipping re-init.");
      return;
    }

    debugPrint("[BackgroundService] (Re)Initializing Notification Socket...");
    _globalSocketService?.disconnect();
    _globalSocketService = NotificationSocketService();
    
    _globalSocketService!.connect(
      socketBaseUrl: ApiConstants.baseUrl,
      token: token,
      onNewNotification: (data) async {
        debugPrint("[BackgroundService] 🔔 New Socket Notification: $data");
        
        try {
          final notification = NotificationModel.fromJson(data);
          
          await notifications.show(
            notification.id,
            notification.title,
            notification.message,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'tms_notifications',
                'TMS Notifications',
                channelDescription: 'Real-time notifications for TripZo TMS',
                importance: Importance.max,
                priority: Priority.high,
                fullScreenIntent: true,
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
          );

          service.invoke('new_notification_received', data);
        } catch (e) {
          debugPrint("[BackgroundService] Notification parsing error: $e");
        }
      },
      onConnected: () => debugPrint("[BackgroundService] Notification Socket Connected"),
      onDisconnected: () => debugPrint("[BackgroundService] Notification Socket Disconnected"),
      onError: (err) => debugPrint("[BackgroundService] Notification Socket Error: $err"),
    );
  } catch (e) {
    debugPrint("[BackgroundService] Socket Init Error: $e");
  }
}
