import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/notification_bell.dart';
import '../../utils/routes.dart';
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
  @override
  void initState() {
    super.initState();
    if (useFacultyStore.profileData.value == null) {
      useFacultyStore.fetchProfile();
    }
    useFacultyStore.errorMessage.addListener(_handleAuthError);
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
                  const SizedBox(height: 20),

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
                const ChangeTabNotification(-1).dispatch(context);
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

  Widget _buildAttendanceSection(Color primary, Color surface, bool isDark, double width, Color titleColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "Excellent Status",
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Keep it up!",
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Tap to view your detailed attendance overview.",
                  style: TextStyle(
                    color: subColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: attendancePercentage,
                  strokeWidth: 12,
                  backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                  color: primary,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${(attendancePercentage * 100).toInt()}%",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusDetailsSection(Color primary, Color surface, bool isDark, Color titleColor, Color subColor) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primary.withValues(alpha: 0.12),
                  primary.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Row(
              children: [
                // Prominent Bus Number Badge
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      busDetails["busNumber"]!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        busDetails["route"]!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.directions_bus_rounded, size: 14, color: subColor),
                          const SizedBox(width: 6),
                          Text(
                            busDetails["vehicleNo"]!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: subColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.access_time_rounded, size: 16, color: Colors.orange),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Pick-up Time",
                            style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        busDetails["time"]!,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 50, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "Live Status",
                        style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              busDetails["status"]!,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
      return const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: CircularProgressIndicator(),
      ));
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
}
