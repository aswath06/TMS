import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/screens/admin/request/daily_bus_run_details_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tripzo/screens/student/student_apply_leave_page.dart';
import 'package:tripzo/screens/driver/DriverLeaveScreen.dart';


import 'package:tripzo/screens/student/student_attendance_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/notification_bell.dart';
import '../../utils/routes.dart';
import 'package:tripzo/store/student_leave_store.dart';
import 'package:tripzo/screens/driver/apply_leave_page.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/components/notification_card.dart';
import 'package:tripzo/utils/tab_notification.dart';
import 'package:tripzo/store/faculty_store.dart';
import 'package:tripzo/store/user_store.dart';

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends ConsumerState<StudentDashboardScreen> {
  final useStudentLeaveStore = StudentLeaveStore();
  bool _isLoadingRun = false;
  List<dynamic> _runs = [];
  String? _runError;
  int _leaveCount = 2;
  int _absentCount = 1;
  int _attendanceDays = 17;
  int _totalDays = 20; // Mocked leave count for now

  @override
  void initState() {
    super.initState();
    if (useFacultyStore.profileData.value == null) {
      useFacultyStore.fetchProfile();
    }
    _loadTodayRun();
    useFacultyStore.errorMessage.addListener(_handleAuthError);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      useStudentLeaveStore.fetchDashboardMetrics();
    });
  }

  void _handleAuthError() async {
    if (useFacultyStore.errorMessage.value == "SESSION_EXPIRED") {
       useFacultyStore.errorMessage.removeListener(_handleAuthError);
       await UserStore.clear();
       if (!mounted) return;
       Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  void dispose() {
    useFacultyStore.errorMessage.removeListener(_handleAuthError);
    super.dispose();
  }


  Future<void> _loadTodayRun() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRun = true;
      _runError = null;
    });

    try {
      final token = await UserStore.getToken();
      final userId = await UserStore.getUserId() ?? 80;
      
      if (token == null) {
        if (mounted) setState(() { _runError = "Session expired."; _isLoadingRun = false; });
        return;
      }

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      String url = "${ApiConstants.baseUrl}/daily-bus/bus-run/get-all?user_id=$userId&service_date=$todayStr";

      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          setState(() {
            _runs = decoded['data']['runs'] ?? [];
            _isLoadingRun = false;
          });
        } else {
          setState(() {
            _runError = decoded['message'] ?? "Failed to load run.";
            _isLoadingRun = false;
          });
        }
      } else {
        setState(() {
          _runError = "Failed to load today's run.";
          _isLoadingRun = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _runError = "Connection error"; _isLoadingRun = false; });
    }
  }
  
  String _formatShift(dynamic shiftCode) {
    if (shiftCode == null) return 'FULL DAY';
    final s = shiftCode.toString().replaceAll('_', ' ').toUpperCase();
    if (s == 'FULL DAY') return 'FULL DAY';
    return s;
  }

  String _getVehicleNumber(Map<String, dynamic> run) {
    final assignments = run['assignment'] as List? ?? [];
    if (assignments.isEmpty) return 'No Vehicle';
    final numbers = assignments.map((a) => a['vehicle']?['vehicle_number']?.toString()).whereType<String>().toSet();
    if (numbers.isEmpty) return 'No Vehicle';
    return numbers.join(', ');
  }

  String? _getBusNumber(Map<String, dynamic> run) {
    final assignments = run['assignment'] as List? ?? [];
    if (assignments.isEmpty) return null;
    for (var a in assignments) {
      final bn = a['vehicle']?['bus_number']?.toString();
      if (bn != null && bn.trim().isNotEmpty && bn.toLowerCase() != 'null') {
        return bn;
      }
    }
    return null;
  }
  
  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label = status.toUpperCase();

    switch (status.toUpperCase()) {
      case 'UPCOMING':
      case 'PUBLISHED':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        label = 'UPCOMING';
        break;
      case 'IN_PROGRESS':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      case 'COMPLETED':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDriverMinimal(Color blue, String title, String subtitle, Color subColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: blue.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: blue.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.directions_bus_rounded, color: blue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mock Data
  final double attendancePercentage = 0.85; // 85%
  final String studentName = "Student";
  final Map<String, String> busDetails = {
    "busNumber": "13",
    "route": "Route 4 - Downtown",
    "vehicleNo": "TN-01-AB-1234",
    "time": "08:30 AM",
    "status": "On Time"
  };

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background decorative circle
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
                    primaryBlue.withValues(alpha: 0.0),
                  ]
                )
              ),
            ),
          ),

          SafeArea(
            bottom: true,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _buildHeader(titleColor, screenWidth, primaryBlue),
                  const SizedBox(height: 32),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle("Attendance", titleColor),
                  const SizedBox(height: 16),
                  ListenableBuilder(
                    listenable: useStudentLeaveStore,
                    builder: (context, _) {
                      if (useStudentLeaveStore.isLoadingMetrics) {
                        return Shimmer.fromColors(
                          baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: surfaceColor,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: surfaceColor,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return _buildAttendanceSection(primaryBlue, surfaceColor, isDark, screenWidth, titleColor, subColor);
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle("Today's Bus", titleColor),
                  const SizedBox(height: 16),
                  _buildTodayRunSection(surfaceColor, titleColor, subColor, isDark),
                  
                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle("Recent Notifications", titleColor),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
                        child: Text(
                          "See All",
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildNotificationList(primaryBlue, surfaceColor, isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color titleColor, double width, Color primary) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: useFacultyStore.profileData,
      builder: (context, profileData, _) {
        final displayName = profileData?['name'] ?? studentName;
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "ROLE: STUDENT",
                      style: TextStyle(
                        fontSize: 10,
                        color: primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Hello, $displayName",
                    style: TextStyle(
                      fontSize: width * 0.075,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
              ),
            ),
            NotificationBell(iconColor: titleColor),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                ChangeTabNotification(4).dispatch(context);
              },
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [primary, primary.withValues(alpha: 0.4)],
                  ),
                ),
                child: CircleAvatar(
                  radius: width * 0.065,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: width * 0.06,
                    backgroundImage: NetworkImage(
                      "https://ui-avatars.com/api/?name=$displayName&background=6366F1&color=fff",
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGraphicalCard({
    required String title,
    required String currentValue,
    required String totalValue,
    double? percent,
    required IconData icon,
    required Color color,
    required Color surface,
    required bool isDark,
    required double width,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              if (percent != null)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: percent),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return CircularProgressIndicator(
                            value: value,
                            strokeWidth: 5,
                            backgroundColor: color.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            strokeCap: StrokeCap.round,
                          );
                        },
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: percent * 100),
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Text(
                          '${value.toInt()}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        );
                      },
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  currentValue,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: width * 0.07,
                    letterSpacing: -1.0,
                    color: isDark ? Colors.white : Colors.black,
                    height: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (totalValue.isNotEmpty)
                const SizedBox(width: 4),
              if (totalValue.isNotEmpty)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      totalValue,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSection(Color primary, Color surface, bool isDark, double width, Color titleColor, Color subColor) {
    final absentCount = useStudentLeaveStore.dashboardAbsentCount;
    final leaveCount = useStudentLeaveStore.dashboardLeaveCount;
    final totalMapped = useStudentLeaveStore.dashboardTotalMappedDays;
    
    // Format to remove trailing zeros for clean display
    String formatMetric(double val) {
      if (val == val.toInt()) {
        return val.toInt().toString();
      }
      return val.toString();
    }
    
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StudentAttendanceScreen()),
              );
            },
            child: _buildGraphicalCard(
              title: "Absent Count",
              currentValue: formatMetric(absentCount),
              totalValue: "/ $totalMapped days",
              icon: Icons.person_off_rounded,
              color: const Color(0xFFEF4444), // Red for Absent
              surface: surface,
              isDark: isDark,
              width: width,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StudentAttendanceScreen()),
              );
            },
            child: _buildGraphicalCard(
              title: "Leave Count",
              currentValue: formatMetric(leaveCount),
              totalValue: "/ $totalMapped days",
              icon: Icons.calendar_today_rounded,
              color: const Color(0xFFF59E0B), // Orange for Leave
              surface: surface,
              isDark: isDark,
              width: width,
            ),
          ),
        ),
      ],
    );
  }

    Widget _buildTodayRunSection(Color cardColor, Color titleColor, Color subColor, bool isDark) {
    if (_isLoadingRun) {
      return Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Container(
          width: double.infinity,
          height: 100,
          margin: const EdgeInsets.symmetric(horizontal: 0),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      );
    }
    if (_runError != null) {
      return Center(child: Text(_runError!, style: TextStyle(color: Colors.red)));
    }
    if (_runs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          "No bus assigned for today.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: subColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final run = _runs[0] as Map<String, dynamic>;

    if (run['is_on_leave'] == true) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_busy_rounded, size: 32, color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            const Text(
              "On Leave Today",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.redAccent),
            ),
            const SizedBox(height: 8),
            Text(
              "Your mapped bus will not be displayed.",
              style: TextStyle(fontSize: 14, color: subColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    final status = run['status']?.toString() ?? 'UNKNOWN';
    final runName = run['run_name']?.toString() ?? 'Route';
    final startLoc = run['start_location_name']?.toString() ?? 'N/A';
    final haltLoc = run['halt_location_name']?.toString() ?? 'N/A';
    final shift = _formatShift(run['shift_code']);
    
    final routeData = run['dailyBusRoute'] as Map<String, dynamic>?;
    final routeName = routeData?['route_name']?.toString() ?? 'N/A';
    final maxCapacity = routeData?['max_vehicle_capacity'] ?? 60;
    
    final vehicleNo = _getVehicleNumber(run);
    final busNo = _getBusNumber(run);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DailyBusRunDetailsPage(runData: run),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Date + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          run['service_date']?.toString() ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),
            
            // Title: run_name
            Text(
              runName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            
            // Route info + Capacity
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.directions_bus_outlined, size: 14, color: subColor),
                const SizedBox(width: 4),
                Text(
                  "Route: ",
                  style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w600),
                ),
                Text(
                  routeName,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Text("•", style: TextStyle(fontSize: 12, color: subColor)),
                const SizedBox(width: 8),
                Icon(Icons.airline_seat_recline_normal_rounded, size: 14, color: subColor),
                const SizedBox(width: 4),
                Text(
                  "Capacity: ",
                  style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w600),
                ),
                Text(
                  "$maxCapacity Seats",
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Vehicle + Bus Panel
            _buildDriverMinimal(
              const Color(0xFF6366F1), 
              "Bus Number: ${busNo != null && busNo.toLowerCase() != 'null' ? busNo : 'N/A'}", 
              "Vehicle: $vehicleNo", 
              subColor
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "STOP SEQUENCE",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  shift.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6366F1),
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSimpleTimelineRow(0, startLoc, false, const Color(0xFF6366F1), titleColor, subColor, true, status.toUpperCase() == 'COMPLETED'),
            _buildSimpleTimelineRow(1, haltLoc, true, const Color(0xFF6366F1), titleColor, subColor, status.toUpperCase() == 'COMPLETED', status.toUpperCase() == 'COMPLETED'),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, Color primaryBlue, Color surface, bool isDark) {
    return Row(
      children: [
        _buildActionBtn(
          "Leave Req",
          Icons.edit_calendar_rounded,
          const Color(0xFFEC4899),
          surface,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ApplyLeavePage(userRole: 'student')),
            );
          },
        ),
        const SizedBox(width: 15),
        _buildActionBtn(
          "Bus Tracking",
          Icons.map_rounded,
          const Color(0xFFF59E0B),
          surface,
          onTap: () {
            // Future navigation to map dashboard or live tracking
          },
        ),
      ],
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color color, Color surface, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: color.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildNotificationList(Color primaryBlue, Color surface, bool isDark) {
    final notificationProvider = ref.watch(notificationProviderFamily);
    final notifications = notificationProvider.notifications;

    if (notificationProvider.isLoading && notifications.isEmpty) {
      return Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Column(
          children: List.generate(3, (index) => Container(
            width: double.infinity,
            height: 80,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
            ),
          )),
        ),
      );
    }

    if (notifications.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(Icons.notifications_none_rounded, color: Colors.grey.withValues(alpha: 0.5), size: 40),
            const SizedBox(height: 12),
            Text(
              "No new notifications",
              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    final recentNotifications = notifications.take(3).toList();
    return Column(
      children: recentNotifications.map((notification) {
        return NotificationCard(
          notification: notification,
          isDashboard: true,
        );
      }).toList(),
    );
  }



  Widget _buildSimpleTimelineRow(
    int order,
    String name,
    bool isLast,
    Color blue,
    Color titleColor,
    Color sub,
    bool isPast,
    bool isCompleted,
  ) {
    final Color dotColor = isCompleted
        ? const Color(0xFF10B981)
        : (isPast ? blue : const Color(0xFF94A3B8));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : dotColor.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
