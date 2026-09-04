import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/store/providers.dart';

class DutyAllocationDetailsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> schedule;

  const DutyAllocationDetailsScreen({
    super.key,
    required this.schedule,
  });

  @override
  ConsumerState<DutyAllocationDetailsScreen> createState() => _DutyAllocationDetailsScreenState();
}

class _DutyAllocationDetailsScreenState extends ConsumerState<DutyAllocationDetailsScreen> {
  List<Map<String, dynamic>> _mistakeOptions = [
    {'id': 1, 'name': 'Super Admin'},
    {'id': 2, 'name': 'Admin'},
    {'id': 3, 'name': 'Driver'},
    {'id': 4, 'name': 'Helper'},
    {'id': 5, 'name': 'Operator'},
    {'id': 6, 'name': 'User'},
    {'id': 7, 'name': 'Vendor'},
    {'id': 8, 'name': 'Organization'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchRoles();
  }

  Future<void> _fetchRoles() async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return;
      
      final res = await http.get(
        Uri.parse(ApiConstants.getRoles),
        headers: ApiConstants.getHeaders(token),
      );
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> roles = data['data'];
          final List<Map<String, dynamic>> fetchedRoles = roles
              .map((r) => {'id': r['id'], 'name': r['name']?.toString() ?? ''})
              .where((r) => r['name'] != '')
              .toList();
              
          if (fetchedRoles.isNotEmpty && mounted) {
            setState(() {
              _mistakeOptions = fetchedRoles;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching roles: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final String name = widget.schedule['schedule_name'] ?? widget.schedule['template']?['name'] ?? 'Unnamed Schedule';
    final String dutyDateStr = widget.schedule['duty_date'] ?? '';
    
    String formattedDate = dutyDateStr;
    if (dutyDateStr.isNotEmpty) {
      try {
        final date = DateTime.parse(dutyDateStr);
        formattedDate = DateFormat('MMMM dd, yyyy').format(date);
      } catch (e) {
        // ignore
      }
    }

    final List<dynamic> shifts = widget.schedule['masterShifts'] ?? [];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Schedule Details",
          style: TextStyle(
            color: titleColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: primaryBlue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "SHIFTS & ASSIGNMENTS",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: subColor,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            if (shifts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    "No shifts assigned to this schedule.",
                    style: TextStyle(color: subColor),
                  ),
                ),
              )
            else
              ...shifts.map((shift) => _buildShiftCard(shift, cardColor, titleColor, subColor, primaryBlue)),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCard(dynamic shift, Color cardColor, Color titleColor, Color subColor, Color primaryBlue) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    final String shiftName = shift['shift_name'] ?? 'Unnamed Shift';
    final String shiftStart = shift['shift_start'] ?? '--:--';
    final String shiftEnd = shift['shift_end'] ?? '--:--';
    final String shiftStatus = shift['status'] ?? 'UNKNOWN';

    final List<dynamic> drivers = shift['drivers'] ?? [];
    final List<dynamic> vehicles = shift['vehicles'] ?? [];

    bool showDirectStart = false;
    bool showDirectEnd = false;

    for (var v in vehicles) {
      final int vId = v['vehicle_id'] ?? v['vehicle']?['id'] ?? v['id'] ?? 0;
      final dynamic odo = v['odometer'] ?? (shift['odometers'] as List<dynamic>? ?? []).firstWhere(
        (o) => o['vehicle_id']?.toString() == vId.toString(),
        orElse: () => null
      ) ?? v;
      
      String startOdo = "--";
      String endOdo = "--";
      
      if (odo != null && odo is Map) {
        if (odo['start_odometer'] != null) startOdo = odo['start_odometer'].toString();
        else if (odo['startOdometer'] != null) startOdo = odo['startOdometer'].toString();
        if (odo['end_odometer'] != null) endOdo = odo['end_odometer'].toString();
        else if (odo['endOdometer'] != null) endOdo = odo['endOdometer'].toString();
      }

      if (startOdo == "--") {
        if (shift['start_odometer'] != null) startOdo = shift['start_odometer'].toString();
        else if (shift['startOdometer'] != null) startOdo = shift['startOdometer'].toString();
        else if (v['pivot'] != null && v['pivot']['start_odometer'] != null) startOdo = v['pivot']['start_odometer'].toString();
        else if (v['pivot'] != null && v['pivot']['startOdometer'] != null) startOdo = v['pivot']['startOdometer'].toString();
        else if (v['start_odometer'] != null) startOdo = v['start_odometer'].toString();
      }

      if (endOdo == "--" || endOdo == "Started") {
        if (shift['end_odometer'] != null) endOdo = shift['end_odometer'].toString();
        else if (shift['endOdometer'] != null) endOdo = shift['endOdometer'].toString();
        else if (v['pivot'] != null && v['pivot']['end_odometer'] != null) endOdo = v['pivot']['end_odometer'].toString();
        else if (v['pivot'] != null && v['pivot']['endOdometer'] != null) endOdo = v['pivot']['endOdometer'].toString();
        else if (v['end_odometer'] != null) endOdo = v['end_odometer'].toString();
      }

      if (startOdo == "--") showDirectStart = true;
      if (startOdo != "--" && (endOdo == "--" || endOdo == "Started")) {
        showDirectEnd = true;
      }
    }
    
    if (vehicles.isEmpty) {
        if (shiftStatus == 'PLANNED' || shiftStatus == 'READY') showDirectStart = true;
        if (shiftStatus == 'STARTED' || shiftStatus == 'ONGOING') showDirectEnd = true;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryBlue.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shift Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shiftName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 14, color: subColor),
                          const SizedBox(width: 4),
                          Text(
                            "$shiftStart - $shiftEnd",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: subColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(shiftStatus),
              ],
            ),
          ),
          
          // Drivers and Vehicles
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("ASSIGNED DRIVERS", Icons.people_alt_rounded, primaryBlue),
                const SizedBox(height: 12),
                if (drivers.isEmpty)
                  Text("No drivers assigned.", style: TextStyle(color: subColor, fontSize: 13))
                else
                  ...drivers.map((d) {
                    final String dName = d['driver']?['user']?['name'] ?? 'Unknown Driver';
                    final String type = d['assignment_type'] ?? 'PRIMARY';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.01),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: primaryBlue.withOpacity(0.1),
                            child: Icon(Icons.person, size: 20, color: primaryBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              dName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: type == 'PRIMARY' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: type == 'PRIMARY' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: type == 'PRIMARY' ? Colors.green : Colors.orange,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                
                const Divider(height: 32),
                
                _buildSectionHeader("ASSIGNED VEHICLES", Icons.directions_bus_rounded, Colors.orange),
                const SizedBox(height: 12),
                if (vehicles.isEmpty)
                  Text("No vehicles assigned.", style: TextStyle(color: subColor, fontSize: 13))
                else
                  ...vehicles.asMap().entries.expand<Widget>((entry) {
                    final int vIndex = entry.key;
                    final dynamic v = entry.value;
                    
                    final String vNum = v['vehicle']?['vehicle_number'] ?? v['vehicle_number'] ?? 'Unknown Vehicle';
                    final int vId = v['vehicle_id'] ?? v['vehicle']?['id'] ?? v['id'] ?? 0;
                    
                    List<dynamic> vehicleOdos = [];
                    if (v['odometer'] != null) {
                       vehicleOdos.add(v['odometer']);
                    } else {
                       vehicleOdos = (shift['odometers'] as List<dynamic>? ?? []).where((o) => o['vehicle_id']?.toString() == vId.toString()).toList();
                    }
                    if (vehicleOdos.isEmpty) vehicleOdos = [v];

                    return vehicleOdos.map((odo) {
                    
                    // Find assigned driver
                    String driverInfo = "No driver assigned";
                    final List<dynamic> drvs = shift['drivers'] ?? [];
                    final drvMatch = drvs.lastWhere(
                      (d) => d['vehicle_id']?.toString() == vId.toString(),
                      orElse: () => null
                    );
                    
                    if (drvMatch != null) {
                      driverInfo = drvMatch['driver']?['user']?['name'] ?? "Unknown Driver";
                    } else if (v['assignedDriver'] != null) {
                      driverInfo = v['assignedDriver']['user']?['name'] ?? "Unknown Driver";
                    } else if (v['assigned_driver_id'] != null) {
                       driverInfo = "Driver ID: ${v['assigned_driver_id']}";
                    }
                    
                    // Prioritize odometer driver if shift has started and odometer has a driver
                    if (odo != null && odo is Map && odo['driver_id'] != null) {
                       if (odo['driver']?['user']?['name'] != null) {
                          driverInfo = odo['driver']['user']['name'];
                       } else {
                          final odoDrv = drvs.lastWhere(
                             (d) => d['driver_id']?.toString() == odo['driver_id'].toString() || d['id']?.toString() == odo['driver_id'].toString(), 
                             orElse: () => null
                          );
                          if (odoDrv != null) {
                             driverInfo = odoDrv['driver']?['user']?['name'] ?? "Unknown Driver (ID: ${odo['driver_id']})";
                          } else {
                             driverInfo = "Driver ID: ${odo['driver_id']}";
                          }
                       }
                    }
                    
                    bool hasStartedVehicle = odo != null && odo['start_odometer'] != null;
                    if (hasStartedVehicle && driverInfo == "No driver assigned") {
                        // Fallback: assume the driver at the same index as the vehicle is the one who drove it
                        if (drvs.isNotEmpty) {
                           if (drvs.length > vIndex) {
                               driverInfo = drvs[vIndex]['driver']?['user']?['name'] ?? "Unknown Driver";
                           } else {
                               driverInfo = drvs[0]['driver']?['user']?['name'] ?? "Unknown Driver";
                           }
                        }
                    }
                    
                    String formatOdo(dynamic value) {
                      if (value == null) return '--';
                      double val = double.tryParse(value.toString()) ?? 0;
                      return val == val.toInt() ? val.toInt().toString() : val.toString();
                    }
                    
                    String startOdo = "--";
                    String endOdo = "--";
                    String distance = "--";
                    String startTime = "";
                    String endTime = "";
                    String durationStr = "";

                    DateTime? startDt;
                    DateTime? endDt;

                    final List<String> possibleStartKeys = ['updated_at', 'updatedAt', 'start_time', 'startTime', 'started_at', 'startedAt', 'start_date', 'startDate', 'actual_start_time', 'actualStartTime', 'start_odometer_time', 'startOdometerTime', 'created_at', 'createdAt'];
                    final List<String> possibleEndKeys = ['updated_at', 'updatedAt', 'end_time', 'endTime', 'ended_at', 'endedAt', 'end_date', 'endDate', 'actual_end_time', 'actualEndTime', 'end_odometer_time', 'endOdometerTime'];

                    if (odo != null && odo['start_odometer'] != null) {
                      for (String key in possibleStartKeys) {
                        if (odo[key] != null) { try { startDt = DateTime.parse(odo[key]).toLocal(); startTime = DateFormat('hh:mm a').format(startDt!); break; } catch (_) {} }
                        if (v[key] != null) { try { startDt = DateTime.parse(v[key]).toLocal(); startTime = DateFormat('hh:mm a').format(startDt!); break; } catch (_) {} }
                      }
                    }
                    if (odo != null && odo['end_odometer'] != null) {
                      for (String key in possibleEndKeys) {
                        if (odo[key] != null) { try { endDt = DateTime.parse(odo[key]).toLocal(); endTime = DateFormat('hh:mm a').format(endDt!); break; } catch (_) {} }
                        if (v[key] != null) { try { endDt = DateTime.parse(v[key]).toLocal(); endTime = DateFormat('hh:mm a').format(endDt!); break; } catch (_) {} }
                      }
                    }
                    if (startTime.isEmpty && shift['actual_start_time'] != null) {
                      try { startDt = DateTime.parse(shift['actual_start_time']).toLocal(); startTime = DateFormat('hh:mm a').format(startDt!); } catch (_) {}
                    }
                    if (endTime.isEmpty && shift['actual_end_time'] != null) {
                      try { endDt = DateTime.parse(shift['actual_end_time']).toLocal(); endTime = DateFormat('hh:mm a').format(endDt!); } catch (_) {}
                    }
                    if (startDt != null && endDt != null) {
                      Duration diff = endDt!.difference(startDt!).abs();
                      int hours = diff.inHours;
                      int mins = diff.inMinutes.remainder(60);
                      if (hours > 0) {
                        durationStr = "${hours}h ${mins}m";
                      } else {
                        durationStr = "${mins}m";
                      }
                    }

                    if (odo != null && odo is Map) {
                      if (odo['start_odometer'] != null) startOdo = formatOdo(odo['start_odometer']);
                      else if (odo['startOdometer'] != null) startOdo = formatOdo(odo['startOdometer']);
                      
                      if (odo['end_odometer'] != null) endOdo = formatOdo(odo['end_odometer']);
                      else if (odo['endOdometer'] != null) endOdo = formatOdo(odo['endOdometer']);
                    }

                    if (startOdo == "--") {
                      if (shift['start_odometer'] != null) startOdo = formatOdo(shift['start_odometer']);
                      else if (shift['startOdometer'] != null) startOdo = formatOdo(shift['startOdometer']);
                      else if (v['pivot'] != null && v['pivot']['start_odometer'] != null) startOdo = formatOdo(v['pivot']['start_odometer']);
                      else if (v['pivot'] != null && v['pivot']['startOdometer'] != null) startOdo = formatOdo(v['pivot']['startOdometer']);
                      else if (v['start_odometer'] != null) startOdo = formatOdo(v['start_odometer']);
                    }
                    
                    if (endOdo == "--" || endOdo == "Started") {
                      if (shift['end_odometer'] != null) endOdo = formatOdo(shift['end_odometer']);
                      else if (shift['endOdometer'] != null) endOdo = formatOdo(shift['endOdometer']);
                      else if (v['pivot'] != null && v['pivot']['end_odometer'] != null) endOdo = formatOdo(v['pivot']['end_odometer']);
                      else if (v['pivot'] != null && v['pivot']['endOdometer'] != null) endOdo = formatOdo(v['pivot']['endOdometer']);
                      else if (v['end_odometer'] != null) endOdo = formatOdo(v['end_odometer']);
                    }
                    
                    if (startOdo != "--" && endOdo != "--" && endOdo != "Started") {
                      double s = double.tryParse(startOdo) ?? 0;
                      double e = double.tryParse(endOdo) ?? 0;
                      double dist = e - s;
                      distance = "${dist == dist.toInt() ? dist.toInt() : dist.toStringAsFixed(1)} km";
                    } else if (startOdo != "--" && endOdo == "--") {
                      endOdo = "Started";
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.01),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Vehicle and Driver
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.orange.withOpacity(0.15),
                                  child: const Icon(Icons.directions_bus_rounded, size: 20, color: Colors.orange),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vNum,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: titleColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (driverInfo != "No driver assigned") ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.person, size: 14, color: subColor),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                hasStartedVehicle ? (vehicleOdos.indexOf(odo) > 0 ? "Transferred to: $driverInfo" : "Started by: $driverInfo") : "Assigned to: $driverInfo",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: hasStartedVehicle ? Colors.green[700] : subColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (startOdo != '--' || shiftStatus == 'STARTED' || shiftStatus == 'ONGOING')
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: InkWell(
                                      onTap: () => _handleEditOdometer(shift, vId, startOdo, endOdo, startTime, endTime),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: const [
                                            Icon(Icons.edit_rounded, size: 12, color: Colors.blue),
                                            SizedBox(width: 4),
                                            Text('Edit Odo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            
                            // Bottom Row: Odometer and Distance
                            if (true) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(isDark ? 0.05 : 0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Start Odo
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "START ODO",
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: subColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          startOdo,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: titleColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          startTime.isNotEmpty ? startTime : "--:--",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: subColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // End Odo
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          "END ODO",
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: subColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          endOdo,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: titleColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          endTime.isNotEmpty ? endTime : "--:--",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: subColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    // Distance
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "DISTANCE",
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.orange,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            distance,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          durationStr.isNotEmpty ? durationStr : "--h --m",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.orange.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                      ],
                    ),
                  ),
                );
              });
            }),
            ],
            ),
          ),
          if (shiftStatus == 'PLANNED' || shiftStatus == 'READY')
            Padding(
              padding: const EdgeInsets.all(16.0).copyWith(top: 0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleDirectAction(shift, 'start'),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Direct Start'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleDirectTransfer(shift),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Transfer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (shiftStatus == 'STARTED' || shiftStatus == 'ONGOING')
            Padding(
              padding: const EdgeInsets.all(16.0).copyWith(top: 0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleDirectAction(shift, 'end'),
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Direct End'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleDirectTransfer(shift),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Transfer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  
  void _handleDirectTransfer(dynamic shift) async {
    final List<dynamic> vehicles = shift['vehicles'] ?? [];
    final List<dynamic> drivers = shift['drivers'] ?? [];
    
    if (vehicles.isEmpty || drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No vehicles or drivers available for transfer')));
      return;
    }

    final _formKey = GlobalKey<FormState>();
    int? selectedVehicleId;
    int? toDriverId;
    final TextEditingController odoController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();

    final bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final Color primaryBlue = const Color(0xFF6366F1);
        
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                        ),
                        const SizedBox(height: 20),
                        Text('Direct Transfer Driver', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 16),
                        
                        DropdownButtonFormField<int>(
                          decoration: InputDecoration(
                            labelText: 'Select Vehicle (to transfer from)',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          value: selectedVehicleId,
                          items: vehicles.map((v) {
                            final int vId = v['vehicle_id'] ?? v['vehicle']?['id'] ?? v['id'] ?? 0;
                            final String vNum = v['vehicle']?['vehicle_number'] ?? v['vehicle_number'] ?? '';
                            return DropdownMenuItem<int>(
                              value: vId,
                              child: Text(vNum, style: TextStyle(color: textColor)),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => selectedVehicleId = val),
                          validator: (val) => val == null ? 'Please select a vehicle' : null,
                        ),
                        const SizedBox(height: 16),
                        
                        DropdownButtonFormField<int>(
                          decoration: InputDecoration(
                            labelText: 'Select Replacement Driver',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          value: toDriverId,
                          items: drivers.map((d) {
                            final int dId = d['driver_id'] ?? d['id'] ?? 0;
                            final String dName = d['driver']?['user']?['name'] ?? d['driver']?['name'] ?? d['name'] ?? 'Unknown Driver';
                            return DropdownMenuItem<int>(
                              value: dId,
                              child: Text(dName, style: TextStyle(color: textColor)),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => toDriverId = val),
                          validator: (val) => val == null ? 'Please select replacement driver' : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: odoController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'End Odometer (Current Driver)',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            prefixIcon: const Icon(Icons.speed, color: Colors.blue),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Odometer is required';
                            if (double.tryParse(value) == null || double.parse(value) < 0) return 'Invalid odometer';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: reasonController,
                          style: TextStyle(color: textColor),
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Transfer Reason',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Reason is required' : null,
                        ),
                        const SizedBox(height: 24),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                Navigator.pop(context, true);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Confirm Transfer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirm != true || selectedVehicleId == null || toDriverId == null) return;

    // Find the from_driver_id
    final v = vehicles.firstWhere((v) {
       final int id = v['vehicle_id'] ?? v['vehicle']?['id'] ?? v['id'] ?? 0;
       return id == selectedVehicleId;
    }, orElse: () => null);
    
    if (v == null) return;

    final drvMatch = drivers.firstWhere((d) => d['vehicle_id']?.toString() == selectedVehicleId.toString(), orElse: () => drivers.isNotEmpty ? drivers.first : null);
    final int fromDriverId = v['assigned_driver_id'] ?? v['driver_id'] ?? v['assignedDriver']?['id'] ?? drvMatch?['driver_id'] ?? drvMatch?['id'] ?? 0;

    try {
      final store = ref.read(scheduleDutyStoreProvider);
      await store.transferDriverMasterShift(
        int.parse(shift['id'].toString()),
        fromDriverId: fromDriverId,
        toDriverId: toDriverId!,
        vehicleId: selectedVehicleId!,
        endOdometer: double.parse(odoController.text.trim()),
        reason: reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shift transferred successfully! Please pull down to refresh.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ')));
      }
    }
  }


  
  void _handleEditOdometer(dynamic shift, int vehicleId, String currentStartOdo, String currentEndOdo, String currentStartTime, String currentEndTime) async {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController startOdoController = TextEditingController(text: currentStartOdo != '--' ? currentStartOdo : '');
    final TextEditingController endOdoController = TextEditingController(text: currentEndOdo != '--' && currentEndOdo != 'Started' ? currentEndOdo : '');
    final TextEditingController reasonController = TextEditingController();
    int roleId = 3; // Default to driver mistake

    final bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final Color primaryBlue = const Color(0xFF6366F1);
        
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 20),
                        Text('Edit Odometer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: startOdoController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Start Odometer',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            if (double.tryParse(value) == null || double.parse(value) < 0) return 'Invalid odometer';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: endOdoController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'End Odometer',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (double.tryParse(value) == null || double.parse(value) < 0) return 'Invalid odometer';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        DropdownButtonFormField<int>(
                          decoration: InputDecoration(
                            labelText: 'Mistake By',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          value: roleId,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          items: _mistakeOptions.map((role) {
                            return DropdownMenuItem<int>(
                              value: role['id'] as int,
                              child: Text("${role['name']}", style: TextStyle(color: textColor)),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => roleId = val ?? 3),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: reasonController,
                          style: TextStyle(color: textColor),
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Remark (Mandatory)',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Remark is required' : null,
                        ),
                        const SizedBox(height: 24),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                Navigator.pop(context, true);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Update Time & Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (confirm != true) return;

    try {
      final store = ref.read(scheduleDutyStoreProvider);
      await store.editMasterShiftOdometer(
        int.parse(shift['id'].toString()),
        vehicleId,
        startOdometer: double.parse(startOdoController.text.trim()),
        endOdometer: endOdoController.text.trim().isNotEmpty ? double.parse(endOdoController.text.trim()) : 0,
        startTime: currentStartTime.isEmpty || currentStartTime == '--:--' ? DateTime.now().toUtc().toIso8601String() : currentStartTime,
        endTime: currentEndTime.isEmpty || currentEndTime == '--:--' ? DateTime.now().toUtc().toIso8601String() : currentEndTime,
        mistakeOnRoleId: roleId,
        remark: reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Odometer updated successfully! Please pull down to refresh.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ')));
      }
    }
  }

  void _handleDirectAction(dynamic shift, String action) async {
    final List<dynamic> vehicles = shift['vehicles'] ?? [];
    final Map<String, TextEditingController> odoControllers = {};
    for (var v in vehicles) {
      final int vId = v['vehicle_id'] ?? v['vehicle']?['id'] ?? v['id'] ?? 0;
      odoControllers[vId.toString()] = TextEditingController();
    }

    final _formKey = GlobalKey<FormState>();
    final bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final Color primaryBlue = const Color(0xFF6366F1);
        
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Confirm ${action == 'start' ? 'Start' : 'End'}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Are you sure you want to directly ${action} this shift? Please enter odometer readings below.',
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                  const SizedBox(height: 24),
                  if (vehicles.isNotEmpty) ...vehicles.map((v) {
                    final String vNum = v['vehicle']?['vehicle_number'] ?? v['vehicle_number'] ?? 'Unknown Vehicle';
                    final int vId = v['vehicle_id'] ?? v['vehicle']?['id'] ?? v['id'] ?? 0;
                    
                    // Odometer Logic (Find start odometer if action is end)
                    double? startOdoVal;
                    if (action == 'end') {
                      final dynamic odo = v['odometer'] ?? (shift['odometers'] as List<dynamic>? ?? []).firstWhere(
                        (o) => o['vehicle_id']?.toString() == vId.toString(),
                        orElse: () => null
                      ) ?? v;
                      if (odo != null && odo['start_odometer'] != null) {
                        startOdoVal = double.tryParse(odo['start_odometer'].toString());
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        controller: odoControllers[vId.toString()],
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor),
                        validator: (value) {
                          final bool isAnyFilled = odoControllers.values.any((c) => c.text.trim().isNotEmpty);
                          if (!isAnyFilled) {
                            return 'At least one odometer is required';
                          }
                          if (value != null && value.trim().isNotEmpty) {
                            final double? enteredValue = double.tryParse(value.trim());
                            if (enteredValue == null || enteredValue < 0) {
                              return 'Enter a valid number';
                            }
                            if (action == 'end' && startOdoVal != null) {
                              if (enteredValue < startOdoVal!) {
                                return 'Must be >= start ()';
                              }
                            }
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: '$vNum ${action == 'start' ? 'Start' : 'End'} Odometer',
                          labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.w500),
                          prefixIcon: const Icon(Icons.speed_rounded, color: Color(0xFF6366F1), size: 22),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                          ),
                          child: Text('Cancel', style: TextStyle(color: textColor)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              Navigator.pop(context, true);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: action == 'start' ? Colors.green : Colors.red,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(action == 'start' ? 'Start Shift' : 'End Shift', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          ),
        );
      },
    );

    if (confirm != true) return;

    List<Map<String, dynamic>> odometers = [];
    final List<dynamic> drvs = shift['drivers'] ?? [];
    for (var v in vehicles) {
      final int vId = v['vehicle_id'] ?? v['vehicle']?['id'] ?? v['id'] ?? 0;
      final String vNum = v['vehicle']?['vehicle_number'] ?? v['vehicle_number'] ?? '';
      final drvMatch = drvs.firstWhere((d) => d['vehicle_id']?.toString() == vId.toString(), orElse: () => drvs.isNotEmpty ? drvs.first : null);
      final int? driverId = v['assigned_driver_id'] ?? v['driver_id'] ?? v['assignedDriver']?['id'] ?? drvMatch?['driver_id'] ?? drvMatch?['id'];
      final val = odoControllers[vId.toString()]?.text.trim() ?? '';
      if (val.isNotEmpty) {
        odometers.add({
          "vehicle_id": vId,
          "vehicle_number": vNum,
          "${action}_odometer": int.tryParse(val) ?? 0,
          "driver_id": driverId,
        });
      }
    }

    try {
      final store = ref.read(scheduleDutyStoreProvider);
      if (action == 'start') {
        await store.startDirectMasterShift(int.parse(shift['id'].toString()), odometers: odometers.isNotEmpty ? odometers : null);
      } else {
        await store.endDirectMasterShift(int.parse(shift['id'].toString()), odometers: odometers.isNotEmpty ? odometers : null);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shift ${action == 'start' ? 'started' : 'ended'} successfully! Please pull down to refresh.')),
        );
        Navigator.pop(context); // Go back so the user can refresh the main list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final String s = status.toUpperCase();
    final Map<String, Map<String, Color>> statusStyles = {
      'PLANNED': {
        'bg': const Color(0xFFFDF2F8),
        'text': const Color(0xFFEC4899),
        'border': const Color(0xFFFBCFE8),
      },
      'READY': {
        'bg': const Color(0xFFFFFBEB),
        'text': const Color(0xFFF59E0B),
        'border': const Color(0xFFFDE68A),
      },
      'STARTED': {
        'bg': const Color(0xFFDBEAFE),
        'text': const Color(0xFF2563EB),
        'border': const Color(0xFF93C5FD),
      },
      'ONGOING': {
        'bg': const Color(0xFFEEF2FF),
        'text': const Color(0xFF6366F1),
        'border': const Color(0xFFC7D2FE),
      },
      'COMPLETED': {
        'bg': const Color(0xFFECFDF5),
        'text': const Color(0xFF10B981),
        'border': const Color(0xFFA7F3D0),
      },
    };

    final style = statusStyles[s] ??
        {
          'bg': Colors.grey.withOpacity(0.1),
          'text': Colors.grey,
          'border': Colors.grey.withOpacity(0.2),
        };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style['bg'],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style['border']!, width: 1),
      ),
      child: Text(
        s,
        style: TextStyle(
          color: style['text'],
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
