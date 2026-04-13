import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_socket_service.dart';
import '../services/notification_local_service.dart';
import '../services/notification_api_service.dart';
import '../utils/api_constants.dart';

class NotificationProvider extends ChangeNotifier {
  late NotificationApiService apiService;
  final NotificationSocketService socketService;

  NotificationProvider({
    required this.apiService,
    required this.socketService,
  });

  List<NotificationModel> notifications = [];
  int unreadCount = 0;
  bool isSocketConnected = false;
  bool isLoading = false;

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

    socketService.connect(
      socketBaseUrl: socketBaseUrl ?? ApiConstants.baseUrl,
      token: token,
      onConnected: () {
        debugPrint("✅ Notification Socket Connected");
        isSocketConnected = true;
        notifyListeners();
      },
      onDisconnected: () {
        debugPrint("❌ Notification Socket Disconnected");
        isSocketConnected = false;
        notifyListeners();
      },
      onError: (error) {
        debugPrint("⚠️ Socket error: $error");
      },
      onNewNotification: (data) {
        debugPrint("🔔 New Notification Received: $data");
        final notification = NotificationModel.fromJson(data);
        
        // Avoid duplicate if already in list (some sockets might re-emit)
        if (notifications.any((n) => n.id == notification.id)) return;

        notifications.insert(0, notification);
        unreadCount += 1;

        // Show Local Notification Pop-up
        NotificationLocalService.showNotification(
          id: notification.id,
          title: notification.title,
          body: notification.message,
        );

        notifyListeners();
      },
    );
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
    socketService.disconnect();
    super.dispose();
  }
}
