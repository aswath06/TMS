import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/services/api_service.dart';

class DailyRoutinesStore extends ChangeNotifier {
  List<Map<String, dynamic>> _runs = [];
  bool _isLoading = false;
  int _currentPage = 1;
  int _limit = 50;
  int _totalCount = 0;
  int _totalPages = 1;
  bool _hasMore = true;
  String? _errorMessage;

  String _currentSearch = "";
  String _selectedDate = "";

  // Getters
  List<Map<String, dynamic>> get runs => _runs;
  bool get isLoading => _isLoading;
  int get currentPage => _currentPage;
  int get limit => _limit;
  int get totalCount => _totalCount;
  int get totalPages => _totalPages;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  String get selectedDate => _selectedDate;
  String get currentSearch => _currentSearch;

  DateTime? _lastFetch;

  Future<void> fetchDailyRoutines({
    int page = 1,
    int limit = 50,
    bool isRefresh = false,
    String? search,
    String? date,
  }) async {
    if (search != null) {
      _currentSearch = search;
    }
    if (date != null) {
      _selectedDate = date;
    }

    if (!isRefresh && page == 1 && _lastFetch != null && _currentSearch.isEmpty && DateTime.now().difference(_lastFetch!).inMinutes < 5) {
      return;
    }

    if (isRefresh) {
      _currentPage = 1;
      _hasMore = true;
      _runs = [];
    }

    if (!_hasMore && !isRefresh) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String url = "${ApiConstants.baseUrl}/daily-bus/bus-run/get-all?page=$page&limit=$limit";
      if (_selectedDate.isNotEmpty && _selectedDate != 'ALL') {
        url += "&service_date=${Uri.encodeComponent(_selectedDate)}";
      }
      if (_currentSearch.isNotEmpty) {
        url += "&search=${Uri.encodeComponent(_currentSearch)}";
      }

      final data = await ApiService.get(url);

      if (data != null && data['success'] == true) {
        final resData = data['data'] ?? {};
        final List<dynamic> runsList = resData['runs'] ?? [];
        final List<Map<String, dynamic>> formattedRuns = runsList.map((run) => Map<String, dynamic>.from(run)).toList();

        if (page == 1) {
          _runs = formattedRuns;
          if (_currentSearch.isEmpty) _lastFetch = DateTime.now();
        } else {
          _runs.addAll(formattedRuns);
        }

        _currentPage = resData['current_page'] ?? page;
        _limit = resData['limit'] ?? limit;
        _totalCount = resData['total_count'] ?? 0;
        _totalPages = resData['total_pages'] ?? 1;
        _hasMore = _runs.length < _totalCount;
      } else {
        _errorMessage = data?['message'] ?? "Failed to load routines.";
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("DailyRoutinesStore Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchNextPage() async {
    if (_isLoading || !_hasMore) return;
    await fetchDailyRoutines(page: _currentPage + 1, limit: _limit);
  }
}
