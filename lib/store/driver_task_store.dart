import 'package:flutter/material.dart';
import 'package:tripzo/providers/notification_provider.dart';
import 'package:tripzo/services/api_service.dart';
import 'package:tripzo/services/notification_local_service.dart';
import 'package:tripzo/utils/api_constants.dart';

class DriverTaskStore extends ChangeNotifier {
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _taskTypes = [];
  List<Map<String, dynamic>> _availableDrivers = [];
  final Set<String> _notifiedTaskIds = {};
  bool _isLoading = false;
  String? _errorMessage;
  NotificationProvider? notificationProvider;
  Map<String, dynamic>? _pendingEmergencyTaskPopup;

  List<Map<String, dynamic>> get tasks => _tasks;
  List<Map<String, dynamic>> get taskTypes => _taskTypes;
  List<Map<String, dynamic>> get availableDrivers => _availableDrivers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get pendingEmergencyTaskPopup => _pendingEmergencyTaskPopup;

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void clearEmergencyTaskPopup() {
    _pendingEmergencyTaskPopup = null;
    notifyListeners();
  }

  bool isEmergencyTask(Map<String, dynamic> task) {
    final String title = (task['title'] ?? '').toString().toLowerCase();
    final String category = (task['category'] ?? task['category_name'] ?? task['task_type'] ?? task['taskType'] ?? '').toString().toLowerCase();
    final String desc = (task['description'] ?? '').toString().toLowerCase();
    final String remarks = (task['remarks'] ?? '').toString().toLowerCase();
    final String combined = "$title $category $desc $remarks";

    return combined.contains('emergenc') ||
           combined.contains('sos') ||
           combined.contains('urgent') ||
           combined.contains('critical') ||
           combined.contains('alert') ||
           combined.contains('breakdown');
  }

  /// Fetch All Drivers without pagination (returns status: AVAILABLE | BUSY)
  Future<void> fetchAvailableDrivers() async {
    try {
      final res = await ApiService.get(ApiConstants.getAllDriversWithoutPagination);
      if (res != null) {
        final List<dynamic> data = res['data'] ?? (res is List ? res : []);
        _availableDrivers = data.map((e) => Map<String, dynamic>.from(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("fetchAvailableDrivers Error: $e");
    }
  }

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
        final data = res['data'];
        final List<Map<String, dynamic>> extractedTasks = [];
        if (data != null) {
          if (data is List) {
            extractedTasks.addAll(data.map((e) => Map<String, dynamic>.from(e)));
          } else if (data is Map && data['columns'] is List) {
            final List columns = data['columns'];
            for (var col in columns) {
              if (col is Map && col['tasks'] is List) {
                final List tasksList = col['tasks'];
                extractedTasks.addAll(tasksList.map((t) => Map<String, dynamic>.from(t)));
              }
            }
          } else if (data is Map && data['tasks'] is List) {
            final List tasksList = data['tasks'];
            extractedTasks.addAll(tasksList.map((t) => Map<String, dynamic>.from(t)));
          }
        }
        _tasks = extractedTasks;

        // Trigger push notification & popup ONLY for newly assigned EMERGENCY tasks
        for (var task in extractedTasks) {
          final String taskIdStr = (task['id'] ?? task['task_number'] ?? '').toString();
          final String status = (task['status'] ?? '').toString().toUpperCase();
          final bool isClosed = status == 'COMPLETED' || status == 'VERIFIED' || status == 'CANCELLED';

          if (taskIdStr.isNotEmpty && !isClosed && isEmergencyTask(task)) {
            if (!_notifiedTaskIds.contains(taskIdStr)) {
              _notifiedTaskIds.add(taskIdStr);
              _pendingEmergencyTaskPopup = task;
              final String taskTitle = task['title'] ?? 'Emergency Task';
              final String location = task['location_name'] ?? task['from_location'] ?? task['in_campus'] ?? 'Assigned Location';
              final int notifId = int.tryParse(taskIdStr) ?? (DateTime.now().millisecondsSinceEpoch % 100000);

              debugPrint("🚨 Triggering Emergency Task push notification & in-app popup for task: $taskIdStr ($taskTitle)");
              NotificationLocalService.showRouteAssignmentAlert(
                id: notifId,
                title: "🚨 EMERGENCY TASK ASSIGNED!",
                body: "Urgent Task: $taskTitle ($location). Tap to open details.",
                payload: taskIdStr,
              );

              notificationProvider?.addLocalTaskNotification(
                id: notifId,
                title: "🚨 Emergency Task Assigned",
                message: "Urgent Task: $taskTitle ($location)",
              );
            }
          }
        }
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
      if (res != null && (res['success'] == true || res['id'] != null || res['status'] != null || res['data'] != null)) {
        final taskObj = res['data'] is Map ? res['data'] : (res is Map ? res : {});
        final String taskIdStr = (taskObj['id'] ?? data['task_number'] ?? DateTime.now().millisecondsSinceEpoch).toString();
        final String taskTitle = data['title'] ?? taskObj['title'] ?? 'Emergency Task';
        final String location = data['in_campus'] ?? data['from_location'] ?? taskObj['location_name'] ?? 'Assigned Location';
        final int notifId = int.tryParse(taskIdStr) ?? (DateTime.now().millisecondsSinceEpoch % 100000);

        if (isEmergencyTask(data) || isEmergencyTask(taskObj)) {
          _notifiedTaskIds.add(taskIdStr);
          _pendingEmergencyTaskPopup = taskObj;

          NotificationLocalService.showRouteAssignmentAlert(
            id: notifId,
            title: "🚨 EMERGENCY TASK ASSIGNED!",
            body: "Urgent Task: $taskTitle ($location). Tap to open details.",
            payload: taskIdStr,
          );

          notificationProvider?.addLocalTaskNotification(
            id: notifId,
            title: "🚨 Emergency Task Assigned",
            message: "Urgent Task: $taskTitle ($location)",
          );
        }

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
        final String taskIdStr = id.toString();
        final taskObj = res['data'] is Map ? res['data'] : (res is Map ? res : {});
        final String taskTitle = taskObj['title'] ?? data['title'] ?? 'Emergency Task';
        final String location = taskObj['location_name'] ?? data['from_location'] ?? 'Assigned Location';
        final int notifId = int.tryParse(taskIdStr) ?? (DateTime.now().millisecondsSinceEpoch % 100000);

        if ((isEmergencyTask(data) || isEmergencyTask(taskObj)) && !_notifiedTaskIds.contains(taskIdStr)) {
          _notifiedTaskIds.add(taskIdStr);
          _pendingEmergencyTaskPopup = taskObj;

          NotificationLocalService.showRouteAssignmentAlert(
            id: notifId,
            title: "🚨 EMERGENCY TASK ASSIGNED!",
            body: "Urgent Task: $taskTitle ($location). Tap to open details.",
            payload: taskIdStr,
          );

          notificationProvider?.addLocalTaskNotification(
            id: notifId,
            title: "🚨 Emergency Task Assigned",
            message: "Urgent Task: $taskTitle ($location)",
          );
        }

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
  Future<bool> startTask(dynamic id, {num? startOdometer, String? remarks}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final Map<String, dynamic> body = {};
      if (startOdometer != null) body['start_odometer'] = startOdometer;
      if (remarks != null && remarks.isNotEmpty) body['remarks'] = remarks;

      final res = await ApiService.patch(
        ApiConstants.driverTaskStart(id),
        body: body,
      );
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
  Future<bool> completeTask(dynamic id, {num? endOdometer, String? remarks}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final Map<String, dynamic> body = {};
      if (endOdometer != null) body['end_odometer'] = endOdometer;
      if (remarks != null && remarks.isNotEmpty) body['remarks'] = remarks;

      final res = await ApiService.patch(
        ApiConstants.driverTaskComplete(id),
        body: body,
      );
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
