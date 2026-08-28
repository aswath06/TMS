import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final String name = widget.schedule['schedule_name'] ?? widget.schedule['template']?['name'] ?? 'Unnamed Schedule';
    final String status = widget.schedule['status'] ?? 'UNKNOWN';
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
                      _buildStatusBadge(status),
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: primaryBlue.withOpacity(0.1),
                            child: Icon(Icons.person, size: 16, color: primaryBlue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              dName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: titleColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: type == 'PRIMARY' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: type == 'PRIMARY' ? Colors.green : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                
                const Divider(height: 32),
                
                _buildSectionHeader("ASSIGNED VEHICLES", Icons.directions_bus_rounded, Colors.orange),
                const SizedBox(height: 12),
                if (vehicles.isEmpty)
                  Text("No vehicles assigned.", style: TextStyle(color: subColor, fontSize: 13))
                else
                  ...vehicles.map((v) {
                    final String vNum = v['vehicle']?['vehicle_number'] ?? v['vehicle_number'] ?? 'Unknown Vehicle';
                    final int vId = v['vehicle_id'] ?? v['vehicle']?['id'] ?? 0;
                    
                    // Find assigned driver
                    String driverInfo = "No driver assigned";
                    if (v['assignedDriver'] != null && v['assignedDriver']['user'] != null) {
                      driverInfo = v['assignedDriver']['user']['name'] ?? "Unknown Driver";
                    } else if (v['assigned_driver_id'] != null) {
                       // fallback if driver info wasn't populated but ID exists
                       driverInfo = "Driver ID: ${v['assigned_driver_id']}";
                    }
                    
                    // Find odometer
                    final List<dynamic> odos = shift['odometers'] ?? [];
                    final odo = odos.firstWhere(
                      (o) => o['vehicle_id'] == vId, 
                      orElse: () => null
                    );
                    
                    String formatOdo(dynamic value) {
                      if (value == null) return '--';
                      double val = double.tryParse(value.toString()) ?? 0;
                      return val == val.toInt() ? val.toInt().toString() : val.toString();
                    }
                    
                    String startOdo = "--";
                    String endOdo = "--";
                    String distance = "--";

                    if (odo != null && odo['start_odometer'] != null) {
                      startOdo = formatOdo(odo['start_odometer']);
                      if (odo['end_odometer'] != null) {
                        endOdo = formatOdo(odo['end_odometer']);
                        double s = double.tryParse(odo['start_odometer'].toString()) ?? 0;
                        double e = double.tryParse(odo['end_odometer'].toString()) ?? 0;
                        double dist = e - s;
                        distance = "${dist == dist.toInt() ? dist.toInt() : dist.toStringAsFixed(1)} km";
                      } else {
                        endOdo = "Started";
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.withOpacity(0.15)),
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
                                                driverInfo,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: subColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            // Bottom Row: Odometer and Distance
                            if (odo != null && odo['start_odometer'] != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(isDark ? 0.05 : 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.withOpacity(0.1)),
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
                  }),
              ],
            ),
          ),
        ],
      ),
    );
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
