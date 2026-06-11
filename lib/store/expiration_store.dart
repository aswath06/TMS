import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/api_constants.dart';
import 'user_store.dart';

class ExpirationStore extends ChangeNotifier {
  List<dynamic> _expirationData = [];
  int _expiredCount = 0;
  int _expiringSoonCount = 0;
  bool _isLoading = false;

  // Track the last fetch parameters to avoid redundant network calls
  String _lastFilterType = "";
  String _lastSearchQuery = "";
  bool _hasFetched = false;

  List<dynamic> get expirationData => _expirationData;
  int get expiredCount => _expiredCount;
  int get expiringSoonCount => _expiringSoonCount;
  bool get isLoading => _isLoading;

  Future<void> fetchExpirations({String filterType = "all", String searchQuery = "", bool force = false}) async {
    // Return cached data if not forcing a refresh and parameters match
    if (!force && _hasFetched && _lastFilterType == filterType && _lastSearchQuery == searchQuery) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final token = await UserStore.getToken();
      final url = ApiConstants.vehicleExpirations(1, 50, filterType, searchQuery);

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          _expiredCount = data['expired_count'] ?? 0;
          _expiringSoonCount = data['expiring_soon_count'] ?? 0;
          _expirationData = data['data'] ?? [];
          
          _lastFilterType = filterType;
          _lastSearchQuery = searchQuery;
          _hasFetched = true;
        }
      }
    } catch (e) {
      debugPrint("Error fetching expirations: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void forceRefresh() {
    fetchExpirations(filterType: _lastFilterType, searchQuery: _lastSearchQuery, force: true);
  }
}
