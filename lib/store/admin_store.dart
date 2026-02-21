import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tms/store/user_store.dart';
import 'package:tms/utils/api_constants.dart';

class AdminStore {
  // Singleton pattern to access the same store everywhere
  static final AdminStore _instance = AdminStore._internal();
  factory AdminStore() => _instance;
  AdminStore._internal();

  // Observable state variables (ValueNotifiers)
  final ValueNotifier<Map<String, dynamic>?> adminData = ValueNotifier(null);
  final ValueNotifier<bool> isLoading = ValueNotifier(false);
  final ValueNotifier<String?> errorMessage = ValueNotifier(null);

  // Actions (Similar to Zustand actions)
  Future<void> fetchProfile() async {
    isLoading.value = true;
    errorMessage.value = null;

    try {
      final token = await UserStore.getToken();
      final response = await http.get(
        Uri.parse(ApiConstants.userMe),
        headers: {
          'Authorization': 'TMS $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        adminData.value = decodedData['data'];
      } else {
        errorMessage.value = "Error: ${response.statusCode}";
      }
    } catch (e) {
      errorMessage.value = "Network Connection Failed";
    } finally {
      isLoading.value = false;
    }
  }

  // Clear store (for logout)
  void reset() {
    adminData.value = null;
    isLoading.value = false;
    errorMessage.value = null;
  }
}

// Global shortcut (Like a hook)
final useAdminStore = AdminStore();
