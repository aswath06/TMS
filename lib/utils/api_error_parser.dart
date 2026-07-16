import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiErrorParser {
  static String parse(http.Response response, {String fallback = "Something went wrong"}) {
    try {
      final data = json.decode(response.body);
      if (data != null && data is Map<String, dynamic>) {
        if (data['message'] != null && data['message'].toString().isNotEmpty) {
          return data['message'].toString();
        } else if (data['error'] != null && data['error'].toString().isNotEmpty) {
          return data['error'].toString();
        }
      }
    } catch (_) {}
    return "$fallback (HTTP ${response.statusCode})";
  }
}
