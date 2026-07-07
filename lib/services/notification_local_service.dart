import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../utils/routes.dart';

// Top-level callback for background notification taps.
// MUST be a top-level function (not inside a class) so it can run in a
// separate isolate on iOS when the app is in the background/terminated.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint(
      '🔔 [BG] Notification tapped in background: ${notificationResponse.payload}');
  // Note: You cannot navigate here because the Flutter engine may not be ready.
  // Navigation on tap is handled in the foreground handler below.
}

class NotificationLocalService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // ── Android Settings ────────────────────────────────────────────────────
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // ── iOS Settings ────────────────────────────────────────────────────────
    // Set request*Permission to false here because we request permissions
    // via Firebase Messaging (requestPermission()) which is more reliable
    // and gives us the authorization status. Setting these to true here would
    // show a SECOND permission dialog which is confusing for users.
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      // IMPORTANT: These default presentation options control how
      // flutter_local_notifications shows notifications when the app is
      // in the FOREGROUND on iOS. Setting all to true ensures banners,
      // sounds and badge updates appear even while the app is open.
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
      // Foreground tap handler — called when user taps a notification while
      // the app is in the foreground.
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint(
            '🔔 [FG] Notification tapped (foreground): ${details.payload}');
        // Navigate to the notifications screen
        AppRoutes.navigatorKey.currentState?.pushNamed(AppRoutes.notifications);
      },
      // Background tap handler — called when user taps a notification while
      // the app is in the background or terminated.
      // MUST be a top-level function annotated with @pragma('vm:entry-point').
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

    // ── iOS: Request local notification permission if not already granted ───
    // This is a belt-and-suspenders check — Firebase already requests it,
    // but this ensures flutter_local_notifications also has the entitlement.
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

    // iOS notification details — presentAlert/presentBadge/presentSound
    // tell iOS to show the banner + play sound + update badge even when
    // the app is in the FOREGROUND (essential for WhatsApp-style behaviour).
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

    // Critical iOS alert — time-sensitive interruption level ensures it
    // breaks through Focus modes (like WhatsApp calls / critical alerts).
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
  }
}
