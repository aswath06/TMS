import 'package:flutter/material.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/notification_model.dart';
import '../services/notification_firebase_service.dart';
import '../services/notification_local_service.dart';
import '../services/notification_api_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../utils/api_constants.dart';
import '../utils/animated_notification.dart';

class NotificationProvider extends ChangeNotifier {
  late NotificationApiService apiService;
  final NotificationFirebaseService firebaseService;

  NotificationProvider({
    required this.apiService,
    required this.firebaseService,
  });

  List<NotificationModel> notifications = [];
  int unreadCount = 0;
  bool isFirebaseInitialized = false;
  bool isLoading = false;
  StreamSubscription? _connectivitySubscription;

  Future<void> initialize({
    String? socketBaseUrl,
    required String token,
  }) async {
    // Update API service with correct token if it was empty
    apiService = NotificationApiService(
      baseUrl: ApiConstants.baseUrl,
      token: token,
    );

    await fetchNotifications();
    await fetchUnreadCount();

    // 1. Establish Firebase Connection
    await firebaseService.initialize(
      onNewNotification: (data) async {
        debugPrint("🔔 Foreground direct firebase received notification: $data");
        try {
          final eventType = data['event'];
          if (eventType != 'notification:new') return;

          final notification = NotificationModel.fromJson(data);
          
          // Avoid duplicate if already in list
          if (notifications.any((n) => n.id == notification.id)) return;

          notifications.insert(0, notification);
          unreadCount += 1;
          notifyListeners();

          // Show real-time local push notification on screen
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

          // Show beautifully animated top-sliding premium in-app overlay banner
          showPremiumInAppNotification(
            title: notification.title,
            message: notification.message,
            type: notification.type,
          );
        } catch (e) {
          debugPrint("Error handling new firebase notification: $e");
        }
      },
    );
    isFirebaseInitialized = true;
    
    // Sync FCM token with backend
    try {
      final token = await firebaseService.getToken();
      if (token != null) {
        await apiService.updateFcmToken(token);
        debugPrint("🔔 FCM Token synced with backend");
      }
    } catch (e) {
      debugPrint("Error syncing FCM token: $e");
    }

    notifyListeners();
    debugPrint("🔔 Firebase Notification Initialized");

    // 2. Backup Listener: Also listen to the Background Service if running
    final service = FlutterBackgroundService();
    
    service.on('new_notification_received').listen((data) {
      if (data != null) {
        debugPrint("🔔 Foreground received notification from Background Service: $data");
        final notification = NotificationModel.fromJson(data);
        
        // Avoid duplicate if already in list
        if (notifications.any((n) => n.id == notification.id)) return;

        notifications.insert(0, notification);
        unreadCount += 1;
        notifyListeners();
      }
    });

    // 3. Monitor internet connection restoration to sync missed notifications
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        debugPrint("🔔 NotificationProvider: Connection restored! Syncing missed notifications...");
        await fetchNotificationsAndSyncMissed();
      }
    });
  }

  Future<void> fetchNotificationsAndSyncMissed() async {
    try {
      final fetchedList = await apiService.getMyNotifications();
      
      // Filter out notifications we already have in our list, AND are unread
      final List<NotificationModel> newUnread = [];
      for (final item in fetchedList) {
        final bool alreadyHave = notifications.any((n) => n.id == item.id);
        if (!alreadyHave && !item.isRead) {
          newUnread.add(item);
        }
      }

      // Sync local list and update unread count
      notifications = fetchedList;
      await fetchUnreadCount();
      notifyListeners();

      // Trigger standard local & top sliding animated push notifications for any missed unread notifications!
      for (final notification in newUnread.reversed) {
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

        showPremiumInAppNotification(
          title: notification.title,
          message: notification.message,
          type: notification.type,
        );
      }
    } catch (e) {
      debugPrint("Error syncing missed notifications on reconnect: $e");
    }
  }

  Future<void> fetchNotifications() async {
    isLoading = true;
    notifyListeners();

    try {
      notifications = await apiService.getMyNotifications();
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      unreadCount = await apiService.getUnreadCount();
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching unread count: $e");
    }
  }

  // ... rest of the markAsRead and markAllAsRead methods ...
  Future<void> markAsRead(int notificationId) async {
    try {
      await apiService.markAsRead(notificationId);

      final index = notifications.indexWhere((e) => e.id == notificationId);
      if (index != -1 && notifications[index].isRead == false) {
        final old = notifications[index];
        notifications[index] = NotificationModel(
          id: old.id,
          userId: old.userId,
          title: old.title,
          message: old.message,
          type: old.type,
          referenceTable: old.referenceTable,
          referenceId: old.referenceId,
          isRead: true,
          createdAt: old.createdAt,
        );
        unreadCount = unreadCount > 0 ? unreadCount - 1 : 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await apiService.markAllAsRead();
      notifications = notifications
          .map(
            (e) => NotificationModel(
              id: e.id,
              userId: e.userId,
              title: e.title,
              message: e.message,
              type: e.type,
              referenceTable: e.referenceTable,
              referenceId: e.referenceId,
              isRead: true,
              createdAt: e.createdAt,
            ),
          )
          .toList();
      unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint("Error marking all as read: $e");
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
