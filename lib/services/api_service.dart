import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/routes.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const Duration timeoutDuration = Duration(seconds: 15);

  /// Helper to get headers with the bearer token automatically injected
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await UserStore.getToken();
    return ApiConstants.getHeaders(token);
  }

  /// Parses the response, handling common errors
  static dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      // Handle unauthorized (token expired)
      UserStore.forceLogout();
      throw Exception('Session expired. Please log in again.');
    } else {
      String errorMessage = 'Error ${response.statusCode}';
      try {
        final decoded = json.decode(response.body);
        if (decoded['message'] != null) {
          errorMessage = decoded['message'];
        }
      } catch (_) {}
      
      if (response.statusCode == 403 && errorMessage == 'ACCOUNT_BLOCKED') {
        AppRoutes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.accountBlocked,
          (route) => false,
        );
        throw Exception('ACCOUNT_BLOCKED');
      }
      
      throw Exception(errorMessage);
    }
  }

  /// Generic GET Request
  static Future<dynamic> get(String url) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(Uri.parse(url), headers: headers).timeout(timeoutDuration);
      return _processResponse(response);
    } on SocketException {
      throw Exception('No Internet connection');
    } on TimeoutException {
      throw Exception('Request timed out');
    } catch (e) {
      debugPrint('GET ERROR ($url): $e');
      rethrow;
    }
  }

  /// Generic POST Request
  static Future<dynamic> post(String url, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http
          .post(Uri.parse(url), headers: headers, body: body != null ? json.encode(body) : null)
          .timeout(timeoutDuration);
      return _processResponse(response);
    } on SocketException {
      throw Exception('No Internet connection');
    } on TimeoutException {
      throw Exception('Request timed out');
    } catch (e) {
      debugPrint('POST ERROR ($url): $e');
      rethrow;
    }
  }

  /// Generic PUT Request
  static Future<dynamic> put(String url, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http
          .put(Uri.parse(url), headers: headers, body: body != null ? json.encode(body) : null)
          .timeout(timeoutDuration);
      return _processResponse(response);
    } on SocketException {
      throw Exception('No Internet connection');
    } on TimeoutException {
      throw Exception('Request timed out');
    } catch (e) {
      debugPrint('PUT ERROR ($url): $e');
      rethrow;
    }
  }

  /// Generic PATCH Request
  static Future<dynamic> patch(String url, {Map<String, dynamic>? body}) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http
          .patch(Uri.parse(url), headers: headers, body: body != null ? json.encode(body) : null)
          .timeout(timeoutDuration);
      return _processResponse(response);
    } on SocketException {
      throw Exception('No Internet connection');
    } on TimeoutException {
      throw Exception('Request timed out');
    } catch (e) {
      debugPrint('PATCH ERROR ($url): $e');
      rethrow;
    }
  }

  /// Generic DELETE Request
  static Future<dynamic> delete(String url) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(Uri.parse(url), headers: headers).timeout(timeoutDuration);
      return _processResponse(response);
    } on SocketException {
      throw Exception('No Internet connection');
    } on TimeoutException {
      throw Exception('Request timed out');
    } catch (e) {
      debugPrint('DELETE ERROR ($url): $e');
      rethrow;
    }
  }
}
