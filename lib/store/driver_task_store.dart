import 'package:flutter/material.dart';
import 'package:tripzo/services/api_service.dart';
import 'package:tripzo/utils/api_constants.dart';

class DriverTaskStore extends ChangeNotifier {
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _taskTypes = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> get tasks => _tasks;
  List<Map<String, dynamic>> get taskTypes => _taskTypes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 1. Get All Task Types
  Future<void> fetchTaskTypes() async {
    try {
      final res = await ApiService.get(ApiConstants.driverTaskType);
      if (res != null) {
        final List<dynamic> data = res['data'] ?? (res is List ? res : []);
        _taskTypes = data.map((e) => Map<String, dynamic>.from(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("fetchTaskTypes Error: $e");
    }
  }

  /// 3. Get All Driver Tasks
  Future<void> fetchAllTasks({bool isRefresh = false}) async {
    if (!isRefresh) _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.get(ApiConstants.driverTaskGetAll);
      if (res != null) {
        final List<dynamic> data = res['data'] ?? (res is List ? res : []);
        _tasks = data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("fetchAllTasks Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 4. Get Driver Task by ID
  Future<Map<String, dynamic>?> getTaskById(dynamic id) async {
    try {
      final res = await ApiService.get(ApiConstants.driverTaskGetById(id));
      if (res != null && res['data'] != null) {
        return Map<String, dynamic>.from(res['data']);
      }
      if (res is Map<String, dynamic>) return res;
    } catch (e) {
      debugPrint("getTaskById Error: $e");
    }
    return null;
  }

  /// 2. Create Driver Task (Admin Only)
  Future<bool> createTask(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.post(ApiConstants.driverTaskCreate, body: data);
      if (res != null && (res['success'] == true || res['id'] != null || res['status'] != null)) {
        await fetchAllTasks(isRefresh: true);
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("createTask Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// 5. Update Driver Task (Regular, Verify & Convert to Route, or Verify with Manual Points)
  Future<bool> updateTask(dynamic id, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.patch(ApiConstants.driverTaskUpdate(id), body: data);
      if (res != null) {
        await fetchAllTasks(isRefresh: true);
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("updateTask Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// 6. Start Task (Driver Only)
  Future<bool> startTask(dynamic id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.patch(ApiConstants.driverTaskStart(id));
      if (res != null) {
        await fetchAllTasks(isRefresh: true);
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("startTask Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// 7. Complete Task (Driver Only)
  Future<bool> completeTask(dynamic id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.patch(ApiConstants.driverTaskComplete(id));
      if (res != null) {
        await fetchAllTasks(isRefresh: true);
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("completeTask Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// 8. Direct Verify Task (Admin Only)
  Future<bool> verifyTask(dynamic id, {String? remarks}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final body = remarks != null ? {'remarks': remarks} : <String, dynamic>{};
      final res = await ApiService.patch(ApiConstants.driverTaskVerify(id), body: body);
      if (res != null) {
        await fetchAllTasks(isRefresh: true);
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("verifyTask Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// 9. Cancel Task (Admin Only)
  Future<bool> cancelTask(dynamic id, {String? reason}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final body = reason != null ? {'reason': reason} : <String, dynamic>{};
      final res = await ApiService.patch(ApiConstants.driverTaskCancel(id), body: body);
      if (res != null) {
        await fetchAllTasks(isRefresh: true);
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("cancelTask Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// 10. Delete Task (Admin Only)
  Future<bool> deleteTask(dynamic id) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.delete(ApiConstants.driverTaskDelete(id));
      if (res != null) {
        await fetchAllTasks(isRefresh: true);
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint("deleteTask Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }
}
