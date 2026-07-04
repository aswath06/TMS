import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
      // Config updates
    });

    // 2. Initialize Notification Plugin
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    debugPrint("[BackgroundService] Isolate initialized successfully");
    _updateNotificationUI(flutterLocalNotificationsPlugin, "");

    // Removed Socket Initialization since Firebase handles background notifications natively
  } catch (e, stack) {
    debugPrint("[BackgroundService] CRITICAL ISOLATE ERROR: $e");
    debugPrint(stack.toString());
  }
}

// Helper to update background persistent service indicator
void _updateNotificationUI(FlutterLocalNotificationsPlugin notifications, String subText) {
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

