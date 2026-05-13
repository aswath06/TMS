import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
    _updateNotificationUI(flutterLocalNotificationsPlugin, "");

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
  // No-op to completely hide the background service notification in the notification drawer
}

class AndroidAndroidNotificationDetailsSpec extends AndroidNotificationDetails {
  const AndroidAndroidNotificationDetailsSpec() : super(
    'notification_channel',
    'TripZo Service',
    ongoing: false,
    icon: 'ic_launcher',
    importance: Importance.min,
    priority: Priority.min,
    showWhen: false,
  );
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
