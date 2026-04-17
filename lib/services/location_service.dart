import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tripzo/services/location_callback_handler.dart';
import 'package:tripzo/store/user_store.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // 1. Create Notification Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'location_tracking_channel',
      'TripZo Tracking',
      description: 'Background service for notifications and tracking',
      importance: Importance.low,
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
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'location_tracking_channel',
        initialNotificationTitle: 'TripZo Tracking Active',
        initialNotificationContent: 'Initializing GPS Fix...',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart, // From location_callback_handler.dart
      ),
    );

    // 3. Auto-start if driver is logged in
    final role = await UserStore.getRole();
    final token = await UserStore.getToken();
    if (role == 'driver' && token != null) {
      bool isRunning = await service.isRunning();
      if (!isRunning) {
        debugPrint("[LocationService] Background service auto-starting for driver notifications.");
        await service.startService();
      }
    }
  }

  Future<void> startTracking(int tripInstanceId) async {
    // 0. Only Drivers should be tracked
    final role = await UserStore.getRole();
    if (role != 'driver') {
      debugPrint("[LocationService] Role is '$role'. Tracking is restricted to drivers only. Aborting.");
      return;
    }

    debugPrint("[LocationService] Preparing to start tracking for Trip #$tripInstanceId");

    // 1. Check & Request Permissions
    bool isEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      debugPrint("[LocationService] GPS is disabled. Tracking cannot start.");
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      debugPrint("[LocationService] Requesting location permission...");
      permission = await Geolocator.requestPermission();
    }
    
    // Request Notification permission (Android 13+)
    debugPrint("[LocationService] Requesting notification permission...");
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      debugPrint("[LocationService] Location permissions blocked. Tracking aborted.");
      return;
    }

    // 1.5 Check Battery Optimization (Critical for unplugged reliability)
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (!batteryStatus.isGranted) {
      debugPrint("[LocationService] Battery optimization exemption not granted. Requesting...");
      await Permission.ignoreBatteryOptimizations.request();
    }

    // 2. Save trip state persistently for the background isolate
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_trip_instance_id', tripInstanceId);
    await prefs.remove('last_lat'); // Reset for new trip
    await prefs.remove('last_lon');

    // 3. Start the service
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    
    final token = await UserStore.getToken();

    if (!isRunning) {
      debugPrint("[LocationService] Launching background service...");
      await service.startService();
    } else {
      debugPrint("[LocationService] Service already running. Re-syncing trip state.");
    }

    // Always push latest config to the background isolate
    debugPrint("[LocationService] Pushing config to background: Trip #$tripInstanceId");
    service.invoke('updateConfig', {
      'token': token,
      'tripId': tripInstanceId,
    });
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
