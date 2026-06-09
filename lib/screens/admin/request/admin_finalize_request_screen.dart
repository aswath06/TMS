import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/store/VehicleStore.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:intl/intl.dart';
import 'package:tripzo/utils/toast_utils.dart';

class AdminFinalizeRequestScreen extends ConsumerStatefulWidget {
  final String requestId;

  const AdminFinalizeRequestScreen({super.key, required this.requestId});

  @override
  ConsumerState<AdminFinalizeRequestScreen> createState() => _AdminFinalizeRequestScreenState();
}

class _AdminFinalizeRequestScreenState extends ConsumerState<AdminFinalizeRequestScreen> {
  bool _isLoading = true;
  bool _isFinalizing = false;
  Map<String, dynamic>? _requestData;
  
  // State for groupings and assignments
  List<Map<String, dynamic>> _groups = [];
  List<dynamic> _availableVehicles = [];
  List<dynamic> _availableDrivers = [];
  bool _isLoadingFleet = false;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final token = await UserStore.getToken();
      final url = "${ApiConstants.getRouteById}${widget.requestId}";
      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true) {
          final data = decoded['data'];
          _requestData = data;
          
          // Initialize passenger groups from vehicle_config
          final config = data['vehicle_config'];
          final groupsData = config['passenger_groups'] as List?;
          
          if (groupsData != null && groupsData.isNotEmpty) {
            _groups = groupsData.map((g) {
              return {
                "label": g['group_label'] ?? "Vehicle Group",
                "passengers": List<Map<String, dynamic>>.from(g['passengers'] ?? []),
                "vehicle_id": null,
                "driver_id": null,
                "remark": "",
              };
            }).toList();
          } else {
            // Default group if none exist
            _groups = [{
              "label": "Vehicle Group 1",
              "passengers": List<Map<String, dynamic>>.from(data['passengers'] ?? []),
              "vehicle_id": null,
              "driver_id": null,
              "remark": "",
            }];
          }

          // Fetch available fleet after details are loaded
          _fetchAvailableFleet();
        }
      }
    } catch (e) {
      debugPrint("Fetch Details Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAvailableFleet() async {
    final start = _requestData?['travel_info']?['start_datetime'];
    final end = _requestData?['travel_info']?['end_datetime'];
    if (start == null || end == null) return;

    setState(() => _isLoadingFleet = true);
    try {
      final token = await UserStore.getToken();
      
      // Fetch available vehicles
      final vUrl = Uri.parse(ApiConstants.getAvailableVehicles).replace(queryParameters: {
        "start_datetime": start.toString(),
        "end_datetime": end.toString(),
      });
      final vResp = await http.get(vUrl, headers: ApiConstants.getHeaders(token));
      if (vResp.statusCode == 200) {
        final decoded = json.decode(vResp.body);
        _availableVehicles = decoded['data']?['vehicles'] ?? [];
      }

      // Fetch available drivers
      final dUrl = Uri.parse(ApiConstants.getAvailableDrivers).replace(queryParameters: {
        "start_datetime": start.toString(),
        "end_datetime": end.toString(),
      });
      final dResp = await http.get(dUrl, headers: ApiConstants.getHeaders(token));
      if (dResp.statusCode == 200) {
        final decoded = json.decode(dResp.body);
        _availableDrivers = decoded['data']?['drivers'] ?? [];
      }
    } catch (e) {
      debugPrint("Fetch Fleet Error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingFleet = false);
    }
  }

  Future<void> _showSelectionSheet({
    required String title,
    required List<dynamic> items,
    required Map<String, dynamic>? selected,
    required Function(Map<String, dynamic>) onSelect,
    required bool isVehicle,
    required Color p,
    required Color t,
    int? currentGuestCount,
  }) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter and Sort items
    List<dynamic> filteredItems = List.from(items);
    if (isVehicle && currentGuestCount != null) {
      filteredItems.sort((a, b) {
        int ac = int.tryParse(a['capacity']?.toString() ?? "0") ?? 0;
        int bc = int.tryParse(b['capacity']?.toString() ?? "0") ?? 0;
        
        bool aAvail = (a['available'] != false);
        bool bAvail = (b['available'] != false);

        if (aAvail != bAvail) return aAvail ? -1 : 1;

        // Secondary sort: default driver first
        bool aDef = a['default_driver'] != null;
        bool bDef = b['default_driver'] != null;
        if (aDef != bDef) return aDef ? -1 : 1;

        return ac.compareTo(bc); 
      });
    } else if (!isVehicle) {
       // Driver sorting: Backend availability takes precedence
       filteredItems.sort((a, b) {
         bool aAvail = (a['available'] == true);
         bool bAvail = (b['available'] == true);
         if (aAvail != bAvail) return aAvail ? -1 : 1;
         
         // Secondary sort: Available status first among same-availability group
         if (aAvail) {
           bool aReady = a['status'] == "AVAILABLE";
           bool bReady = b['status'] == "AVAILABLE";
           if (aReady != bReady) return aReady ? -1 : 1;
         }
         return 0;
       });
    }

    String searchQuery = "";

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final bool isDark = Theme.of(context).brightness == Brightness.dark;

            final List<dynamic> currentFilteredList = filteredItems.where((item) {
              if (searchQuery.isEmpty) return true;
              if (isVehicle) {
                final vNumber = (item['vehicle_number'] ?? "").toString().toLowerCase();
                final vType = (item['vehicle_type_name'] ?? "").toString().toLowerCase();
                return vNumber.contains(searchQuery.toLowerCase()) || 
                       vType.contains(searchQuery.toLowerCase());
              } else {
                final dName = (item['name'] ?? item['user']?['name'] ?? "").toString().toLowerCase();
                final dPhone = (item['phone'] ?? item['user']?['phone'] ?? "").toString().toLowerCase();
                return dName.contains(searchQuery.toLowerCase()) || 
                       dPhone.contains(searchQuery.toLowerCase());
              }
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: t)),
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
                        if (isVehicle && currentGuestCount != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: p.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              "REQUIRED CAPACITY: $currentGuestCount SEATS",
                              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: p, letterSpacing: 0.5),
                            ),
                          ),
                        ]
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
                        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200, width: 1.5),
                      ),
                      child: TextField(
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: isVehicle ? "Search vehicle number or type..." : "Search driver name or phone...",
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600, fontSize: 14),
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
                            Text("No matching ${isVehicle ? 'vehicles' : 'drivers'} found", style: TextStyle(color: t.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                      itemCount: currentFilteredList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final item = currentFilteredList[i];
                        final bool isSelected = selected != null && (item['id'] == selected['id']);
                        
                        String main = isVehicle ? item['vehicle_number'] : (item['name'] ?? item['user']?['name'] ?? "Unknown");
                        String sub = isVehicle ? item['vehicle_type_name'] : "Driver";
                        int cap = isVehicle ? (int.tryParse(item['capacity']?.toString() ?? "0") ?? 0) : 0;
                        
                        String status = (item['status'] ?? "AVAILABLE").toString().toUpperCase();
                        bool isDisabled = (item['available'] == false);

                        return GestureDetector(
                          onTap: isDisabled ? null : () {
                            onSelect(item);
                            Navigator.pop(ctx);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? p.withValues(alpha: 0.1) : (isDisabled ? t.withValues(alpha: 0.02) : t.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? p : (isDisabled ? Colors.red.withValues(alpha: 0.1) : Colors.transparent), width: 1.5),
                            ),
                            child: Opacity(
                              opacity: isDisabled ? 0.5 : 1.0,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: (isSelected ? p : t).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                                    child: Icon(isVehicle ? Icons.directions_bus_rounded : Icons.person_rounded, size: 20, color: isSelected ? p : t.withValues(alpha: 0.5)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(main, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: t)),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            Text(sub, style: TextStyle(fontSize: 12, color: t.withValues(alpha: 0.4), fontWeight: FontWeight.w600)),
                                            if (isVehicle) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: p.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text("Cap: $cap", style: TextStyle(fontSize: 9, color: p, fontWeight: FontWeight.w900))),
                                            if (isVehicle && item['default_driver'] != null) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text("👤 ${item['default_driver']['name']}", style: const TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.w900))),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isDisabled) Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Text("UNAVAILABLE", style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.w900)))
                                  else if (!isVehicle && status == "AVAILABLE") Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Text("AVAILABLE", style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w900))),
                                  if (isSelected) Icon(Icons.check_circle_rounded, color: p, size: 20),
                                ],
                              ),
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
        ),
      ),
    );
  }

  Widget _resSelector({
    required String label,
    required List<dynamic> items,
    required Map<String, dynamic>? selected,
    required Function(Map<String, dynamic>) onSelect,
    required bool isVehicle,
    required Color p,
    required Color t,
    required Color c,
    int? guestCount,
  }) {
    String disp = selected != null ? (isVehicle ? selected['vehicle_number'] : (selected['name'] ?? selected['user']?['name'] ?? "Unknown")) : (isVehicle ? "Choose Vehicle" : "Choose Driver");
    String? sub = selected != null ? (isVehicle ? selected['vehicle_type_name'] : "Driver") : null;
    Map<String, dynamic>? defD = (isVehicle && selected != null) ? selected['default_driver'] : null;

    return GestureDetector(
      onTap: () => _showSelectionSheet(
        title: isVehicle ? "Select Vehicle" : "Select Driver",
        items: items,
        selected: selected,
        onSelect: onSelect,
        isVehicle: isVehicle,
        p: p, t: t,
        currentGuestCount: guestCount,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.withValues(alpha: 0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: p, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (selected != null ? p : t).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(isVehicle ? Icons.directions_bus_filled_rounded : Icons.person_rounded, size: 18, color: selected != null ? p : t.withValues(alpha: 0.3))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(disp, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: selected != null ? t : t.withValues(alpha: 0.3))),
                      if (sub != null) Text(sub, style: TextStyle(fontSize: 11, color: t.withValues(alpha: 0.4), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (defD != null) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text("👤 ${defD['name']}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.green))),
                Icon(Icons.keyboard_arrow_down_rounded, color: t.withValues(alpha: 0.2)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFinalize() async {
    // Validate assignments
    for (var g in _groups) {
      if (g['passengers'].isEmpty) continue;
      if (g['vehicle_id'] == null || g['driver_id'] == null) {
        showTopToast(
          context,
          "Please assign a vehicle and driver for ${g['label']}",
          isError: true,
        );
        return;
      }
    }

    setState(() => _isFinalizing = true);
    try {
      final token = await UserStore.getToken();
      final legCode = (_requestData?['route_details']?['legs'] as List?)?.first?['leg_code'] ?? "LEG-1";

      final body = {
        "route_name": _requestData?['travel_info']?['route_name'] ?? "Finalized Route",
        "purpose": _requestData?['travel_info']?['purpose'] ?? "Business",
        "special_instructions": _requestData?['additional_info']?['special_instructions'] ?? "None",
        "approx_distance_km": _requestData?['route_details']?['approx_distance_km'] ?? 0,
        "approx_duration_minutes": _requestData?['route_details']?['approx_duration'] ?? 0,
        "admin_remark": "Finalized via Mobile APP",
        "groupings": _groups.where((g) => g['passengers'].isNotEmpty).map((g) => {
          "group_label": g['label'],
          "leg_code": legCode,
          "passenger_ids": (g['passengers'] as List).map((p) => p['passenger_id'] ?? p['id']).toList(),
        }).toList(),
        "admin_assignments": [
          {
            "leg_code": legCode,
            "vehicles": _groups.where((g) => g['passengers'].isNotEmpty).map((g) => {
              "vehicle_id": g['vehicle_id'],
              "driver_id": g['driver_id'],
              "passenger_ids": (g['passengers'] as List).map((p) => p['passenger_id'] ?? p['id']).toList(),
              "remarks": g['remark'].isEmpty ? "Allocated" : g['remark'],
            }).toList(),
          }
        ],
      };

      final url = ApiConstants.adminFinalize(widget.requestId);
      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(body),
      );

      final respData = json.decode(response.body);
      if (response.statusCode == 200 && respData['success'] == true) {
        if (!mounted) return;
        showTopToast(context, "Route Finalized Successfully!");
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        showTopToast(
          context,
          respData['message'] ?? "Failed to finalize",
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showTopToast(context, "Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isFinalizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final primaryBlue = const Color(0xFF6366F1);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Manage Allocations", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildSectionHeader("Passenger Groups", Icons.group_add_rounded, primaryBlue, titleColor),
                        const SizedBox(height: 16),
                        ...List.generate(_groups.length, (idx) => _buildGroupCard(_groups[idx], idx, isDark, primaryBlue, titleColor)),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  _buildBottomAction(primaryBlue),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color blue, Color text) {
    return Row(
      children: [
        Icon(icon, color: blue, size: 20),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: text)),
      ],
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group, int index, bool isDark, Color primaryBlue, Color titleColor) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final passengers = group['passengers'] as List<Map<String, dynamic>>;

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) => !passengers.any((p) => (p['passenger_id'] ?? p['id'] ?? '') == (details.data['passenger_id'] ?? details.data['id'] ?? 'NaN')),
      onAcceptWithDetails: (details) {
        setState(() {
          final p = details.data;
          // Add to this group
          passengers.add(p);
          // Remove from others
          for (int i = 0; i < _groups.length; i++) {
            if (i != index) {
              _groups[i]['passengers'].removeWhere((item) => (item['passenger_id'] ?? item['id'] ?? '') == (p['passenger_id'] ?? p['id'] ?? 'NaN'));
            }
          }
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: isHovering ? primaryBlue.withValues(alpha: 0.05) : cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isHovering ? primaryBlue : Colors.transparent, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildGroupHeader(group, index, isDark, primaryBlue, titleColor),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (passengers.isEmpty)
                      _buildEmptyPassengerDrop(primaryBlue)
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: passengers.map((p) => _buildPassengerDraggable(p, primaryBlue)).toList(),
                      ),
                    const SizedBox(height: 20),
                    _buildAllocationDropdowns(group, isDark, primaryBlue, titleColor, subColor),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (v) => group['remark'] = v,
                      style: TextStyle(fontSize: 13, color: titleColor),
                      decoration: InputDecoration(
                        hintText: "Administrative remark...",
                        hintStyle: TextStyle(color: subColor.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: isDark ? Colors.black26 : Colors.grey.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupHeader(Map<String, dynamic> group, int index, bool isDark, Color primaryBlue, Color titleColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Icon(Icons.trip_origin_rounded, color: primaryBlue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              group['label'],
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: titleColor, letterSpacing: 0.5),
            ),
          ),
          if (_groups.length > 1)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => setState(() => _groups.removeAt(index)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyPassengerDrop(Color blue) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: blue.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.add_to_photos_rounded, color: blue.withValues(alpha: 0.5), size: 24),
          const SizedBox(height: 8),
          Text("Drop guests here", style: TextStyle(color: blue.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPassengerDraggable(Map<String, dynamic> person, Color blue) {
    return Draggable<Map<String, dynamic>>(
      data: person,
      feedback: Material(color: Colors.transparent, child: _buildPassengerPill(person, blue, true)),
      childWhenDragging: Opacity(opacity: 0.3, child: _buildPassengerPill(person, Colors.grey, false)),
      child: _buildPassengerPill(person, blue, false),
    );
  }

  Widget _buildPassengerPill(Map<String, dynamic> p, Color color, bool isDragging) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDragging ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_pin_rounded, size: 14, color: isDragging ? Colors.white : color),
          const SizedBox(width: 6),
          Text(
            p['passenger_name'] ?? p['name'] ?? "Guest",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDragging ? Colors.white : color),
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationDropdowns(Map<String, dynamic> group, bool isDark, Color blue, Color title, Color sub) {
    if (_isLoadingFleet) {
      return const Column(
        children: [
           SizedBox(height: 12),
           SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
           SizedBox(height: 12),
        ],
      );
    }

    final cardColor = isDark ? Colors.black26 : Colors.grey.withValues(alpha: 0.05);

    return Column(
      children: [
        _resSelector(
          label: "VEHICLE ALLOCATION",
          items: _availableVehicles,
          selected: _availableVehicles.firstWhere((v) => v['id'] == group['vehicle_id'], orElse: () => null),
          onSelect: (v) {
            setState(() {
              group['vehicle_id'] = v['id'];
              // Smart Propose Default Driver
              final defD = v['default_driver'];
              if (defD != null) {
                final dID = defD['driver_id'];
                if (_availableDrivers.any((d) => d['id'] == dID)) {
                  group['driver_id'] = dID;
                }
              }
            });
          },
          isVehicle: true,
          p: blue, t: title, c: cardColor,
          guestCount: (group['passengers'] as List).length,
        ),
        _resSelector(
          label: "DRIVER ASSIGNMENT",
          items: _availableDrivers,
          selected: _availableDrivers.firstWhere((d) => d['id'] == group['driver_id'], orElse: () => null),
          onSelect: (d) => setState(() => group['driver_id'] = d['id']),
          isVehicle: false,
          p: blue, t: title, c: cardColor,
        ),
      ],
    );
  }

  Widget _buildBottomAction(Color blue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isFinalizing ? null : _handleFinalize,
          style: ElevatedButton.styleFrom(
            backgroundColor: blue,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 4,
          ),
          child: _isFinalizing 
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("CREATE FULL ROUTE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
      ),
    );
  }
}
