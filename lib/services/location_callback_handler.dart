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

    service.on('updateConfig').listen((event) async {
      if (event != null) {
        final tripId = event['tripId'];
        debugPrint("[BackgroundService] New configuration received for Trip #$tripId. Forcing sync...");
        
        // Force an immediate update
        await _performUpdate(service, flutterLocalNotificationsPlugin);
      }
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
    
    // Listen for manual sync triggers to reset countdown
    service.on('sync_triggered').listen((event) {
      secondsToNextSync = 120;
    });

    Timer.periodic(const Duration(seconds: 1), (timer) {
      secondsToNextSync--;
      if (secondsToNextSync < 0) {
        secondsToNextSync = 120;
      }
      
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

    // 6. Sync Timer (Heartbeat and Location)
    Timer.periodic(const Duration(seconds: 120), (timer) async {
      debugPrint("[BackgroundService] Scheduled Sync Timer Fired.");
      await _performUpdate(service, flutterLocalNotificationsPlugin).catchError((e) => debugPrint("Sync Error: $e"));
      // Reset UI countdown
      service.invoke('sync_triggered');
    });

    // 7. Initialize Notification Socket (PERSISTENT LOGIC)
    final token = await UserStore.getToken();
    if (token != null) {
      debugPrint("[BackgroundService] Initializing Notification Socket...");
      final socketService = NotificationSocketService();
      socketService.connect(
        socketBaseUrl: ApiConstants.baseUrl,
        token: token,
        onNewNotification: (data) async {
          debugPrint("[BackgroundService] 🔔 New Socket Notification: $data");
          
          try {
            final notification = NotificationModel.fromJson(data);
            
            // Show Local Notification
            await flutterLocalNotificationsPlugin.show(
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
                ),
                iOS: DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
            );

            // Notify Foreground App if it's running
            service.invoke('new_notification_received', data);
          } catch (e) {
            debugPrint("[BackgroundService] Notification parsing error: $e");
          }
        },
        onConnected: () => debugPrint("[BackgroundService] Notification Socket Connected"),
        onDisconnected: () => debugPrint("[BackgroundService] Notification Socket Disconnected"),
        onError: (err) => debugPrint("[BackgroundService] Notification Socket Error: $err"),
      );

      // Store socketService reference to keep it alive or for cleanup if needed
      // (Isolate keeps it alive as long as listeners exist)
    }
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
