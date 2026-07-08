import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/screens/driver/split_vehicle_screen.dart';
import 'package:tripzo/screens/driver/merge_vehicle_screen.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class AssignmentDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> assignment;
  final Map<String, dynamic> run;

  const AssignmentDetailsScreen({
    super.key,
    required this.assignment,
    required this.run,
  });

  @override
  State<AssignmentDetailsScreen> createState() =>
      _AssignmentDetailsScreenState();
}

class _AssignmentDetailsScreenState extends State<AssignmentDetailsScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> assignment;
  late Map<String, dynamic> run;
  late AnimationController _pulseController;
  bool _isHaltSubmitting = false;
  String? _userRole;

  int _selectedTab = 0;
  Map<String, dynamic>? _detailedRun;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    assignment = widget.assignment;
    run = widget.run;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _loadUserRole();
    _fetchRunDetails();
  }

  Future<void> _loadUserRole() async {
    final role = await UserStore.getRole();
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchRunDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoadingDetails = true;
    });

    try {
      final token = await UserStore.getToken();
      if (token == null) return;
      
      final dynamic rawRunId = run['id'] ?? assignment['daily_bus_run_id'];
      final int runId = rawRunId is int ? rawRunId : int.tryParse(rawRunId?.toString() ?? '0') ?? 0;
      
      if (runId == 0) return;

      final url = "${ApiConstants.baseUrl}/daily-bus/bus-run-id/$runId";
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          if (mounted) {
            setState(() {
              _detailedRun = decoded['data'];
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching detailed run: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _fetchRunDetails();
    final role = await UserStore.getRole();
    if (role == 'transport admin' || role == 'super admin') {
      final token = await UserStore.getToken();
      if (token == null) return;
      final userId = await UserStore.getUserId();
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final url =
          "${ApiConstants.baseUrl}/daily-bus/bus-run/get-all?service_date=$dateStr${userId != null ? '&user_id=$userId' : ''}";

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final runs = decoded['data']['runs'] as List? ?? [];
          for (var r in runs) {
            if (r['id'] == run['id']) {
              if (mounted) {
                setState(() {
                  run = r;
                  assignment = {...assignment, ...r};
                });
              }
              return;
            }
          }
        }
      }
    } else {
      await useDriverStore.fetchDailyBusRuns();
      final runId = run['id'];
      final assignId = assignment['id'];

      if (useDriverStore.dailyBusRuns.isNotEmpty) {
        for (var r in useDriverStore.dailyBusRuns) {
          if (r['id'] == runId) {
            final assigns = r['assignment'] as List? ?? [];
            if (assigns.isEmpty) {
              if (mounted) {
                setState(() {
                  run = r;
                  assignment = {...assignment, ...r};
                });
              }
              return;
            }

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

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "—";
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        String ampm = hour >= 12 ? 'PM' : 'AM';
        hour = hour % 12;
        if (hour == 0) hour = 12;
        return "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $ampm";
      }
    } catch (_) {}
    return timeStr;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
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
      double start =
          double.tryParse(
            filteredReadings[0]['odometer_reading']?.toString() ?? '0',
          ) ??
          0;
      double end =
          double.tryParse(
            filteredReadings[1]['odometer_reading']?.toString() ?? '0',
          ) ??
          0;
      if (start > 0 && end > 0) {
        distance = (end - start).abs();
      }
    }

    final routeObj = run['dailyBusRoute'] as Map<String, dynamic>?;
    final routeName = routeObj?['route_name'] ?? 'Unknown Route';
    final routeCode = routeObj?['route_code'] ?? '';
    final stops = (routeObj?['stops'] as List<dynamic>?) ?? [];
    stops.sort((a, b) {
      final orderA = a['stop_order'] as int? ?? 0;
      final orderB = b['stop_order'] as int? ?? 0;
      return shiftCode == 'EVENING'
          ? orderB.compareTo(orderA)
          : orderA.compareTo(orderB);
    });

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Daily Bus Route",
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: titleColor),
        actions: [
          if (statusStr == 'STARTED')
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.merge_rounded, color: primaryBlue, size: 20),
                ),
                onPressed: () async {
                  final dynamic rawRunId = run['id'] ?? assignment['daily_bus_run_id'];
                  final int runId = rawRunId is int ? rawRunId : int.tryParse(rawRunId?.toString() ?? '0') ?? 0;
                  
                  if (runId == 0) return;

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MergeVehicleScreen(currentRunId: runId),
                    ),
                  );
                  if (result == true) {
                    _handleRefresh();
                  }
                },
              ),
            ),
          if (statusStr == 'DEPARTED_CAMPUS' || statusStr == 'MERGED_HALTED')
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.call_split_rounded, color: primaryBlue, size: 20),
                ),
                onPressed: () async {
                  final dynamic rawRunId = run['id'] ?? assignment['daily_bus_run_id'];
                  final int runId = rawRunId is int ? rawRunId : int.tryParse(rawRunId?.toString() ?? '0') ?? 0;
                  
                  if (runId == 0) return;

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SplitVehicleScreen(runId: runId),
                    ),
                  );
                  if (result == true) {
                    _handleRefresh();
                  }
                },
              ),
            ),
        ],
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
                              _buildStatusBadgeWidget(statusStr),
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
                                    style: TextStyle(
                                      color: subColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
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

                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              
              // Merged Vehicle Card
              _buildMergedVehicleCard(surfaceColor, primaryBlue),

              // Tabs Toggle
              _buildToggleSwitch(primaryBlue, surfaceColor, subColor, titleColor),

              if (_isLoadingDetails)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_selectedTab == 0) ...[
                const SizedBox(height: 24),
                if (statusStr == 'MERGED_HALTED')
                  _buildMergedHaltedMetrics(isDark, primaryBlue)
                else
                  _buildTravelMetrics(isDark, primaryBlue, shiftCode),

                if (_userRole == 'driver') ...[
                  const SizedBox(height: 24),
                  _buildAssignedFacultySection(isDark, primaryBlue, surfaceColor, titleColor, subColor),
                ],
              ] else ...[
                const SizedBox(height: 24),
                _buildDetailedStops(isDark, primaryBlue, surfaceColor, titleColor, subColor, shiftCode),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ), // closes SingleChildScrollView
      ), // closes RefreshIndicator
      bottomNavigationBar: shiftCode == 'EVENING'
          ? _buildEveningBottomNavigationBar(
              statusStr,
              surfaceColor,
              isDark,
              titleColor,
              subColor,
              primaryBlue,
            )
          : _buildMorningBottomNavigationBar(
              statusStr,
              surfaceColor,
              isDark,
              titleColor,
              subColor,
              primaryBlue,
            ),
    );
  }

  Widget? _buildMorningBottomNavigationBar(
    String statusStr,
    Color surfaceColor,
    bool isDark,
    Color titleColor,
    Color subColor,
    Color primaryBlue,
  ) {
    if (statusStr == 'READY') {
      return Container(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showStartBottomSheet(
              context,
              isDark,
              titleColor,
              subColor,
              primaryBlue,
            ),
            icon: const Icon(Icons.info_outline_rounded, size: 20),
            label: const Text(
              "START",
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.3),
            ),
          ),
        ),
      );
    } else if (statusStr == 'ARRIVED_CAMPUS') {
      return Container(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _showEndBottomSheet(
            context,
            isDark,
            titleColor,
            subColor,
            primaryBlue,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            "END",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ),
      );
    }
    return null;
  }

  Widget? _buildEveningBottomNavigationBar(
    String statusStr,
    Color surfaceColor,
    bool isDark,
    Color titleColor,
    Color subColor,
    Color primaryBlue,
  ) {
    if (statusStr == 'FN_COMPLETED') {
      return Container(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showEveningStartBottomSheet(
              context,
              isDark,
              titleColor,
              subColor,
              primaryBlue,
            ),
            icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
            label: const Text(
              "START",
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.3),
            ),
          ),
        ),
      );
    } else if (statusStr == 'DEPARTED_CAMPUS' || statusStr == 'RESUMED_MIDWAY') {
      return Container(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isHaltSubmitting
                        ? null
                        : () async {
                            setState(() => _isHaltSubmitting = true);
                            final dynamic rawRunId =
                                widget.run['id'] ?? widget.assignment['daily_bus_run_id'];
                            final int runId = rawRunId is int
                                ? rawRunId
                                : int.tryParse(rawRunId?.toString() ?? '0') ?? 0;

                            if (runId == 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Error: Run ID is missing"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              setState(() => _isHaltSubmitting = false);
                              return;
                            }

                            final result = await useDriverStore.haltEveningBusRun(
                              runId: runId,
                            );

                            if (result['success']) {
                              setState(() => _isHaltSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['message'] ?? 'Success'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              await _handleRefresh();
                            } else {
                              setState(() => _isHaltSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['message']),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isHaltSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "I Am Halting The Vehicle",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),

            ],
          ),
      );
    } else if (statusStr == 'HALTED') {
      return Container(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _showEveningEndBottomSheet(
            context,
            isDark,
            titleColor,
            subColor,
            primaryBlue,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            "END",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ),
      );
    }
    return null;
  }

  void _showStartBottomSheet(
    BuildContext context,
    bool isDark,
    Color titleColor,
    Color subColor,
    Color primaryBlue,
  ) {
    final odometerController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext stateContext, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom
                    : 0,
              ),
              child: Container(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0
                      ? 24
                      : MediaQuery.of(context).padding.bottom + 24,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
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
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter your starting odometer reading.",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Odometer Input
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
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
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          labelText: "Start Odometer",
                          labelStyle: TextStyle(
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          floatingLabelStyle: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w700,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.speed,
                            color: Color(0xFF6366F1),
                          ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "Close",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (odometerController.text
                                        .trim()
                                        .isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Odometer reading cannot be empty.",
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() => isSubmitting = true);
                                    final int odo =
                                        int.tryParse(
                                          odometerController.text.trim(),
                                        ) ??
                                        0;

                                    final dynamic rawRunId =
                                        widget.run['id'] ??
                                        widget.assignment['daily_bus_run_id'];
                                    final int runId = rawRunId is int
                                        ? rawRunId
                                        : int.tryParse(
                                                rawRunId?.toString() ?? '0',
                                              ) ??
                                              0;

                                    if (runId == 0) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Error: Run ID is missing",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      setState(() => isSubmitting = false);
                                      return;
                                    }

                                    try {
                                      final result = await useDriverStore
                                          .startBusRun(
                                            runId: runId,
                                            startOdometer: odo,
                                            imageUrl: null,
                                          );

                                      if (result['success'] == true) {
                                        if (mounted) {
                                          setState(() => isSubmitting = false);
                                          Navigator.pop(sheetContext); // Close sheet
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text("Run started successfully"),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          
                                          await _handleRefresh(); // Reload page
                                        }
                                      } else {
                                        if (mounted) {
                                          setState(() => isSubmitting = false);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                result['message'] ??
                                                    "Failed to start run",
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        setState(() => isSubmitting = false);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text("Error: $e"),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "SUBMIT",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
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

  void _showEndBottomSheet(
    BuildContext context,
    bool isDark,
    Color titleColor,
    Color subColor,
    Color primaryBlue,
  ) {
    final odometerController = TextEditingController();
    final passengerController = TextEditingController();
    bool? allowanceNeeded;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom
                    : 0,
              ),
              child: Container(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0
                      ? 24
                      : MediaQuery.of(context).padding.bottom + 24,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
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
                    Text(
                      "End Morning Shift Information",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please enter the final details before completing the shift.",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Odometer Input
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: odometerController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: "End Odometer",
                          hintStyle: TextStyle(
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.speed,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_userRole == 'driver') ...[
                      // Display Campus In Count
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.group_rounded,
                                  color: primaryBlue,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "Campus In Count",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: (run['campus_in_count'] == null)
                                    ? Colors.orange.withValues(alpha: 0.1)
                                    : primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                run['campus_in_count']?.toString() ?? "null",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: (run['campus_in_count'] == null)
                                      ? Colors.orange
                                      : primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      // Passenger Count Display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.group, color: primaryBlue),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Passenger Count",
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${widget.run['campus_in_count'] ?? '0'}",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // DA/TA Required Option (Allowance)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "DA/TA is required for driver*",
                            style: TextStyle(
                              color: titleColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => allowanceNeeded = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          allowanceNeeded == true
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          color: allowanceNeeded == true
                                              ? const Color(0xFF6366F1)
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Yes",
                                          style: TextStyle(
                                            color: titleColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => allowanceNeeded = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          allowanceNeeded == false
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          color: allowanceNeeded == false
                                              ? const Color(0xFF6366F1)
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "No",
                                          style: TextStyle(
                                            color: titleColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "Close",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (odometerController.text
                                        .trim()
                                        .isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Odometer reading cannot be empty.",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    if (_userRole != 'driver' &&
                                        passengerController.text.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Passenger count is required",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    if (allowanceNeeded == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Please select DA/TA requirement",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() => isSubmitting = true);
                                    final int odo =
                                        int.tryParse(
                                          odometerController.text.trim(),
                                        ) ??
                                        0;
                                    final int? passCount = (_userRole == 'driver')
                                        ? null
                                        : (int.tryParse(
                                              passengerController.text,
                                            ) ??
                                            0);

                                    final dynamic rawRunId =
                                        widget.run['id'] ??
                                        widget.assignment['daily_bus_run_id'];
                                    final int runId = rawRunId is int
                                        ? rawRunId
                                        : int.tryParse(
                                                rawRunId?.toString() ?? '0',
                                              ) ??
                                              0;

                                    if (runId == 0) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Error: Run ID is missing",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      setState(() => isSubmitting = false);
                                      return;
                                    }

                                    final result = await useDriverStore
                                        .endMorningBusRun(
                                          runId: runId,
                                          endOdometer: odo,
                                          passengerCount: passCount,
                                          allowanceNeeded:
                                              allowanceNeeded ?? false,
                                        );

                                    if (result['success'] == true) {
                                      if (mounted) {
                                        setState(() => isSubmitting = false);
                                        Navigator.pop(context);
                                        
                                        // Get count from result or passCount
                                        int campusInCount = 0;
                                        if (result['data'] != null && result['data']['campus_in_count'] != null) {
                                          campusInCount = result['data']['campus_in_count'];
                                        } else if (result['campus_in_count'] != null) {
                                          campusInCount = result['campus_in_count'];
                                        } else {
                                          campusInCount = passCount ?? 0;
                                        }
                                        
                                        // Show Alert with count for non-drivers
                                        if (_userRole != 'driver') {
                                          showDialog(
                                            context: this.context, 
                                            builder: (ctx) => AlertDialog(
                                              title: const Text("Run Ended"),
                                              content: Text("Successfully ended run.\nCampus In Count: $campusInCount"),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx),
                                                  child: const Text("OK"),
                                                ),
                                              ],
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(this.context).showSnackBar(
                                            const SnackBar(
                                              content: Text("Run ended successfully."),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }

                                        await _handleRefresh();
                                      }
                                    } else {
                                      if (mounted) {
                                        setState(() => isSubmitting = false);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(result['message']),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "SUBMIT",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
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

  Widget _buildStatRow(
    String label,
    String value,
    Color titleColor,
    Color subColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              color: subColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: titleColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignedFacultySection(
    bool isDark,
    Color primaryColor,
    Color surfaceColor,
    Color titleColor,
    Color subColor,
  ) {
    final faculty = run['assignedFaculty'] as Map<String, dynamic>?;
    if (faculty == null) return const SizedBox.shrink();

    final String name = faculty['name'] ?? faculty['user']?['name'] ?? 'N/A';
    final String rawPhone = faculty['phone']?.toString() ?? faculty['user']?['phone']?.toString() ?? '';
    final String phone = rawPhone.isNotEmpty ? rawPhone : '9876543210';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
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
              Icon(Icons.person_outline_rounded, color: primaryColor, size: 24),
              const SizedBox(width: 10),
              Text(
                "Assigned Faculty",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'F',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 14,
                          color: subColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (phone.isNotEmpty)
                IconButton(
                  onPressed: () async {
                    final String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
                    final Uri url = Uri.parse("tel:$cleanPhone");
                    try {
                      await launchUrl(url);
                    } catch (e) {
                      debugPrint("Error launching phone dialer: $e");
                    }
                  },
                  icon: const Icon(Icons.call_rounded),
                  color: Colors.green,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMergedHaltedMetrics(bool isDark, Color primaryBlue) {
    final runData = _detailedRun ?? widget.run;
    final targetMerges = runData['targetMerges'] as List<dynamic>?;
    
    if (targetMerges == null || targetMerges.isEmpty) {
       return const SizedBox.shrink();
    }

    final merge = targetMerges.firstWhere((m) => m['status'] == 'ACTIVE', orElse: () => targetMerges.first);
    
    String mergedAt = 'N/A';
    if (merge['merged_at'] != null) {
      try {
        final dt = DateTime.parse(merge['merged_at'].toString()).toLocal();
        mergedAt = "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} ${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
      } catch (e) {
        mergedAt = merge['merged_at'].toString();
      }
    }

    final String mergeStopName = merge['mergeStop']?['stop_name']?.toString() ?? 'Unknown Stop';
    
    final targetRun = merge['targetRun'];
    final String runName = targetRun?['run_name']?.toString() ?? 'Unknown Route';
    
    String vehicleNumber = 'Unknown Vehicle';
    String driverName = 'Unknown Driver';
    
    if (targetRun != null && targetRun['assignment'] != null && (targetRun['assignment'] as List).isNotEmpty) {
      final assignment = targetRun['assignment'][0];
      vehicleNumber = assignment['vehicle']?['vehicle_number']?.toString() ?? 'Unknown Vehicle';
      driverName = assignment['driver']?['user']?['name']?.toString() ?? 'Unknown Driver';
    }

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cancel_presentation_rounded, color: Colors.red.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                "Run Halted & Merged",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMetricRow(Icons.access_time_rounded, "Merged At", mergedAt, textColor, subColor),
          const SizedBox(height: 12),
          _buildMetricRow(Icons.place_rounded, "Merge Stop", mergeStopName, textColor, subColor),
          const SizedBox(height: 12),
          _buildMetricRow(Icons.directions_bus_rounded, "Target Vehicle", "$vehicleNumber - $driverName", textColor, subColor),
          const SizedBox(height: 12),
          _buildMetricRow(Icons.route_rounded, "Target Route", runName, textColor, subColor),
        ],
      ),
    );
  }

  Widget _buildMetricRow(IconData icon, String label, String value, Color textColor, Color subColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: subColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: subColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTravelMetrics(
    bool isDark,
    Color primaryColor,
    String shiftCode,
  ) {
    final startedAt = shiftCode == 'EVENING'
        ? run['actual_campus_out_time']
        : run['actual_start_at'];
    final endedAt = shiftCode == 'EVENING'
        ? run['actual_halt_time']
        : run['actual_campus_in_time'];

    final filteredReadings = (run['odometerReadings'] as List?) ?? [];
    String startOdoStr = "N/A";
    String endOdoStr = "N/A";

    final startReadingType = shiftCode == 'EVENING' ? 'CAMPUS_OUT' : 'START';
    final endReadingType = shiftCode == 'EVENING' ? 'HALT' : 'CAMPUS_IN';

    final startReading = filteredReadings.firstWhere(
      (r) => r['reading_type'] == startReadingType,
      orElse: () => {},
    );
    final endReading = filteredReadings.firstWhere(
      (r) => r['reading_type'] == endReadingType,
      orElse: () => {},
    );

    double startOdoVal = 0;
    double endOdoVal = 0;

    if (startReading.isNotEmpty) {
      final valStr = startReading['odometer_reading']?.toString() ?? "0";
      startOdoVal = double.tryParse(valStr) ?? 0;
      if (startOdoVal > 0) {
        startOdoStr = startOdoVal.toStringAsFixed(
          startOdoVal.truncateToDouble() == startOdoVal ? 0 : 2,
        );
      }
    }

    if (endReading.isNotEmpty) {
      final valStr = endReading['odometer_reading']?.toString() ?? "0";
      endOdoVal = double.tryParse(valStr) ?? 0;
      if (endOdoVal > 0) {
        endOdoStr = endOdoVal.toStringAsFixed(
          endOdoVal.truncateToDouble() == endOdoVal ? 0 : 2,
        );
      }
    }

    double? distance;
    if (startOdoVal > 0 && endOdoVal > 0 && endOdoVal >= startOdoVal) {
      distance = endOdoVal - startOdoVal;
    }

    final count = shiftCode == 'EVENING'
        ? run['campus_out_count']?.toString()
        : run['campus_in_count']?.toString();

    String? verifiedByName;
    if (shiftCode == 'EVENING') {
      final vObj = run['campusOutVerifiedBy'];
      verifiedByName = (vObj is Map)
          ? vObj['name']
          : run['campus_out_verified_by']?.toString();
    } else {
      final vObj = run['campusInVerifiedBy'];
      verifiedByName = (vObj is Map)
          ? vObj['name']
          : run['campus_in_verified_by']?.toString();
    }

    final allowanceNeeded = assignment['allowance_needed'] == true
        ? "YES"
        : "NO";

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
          _buildTimeDurationSection(
            startedAt,
            endedAt,
            null,
            null,
            primaryColor,
            isDark,
          ),
          const SizedBox(height: 24),
          Divider(
            height: 1,
            thickness: 1,
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  "START ODOMETER",
                  startOdoStr,
                  Icons.flag_circle_rounded,
                  Colors.blue,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  "END ODOMETER",
                  endOdoStr,
                  Icons.check_circle_rounded,
                  Colors.green,
                  isDark,
                ),
              ),
            ],
          ),
          if (startedAt != null || distance != null) ...[
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final startDt = _parseTimestamp(startedAt);
                final endDt = _parseTimestamp(endedAt);
                Duration? dur;
                if (startDt != null && endDt != null) {
                  dur = endDt.difference(startDt);
                } else if (startDt != null && endedAt == null)
                  dur = DateTime.now().difference(startDt);

                final bool isOngoing = startedAt != null && endedAt == null;
                final String label = dur != null
                    ? _formatDuration(dur)
                    : (isOngoing ? "Calculating..." : "N/A");

                return Row(
                  children: [
                    if (startedAt != null)
                      Expanded(
                        child: _buildMetricTile(
                          "TOTAL DURATION",
                          label,
                          Icons.timer_outlined,
                          primaryColor,
                          isDark,
                        ),
                      ),
                    if (startedAt != null && distance != null)
                      const SizedBox(width: 12),
                    if (distance != null)
                      Expanded(
                        child: _buildMetricTile(
                          "TOTAL DISTANCE",
                          "${distance.toStringAsFixed(1)} KM",
                          Icons.route_outlined,
                          primaryColor,
                          isDark,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  "CAMPUS COUNT",
                  count ?? "Not Entered",
                  Icons.people_alt_outlined,
                  Colors.orange,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  "VERIFIED BY",
                  verifiedByName ?? "Not Entered",
                  Icons.verified_user_outlined,
                  Colors.purple,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDurationSection(
    dynamic startedAt,
    dynamic endedAt,
    String? startedBy,
    String? endedBy,
    Color primaryColor,
    bool isDark,
  ) {
    final bool isOngoing = startedAt != null && endedAt == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildTimeNodeCard(
                "STARTED",
                startedAt,
                startedBy,
                Icons.play_circle_fill_rounded,
                Colors.green,
                isDark,
              ),
            ),
            _buildConnectingBridge(primaryColor, isOngoing),
            Expanded(
              child: _buildTimeNodeCard(
                endedAt != null
                    ? "ENDED"
                    : (startedAt != null ? "ONGOING" : "PENDING"),
                endedAt ?? (startedAt != null ? "In Progress" : null),
                endedBy,
                Icons.stop_circle_rounded,
                endedAt != null
                    ? Colors.redAccent
                    : (startedAt != null ? Colors.orange : Colors.grey),
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
              CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
            ),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOngoing ? Colors.orange : activeColor,
                boxShadow: [
                  BoxShadow(
                    color: (isOngoing ? Colors.orange : activeColor).withValues(
                      alpha: 0.6,
                    ),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
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

  void _showEveningStartBottomSheet(
    BuildContext context,
    bool isDark,
    Color titleColor,
    Color subColor,
    Color primaryBlue,
  ) {
    final odometerController = TextEditingController();
    final passengerController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext stateContext, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom
                    : 0,
              ),
              child: Container(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0
                      ? 24
                      : MediaQuery.of(context).padding.bottom + 24,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
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
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter your starting details.",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Odometer Input
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: odometerController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          labelText: "Starting Odometer",
                          labelStyle: TextStyle(
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          floatingLabelStyle: TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.w700,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          prefixIcon: Icon(Icons.speed, color: primaryBlue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Passenger Count Display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.group, color: primaryBlue),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Passenger Count",
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${widget.run['campus_out_count'] ?? '0'}",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "Close",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Odometer reading is required",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() => isSubmitting = true);
                                    final int odo =
                                        int.tryParse(odometerController.text) ??
                                        0;
                                    final int passCount =
                                        int.tryParse(
                                          widget.run['campus_out_count']?.toString() ?? '0',
                                        ) ??
                                        0;
                                    final dynamic rawRunId =
                                        widget.run['id'] ??
                                        widget.assignment['daily_bus_run_id'];
                                    final int runId = rawRunId is int
                                        ? rawRunId
                                        : int.tryParse(
                                                rawRunId?.toString() ?? '0',
                                              ) ??
                                              0;

                                    if (runId == 0) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Error: Run ID is missing",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      setState(() => isSubmitting = false);
                                      return;
                                    }

                                    final result = await useDriverStore
                                        .startEveningCampusOut(
                                          runId: runId,
                                          startOdometer: odo,
                                          passengerCount: passCount,
                                        );

                                    if (result['success']) {
                                      if (mounted) {
                                        setState(() => isSubmitting = false);
                                        Navigator.pop(sheetContext);
                                        
                                        // Get count from result or passCount
                                        int campusOutCount = 0;
                                        if (result['data'] != null && result['data']['campus_out_count'] != null) {
                                          campusOutCount = result['data']['campus_out_count'];
                                        } else if (result['campus_out_count'] != null) {
                                          campusOutCount = result['campus_out_count'];
                                        } else {
                                          campusOutCount = passCount;
                                        }
                                        
                                        // Show Alert with count for non-drivers
                                        if (_userRole != 'driver') {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text("Evening Run Started"),
                                              content: Text("Successfully started evening run.\nCampus Out Count: $campusOutCount"),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx),
                                                  child: const Text("OK"),
                                                ),
                                              ],
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text("Evening run started successfully."),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                        
                                        await _handleRefresh();
                                      }
                                    } else {
                                      setState(() => isSubmitting = false);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(result['message']),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "SUBMIT",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
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

  void _showEveningEndBottomSheet(
    BuildContext context,
    bool isDark,
    Color titleColor,
    Color subColor,
    Color primaryBlue,
  ) {
    final odometerController = TextEditingController();

    bool? allowanceNeeded;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom
                    : 0,
              ),
              child: Container(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0
                      ? 24
                      : MediaQuery.of(context).padding.bottom + 24,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
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
                    Text(
                      "End Evening Shift Information",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please enter the final details before completing the shift.",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Odometer Input
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: odometerController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: "End Odometer",
                          hintStyle: TextStyle(
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          prefixIcon: const Icon(
                            Icons.speed,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Passenger Count Display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.group, color: primaryBlue),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Passenger Count",
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${widget.run['campus_out_count'] ?? '0'}",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // DA/TA Required Option (Allowance)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "DA/TA is required for driver*",
                            style: TextStyle(
                              color: titleColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => allowanceNeeded = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          allowanceNeeded == true
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          color: allowanceNeeded == true
                                              ? const Color(0xFF6366F1)
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Yes",
                                          style: TextStyle(
                                            color: titleColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => allowanceNeeded = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          allowanceNeeded == false
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          color: allowanceNeeded == false
                                              ? const Color(0xFF6366F1)
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "No",
                                          style: TextStyle(
                                            color: titleColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "Close",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    if (odometerController.text
                                        .trim()
                                        .isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Odometer reading cannot be empty.",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    if (allowanceNeeded == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Please select DA/TA requirement",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() => isSubmitting = true);
                                    final int odo =
                                        int.tryParse(
                                          odometerController.text.trim(),
                                        ) ??
                                        0;

                                    final dynamic rawRunId =
                                        widget.run['id'] ??
                                        widget.assignment['daily_bus_run_id'];
                                    final int runId = rawRunId is int
                                        ? rawRunId
                                        : int.tryParse(
                                                rawRunId?.toString() ?? '0',
                                              ) ??
                                              0;

                                    if (runId == 0) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Error: Run ID is missing",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      setState(() => isSubmitting = false);
                                      return;
                                    }

                                    final result = await useDriverStore
                                        .endEveningOdometer(
                                          runId: runId,
                                          endOdometer: odo,

                                          allowanceNeeded:
                                              allowanceNeeded ?? false,
                                        );

                                    if (result['success'] == true) {
                                      if (mounted) {
                                        setState(() => isSubmitting = false);
                                        Navigator.pop(context);
                                        
                                        // Get count from result or passCount
                                        int campusOutCount = 0;
                                        if (result['data'] != null && result['data']['campus_out_count'] != null) {
                                          campusOutCount = result['data']['campus_out_count'];
                                        } else if (result['campus_out_count'] != null) {
                                          campusOutCount = result['campus_out_count'];
                                        } else {
                                          campusOutCount = 0;
                                        }
                                        
                                        // Show Alert with count for non-drivers
                                        if (_userRole != 'driver') {
                                          showDialog(
                                            context: this.context, 
                                            builder: (ctx) => AlertDialog(
                                              title: const Text("Run Ended"),
                                              content: Text("Successfully ended run.\nCampus Out Count: $campusOutCount"),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx),
                                                  child: const Text("OK"),
                                                ),
                                              ],
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(this.context).showSnackBar(
                                            const SnackBar(
                                              content: Text("Run ended successfully."),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }

                                        await _handleRefresh();
                                      }
                                    } else {
                                      if (mounted) {
                                        setState(() => isSubmitting = false);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(result['message']),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "SUBMIT",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
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

  Widget _buildTimeNodeCard(
    String title,
    dynamic rawTime,
    String? byName,
    IconData icon,
    Color accentColor,
    bool isDark,
  ) {
    final String timeStr = (rawTime != null && rawTime != "In Progress")
        ? _formatActualTime(rawTime.toString())
        : (rawTime == "In Progress" ? "In Progress" : "N/A");
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark
        ? Colors.white60
        : const Color(0xFF64748B);
    final Color cardBg = isDark
        ? Colors.white.withValues(alpha: 0.02)
        : Colors.grey.shade50;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
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
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: subTextColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: titleColor,
              letterSpacing: 0.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    String title,
    String value,
    IconData icon,
    Color iconColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  String _formatActualTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      final months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
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
    if (hours == 0 && minutes == 0) {
      parts.add("$seconds sec${seconds > 1 ? 's' : ''}");
    }
    return parts.join(" ");
  }

  List<Map<String, String>> _getMergedVehiclesData() {
    List<Map<String, String>> mergedData = [];
    
    // Fallback to widget.run if _detailedRun is null or empty
    final runData = _detailedRun ?? widget.run;

    void addData(dynamic runObj) {
      if (runObj == null) return;
      final runName = runObj['run_name']?.toString() ?? 'Unknown Run';
      final assignments = runObj['assignment'] as List<dynamic>?;
      if (assignments != null && assignments.isNotEmpty) {
        final vehicle = assignments[0]['vehicle'];
        final driver = assignments[0]['driver'];
        final vehicleNum = vehicle?['vehicle_number']?.toString() ?? 'Unknown Vehicle';
        final driverName = driver?['user']?['name']?.toString() ?? 'Unknown Driver';
        
        // Prevent duplicates based on vehicle number
        if (!mergedData.any((m) => m['vehicle'] == vehicleNum)) {
           mergedData.add({
             'vehicle': vehicleNum,
             'driver': driverName,
             'run_name': runName,
           });
        }
      }
    }

    // Check targetMerges
    final targetMerges = runData['targetMerges'] as List<dynamic>?;
    if (targetMerges != null && targetMerges.isNotEmpty) {
      for (var merge in targetMerges) {
        addData(merge['sourceRun']);
      }
    }

    // Check sourceMerges
    final sourceMerges = runData['sourceMerges'] as List<dynamic>?;
    if (sourceMerges != null && sourceMerges.isNotEmpty) {
      for (var merge in sourceMerges) {
        addData(merge['targetRun']);
      }
    }
    
    return mergedData;
  }

  Widget _buildMergedVehicleCard(Color surfaceColor, Color primaryBlue) {
    final List<Map<String, String>> mergedVehicles = _getMergedVehiclesData();
    if (mergedVehicles.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.call_merge_rounded, color: Colors.orange.shade700, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Merged Vehicle Details",
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ...mergedVehicles.map((data) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.directions_bus_rounded, size: 14, color: Colors.orange.shade900),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "${data['vehicle']} - ${data['driver']}",
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(Icons.route_rounded, size: 14, color: Colors.orange.shade700),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "${data['run_name']}",
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadgeWidget(String status) {
    final String s = status.toUpperCase();
    Color bgColor;
    Color textColor;
    Color borderColor;

    switch (s) {
      case "PLANNED":
      case "APPROVED":
      case "ASSIGNED":
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        borderColor = const Color(0xFFFDE68A);
        break;
      case "READY":
        bgColor = const Color(0xFFFCE7F3);
        textColor = const Color(0xFFBE185D);
        borderColor = const Color(0xFFFBCFE8);
        break;
      case "STARTED":
      case "ON_TRIP":
      case "ONGOING":
        bgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF2563EB);
        borderColor = const Color(0xFF93C5FD);
        break;
      case "ARRIVED_CAMPUS":
      case "CAMPUS_IN":
        bgColor = const Color(0xFFEEF2FF);
        textColor = const Color(0xFF6366F1);
        borderColor = const Color(0xFFC7D2FE);
        break;
      case "FN_COMPLETED":
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF059669);
        borderColor = const Color(0xFFA7F3D0);
        break;
      case "RESUMED_MIDWAY":
      case "DEPARTED_CAMPUS":
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFB45309);
        borderColor = const Color(0xFFFDE68A);
        break;
      case "HALTED":
        bgColor = const Color(0xFFFAF5FF);
        textColor = const Color(0xFF8B5CF6);
        borderColor = const Color(0xFFE9D5FF);
        break;
      case "COMPLETED":
      case "FINISHED":
      case "MERGED_HALTED":
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF047857);
        borderColor = const Color(0xFFA7F3D0);
        break;
      case "CANCELLED":
      case "REJECTED":
        bgColor = const Color(0xFFFFE4E6);
        textColor = const Color(0xFFBE123C);
        borderColor = const Color(0xFFFECDD3);
        break;
      default:
        bgColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF475569);
        borderColor = const Color(0xFFE2E8F0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        s == "MERGED_HALTED" ? "ENDED" : status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildToggleSwitch(Color primaryBlue, Color surfaceColor, Color subColor, Color titleColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      height: 48,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: subColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTab = 0);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Overview",
                  style: TextStyle(
                    color: _selectedTab == 0 ? primaryBlue : subColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTab = 1);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Stops",
                  style: TextStyle(
                    color: _selectedTab == 1 ? primaryBlue : subColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfoCard(bool isDark, Color primaryBlue, Color surfaceColor, Color titleColor, Color subColor) {
    final vehicle = _detailedRun?['vehicle'];
    if (vehicle == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: subColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.directions_bus_rounded, color: primaryBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle['registration_number'] ?? 'Unknown Vehicle',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor),
                ),
                const SizedBox(height: 4),
                Text(
                  "Capacity: ${vehicle['capacity'] ?? 'N/A'} • ${vehicle['type'] ?? 'Bus'}",
                  style: TextStyle(fontSize: 13, color: subColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfoCard(bool isDark, Color primaryBlue, Color surfaceColor, Color titleColor, Color subColor) {
    final driver = _detailedRun?['driver'];
    if (driver == null) return const SizedBox.shrink();

    final user = driver['user'] ?? {};
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: subColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person_rounded, color: primaryBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] ?? 'Unknown Driver',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
                ),
                const SizedBox(height: 4),
                Text(
                  user['phone'] ?? driver['employee_code'] ?? 'No contact info',
                  style: TextStyle(fontSize: 13, color: subColor),
                ),
              ],
            ),
          ),
          if (user['phone'] != null)
            IconButton(
              icon: const Icon(Icons.call, color: Colors.green),
              onPressed: () {
                launchUrl(Uri.parse('tel:${user['phone']}'));
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDetailedStops(bool isDark, Color primaryBlue, Color surfaceColor, Color titleColor, Color subColor, String shiftCode) {
    final stops = (_detailedRun?['runStops'] as List<dynamic>?) ?? [];
    if (stops.isEmpty) return const SizedBox.shrink();

    stops.sort((a, b) {
      final orderA = a['stop_order'] as int? ?? 0;
      final orderB = b['stop_order'] as int? ?? 0;
      return shiftCode == 'EVENING' ? orderB.compareTo(orderA) : orderA.compareTo(orderB);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 24.0),
          child: Text(
            "Assigned Stops",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: titleColor,
            ),
          ),
        ),
        ...List.generate(stops.length, (index) {
          final stop = stops[index];
          final bool isFirst = index == 0;
          final bool isLast = index == stops.length - 1;
          final int order = stop['stop_order'] ?? (index + 1);
          final String stopName = stop['stop_name'] ?? 'Unknown Stop';
          
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isFirst ? const Color(0xFF10B981) : (isLast ? const Color(0xFFEF4444) : primaryBlue),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: (isFirst ? const Color(0xFF10B981) : (isLast ? const Color(0xFFEF4444) : primaryBlue)).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isFirst ? Icons.home_rounded : (isLast ? Icons.flag_rounded : Icons.location_on_rounded),
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: primaryBlue.withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primaryBlue.withValues(alpha: 0.05)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isFirst ? const Color(0xFF10B981) : (isLast ? const Color(0xFFEF4444) : primaryBlue)).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Stop $order",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isFirst ? const Color(0xFF10B981) : (isLast ? const Color(0xFFEF4444) : primaryBlue),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                stopName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (shiftCode == 'MORNING' && stop['pickup_plan_time'] != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.arrow_upward_rounded, size: 14, color: const Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text("Pickup: ${_formatTime(stop['pickup_plan_time']?.toString())}", style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ] else if (shiftCode == 'EVENING' && stop['drop_plan_time'] != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.arrow_downward_rounded, size: 14, color: const Color(0xFFEF4444)),
                              const SizedBox(width: 4),
                              Text("Drop: ${_formatTime(stop['drop_plan_time']?.toString())}", style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
