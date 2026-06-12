import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';

class FacultyStore {
  // Singleton
  static final FacultyStore _instance = FacultyStore._internal();
  factory FacultyStore() => _instance;
  FacultyStore._internal();

  // Observable state
  final ValueNotifier<Map<String, dynamic>?> profileData = ValueNotifier(null);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<String?> errorMessage = ValueNotifier(null);

  Future<void> fetchProfile() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final token = await UserStore.getToken();
      if (token == null) {
        errorMessage.value = "Session expired. Please login again.";
        return;
      }

      final response = await http.get(
        Uri.parse(ApiConstants.userMe),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        
        // Remote logout check has been removed because it causes unintended logouts
        // when the app is restarted (backend sets it to false on disconnect).

        profileData.value = decoded['data'];
        
        // Persist name for dashboards
        if (decoded['data'] != null && decoded['data']['name'] != null) {
          await UserStore.saveName(decoded['data']['name']);
        }
      } else if (response.statusCode == 401) {
        errorMessage.value = "SESSION_EXPIRED";
      } else {
        errorMessage.value = "Error: ${response.statusCode}";
      }
    } catch (e) {
      errorMessage.value = "Network connection failed.";
    } finally {
      isLoading.value = false;
    }
  }

  void reset() {
    profileData.value = null;
    isLoading.value = false;
    errorMessage.value = null;
  }
}

// Global singleton shortcut
final useFacultyStore = FacultyStore();
