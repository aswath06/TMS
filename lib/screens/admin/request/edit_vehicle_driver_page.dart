import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';

class EditVehicleDriverPage extends StatefulWidget {
  final Map<String, dynamic> run;
  const EditVehicleDriverPage({super.key, required this.run});

  @override
  State<EditVehicleDriverPage> createState() => _EditVehicleDriverPageState();
}

class _EditVehicleDriverPageState extends State<EditVehicleDriverPage> {
  bool _isLoadingLookups = true;
  bool _isSaving = false;
  String? _errorMessage;

  List<dynamic> _vehicles = [];
  List<dynamic> _drivers = [];

  // Selections
  int? _selectedVehicleId;
  String _selectedVehicleNum = 'Select Vehicle';
  int? _selectedDriverId;
  String _selectedDriverName = 'Select Driver';
  String _selectedShift = 'BOTH'; // 'MORNING', 'EVENING', 'BOTH'

  // Tracks original states to avoid duplicate / redundant API requests
  int? _initialVehicleId;
  int? _initialDriverId;

  @override
  void initState() {
    super.initState();
    _initializeSelections();
    _fetchLookups();
  }

  void _initializeSelections() {
    final status = (widget.run['status'] ?? '').toString().toUpperCase();
    final bool isPlanned = status == 'PLANNED';
    
    // If status is READY and above, default shift is EVENING
    _selectedShift = isPlanned ? 'BOTH' : 'EVENING';

    final assignments = widget.run['assignment'] as List? ?? [];
    if (assignments.isNotEmpty) {
      final assign = assignments.first;
      final vehicle = assign['vehicle'];
      if (vehicle != null) {
        _selectedVehicleId = vehicle['id'];
        _selectedVehicleNum = vehicle['vehicle_number'] ?? 'Select Vehicle';
        _initialVehicleId = vehicle['id'];
      }
      final driver = assign['driver'];
      if (driver != null) {
        _selectedDriverId = driver['id'];
        _selectedDriverName = driver['user']?['name'] ?? 'Select Driver';
        _initialDriverId = driver['id'];
      }
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

      final vRes = await http.get(Uri.parse(ApiConstants.getAllVehiclesWithoutPagination), headers: headers);
      final dRes = await http.get(Uri.parse(ApiConstants.getAllDriversWithoutPagination), headers: headers);

      if (vRes.statusCode == 200 && dRes.statusCode == 200) {
        final vData = json.decode(vRes.body);
        final dData = json.decode(dRes.body);

        setState(() {
          _vehicles = vData['data'] as List? ?? [];
          _drivers = dData['data'] as List? ?? [];
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

  Future<void> _saveChanges() async {
    final String runId = widget.run['id']?.toString() ?? '';
    final String? token = await UserStore.getToken();
    if (token == null) {
      _showSnackBar("Session expired. Please log in again.", Colors.red);
      return;
    }

    final headers = ApiConstants.getHeaders(token);

    // Map UI shifts to API shift codes
    String shiftCode = 'FULL_DAY';
    if (_selectedShift == 'MORNING') shiftCode = 'MORNING';
    if (_selectedShift == 'EVENING') shiftCode = 'EVENING';

    final bool isVehicleChanged = _selectedVehicleId != _initialVehicleId;
    final bool isDriverChanged = _selectedDriverId != _initialDriverId;

    if (!isVehicleChanged && !isDriverChanged) {
      _showSnackBar("No changes detected", Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      bool vSuccess = true;
      bool dSuccess = true;
      String? errorMsg;

      // 1. Change Vehicle API call
      if (isVehicleChanged && _selectedVehicleId != null) {
        final url = "${ApiConstants.baseUrl}/daily-bus/bus-runs/$runId/change-vehicle";
        final body = {
          "vehicle_id": _selectedVehicleId,
          "shift_code": shiftCode,
          "remarks": "Changed vehicle from UI",
        };

        // Console log request curl
        final curlCmd = "curl -X PATCH '$url' \\\n"
            "  -H 'accept: */*' \\\n"
            "  -H 'authorization: TMS $token' \\\n"
            "  -H 'content-type: application/json' \\\n"
            "  --data-raw '${json.encode(body)}'";
        debugPrint("---- [HTTP REQUEST CURL (VEHICLE)] ----\n$curlCmd\n----------------------------");

        final res = await http.patch(Uri.parse(url), headers: headers, body: json.encode(body));
        debugPrint("---- [HTTP RESPONSE STATUS (VEHICLE): ${res.statusCode}] ----\n${res.body}\n----------------------------");

        if (res.statusCode == 200) {
          final resData = json.decode(res.body);
          if (resData['success'] != true) {
            vSuccess = false;
            errorMsg = resData['message'];
          }
        } else {
          vSuccess = false;
          errorMsg = "Server error updating vehicle: ${res.statusCode}";
        }
      }

      // 2. Change Driver API call
      if (isDriverChanged && _selectedDriverId != null) {
        final url = "${ApiConstants.baseUrl}/daily-bus/bus-runs/$runId/change-driver";
        final body = {
          "driver_id": _selectedDriverId,
          "shift_code": shiftCode,
          "remarks": "Changed driver from UI",
        };

        // Console log request curl
        final curlCmd = "curl -X PATCH '$url' \\\n"
            "  -H 'accept: */*' \\\n"
            "  -H 'authorization: TMS $token' \\\n"
            "  -H 'content-type: application/json' \\\n"
            "  --data-raw '${json.encode(body)}'";
        debugPrint("---- [HTTP REQUEST CURL (DRIVER)] ----\n$curlCmd\n----------------------------");

        final res = await http.patch(Uri.parse(url), headers: headers, body: json.encode(body));
        debugPrint("---- [HTTP RESPONSE STATUS (DRIVER): ${res.statusCode}] ----\n${res.body}\n----------------------------");

        if (res.statusCode == 200) {
          final resData = json.decode(res.body);
          if (resData['success'] != true) {
            dSuccess = false;
            if (errorMsg == null) {
              errorMsg = resData['message'];
            } else {
              errorMsg = "$errorMsg | ${resData['message']}";
            }
          }
        } else {
          dSuccess = false;
          final err = "Server error updating driver: ${res.statusCode}";
          errorMsg = errorMsg == null ? err : "$errorMsg | $err";
        }
      }

      if (vSuccess && dSuccess) {
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

  void _showSelectionSheet({
    required String title,
    required bool isVehicle,
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
        final Color p = const Color(0xFF6366F1);
        final Color modalBg = isDark ? const Color(0xFF1E293B) : Colors.white;

        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentFilteredList = items.where((item) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              if (isVehicle) {
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
                          hintText: isVehicle ? "Search vehicle number or type..." : "Search driver name or phone...",
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
                  Expanded(
                    child: currentFilteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 48, color: t.withValues(alpha: 0.2)),
                                const SizedBox(height: 16),
                                Text(
                                  "No matching ${isVehicle ? 'vehicles' : 'drivers'} found",
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
                              final bool isSelected = selectedId != null && (item['id'] == selectedId);

                              String main = isVehicle
                                  ? (item['vehicle_number'] ?? 'Unknown')
                                  : (item['user']?['name'] ?? item['name'] ?? "Unknown");
                              String sub = isVehicle
                                  ? "${item['make'] ?? ''} ${item['model'] ?? ''}".trim()
                                  : "Driver";
                              if (sub.isEmpty) sub = "Vehicle";
                              int cap = isVehicle ? (int.tryParse(item['capacity']?.toString() ?? "0") ?? 0) : 0;

                              return GestureDetector(
                                onTap: () {
                                  onSelect(item);
                                  Navigator.pop(ctx);
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
                                          isVehicle ? Icons.directions_bus_rounded : Icons.person_rounded,
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
    final bool isPlanned = status == 'PLANNED';

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
                            "EDIT VEHICLE & DRIVER",
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
              const Expanded(child: Center(child: CircularProgressIndicator()))
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
                            if (isPlanned) ...[
                              _buildShiftToggle('MORNING', 'MORNING', primaryBlue, subColor),
                              _buildShiftToggle('EVENING', 'EVENING', primaryBlue, subColor),
                              _buildShiftToggle('BOTH', 'BOTH', primaryBlue, subColor),
                            ] else ...[
                              // Hides MORNING and BOTH options if status is READY and above
                              _buildShiftToggle('EVENING', 'EVENING ONLY', primaryBlue, subColor, fillWidth: true),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Vehicle selector card
                      Text(
                        "SELECT VEHICLE",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: subColor, letterSpacing: 0.8),
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
                      Text(
                        "SELECT DRIVER",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: subColor, letterSpacing: 0.8),
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
        onTap: () => setState(() => _selectedShift = code),
        child: widgetContent,
      ),
    );
  }
}
