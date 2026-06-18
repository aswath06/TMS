import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tripzo/store/driver_store.dart';

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

class _AssignmentDetailsScreenState extends State<AssignmentDetailsScreen> {
  late Map<String, dynamic> assignment;
  late Map<String, dynamic> run;

  @override
  void initState() {
    super.initState();
    assignment = widget.assignment;
    run = widget.run;
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Assignment Details",
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
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
            // Status Header Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryBlue, primaryBlue.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Shift",
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shiftCode.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      statusStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Odometer Readings
            if (filteredReadings.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  "Odometer Readings",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: subColor.withValues(alpha: 0.1)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredReadings.length,
                      separatorBuilder: (context, index) => Divider(color: subColor.withValues(alpha: 0.1), height: 32),
                      itemBuilder: (context, index) {
                        final reading = filteredReadings[index];
                        final String type = reading['reading_type']?.toString().replaceAll('_', ' ') ?? "Reading";
                        final double odoValue = double.tryParse(reading['odometer_reading']?.toString() ?? '0') ?? 0;
                        final bool isEntered = odoValue > 0;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isEntered ? primaryBlue.withValues(alpha: 0.1) : subColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.speed_rounded, color: isEntered ? primaryBlue : subColor, size: 20),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      type,
                                      style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    if (isEntered) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDate(reading['reading_time']),
                                        style: TextStyle(color: subColor, fontSize: 12),
                                      ),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                            if (isEntered)
                              Text(
                                "$odoValue km",
                                style: TextStyle(color: titleColor, fontWeight: FontWeight.w900, fontSize: 15),
                              )
                            else
                              Text(
                                "Not Entered",
                                style: TextStyle(color: subColor, fontWeight: FontWeight.w500, fontSize: 14, fontStyle: FontStyle.italic),
                              ),
                          ],
                        );
                      },
                    ),
                    if (distance > 0) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total Distance Covered",
                              style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              "${distance.toStringAsFixed(2)} km",
                              style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                          ],
                        ),
                      )
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ), // closes SingleChildScrollView
      ), // closes RefreshIndicator
      bottomNavigationBar: statusStr == 'READY'
          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))
                ],
              ),
              child: ElevatedButton(
                onPressed: () => _showStartBottomSheet(context, isDark, titleColor, subColor, primaryBlue),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("START", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          : statusStr == 'ARRIVED_CAMPUS'
              ? Container(
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
                )
              : null,
    );
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
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 24, left: 24, right: 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Start Run", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: titleColor)),
                  const SizedBox(height: 8),
                  Text("Enter your starting odometer reading.", style: TextStyle(color: subColor, fontSize: 14)),
                  const SizedBox(height: 24),

                  // Odometer Input
                  TextField(
                    controller: odometerController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "Odometer Reading",
                      labelStyle: TextStyle(color: subColor),
                      prefixIcon: Icon(Icons.speed, color: primaryBlue),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        if (odometerController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Odometer reading is required"), backgroundColor: Colors.red));
                          return;
                        }

                        setState(() => isSubmitting = true);
                        final int odo = int.tryParse(odometerController.text) ?? 0;
                        final int passCount = 0; // Default to 0 without asking
                        
                        final dynamic rawRunId = run['id'] ?? assignment['daily_bus_run_id'];
                        final int runId = rawRunId is int ? rawRunId : int.tryParse(rawRunId?.toString() ?? '0') ?? 0;
                        
                        if (runId == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Run ID is missing"), backgroundColor: Colors.red));
                          setState(() => isSubmitting = false);
                          return;
                        }

                        final result = await useDriverStore.startBusRun(
                          runId: runId,
                          startOdometer: odo,
                          imageUrl: null, // Sent as null
                        );

                        if (result['success']) {
                          // Also send passenger count
                          await useDriverStore.setCampusInPassengerCount(
                            runId: runId,
                            passengerCount: passCount,
                          );

                          setState(() => isSubmitting = false);
                          Navigator.pop(context); // Close sheet
                          Navigator.pop(context); // Close details page
                        } else {
                          setState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isSubmitting 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("START RUN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
  void _showEndBottomSheet(BuildContext context, bool isDark, Color titleColor, Color subColor, Color primaryBlue) {
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
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 24, left: 24, right: 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("End Run", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: titleColor)),
                  const SizedBox(height: 8),
                  Text("Enter your ending odometer reading.", style: TextStyle(color: subColor, fontSize: 14)),
                  const SizedBox(height: 24),

                  // Odometer Input
                  TextField(
                    controller: odometerController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "Ending Odometer",
                      labelStyle: TextStyle(color: subColor),
                      prefixIcon: Icon(Icons.speed, color: primaryBlue),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Allowance Needed Switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.monetization_on, color: primaryBlue),
                            const SizedBox(width: 12),
                            Text("Allowance Needed", style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Switch(
                          value: allowanceNeeded,
                          activeColor: primaryBlue,
                          onChanged: (val) => setState(() => allowanceNeeded = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        if (odometerController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Odometer reading is required"), backgroundColor: Colors.red));
                          return;
                        }

                        setState(() => isSubmitting = true);
                        final int odo = int.tryParse(odometerController.text) ?? 0;
                        final dynamic rawRunId = run['id'] ?? assignment['daily_bus_run_id'];
                        final int runId = rawRunId is int ? rawRunId : int.tryParse(rawRunId?.toString() ?? '0') ?? 0;
                        
                        if (runId == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Run ID is missing"), backgroundColor: Colors.red));
                          setState(() => isSubmitting = false);
                          return;
                        }

                        final result = await useDriverStore.endMorningBusRun(
                          runId: runId,
                          endOdometer: odo,
                          allowanceNeeded: allowanceNeeded,
                        );

                        if (result['success']) {
                          setState(() => isSubmitting = false);
                          Navigator.pop(context); // Close sheet
                          Navigator.pop(context); // Close details page
                        } else {
                          setState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isSubmitting 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("END RUN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}
