import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';
import '../utils/api_constants.dart';

class NotificationApiService {
  final String baseUrl;
  final String token;

  NotificationApiService({
    required this.baseUrl,
    required this.token,
  });

  Map<String, String> get _headers => ApiConstants.getHeaders(token);

  Future<List<NotificationModel>> getMyNotifications() async {
    final response = await http.get(
      Uri.parse(ApiConstants.myNotifications),
      headers: _headers,
    );

    final body = jsonDecode(response.body);

    if (response.statusCode != 200 || body["success"] != true) {
      throw Exception(body["message"] ?? "Failed to fetch notifications");
    }

    final List data = body["data"] ?? [];
    return data.map((e) => NotificationModel.fromJson(e)).toList();
  }

  Future<int> getUnreadCount() async {
    final response = await http.get(
      Uri.parse(ApiConstants.unreadCount),
      headers: _headers,
    );

    final body = jsonDecode(response.body);

    if (response.statusCode != 200 || body["success"] != true) {
      throw Exception(body["message"] ?? "Failed to fetch unread count");
    }

    return body["data"]["unread_count"] ?? 0;
  }

  Future<void> markAsRead(int notificationId) async {
    final response = await http.patch(
      Uri.parse(ApiConstants.markNotificationRead(notificationId)),
      headers: _headers,
    );

    final body = jsonDecode(response.body);

    if (response.statusCode != 200 || body["success"] != true) {
      throw Exception(body["message"] ?? "Failed to mark notification as read");
    }
  }

  Future<void> markAllAsRead() async {
    final response = await http.patch(
      Uri.parse(ApiConstants.markAllRead),
      headers: _headers,
    );

    final body = jsonDecode(response.body);

    if (response.statusCode != 200 || body["success"] != true) {
      throw Exception(body["message"] ?? "Failed to mark all notifications as read");
    }
  }
}
