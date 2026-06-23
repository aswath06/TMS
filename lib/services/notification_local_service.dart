import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';
import '../utils/routes.dart';

class NotificationLocalService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Navigate to notification list screen when notification is tapped
        AppRoutes.navigatorKey.currentState?.pushNamed(AppRoutes.notifications);
      },
    );

    // Create the high-importance channel natively so background FCM popups work
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'tms_notifications_v2', // id
      'TMS High Priority Notifications', // title
      description: 'Real-time notifications for TripZo TMS', // description
      importance: Importance.max,
    );

    const AndroidNotificationChannel assignmentChannel = AndroidNotificationChannel(
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
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'tms_notifications_v2',
      'TMS High Priority Notifications',
      channelDescription: 'Real-time notifications for TripZo TMS',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
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

  static Future<void> showRouteAssignmentAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final Int32List additionalFlags = Int32List.fromList(<int>[4]); // FLAG_INSISTENT

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'route_assignment_channel_v3',
      'Route Assignments',
      channelDescription: 'Critical alerts for new route assignments',
      importance: Importance.max,
      priority: Priority.high,
      sound: const RawResourceAndroidNotificationSound('alerttone'),
      additionalFlags: additionalFlags,
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
