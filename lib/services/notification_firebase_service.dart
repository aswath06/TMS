import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'notification_local_service.dart';
import '../models/notification_model.dart';

// Top-level background message handler.
// MUST be a top-level function (not a class method) and annotated with @pragma.
// This runs in a SEPARATE ISOLATE when the app is in background/terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Must initialize Flutter and Firebase before doing anything else
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  debugPrint("🔔 [BG] Handling background message: ${message.messageId}");

  try {
    final data = message.data;
    final eventType = data['event'];

    if (eventType == 'notification:new') {
      await NotificationLocalService.initialize();
      final notification = NotificationModel.fromJson(data);
      if (notification.type.toUpperCase() == 'ALERT') {
        await NotificationLocalService.showRouteAssignmentAlert(
          id: notification.id,
          title: notification.title,
          body: notification.message,
        );
      } else {
        await NotificationLocalService.showNotification(
          id: notification.id,
          title: notification.title,
          body: notification.message,
        );
      }
    }
  } catch (e) {
    debugPrint("🔔 [BG] Error handling background message: $e");
  }
}

class NotificationFirebaseService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  Function(Map<String, dynamic>)? onNewNotification;

  Future<void> initialize({
    required Function(Map<String, dynamic>) onNewNotification,
  }) async {
    this.onNewNotification = onNewNotification;

    // ── Step 1: Request permissions (critical for iOS) ──────────────────────
    final NotificationSettings settings =
        await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint(
        '🔔 iOS notification permission: ${settings.authorizationStatus}');

    // ── Step 2: iOS foreground presentation options ──────────────────────────
    // This tells Firebase to show the system notification banner/sound/badge
    // even when the app is in the FOREGROUND (like WhatsApp).
    // On iOS, FCM suppresses the visual notification by default when the app
    // is open — this overrides that behaviour.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // ── Step 3: NOTE — background handler is already registered in main() ───
    // Do NOT register it again here — double registration can cause issues.
    // FirebaseMessaging.onBackgroundMessage() is already called in main.dart.

    // ── Step 4: Foreground message listener ─────────────────────────────────
    // onMessage fires when a push arrives while the app is in the FOREGROUND.
    // On Android, we must show a local notification manually (FCM won't show
    // a system banner while the app is active on Android).
    // On iOS, setForegroundNotificationPresentationOptions (Step 2) + the
    // AppDelegate.willPresent delegate already handle showing the banner natively,
    // but we still call onNewNotification so the app state updates.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('🔔 [FG] Foreground message received: ${message.messageId}');
      debugPrint('🔔 [FG] Data: ${message.data}');

      if (message.data.isNotEmpty) {
        // Update in-app state (notification list, badge count, overlay banner)
        this.onNewNotification?.call(message.data);

        // On Android, we must show the local notification manually since FCM
        // won't display a system banner while the app is in the foreground.
        // On iOS the system handles it via willPresent in AppDelegate, but
        // showing via flutter_local_notifications is harmless and gives a
        // consistent in-app overlay experience.
        try {
          final data = message.data;
          final eventType = data['event'];
          if (eventType == 'notification:new') {
            final notification = NotificationModel.fromJson(data);
            if (notification.type.toUpperCase() == 'ALERT') {
              await NotificationLocalService.showRouteAssignmentAlert(
                id: notification.id,
                title: notification.title,
                body: notification.message,
              );
            } else {
              await NotificationLocalService.showNotification(
                id: notification.id,
                title: notification.title,
                body: notification.message,
              );
            }
          }
        } catch (e) {
          debugPrint('🔔 [FG] Error showing local notification: $e');
        }
      }

      if (message.notification != null) {
        debugPrint(
            '🔔 [FG] Notification payload: ${message.notification?.title}');
      }
    });

    // ── Step 5: Handle app launched from a TERMINATED state via notification ─
    // getInitialMessage() returns the notification that caused the app to open
    // from a fully terminated (killed) state.
    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null && initialMessage.data.isNotEmpty) {
      debugPrint(
          '🔔 [TERMINATED] App opened from killed state via notification');
      this.onNewNotification?.call(initialMessage.data);
    }

    // ── Step 6: Handle app opened from BACKGROUND state via notification ─────
    // onMessageOpenedApp fires when the user taps a notification while the
    // app was in the background (not killed).
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 [BG→FG] App brought to foreground via notification tap');
      if (message.data.isNotEmpty) {
        this.onNewNotification?.call(message.data);
      }
    });
  }

  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }
}
