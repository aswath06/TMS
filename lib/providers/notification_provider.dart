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
  int totalCount = 0;
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
        debugPrint("🔔 [FG] App state update received: $data");
        try {
          final eventType = data['event'];
          if (eventType != 'notification:new') return;

          final notification = NotificationModel.fromJson(data);

          // Avoid duplicate if already in list
          if (notifications.any((n) => n.id == notification.id)) return;

          // Update in-app state (notification list + badge counter)
          notifications.insert(0, notification);
          unreadCount += 1;
          notifyListeners();

          // NOTE: The local push notification (system banner) is already shown
          // by NotificationFirebaseService.onMessage listener directly, so we
          // do NOT call showNotification/showRouteAssignmentAlert here again
          // to avoid showing duplicate banners.

          // Show the beautiful in-app overlay slide-down banner
          showPremiumInAppNotification(
            title: notification.title,
            message: notification.message,
            type: notification.type,
          );
        } catch (e) {
          debugPrint("🔔 Error handling new firebase notification in provider: $e");
        }
      },
      // When Firebase gives us a fresh token (e.g. after deleteToken() on first
      // run to replace a stale legacy APA91b token), immediately sync it to the
      // backend so the very next push notification reaches the device.
      onTokenRefresh: (newToken) async {
        try {
          await apiService.updateFcmToken(newToken);
          debugPrint("🔔 FCM Token refreshed and synced with backend ✅");
        } catch (e) {
          debugPrint("Error syncing refreshed FCM token: $e");
        }
      },
    );
    isFirebaseInitialized = true;
    
    // Sync FCM token with backend (deleteToken + getToken ensures a fresh v1 token)
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
      final response = await apiService.getMyNotifications();
      final fetchedList = response["data"] as List<NotificationModel>;
      totalCount = response["total"] as int;
      
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

  int currentPage = 1;
  bool hasMore = true;
  String currentType = 'All';

  Future<void> fetchNotifications({bool refresh = false, String? type}) async {
    if (type != null && currentType != type) {
      currentType = type;
      refresh = true;
    }
    
    if (refresh) {
      currentPage = 1;
      hasMore = true;
      notifications.clear();
    }

    if (!hasMore || isLoading) return;

    isLoading = true;
    notifyListeners();

    try {
      final response = await apiService.getMyNotifications(
        page: currentPage, 
        limit: 10, 
        type: currentType
      );
      
      final fetchedList = response["data"] as List<NotificationModel>;
      totalCount = response["total"] as int;
      
      if (fetchedList.isEmpty || fetchedList.length < 10) {
        hasMore = false;
      }
      
      if (refresh) {
        notifications = fetchedList;
      } else {
        notifications.addAll(fetchedList);
      }
      currentPage++;
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
