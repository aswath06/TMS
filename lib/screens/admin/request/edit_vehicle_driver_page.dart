import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';

class EditVehicleDriverPage extends StatefulWidget {
  final Map<String, dynamic> run;
  final bool editFacultyOnly;
  const EditVehicleDriverPage({
    super.key,
    required this.run,
    this.editFacultyOnly = false,
  });

  @override
  State<EditVehicleDriverPage> createState() => _EditVehicleDriverPageState();
}

class _EditVehicleDriverPageState extends State<EditVehicleDriverPage> {
  bool _isLoadingLookups = true;
  bool _isSaving = false;
  String? _errorMessage;

  List<dynamic> _vehicles = [];
  List<dynamic> _drivers = [];
  List<dynamic> _faculties = [];

  // Active selections shown in the UI
  int? _selectedVehicleId;
  String _selectedVehicleNum = 'Select Vehicle';
  int? _selectedDriverId;
  String _selectedDriverName = 'Select Driver';
  int? _selectedFacultyId;
  String _selectedFacultyName = 'Select Assigned Faculty';

  String _selectedShift = 'BOTH'; // 'MORNING', 'EVENING', 'BOTH'

  // Tracks for MORNING shift
  int? _selectedMorningVehicleId;
  String _selectedMorningVehicleNum = 'Select Vehicle';
  int? _initialMorningVehicleId;

  int? _selectedMorningDriverId;
  String _selectedMorningDriverName = 'Select Driver';
  int? _initialMorningDriverId;

  int? _selectedMorningFacultyId;
  String _selectedMorningFacultyName = 'Select Assigned Faculty';
  int? _initialMorningFacultyId;

  // Tracks for EVENING shift
  int? _selectedEveningVehicleId;
  String _selectedEveningVehicleNum = 'Select Vehicle';
  int? _initialEveningVehicleId;

  int? _selectedEveningDriverId;
  String _selectedEveningDriverName = 'Select Driver';
  int? _initialEveningDriverId;

  int? _selectedEveningFacultyId;
  String _selectedEveningFacultyName = 'Select Assigned Faculty';
  int? _initialEveningFacultyId;

  String? _morningFacultyRemarks;
  String? _eveningFacultyRemarks;

  @override
  void initState() {
    super.initState();
    _initializeSelections();
    _fetchLookups();
  }

  void _initializeSelections() {
    final status = (widget.run['status'] ?? '').toString().toUpperCase();
    final bool isPlannedOrReady = status == 'PLANNED' || status == 'READY';
    
    // If status is PLANNED or READY, default shift is BOTH. Otherwise EVENING
    _selectedShift = isPlannedOrReady ? 'BOTH' : 'EVENING';

    final assignments = widget.run['assignment'] as List? ?? [];

    // Initialize Morning
    final morningAssign = assignments.firstWhere(
      (a) => a['shift_code'] == 'MORNING',
      orElse: () => null,
    );
    if (morningAssign != null) {
      final vehicle = morningAssign['vehicle'];
      if (vehicle != null) {
        _selectedMorningVehicleId = vehicle['id'];
        _selectedMorningVehicleNum = vehicle['vehicle_number'] ?? 'Select Vehicle';
        _initialMorningVehicleId = vehicle['id'];
      }
      final driver = morningAssign['driver'];
      if (driver != null) {
        _selectedMorningDriverId = driver['id'];
        _selectedMorningDriverName = driver['user']?['name'] ?? 'Select Driver';
        _initialMorningDriverId = driver['id'];
      }
    }

    // Initialize Evening
    final eveningAssign = assignments.firstWhere(
      (a) => a['shift_code'] == 'EVENING',
      orElse: () => null,
    );
    if (eveningAssign != null) {
      final vehicle = eveningAssign['vehicle'];
      if (vehicle != null) {
        _selectedEveningVehicleId = vehicle['id'];
        _selectedEveningVehicleNum = vehicle['vehicle_number'] ?? 'Select Vehicle';
        _initialEveningVehicleId = vehicle['id'];
      }
      final driver = eveningAssign['driver'];
      if (driver != null) {
        _selectedEveningDriverId = driver['id'];
        _selectedEveningDriverName = driver['user']?['name'] ?? 'Select Driver';
        _initialEveningDriverId = driver['id'];
      }
    }

    // If assignments is empty or only one exists, try to fallback
    if (assignments.isNotEmpty && morningAssign == null && eveningAssign == null) {
      final assign = assignments.first;
      final vehicle = assign['vehicle'];
      final driver = assign['driver'];
      final code = assign['shift_code']?.toString() ?? 'BOTH';

      if (code == 'MORNING' || code == 'BOTH' || code == 'FULL_DAY') {
        if (vehicle != null) {
          _selectedMorningVehicleId = vehicle['id'];
          _selectedMorningVehicleNum = vehicle['vehicle_number'] ?? 'Select Vehicle';
          _initialMorningVehicleId = vehicle['id'];
        }
        if (driver != null) {
          _selectedMorningDriverId = driver['id'];
          _selectedMorningDriverName = driver['user']?['name'] ?? 'Select Driver';
          _initialMorningDriverId = driver['id'];
        }
      }
      if (code == 'EVENING' || code == 'BOTH' || code == 'FULL_DAY') {
        if (vehicle != null) {
          _selectedEveningVehicleId = vehicle['id'];
          _selectedEveningVehicleNum = vehicle['vehicle_number'] ?? 'Select Vehicle';
          _initialEveningVehicleId = vehicle['id'];
        }
        if (driver != null) {
          _selectedEveningDriverId = driver['id'];
          _selectedEveningDriverName = driver['user']?['name'] ?? 'Select Driver';
          _initialEveningDriverId = driver['id'];
        }
      }
    }

    // Initialize Faculties
    final morningFaculty = widget.run['morningAssignedFaculty'];
    if (morningFaculty != null) {
      _selectedMorningFacultyId = morningFaculty['id'];
      _selectedMorningFacultyName = morningFaculty['name'] ?? 'Select Assigned Faculty';
      _initialMorningFacultyId = morningFaculty['id'];
    }

    final eveningFaculty = widget.run['eveningAssignedFaculty'];
    if (eveningFaculty != null) {
      _selectedEveningFacultyId = eveningFaculty['id'];
      _selectedEveningFacultyName = eveningFaculty['name'] ?? 'Select Assigned Faculty';
      _initialEveningFacultyId = eveningFaculty['id'];
    }

    // Sync displayed selections
    _syncDisplayedSelections();
  }

  void _syncDisplayedSelections() {
    if (_selectedShift == 'MORNING') {
      _selectedVehicleId = _selectedMorningVehicleId;
      _selectedVehicleNum = _selectedMorningVehicleNum;
      _selectedDriverId = _selectedMorningDriverId;
      _selectedDriverName = _selectedMorningDriverName;
      _selectedFacultyId = _selectedMorningFacultyId;
      _selectedFacultyName = _selectedMorningFacultyName;
    } else if (_selectedShift == 'EVENING') {
      _selectedVehicleId = _selectedEveningVehicleId;
      _selectedVehicleNum = _selectedEveningVehicleNum;
      _selectedDriverId = _selectedEveningDriverId;
      _selectedDriverName = _selectedEveningDriverName;
      _selectedFacultyId = _selectedEveningFacultyId;
      _selectedFacultyName = _selectedEveningFacultyName;
    } else {
      // BOTH - defaults to morning assignment for visual display,
      // but selects are synchronized
      _selectedVehicleId = _selectedMorningVehicleId ?? _selectedEveningVehicleId;
      _selectedVehicleNum = _selectedMorningVehicleNum != 'Select Vehicle' 
          ? _selectedMorningVehicleNum 
          : (_selectedEveningVehicleNum != 'Select Vehicle' ? _selectedEveningVehicleNum : 'Select Vehicle');
      _selectedDriverId = _selectedMorningDriverId ?? _selectedEveningDriverId;
      _selectedDriverName = _selectedMorningDriverName != 'Select Driver' 
          ? _selectedMorningDriverName 
          : (_selectedEveningDriverName != 'Select Driver' ? _selectedEveningDriverName : 'Select Driver');
      _selectedFacultyId = _selectedMorningFacultyId ?? _selectedEveningFacultyId;
      _selectedFacultyName = _selectedMorningFacultyName != 'Select Assigned Faculty' 
          ? _selectedMorningFacultyName 
          : (_selectedEveningFacultyName != 'Select Assigned Faculty' ? _selectedEveningFacultyName : 'Select Assigned Faculty');
    }
  }

  Future<void> _fetchLookups() async {
    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        setState(() {
          _errorMessage = "Session expired. Please log in again.";
          _isLoadingLookups = false;
        });
        return;
      }

      final headers = ApiConstants.getHeaders(token);

      List<dynamic> fetchedFaculties = [];
      final String serviceDate = widget.run['service_date']?.toString() ?? '';
      final int? routeId = widget.run['daily_bus_route_id'] != null
          ? int.tryParse(widget.run['daily_bus_route_id'].toString())
          : null;

      if (serviceDate.isNotEmpty && routeId != null) {
        final fUrl = "${ApiConstants.baseUrl}/daily-bus/bus-runs/assignable-faculties";
        try {
          final fRes = await http.post(
            Uri.parse(fUrl),
            headers: headers,
            body: json.encode({
              "service_date": serviceDate,
              "routeIds": [routeId],
            }),
          );
          if (fRes.statusCode == 200) {
            final fData = json.decode(fRes.body);
            fetchedFaculties = fData['data'] as List? ?? [];
            fetchedFaculties.insert(0, {
              "user_id": -1,
              "name": "Transport Admin",
              "department": "Admin Handover",
            });
          } else {
            setState(() {
              _errorMessage = "Failed to load assignable faculties";
              _isLoadingLookups = false;
            });
            return;
          }
        } catch (e) {
          debugPrint("Error fetching faculties lookup: $e");
          setState(() {
            _errorMessage = "Error loading faculties: $e";
            _isLoadingLookups = false;
          });
          return;
        }
      }

      if (widget.editFacultyOnly) {
        setState(() {
          _vehicles = [];
          _drivers = [];
          _faculties = fetchedFaculties;
          _isLoadingLookups = false;
        });
        return;
      }

      final vRes = await http.get(Uri.parse(ApiConstants.getAllVehiclesWithoutPagination), headers: headers);
      final dRes = await http.get(Uri.parse(ApiConstants.getAllDriversWithoutPagination), headers: headers);

      if (vRes.statusCode == 200 && dRes.statusCode == 200) {
        final vData = json.decode(vRes.body);
        final dData = json.decode(dRes.body);

        setState(() {
          _vehicles = vData['data'] as List? ?? [];
          _drivers = dData['data'] as List? ?? [];
          _faculties = fetchedFaculties;
          _isLoadingLookups = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load vehicles or drivers";
          _isLoadingLookups = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection error: $e";
        _isLoadingLookups = false;
      });
    }
  }

  Future<_ChangeResult> _updateVehicle(
    String runId,
    int vehicleId,
    String shiftCode,
    String token,
    Map<String, String> headers,
  ) async {
    final url = "${ApiConstants.baseUrl}/daily-bus/bus-runs/$runId/change-vehicle";
    final body = {
      "vehicle_id": vehicleId,
      "shift_code": shiftCode,
      "remarks": "Changed vehicle from UI ($shiftCode)",
    };

    try {
      final res = await http.patch(Uri.parse(url), headers: headers, body: json.encode(body));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final resData = json.decode(res.body);
        if (resData['success'] == true) {
          return _ChangeResult(true, null);
        } else {
          return _ChangeResult(false, resData['message']?.toString() ?? "Failed to update vehicle");
        }
      } else {
        try {
          final decoded = json.decode(res.body);
          return _ChangeResult(false, decoded['detail'] ?? decoded['message'] ?? decoded['error'] ?? res.body);
        } catch (_) {
          return _ChangeResult(false, res.body);
        }
      }
    } catch (e) {
      return _ChangeResult(false, "Connection error updating vehicle: $e");
    }
  }

  Future<_ChangeResult> _updateDriver(
    String runId,
    int driverId,
    String shiftCode,
    String token,
    Map<String, String> headers,
  ) async {
    final url = "${ApiConstants.baseUrl}/daily-bus/bus-runs/$runId/change-driver";
    final body = {
      "driver_id": driverId,
      "shift_code": shiftCode,
      "remarks": "Changed driver from UI ($shiftCode)",
    };

    try {
      final res = await http.patch(Uri.parse(url), headers: headers, body: json.encode(body));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final resData = json.decode(res.body);
        if (resData['success'] == true) {
          return _ChangeResult(true, null);
        } else {
          return _ChangeResult(false, resData['message']?.toString() ?? "Failed to update driver");
        }
      } else {
        try {
          final decoded = json.decode(res.body);
          return _ChangeResult(false, decoded['detail'] ?? decoded['message'] ?? decoded['error'] ?? res.body);
        } catch (_) {
          return _ChangeResult(false, res.body);
        }
      }
    } catch (e) {
      return _ChangeResult(false, "Connection error updating driver: $e");
    }
  }

  Future<void> _saveChanges() async {
    final String runId = widget.run['id']?.toString() ?? '';
    final String? token = await UserStore.getToken();
    if (token == null) {
      _showSnackBar("Session expired. Please log in again.", Colors.red);
      return;
    }

    final headers = ApiConstants.getHeaders(token);

    final bool isMorningVehicleChanged = !widget.editFacultyOnly && (_selectedMorningVehicleId != _initialMorningVehicleId);
    final bool isEveningVehicleChanged = !widget.editFacultyOnly && (_selectedEveningVehicleId != _initialEveningVehicleId);
    final bool isMorningDriverChanged = !widget.editFacultyOnly && (_selectedMorningDriverId != _initialMorningDriverId);
    final bool isEveningDriverChanged = !widget.editFacultyOnly && (_selectedEveningDriverId != _initialEveningDriverId);
    final bool isMorningFacultyChanged = _selectedMorningFacultyId != _initialMorningFacultyId;
    final bool isEveningFacultyChanged = _selectedEveningFacultyId != _initialEveningFacultyId;

    if (!isMorningVehicleChanged &&
        !isEveningVehicleChanged &&
        !isMorningDriverChanged &&
        !isEveningDriverChanged &&
        !isMorningFacultyChanged &&
        !isEveningFacultyChanged) {
      _showSnackBar("No changes detected", Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      bool vSuccess = true;
      bool dSuccess = true;
      bool fSuccess = true;
      String? errorMsg;

      // 1. Change Vehicle API call
      if (!widget.editFacultyOnly) {
        if (_selectedShift == 'BOTH') {
          final bool isVehicleChanged = _selectedMorningVehicleId != _initialMorningVehicleId || _selectedEveningVehicleId != _initialEveningVehicleId;
          if (isVehicleChanged && _selectedMorningVehicleId != null) {
            final res = await _updateVehicle(runId, _selectedMorningVehicleId!, 'FULL_DAY', token, headers);
            if (!res.success) {
              vSuccess = false;
              errorMsg = res.message;
            }
          }
        } else {
          if (isMorningVehicleChanged && _selectedMorningVehicleId != null) {
            final res = await _updateVehicle(runId, _selectedMorningVehicleId!, 'MORNING', token, headers);
            if (!res.success) {
              vSuccess = false;
              errorMsg = res.message;
            }
          }
          if (isEveningVehicleChanged && _selectedEveningVehicleId != null) {
            final res = await _updateVehicle(runId, _selectedEveningVehicleId!, 'EVENING', token, headers);
            if (!res.success) {
              vSuccess = false;
              errorMsg = errorMsg == null ? res.message : "$errorMsg | ${res.message}";
            }
          }
        }
      }

      // 2. Change Driver API call
      if (!widget.editFacultyOnly) {
        if (_selectedShift == 'BOTH') {
          final bool isDriverChanged = _selectedMorningDriverId != _initialMorningDriverId || _selectedEveningDriverId != _initialEveningDriverId;
          if (isDriverChanged && _selectedMorningDriverId != null) {
            final res = await _updateDriver(runId, _selectedMorningDriverId!, 'FULL_DAY', token, headers);
            if (!res.success) {
              dSuccess = false;
              errorMsg = errorMsg == null ? res.message : "$errorMsg | ${res.message}";
            }
          }
        } else {
          if (isMorningDriverChanged && _selectedMorningDriverId != null) {
            final res = await _updateDriver(runId, _selectedMorningDriverId!, 'MORNING', token, headers);
            if (!res.success) {
              dSuccess = false;
              errorMsg = errorMsg == null ? res.message : "$errorMsg | ${res.message}";
            }
          }
          if (isEveningDriverChanged && _selectedEveningDriverId != null) {
            final res = await _updateDriver(runId, _selectedEveningDriverId!, 'EVENING', token, headers);
            if (!res.success) {
              dSuccess = false;
              errorMsg = errorMsg == null ? res.message : "$errorMsg | ${res.message}";
            }
          }
        }
      }

      // 3. Faculty changes API call (via update-runs PUT route)
      // 3. Faculty changes API call (via operations/change-faculty PATCH route)
      if (isMorningFacultyChanged || isEveningFacultyChanged) {
        final String facultyUrl = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/$runId/change-faculty";
        
        if (isMorningFacultyChanged && _selectedMorningFacultyId != null) {
          final Map<String, dynamic> body = {
            "trip_type": "MORNING",
            "remarks": _morningFacultyRemarks ?? "Changed morning faculty from UI",
          };
          if (_selectedMorningFacultyId == -1) {
            body["is_admin_handover"] = true;
          } else {
            body["assigned_faculty_user_id"] = _selectedMorningFacultyId;
          }
          
          final res = await http.patch(Uri.parse(facultyUrl), headers: headers, body: json.encode(body));
          debugPrint("---- [HTTP RESPONSE (MORNING FACULTY): ${res.statusCode}] ----\\n${res.body}\\n----------------------------");
          
          if (res.statusCode != 200 && res.statusCode != 201) {
            fSuccess = false;
            try {
              final dec = json.decode(res.body);
              final err = dec['detail'] ?? dec['message'] ?? dec['error'] ?? res.body;
              errorMsg = errorMsg == null ? err : "$errorMsg | $err";
            } catch (_) {
              errorMsg = errorMsg == null ? res.body : "$errorMsg | ${res.body}";
            }
          }
        }
        
        if (isEveningFacultyChanged && _selectedEveningFacultyId != null) {
          final Map<String, dynamic> body = {
            "trip_type": "EVENING",
            "remarks": _eveningFacultyRemarks ?? "Changed evening faculty from UI",
          };
          if (_selectedEveningFacultyId == -1) {
            body["is_admin_handover"] = true;
          } else {
            body["assigned_faculty_user_id"] = _selectedEveningFacultyId;
          }
          
          final res = await http.patch(Uri.parse(facultyUrl), headers: headers, body: json.encode(body));
          debugPrint("---- [HTTP RESPONSE (EVENING FACULTY): ${res.statusCode}] ----\\n${res.body}\\n----------------------------");
          
          if (res.statusCode != 200 && res.statusCode != 201) {
            fSuccess = false;
            try {
              final dec = json.decode(res.body);
              final err = dec['detail'] ?? dec['message'] ?? dec['error'] ?? res.body;
              errorMsg = errorMsg == null ? err : "$errorMsg | $err";
            } catch (_) {
              errorMsg = errorMsg == null ? res.body : "$errorMsg | ${res.body}";
            }
          }
        }
      }

      if (vSuccess && dSuccess && fSuccess) {
        _showSnackBar("Assignment updated successfully", Colors.green);
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _showSnackBar(errorMsg ?? "Failed to save some changes", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e", Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showRemarksBottomSheet(dynamic f) {
    if (f == null) return;
    final TextEditingController remarksController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
        final Color bg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color primaryBlue = const Color(0xFF6366F1);

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Enter Remarks",
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please provide a reason for changing the assigned faculty.",
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: remarksController,
                  maxLines: 3,
                  style: TextStyle(color: titleColor),
                  decoration: InputDecoration(
                    hintText: "Enter your remarks here...",
                    hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: primaryBlue),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      final remarks = remarksController.text.trim();
                      if (remarks.isEmpty) {
                        _showSnackBar("Remarks cannot be empty", Colors.orange);
                        return;
                      }
                      Navigator.pop(ctx);
                      
                      setState(() {
                        final int userId = f['user_id'];
                        final String name = f['name'] ?? 'N/A';
                        _selectedFacultyId = userId;
                        _selectedFacultyName = name;

                        if (_selectedShift == 'BOTH') {
                          _selectedMorningFacultyId = userId;
                          _selectedMorningFacultyName = name;
                          _morningFacultyRemarks = remarks;
                          _selectedEveningFacultyId = userId;
                          _selectedEveningFacultyName = name;
                          _eveningFacultyRemarks = remarks;
                        } else if (_selectedShift == 'MORNING') {
                          _selectedMorningFacultyId = userId;
                          _selectedMorningFacultyName = name;
                          _morningFacultyRemarks = remarks;
                        } else {
                          _selectedEveningFacultyId = userId;
                          _selectedEveningFacultyName = name;
                          _eveningFacultyRemarks = remarks;
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "Save Faculty",
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSelectionSheet({
    required String title,
    required bool isVehicle,
    bool isFaculty = false,
    required List<dynamic> items,
    required int? selectedId,
    required void Function(dynamic) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final Color t = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color p = isFaculty ? Colors.purple : const Color(0xFF6366F1);
        final Color modalBg = isDark ? const Color(0xFF1E293B) : Colors.white;

        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentFilteredList = items.where((item) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              if (isFaculty) {
                final name = (item['name'] ?? '').toString().toLowerCase();
                final code = (item['employee_code'] ?? '').toString().toLowerCase();
                return name.contains(q) || code.contains(q);
              } else if (isVehicle) {
                final vNum = (item['vehicle_number'] ?? '').toString().toLowerCase();
                final make = (item['make'] ?? '').toString().toLowerCase();
                final model = (item['model'] ?? '').toString().toLowerCase();
                return vNum.contains(q) || make.contains(q) || model.contains(q);
              } else {
                final name = (item['user']?['name'] ?? item['name'] ?? '').toString().toLowerCase();
                final code = (item['employee_code'] ?? '').toString().toLowerCase();
                return name.contains(q) || code.contains(q);
              }
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: BoxDecoration(
                color: modalBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: t,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, size: 20, color: t.withValues(alpha: 0.5)),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: isFaculty
                              ? "Search faculty name or department..."
                              : (isVehicle ? "Search vehicle number or type..." : "Search driver name or phone..."),
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            searchQuery = val;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isFaculty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          onSelect(null);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedId == null
                                ? Colors.red.withValues(alpha: 0.1)
                                : t.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selectedId == null ? Colors.red : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (selectedId == null ? Colors.red : t).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.remove_circle_outline_rounded,
                                  size: 20,
                                  color: selectedId == null ? Colors.red : t.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Unassign Faculty",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: selectedId == null ? Colors.red : t,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Remove current assigned faculty coordinator",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: t.withValues(alpha: 0.4),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedId == null)
                                const Icon(Icons.check_circle_rounded, color: Colors.red, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Expanded(
                    child: currentFilteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 48, color: t.withValues(alpha: 0.2)),
                                const SizedBox(height: 16),
                                Text(
                                  "No matching ${isFaculty ? 'faculties' : (isVehicle ? 'vehicles' : 'drivers')} found",
                                  style: TextStyle(
                                    color: t.withValues(alpha: 0.5),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                            itemCount: currentFilteredList.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final item = currentFilteredList[i];
                              final int? itemId = isFaculty ? item['user_id'] : item['id'];
                              final bool isSelected = selectedId != null && (itemId == selectedId);

                              String main = isFaculty
                                  ? (item['name'] ?? 'Unknown')
                                  : (isVehicle
                                      ? (item['vehicle_number'] ?? 'Unknown')
                                      : (item['user']?['name'] ?? item['name'] ?? "Unknown"));
                              String sub = isFaculty
                                  ? (item['department'] ?? 'Faculty')
                                  : (isVehicle
                                      ? "${item['make'] ?? ''} ${item['model'] ?? ''}".trim()
                                      : "Driver");
                              if (sub.isEmpty) sub = isVehicle ? "Vehicle" : "Driver";
                              int cap = isVehicle ? (int.tryParse(item['capacity']?.toString() ?? "0") ?? 0) : 0;

                              return GestureDetector(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  onSelect(item);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? p.withValues(alpha: 0.1)
                                        : t.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected ? p : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: (isSelected ? p : t).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          isFaculty
                                              ? Icons.school_rounded
                                              : (isVehicle ? Icons.directions_bus_rounded : Icons.person_rounded),
                                          size: 20,
                                          color: isSelected ? p : t.withValues(alpha: 0.5),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              main,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: t,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 8,
                                              children: [
                                                Text(
                                                  sub,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: t.withValues(alpha: 0.4),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                if (isVehicle && cap > 0)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: p.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      "Cap: $cap",
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        color: p,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                                if (isVehicle && item['default_driver'] != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      "👤 ${item['default_driver']['name'] ?? 'Driver'}",
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                        color: Colors.green,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(Icons.check_circle_rounded, color: p, size: 20),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final status = (widget.run['status'] ?? '').toString().toUpperCase();
    final bool isPlannedOrReady = status == 'PLANNED' || status == 'READY';

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header with robust Expanded segments to prevent overflows
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.edit_road_rounded, color: primaryBlue, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.editFacultyOnly ? "REASSIGN FACULTY" : "EDIT VEHICLE & DRIVER",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: primaryBlue,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Cancel Button
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: subColor,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: subColor.withValues(alpha: 0.2)),
                      ),
                    ),
                    child: Text("Cancel", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  // Save Button
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                        : Text("Save", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),

            if (_isLoadingLookups)
              _buildShimmerLoading(isDark)
            else if (_errorMessage != null)
              Expanded(child: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))))
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shift Segment Toggles
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            if (isPlannedOrReady) ...[
                              _buildShiftToggle('MORNING', 'MORNING', primaryBlue, subColor),
                              _buildShiftToggle('EVENING', 'EVENING', primaryBlue, subColor),
                              _buildShiftToggle('BOTH', 'BOTH', primaryBlue, subColor),
                            ] else ...[
                              // Hides MORNING and BOTH options if status is STARTED and above
                              _buildShiftToggle('EVENING', 'EVENING ONLY', primaryBlue, subColor, fillWidth: true),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      if (!widget.editFacultyOnly) ...[
                        // Vehicle selector card
                        Row(
                          children: [
                            Text(
                              "SELECT VEHICLE",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: subColor, letterSpacing: 0.8),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _selectedShift == 'BOTH'
                                    ? primaryBlue.withValues(alpha: 0.1)
                                    : (_selectedShift == 'MORNING' ? Colors.orange.withValues(alpha: 0.1) : Colors.purple.withValues(alpha: 0.1)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _selectedShift == 'BOTH' ? 'BOTH SHIFTS' : '${_selectedShift} ONLY',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: _selectedShift == 'BOTH'
                                        ? primaryBlue
                                        : (_selectedShift == 'MORNING' ? Colors.orange : Colors.purple),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showSelectionSheet(
                            title: "Select Vehicle",
                            isVehicle: true,
                            items: _vehicles,
                            selectedId: _selectedVehicleId,
                            onSelect: (v) {
                              setState(() {
                                _selectedVehicleId = v['id'];
                                _selectedVehicleNum = v['vehicle_number'] ?? 'N/A';

                                if (_selectedShift == 'BOTH') {
                                  _selectedMorningVehicleId = v['id'];
                                  _selectedMorningVehicleNum = v['vehicle_number'] ?? 'N/A';
                                  _selectedEveningVehicleId = v['id'];
                                  _selectedEveningVehicleNum = v['vehicle_number'] ?? 'N/A';
                                } else if (_selectedShift == 'MORNING') {
                                  _selectedMorningVehicleId = v['id'];
                                  _selectedMorningVehicleNum = v['vehicle_number'] ?? 'N/A';
                                } else {
                                  _selectedEveningVehicleId = v['id'];
                                  _selectedEveningVehicleNum = v['vehicle_number'] ?? 'N/A';
                                }
                              });
                            },
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: primaryBlue.withValues(alpha: 0.08)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.directions_bus_rounded, color: primaryBlue, size: 20),
                                const SizedBox(width: 14),
                                Text(
                                  _selectedVehicleNum,
                                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor),
                                ),
                                const Spacer(),
                                Icon(Icons.keyboard_arrow_down_rounded, color: subColor),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Driver selector card
                        Row(
                          children: [
                            Text(
                              "SELECT DRIVER",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: subColor, letterSpacing: 0.8),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _selectedShift == 'BOTH'
                                    ? primaryBlue.withValues(alpha: 0.1)
                                    : (_selectedShift == 'MORNING' ? Colors.orange.withValues(alpha: 0.1) : Colors.purple.withValues(alpha: 0.1)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _selectedShift == 'BOTH' ? 'BOTH SHIFTS' : '${_selectedShift} ONLY',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: _selectedShift == 'BOTH'
                                      ? primaryBlue
                                      : (_selectedShift == 'MORNING' ? Colors.orange : Colors.purple),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showSelectionSheet(
                            title: "Select Driver",
                            isVehicle: false,
                            items: _drivers,
                            selectedId: _selectedDriverId,
                            onSelect: (d) {
                              setState(() {
                                _selectedDriverId = d['id'];
                                _selectedDriverName = d['user']?['name'] ?? d['name'] ?? 'N/A';

                                if (_selectedShift == 'BOTH') {
                                  _selectedMorningDriverId = d['id'];
                                  _selectedMorningDriverName = d['user']?['name'] ?? d['name'] ?? 'N/A';
                                  _selectedEveningDriverId = d['id'];
                                  _selectedEveningDriverName = d['user']?['name'] ?? d['name'] ?? 'N/A';
                                } else if (_selectedShift == 'MORNING') {
                                  _selectedMorningDriverId = d['id'];
                                  _selectedMorningDriverName = d['user']?['name'] ?? d['name'] ?? 'N/A';
                                } else {
                                  _selectedEveningDriverId = d['id'];
                                  _selectedEveningDriverName = d['user']?['name'] ?? d['name'] ?? 'N/A';
                                }
                              });
                            },
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: primaryBlue.withValues(alpha: 0.08)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.person_pin_rounded, color: Colors.orange, size: 20),
                                const SizedBox(width: 14),
                                Text(
                                  _selectedDriverName,
                                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor),
                                ),
                                const Spacer(),
                                Icon(Icons.keyboard_arrow_down_rounded, color: subColor),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Assigned Faculty coordinator selector card
                      Row(
                        children: [
                          Text(
                            "SELECT ASSIGNED FACULTY",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: subColor, letterSpacing: 0.8),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _selectedShift == 'BOTH'
                                  ? primaryBlue.withValues(alpha: 0.1)
                                  : (_selectedShift == 'MORNING' ? Colors.orange.withValues(alpha: 0.1) : Colors.purple.withValues(alpha: 0.1)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _selectedShift == 'BOTH' ? 'BOTH SHIFTS' : '${_selectedShift} ONLY',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: _selectedShift == 'BOTH'
                                    ? primaryBlue
                                    : (_selectedShift == 'MORNING' ? Colors.orange : Colors.purple),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showSelectionSheet(
                          title: "Select Assigned Faculty",
                          isVehicle: false,
                          isFaculty: true,
                          items: _faculties,
                          selectedId: _selectedFacultyId,
                          onSelect: (f) {
                            if (f == null) {
                              setState(() {
                                _selectedFacultyId = null;
                                _selectedFacultyName = 'Select Assigned Faculty';

                                if (_selectedShift == 'BOTH') {
                                  _selectedMorningFacultyId = null;
                                  _selectedMorningFacultyName = 'Select Assigned Faculty';
                                  _morningFacultyRemarks = null;
                                  _selectedEveningFacultyId = null;
                                  _selectedEveningFacultyName = 'Select Assigned Faculty';
                                  _eveningFacultyRemarks = null;
                                } else if (_selectedShift == 'MORNING') {
                                  _selectedMorningFacultyId = null;
                                  _selectedMorningFacultyName = 'Select Assigned Faculty';
                                  _morningFacultyRemarks = null;
                                } else {
                                  _selectedEveningFacultyId = null;
                                  _selectedEveningFacultyName = 'Select Assigned Faculty';
                                  _eveningFacultyRemarks = null;
                                }
                              });
                            } else {
                              _showRemarksBottomSheet(f);
                            }
                          },
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.purple.withValues(alpha: 0.08)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.supervisor_account_rounded, color: Colors.purple, size: 20),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  _selectedFacultyName,
                                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded, color: subColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftToggle(String code, String label, Color primaryBlue, Color subColor, {bool fillWidth = false}) {
    final bool isSelected = _selectedShift == code;
    final widgetContent = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))]
            : [],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? primaryBlue : subColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );

    if (fillWidth) {
      return Expanded(child: widgetContent);
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedShift = code;
            _syncDisplayedSelections();
          });
        },
        child: widgetContent,
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    final Color baseColor = isDark ? const Color(0xFF1E293B) : Colors.grey[300]!;
    final Color highlightColor = isDark ? const Color(0xFF334155) : Colors.grey[100]!;

    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shift toggles skeleton
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 28),

              if (!widget.editFacultyOnly) ...[
                // Vehicle selector skeleton
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 24),

                // Driver selector skeleton
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Faculty selector skeleton
              Container(
                width: 150,
                height: 14,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangeResult {
  final bool success;
  final String? message;
  _ChangeResult(this.success, this.message);
}
