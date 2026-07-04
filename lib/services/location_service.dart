import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripzo/services/location_callback_handler.dart';
import 'package:tripzo/store/user_store.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // 1. Create Notification Channels
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'notification_channel',
      'TripZo Service',
      description: 'Persistent notification service for background updates',
      importance: Importance.min,
    );

    const AndroidNotificationChannel notificationChannel = AndroidNotificationChannel(
      'tms_notifications',
      'TMS Notifications',
      description: 'Real-time notifications for TripZo TMS',
      importance: Importance.max,
    );

    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(notificationChannel);

    // 2. Configure Service with top-level entry point
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart, // From location_callback_handler.dart
        autoStart: true,
        isForegroundMode: false,
        notificationChannelId: 'notification_channel',
        initialNotificationTitle: 'TripZo Active',
        initialNotificationContent: '',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart, // From location_callback_handler.dart
        onBackground: onIosBackground,
      ),
    );

    // 3. Auto-start background service if any user is logged in
    final token = await UserStore.getToken();
    if (token != null && token.isNotEmpty) {
      bool isRunning = await service.isRunning();
      if (!isRunning) {
        debugPrint("[LocationService] Background service auto-starting for real-time notifications.");
        await service.startService();
      }
    }
  }

  Future<void> startTracking(int tripInstanceId) async {
    debugPrint("[LocationService] Background tracking is completely disabled.");
    return;
  }

  Future<void> stopTracking() async {
    debugPrint("[LocationService] Stopping tracking process...");
    final service = FlutterBackgroundService();
    service.invoke('stopService');
    
    // Cleanup state
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_trip_instance_id');
    await prefs.remove('last_lat');
    await prefs.remove('last_lon');
  }
}
