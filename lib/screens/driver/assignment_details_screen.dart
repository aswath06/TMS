import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:provider/provider.dart';

class AssignmentDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final Map<String, dynamic> run;

  const AssignmentDetailsScreen({
    super.key,
    required this.assignment,
    required this.run,
  });

  @override
  State<AssignmentDetailsScreen> createState() => _AssignmentDetailsScreenState();
}

class _AssignmentDetailsScreenState extends State<AssignmentDetailsScreen> with SingleTickerProviderStateMixin {
  late Map<String, dynamic> assignment;
  late Map<String, dynamic> run;
  late AnimationController _pulseController;
  bool _isHaltSubmitting = false;

  @override
  void initState() {
    super.initState();
    assignment = widget.assignment;
    run = widget.run;
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await useDriverStore.fetchDailyBusRuns();
    final runId = run['id'];
    final assignId = assignment['id'];

    if (useDriverStore.dailyBusRuns.isNotEmpty) {
      for (var r in useDriverStore.dailyBusRuns) {
        if (r['id'] == runId) {
          final assigns = r['assignment'] as List? ?? [];
          for (var a in assigns) {
            if (a['id'] == assignId) {
              if (mounted) {
                setState(() {
                  run = r;
                  assignment = a;
                });
              }
              return;
            }
          }
          break;
        }
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "—";
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      String ampm = dt.hour >= 12 ? 'PM' : 'AM';
      int hour = dt.hour % 12;
      if (hour == 0) hour = 12;
      return "${dt.day}/${dt.month}/${dt.year} $hour:${dt.minute.toString().padLeft(2, '0')} $ampm";
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);

    final shiftCode = assignment['shift_code'] ?? 'UNKNOWN';
    final statusStr = run['status'] ?? assignment['run_status'] ?? 'UNKNOWN';
    
    final odometerReadings = (run['odometerReadings'] as List?) ?? [];

    List<dynamic> filteredReadings = [];
    if (shiftCode == 'MORNING') {
      filteredReadings = odometerReadings.where((r) {
        final type = r['reading_type']?.toString().toUpperCase() ?? '';
        return type == 'START' || type == 'CAMPUS_IN';
      }).toList();
    } else if (shiftCode == 'EVENING') {
      filteredReadings = odometerReadings.where((r) {
        final type = r['reading_type']?.toString().toUpperCase() ?? '';
        return type == 'CAMPUS_OUT' || type == 'HALT';
      }).toList();
    }

    double distance = 0.0;
    if (filteredReadings.length >= 2) {
      double start = double.tryParse(filteredReadings[0]['odometer_reading']?.toString() ?? '0') ?? 0;
      double end = double.tryParse(filteredReadings[1]['odometer_reading']?.toString() ?? '0') ?? 0;
      if (start > 0 && end > 0) {
        distance = (end - start).abs();
      }
    }

    final routeObj = run['dailyBusRoute'] as Map<String, dynamic>?;
    final routeName = routeObj?['route_name'] ?? 'Unknown Route';
    final routeCode = routeObj?['route_code'] ?? '';
    final stops = (routeObj?['stops'] as List<dynamic>?) ?? [];
    stops.sort((a, b) => (a['stop_order'] as int? ?? 0).compareTo(b['stop_order'] as int? ?? 0));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Daily Bus Route",
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: titleColor),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: primaryBlue,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Card Mimicking Mission Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 25,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: (statusStr.toUpperCase() == 'COMPLETED' || statusStr.toUpperCase() == 'FN_COMPLETED' ? Colors.green : primaryBlue).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusStr.toUpperCase(),
                                style: TextStyle(
                                  color: statusStr.toUpperCase() == 'COMPLETED' || statusStr.toUpperCase() == 'FN_COMPLETED' ? Colors.green : primaryBlue,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (routeCode.isNotEmpty)
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  "Bus Number : $routeCode",
                                  style: TextStyle(color: subColor, fontWeight: FontWeight.w700, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    routeName,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${shiftCode.toUpperCase()} SHIFT",
                          style: TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      if (routeObj?['boarding_otp'] != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.password_rounded, color: Colors.orange, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                "OTP: ${routeObj!['boarding_otp']}",
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Travel Metrics
            _buildTravelMetrics(isDark, primaryBlue, shiftCode),

            if (stops.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: subColor.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Route Stops", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: titleColor)),
                      const SizedBox(height: 20),
                      ...List.generate(stops.length, (index) {
                        final stop = stops[index];
                        final isLast = index == stops.length - 1;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 16, height: 16,
                                  decoration: BoxDecoration(
                                    color: primaryBlue,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC), width: 3),
                                  ),
                                ),
                                if (!isLast) Container(width: 2, height: 40, color: primaryBlue.withValues(alpha: 0.3)),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stop['stop_name'] ?? 'Unknown Stop',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor),
                                    ),
                                    if (shiftCode == 'MORNING' && stop['pickup_plan_time'] != null && stop['pickup_plan_time'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time_rounded, color: subColor, size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Plan Time: ${stop['pickup_plan_time']}",
                                            style: TextStyle(color: subColor, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ] else if (shiftCode == 'EVENING' && stop['drop_plan_time'] != null && stop['drop_plan_time'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time_rounded, color: subColor, size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Plan Time: ${stop['drop_plan_time']}",
                                            style: TextStyle(color: subColor, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 40),
            ],
          ),
        ), // closes SingleChildScrollView
      ), // closes RefreshIndicator
      bottomNavigationBar: shiftCode == 'EVENING'
          ? _buildEveningBottomNavigationBar(statusStr, surfaceColor, isDark, titleColor, subColor, primaryBlue)
          : _buildMorningBottomNavigationBar(statusStr, surfaceColor, isDark, titleColor, subColor, primaryBlue),
    );
  }

  Widget? _buildMorningBottomNavigationBar(String statusStr, Color surfaceColor, bool isDark, Color titleColor, Color subColor, Color primaryBlue) {
    if (statusStr == 'READY') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showStartBottomSheet(context, isDark, titleColor, subColor, primaryBlue),
            icon: const Icon(Icons.info_outline_rounded, size: 20),
            label: const Text(
              "START",
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.3),
            ),
          ),
        ),
      );
    } else if (statusStr == 'ARRIVED_CAMPUS') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))
          ],
        ),
        child: ElevatedButton(
          onPressed: () => _showEndBottomSheet(context, isDark, titleColor, subColor, primaryBlue),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text("END", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
    }
    return null;
  }

  Widget? _buildEveningBottomNavigationBar(String statusStr, Color surfaceColor, bool isDark, Color titleColor, Color subColor, Color primaryBlue) {
    if (statusStr == 'FN_COMPLETED') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showEveningStartBottomSheet(context, isDark, titleColor, subColor, primaryBlue),
            icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
            label: const Text(
              "START",
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.3),
            ),
          ),
        ),
      );
    } else if (statusStr == 'DEPARTED_CAMPUS') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))
          ],
        ),
        child: ElevatedButton(
          onPressed: _isHaltSubmitting
              ? null
              : () async {
                  setState(() => _isHaltSubmitting = true);
                  final dynamic rawRunId = widget.run['id'] ?? widget.assignment['daily_bus_run_id'];
                  final int runId = rawRunId is int ? rawRunId : int.tryParse(rawRunId?.toString() ?? '0') ?? 0;
                  
                  if (runId == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Run ID is missing"), backgroundColor: Colors.red));
                    setState(() => _isHaltSubmitting = false);
                    return;
                  }

                  final result = await useDriverStore.haltEveningBusRun(runId: runId);
                  
                  if (result['success']) {
                    setState(() => _isHaltSubmitting = false);
                    await _handleRefresh();
                  } else {
                    setState(() => _isHaltSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isHaltSubmitting
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("I Am Halting The Vehicle", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
    } else if (statusStr == 'HALTED') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))
          ],
        ),
        child: ElevatedButton(
          onPressed: () => _showEveningEndBottomSheet(context, isDark, titleColor, subColor, primaryBlue),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text("END", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
    }
    return null;
  }

  void _showStartBottomSheet(BuildContext context, bool isDark, Color titleColor, Color subColor, Color primaryBlue) {
    final odometerController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Start Run",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter your starting odometer reading.",
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),

                    // Odometer Input
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: odometerController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          labelText: "Start Odometer",
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          floatingLabelStyle: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w700,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          prefixIcon: const Icon(Icons.speed, color: Color(0xFF6366F1)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text("Close", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (odometerController.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Odometer reading cannot be empty.")));
                                      return;
                                    }
                                    setState(() => isSubmitting = true);
                                    final int odo = int.tryParse(odometerController.text.trim()) ?? 0;
                                    
                                    final dynamic rawRunId = widget.run['id'] ?? widget.assignment['daily_bus_run_id'];
                                    final int runId = rawRunId is int ? rawRunId : int.tryParse(rawRunId?.toString() ?? '0') ?? 0;
                                    
                                    if (runId == 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Run ID is missing"), backgroundColor: Colors.red));
                                      setState(() => isSubmitting = false);
                                      return;
                                    }

                                    try {
                                      final result = await useDriverStore.startBusRun(
                                        runId: runId,
                                        startOdometer: odo,
                                        imageUrl: null,
                                      );

                                      if (result['success'] == true) {
                                        if (mounted) {
                                          setState(() => isSubmitting = false);
                                          Navigator.pop(context); // Close sheet
                                          await _handleRefresh(); // Reload page
                                        }
                                      } else {
                                        if (mounted) {
                                          setState(() => isSubmitting = false);
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? "Failed to start run"), backgroundColor: Colors.red));
                                        }
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        setState(() => isSubmitting = false);
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: isSubmitting
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("SUBMIT", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  void _showEndBottomSheet(BuildContext context, bool isDark, Color titleColor, Color subColor, Color primaryBlue) {
    final odometerController = TextEditingController();
    final passengerController = TextEditingController();
    bool allowanceNeeded = false;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "End Run",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter your ending odometer reading.",
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),

                    // Odometer Input
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: odometerController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          labelText: "Ending Odometer",
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          floatingLabelStyle: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w700,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          prefixIcon: const Icon(Icons.speed, color: Colors.redAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Passenger Count Input
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: passengerController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          labelText: "Passenger Count",
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          floatingLabelStyle: TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.w700,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          prefixIcon: Icon(Icons.group, color: primaryBlue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Allowance Needed Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.monetization_on_rounded, color: primaryBlue),
                              const SizedBox(width: 12),
                              Text("Allowance Needed", style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => allowanceNeeded = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: allowanceNeeded ? primaryBlue : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: allowanceNeeded ? primaryBlue : (isDark ? Colors.white24 : Colors.black12)),
                                  ),
                                  child: Text("YES", style: TextStyle(color: allowanceNeeded ? Colors.white : subColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() => allowanceNeeded = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !allowanceNeeded ? Colors.redAccent : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: !allowanceNeeded ? Colors.redAccent : (isDark ? Colors.white24 : Colors.black12)),
                                  ),
                                  child: Text("NO", style: TextStyle(color: !allowanceNeeded ? Colors.white : subColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text("Close", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (odometerController.text.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Odometer reading is required"), backgroundColor: Colors.red));
                                      return;
                                    }
                                    if (passengerController.text.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passenger count is required"), backgroundColor: Colors.red));
                                      return;
                                    }

                                    setState(() => isSubmitting = true);
                                    final int odo = int.tryParse(odometerController.text) ?? 0;
                                    final int passCount = int.tryParse(passengerController.text) ?? 0;
                                    final dynamic rawRunId = widget.run['id'] ?? widget.assignment['daily_bus_run_id'];
                                    final int runId = rawRunId is int ? rawRunId : int.tryParse(rawRunId?.toString() ?? '0') ?? 0;
                                    
                                    if (runId == 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Run ID is missing"), backgroundColor: Colors.red));
                                      setState(() => isSubmitting = false);
                                      return;
                                    }

                                    final result = await useDriverStore.endMorningBusRun(
                                      runId: runId,
                                      endOdometer: odo,
                                      passengerCount: passCount,
                                      allowanceNeeded: allowanceNeeded,
                                    );

                                    if (result['success']) {
                                      if (mounted) {
                                        setState(() => isSubmitting = false);
                                        Navigator.pop(context);
                                        await _handleRefresh();
                                      }
                                    } else {
                                      setState(() => isSubmitting = false);
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: isSubmitting 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("END RUN", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value, Color titleColor, Color subColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(color: subColor, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(color: titleColor, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
  Widget _buildTravelMetrics(bool isDark, Color primaryColor, String shiftCode) {
    final startedAt = shiftCode == 'EVENING' ? run['actual_campus_out_time'] : run['actual_start_at'];
    final endedAt = shiftCode == 'EVENING' ? run['actual_halt_time'] : run['actual_campus_in_time'];

    final filteredReadings = (run['odometerReadings'] as List?) ?? [];
    String startOdoStr = "N/A";
    String endOdoStr = "N/A";

    final startReadingType = shiftCode == 'EVENING' ? 'CAMPUS_OUT' : 'START';
    final endReadingType = shiftCode == 'EVENING' ? 'HALT' : 'CAMPUS_IN';

    final startReading = filteredReadings.firstWhere((r) => r['reading_type'] == startReadingType, orElse: () => {});
    final endReading = filteredReadings.firstWhere((r) => r['reading_type'] == endReadingType, orElse: () => {});

    double startOdoVal = 0;
    double endOdoVal = 0;

    if (startReading.isNotEmpty) {
      final valStr = startReading['odometer_reading']?.toString() ?? "0";
      startOdoVal = double.tryParse(valStr) ?? 0;
      if (startOdoVal > 0) startOdoStr = startOdoVal.toStringAsFixed(startOdoVal.truncateToDouble() == startOdoVal ? 0 : 2);
    }
    
    if (endReading.isNotEmpty) {
      final valStr = endReading['odometer_reading']?.toString() ?? "0";
      endOdoVal = double.tryParse(valStr) ?? 0;
      if (endOdoVal > 0) endOdoStr = endOdoVal.toStringAsFixed(endOdoVal.truncateToDouble() == endOdoVal ? 0 : 2);
    }

    double? distance;
    if (startOdoVal > 0 && endOdoVal > 0 && endOdoVal >= startOdoVal) {
      distance = endOdoVal - startOdoVal;
    }

    final count = shiftCode == 'EVENING' ? run['campus_out_count']?.toString() : run['campus_in_count']?.toString();
    
    String? verifiedByName;
    if (shiftCode == 'EVENING') {
      final vObj = run['campusOutVerifiedBy'];
      verifiedByName = (vObj is Map) ? vObj['name'] : run['campus_out_verified_by']?.toString();
    } else {
      final vObj = run['campusInVerifiedBy'];
      verifiedByName = (vObj is Map) ? vObj['name'] : run['campus_in_verified_by']?.toString();
    }

    final allowanceNeeded = assignment['allowance_needed'] == true ? "YES" : "NO";

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, color: primaryColor, size: 24),
              const SizedBox(width: 10),
              Text(
                "Travel Metrics",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTimeDurationSection(startedAt, endedAt, null, null, primaryColor, isDark),
          const SizedBox(height: 24),
          Divider(height: 1, thickness: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildMetricTile("START ODOMETER", startOdoStr, Icons.flag_circle_rounded, Colors.blue, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricTile("END ODOMETER", endOdoStr, Icons.check_circle_rounded, Colors.green, isDark)),
            ],
          ),
          if (startedAt != null || distance != null) ...[
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final startDt = _parseTimestamp(startedAt);
                final endDt = _parseTimestamp(endedAt);
                Duration? dur;
                if (startDt != null && endDt != null) dur = endDt.difference(startDt);
                else if (startDt != null && endedAt == null) dur = DateTime.now().difference(startDt);
                
                final bool isOngoing = startedAt != null && endedAt == null;
                final String label = dur != null ? _formatDuration(dur) : (isOngoing ? "Calculating..." : "N/A");
                
                return Row(
                  children: [
                    if (startedAt != null) Expanded(child: _buildMetricTile("TOTAL DURATION", label, Icons.timer_outlined, primaryColor, isDark)),
                    if (startedAt != null && distance != null) const SizedBox(width: 12),
                    if (distance != null) Expanded(child: _buildMetricTile("TOTAL DISTANCE", "${distance!.toStringAsFixed(1)} KM", Icons.route_outlined, primaryColor, isDark)),
                  ],
                );
              }
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricTile("CAMPUS COUNT", count ?? "Not Entered", Icons.people_alt_outlined, Colors.orange, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricTile("VERIFIED BY", verifiedByName ?? "Not Entered", Icons.verified_user_outlined, Colors.purple, isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDurationSection(dynamic startedAt, dynamic endedAt, String? startedBy, String? endedBy, Color primaryColor, bool isDark) {
    final bool isOngoing = startedAt != null && endedAt == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildTimeNodeCard("STARTED", startedAt, startedBy, Icons.play_circle_fill_rounded, Colors.green, isDark),
            ),
            _buildConnectingBridge(primaryColor, isOngoing),
            Expanded(
              child: _buildTimeNodeCard(
                endedAt != null ? "ENDED" : (startedAt != null ? "ONGOING" : "PENDING"),
                endedAt ?? (startedAt != null ? "In Progress" : null),
                endedBy,
                Icons.stop_circle_rounded,
                endedAt != null ? Colors.redAccent : (startedAt != null ? Colors.orange : Colors.grey),
                isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectingBridge(Color activeColor, bool isOngoing) {
    return SizedBox(
      width: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 2,
            width: 32,
            color: activeColor.withValues(alpha: 0.2),
          ),
          ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.2).animate(
              CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOngoing ? Colors.orange : activeColor,
                boxShadow: [
                  BoxShadow(
                    color: (isOngoing ? Colors.orange : activeColor).withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // EVENING SHIFT BOTTOM SHEETS
  // =========================================================================

  void _showEveningStartBottomSheet(BuildContext context, bool isDark, Color titleColor, Color subColor, Color primaryBlue) {
    final odometerController = TextEditingController();
    final passengerController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Start Evening Run",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter your starting details.",
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),

                    // Odometer Input
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: odometerController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          labelText: "Starting Odometer",
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          floatingLabelStyle: TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.w700,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          prefixIcon: Icon(Icons.speed, color: primaryBlue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Passenger Count Input
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: passengerController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          labelText: "Passenger Count",
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          floatingLabelStyle: TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.w700,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          prefixIcon: Icon(Icons.group, color: primaryBlue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text("Close", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (odometerController.text.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Odometer reading is required"), backgroundColor: Colors.red));
                                      return;
                                    }
                                    if (passengerController.text.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passenger count is required"), backgroundColor: Colors.red));
                                      return;
                                    }

                                    setState(() => isSubmitting = true);
                                    final int odo = int.tryParse(odometerController.text) ?? 0;
                                    final int passCount = int.tryParse(passengerController.text) ?? 0;
                                    final dynamic rawRunId = widget.run['id'] ?? widget.assignment['daily_bus_run_id'];
                                    final int runId = rawRunId is int ? rawRunId : int.tryParse(rawRunId?.toString() ?? '0') ?? 0;
                                    
                                    if (runId == 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Run ID is missing"), backgroundColor: Colors.red));
                                      setState(() => isSubmitting = false);
                                      return;
                                    }

                                    final result = await useDriverStore.startEveningCampusOut(
                                      runId: runId,
                                      startOdometer: odo,
                                      passengerCount: passCount,
                                    );

                                    if (result['success']) {
                                      setState(() => isSubmitting = false);
                                      Navigator.pop(context);
                                      await _handleRefresh();
                                    } else {
                                      setState(() => isSubmitting = false);
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: isSubmitting
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("SUBMIT", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEveningEndBottomSheet(BuildContext context, bool isDark, Color titleColor, Color subColor, Color primaryBlue) {
    final odometerController = TextEditingController();
    bool allowanceNeeded = false;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "End Evening Run",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter your ending details.",
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),

                    // Odometer Input
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: odometerController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          labelText: "Ending Odometer",
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          floatingLabelStyle: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w700,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          prefixIcon: const Icon(Icons.speed, color: Colors.orange),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Allowance Needed Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.monetization_on_rounded, color: primaryBlue),
                              const SizedBox(width: 12),
                              Text("Allowance Needed", style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => allowanceNeeded = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: allowanceNeeded ? primaryBlue : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: allowanceNeeded ? primaryBlue : (isDark ? Colors.white24 : Colors.black12)),
                                  ),
                                  child: Text("YES", style: TextStyle(color: allowanceNeeded ? Colors.white : subColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() => allowanceNeeded = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !allowanceNeeded ? Colors.redAccent : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: !allowanceNeeded ? Colors.redAccent : (isDark ? Colors.white24 : Colors.black12)),
                                  ),
                                  child: Text("NO", style: TextStyle(color: !allowanceNeeded ? Colors.white : subColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text("Close", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (odometerController.text.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Odometer reading is required"), backgroundColor: Colors.red));
                                      return;
                                    }

                                    setState(() => isSubmitting = true);
                                    final int odo = int.tryParse(odometerController.text) ?? 0;
                                    final dynamic rawRunId = widget.run['id'] ?? widget.assignment['daily_bus_run_id'];
                                    final int runId = rawRunId is int ? rawRunId : int.tryParse(rawRunId?.toString() ?? '0') ?? 0;
                                    
                                    if (runId == 0) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Run ID is missing"), backgroundColor: Colors.red));
                                      setState(() => isSubmitting = false);
                                      return;
                                    }

                                    final result = await useDriverStore.endEveningOdometer(
                                      runId: runId,
                                      endOdometer: odo,
                                      allowanceNeeded: allowanceNeeded,
                                    );

                                    if (result['success']) {
                                      setState(() => isSubmitting = false);
                                      Navigator.pop(context);
                                      await _handleRefresh();
                                    } else {
                                      setState(() => isSubmitting = false);
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: isSubmitting
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("SUBMIT", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimeNodeCard(String title, dynamic rawTime, String? byName, IconData icon, Color accentColor, bool isDark) {
    final String timeStr = (rawTime != null && rawTime != "In Progress") ? _formatActualTime(rawTime.toString()) : (rawTime == "In Progress" ? "In Progress" : "N/A");
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final Color cardBg = isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: subTextColor, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            timeStr,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: titleColor, letterSpacing: 0.3),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, Color iconColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [BoxShadow(color: iconColor.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        ],
      ),
    );
  }

  String _formatActualTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${dt.day} ${months[dt.month - 1]}, ${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
    } catch (_) {
      return timeStr;
    }
  }

  DateTime? _parseTimestamp(dynamic val) {
    if (val == null) return null;
    try {
      final str = val.toString().replaceAll(' ', 'T');
      return DateTime.parse(str);
    } catch (_) {
      return null;
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    List<String> parts = [];
    if (hours > 0) parts.add("$hours hr${hours > 1 ? 's' : ''}");
    if (minutes > 0) parts.add("$minutes min${minutes > 1 ? 's' : ''}");
    if (hours == 0 && minutes == 0) parts.add("$seconds sec${seconds > 1 ? 's' : ''}");
    return parts.join(" ");
  }
}

