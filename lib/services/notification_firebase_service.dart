import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'notification_local_service.dart';
import '../models/notification_model.dart';

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");

  try {
    final data = message.data;
    final eventType = data['event'];
    
    if (eventType == 'notification:new') {
      await NotificationLocalService.initialize();
      final notification = NotificationModel.fromJson(data);
      
      await NotificationLocalService.showNotification(
        id: notification.id,
        title: notification.title,
        body: notification.message,
      );
    }
  } catch (e) {
    debugPrint("Error handling background message: $e");
  }
}

class NotificationFirebaseService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  Function(Map<String, dynamic>)? onNewNotification;

  Future<void> initialize({
    required Function(Map<String, dynamic>) onNewNotification,
  }) async {
    this.onNewNotification = onNewNotification;

    // Request permissions (especially for iOS)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
      }

      if (this.onNewNotification != null && message.data.isNotEmpty) {
         this.onNewNotification!(message.data);
      }
    });

    // Handle messages that open the app from terminated state
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null && this.onNewNotification != null && initialMessage.data.isNotEmpty) {
      this.onNewNotification!(initialMessage.data);
    }

    // Handle messages that open the app from background state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (this.onNewNotification != null && message.data.isNotEmpty) {
        this.onNewNotification!(message.data);
      }
    });
  }

  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }
}
