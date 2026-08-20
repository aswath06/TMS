import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../screens/driver/driver_task_details_page.dart';
import '../utils/routes.dart';

// Top-level callback for background notification taps.
// MUST be a top-level function (not inside a class) so it can run in a
// separate isolate on iOS when the app is in the background/terminated.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint(
      '🔔 [BG] Notification tapped in background: ${notificationResponse.payload}');
}

class NotificationLocalService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // ── Android Settings ────────────────────────────────────────────────────
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint(
            '🔔 [FG] Notification tapped (foreground): ${details.payload}');
        final payload = details.payload;
        if (payload != null && payload.isNotEmpty) {
          AppRoutes.navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => DriverTaskDetailsPage(taskId: payload),
            ),
          );
        } else {
          AppRoutes.navigatorKey.currentState?.pushNamed(AppRoutes.notifications);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // ── Android Notification Channels ───────────────────────────────────────
    // High-importance channel for general notifications
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'tms_notifications_v2',
      'TMS High Priority Notifications',
      description: 'Real-time notifications for TripZo TMS',
      importance: Importance.max,
    );

    // Critical channel for route assignment alerts (with custom sound)
    const AndroidNotificationChannel assignmentChannel =
        AndroidNotificationChannel(
      'route_assignment_channel_v3',
      'Route Assignments',
      description: 'Critical alerts for new route assignments',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('alerttone'),
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(assignmentChannel);

    // ── Android 13+ (API 33+): Request runtime POST_NOTIFICATIONS permission ──
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // ── iOS: Request local notification permission if not already granted ───
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Shows a standard high-priority notification.
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'tms_notifications_v2',
      'TMS High Priority Notifications',
      channelDescription: 'Real-time notifications for TripZo TMS',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      color: Color(0xFF6366F1), // TripZo Primary Indigo
      enableLights: true,
      ledColor: Color(0xFF6366F1),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Shows a critical route-assignment alert with custom sound.
  static Future<void> showRouteAssignmentAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      final Int32List additionalFlags =
          Int32List.fromList(<int>[4]); // FLAG_INSISTENT

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'route_assignment_channel_v3',
        'Route Assignments',
        channelDescription: 'Critical alerts for new route assignments',
        importance: Importance.max,
        priority: Priority.high,
        sound: const RawResourceAndroidNotificationSound('alerttone'),
        additionalFlags: additionalFlags,
        color: const Color(0xFFEF4444), // Critical Alert Red
        enableLights: true,
        ledColor: const Color(0xFFEF4444),
        ledOnMs: 1000,
        ledOffMs: 500,
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'acknowledge_action',
            'Acknowledge',
            cancelNotification: true,
          ),
        ],
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'alerttone.mp3',
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint("🔔 Primary notification alert error: $e. Retrying standard notification...");
      try {
        await showNotification(id: id, title: title, body: body, payload: payload);
      } catch (err) {
        debugPrint("🔔 Notification fallback error: $err");
      }
    }
  }
}
