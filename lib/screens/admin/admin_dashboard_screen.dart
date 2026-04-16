import 'package:flutter/material.dart';
import 'package:tripzo/store/admin_dashboard_store.dart';
import 'package:tripzo/screens/faculty/missions/mission_history_screen.dart';
import 'package:tripzo/screens/faculty/request/new_request_screen.dart';
import 'package:tripzo/store/faculty_store.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:provider/provider.dart';
import 'package:tripzo/components/request_card.dart';
import 'package:tripzo/store/request_store.dart';
import '../../providers/notification_provider.dart';
import '../../components/notification_card.dart';
import '../../utils/routes.dart';

/// Admin Dashboard Screen – mirrors the Faculty dashboard but adds admin‑specific statistics.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger stats fetch
    AdminDashboardStore().fetchStats();
    // Trigger profile fetch for name
    if (useFacultyStore.profileData.value == null) {
      useFacultyStore.fetchProfile();
    }
    
    // Fetch requests for the "Active Missions" section
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestStore>().fetchRequests();
    });

    // Listen for remote logouts
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

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background decorative circle
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryBlue.withOpacity(isDark ? 0.1 : 0.05),
              ),
            ),
          ),
          SafeArea(
            bottom: true,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  ValueListenableBuilder(
                    valueListenable: useFacultyStore.profileData,
                    builder: (context, data, _) {
                      return FutureBuilder<String?>(
                        future: UserStore.getName(),
                        builder: (context, snapshot) {
                          final String displayName =
                              data?['name'] ?? snapshot.data ?? "Admin";
                          return _buildHeader(
                            displayName,
                            titleColor,
                            subColor,
                            screenWidth,
                            primaryBlue,
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  _buildSearchBar(isDark, subColor, surfaceColor, primaryBlue),
                  const SizedBox(height: 36),
                  // ==== Graphical Overview ==== //
                  _buildSectionTitle('Live Fleet Status', titleColor),
                  const SizedBox(height: 18),
                  _buildGraphicalOverview(
                    primaryBlue,
                    surfaceColor,
                    isDark,
                    screenWidth,
                  ),
                  const SizedBox(height: 36),
                  _buildSectionTitle('Quick Actions', titleColor),
                  const SizedBox(height: 18),
                  _buildQuickActions(
                    context,
                    primaryBlue,
                    surfaceColor,
                    isDark,
                  ),
                  const SizedBox(height: 36),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('Recent Notifications', titleColor),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
                        child: Text(
                          'See All',
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildNotificationList(primaryBlue, surfaceColor, isDark),
                  const SizedBox(height: 36),
                  _buildSectionTitle('Active Missions', titleColor),
                  const SizedBox(height: 18),
                  _buildActiveMissions(context, primaryBlue, isDark),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header, Search, Sections – copied from the faculty dashboard.
  // ---------------------------------------------------------------------
  Widget _buildHeader(
    String name,
    Color titleColor,
    Color subColor,
    double width,
    Color primary,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: FutureBuilder<String?>(
                  future: UserStore.getRole(),
                  builder: (context, snapshot) {
                    final String role = snapshot.data?.toUpperCase() ?? "ADMIN";
                    return Text(
                      'ROLE: $role',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hello, $name',
                style: TextStyle(
                  fontSize: width * 0.075,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                  letterSpacing: -1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20), // ADDED SPACING
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [primary, primary.withOpacity(0.4)],
            ),
          ),
          child: CircleAvatar(
            radius: width * 0.065,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: width * 0.06,
              backgroundImage: NetworkImage(
                'https://ui-avatars.com/api/?name=$name&background=6366F1&color=fff',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(
    bool isDark,
    Color subColor,
    Color surface,
    Color primary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      height: 60,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: subColor.withOpacity(0.8),
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Track Mission ID...',
                hintStyle: TextStyle(
                  color: subColor.withOpacity(0.5),
                  fontSize: 15,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.tune_rounded, color: primary, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: -0.8,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Graphical Overview
  // ---------------------------------------------------------------------
  Widget _buildGraphicalOverview(
    Color primaryBlue,
    Color surface,
    bool isDark,
    double width,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: AdminDashboardStore().driversPresent,
                builder: (_, present, __) => ValueListenableBuilder<int>(
                  valueListenable: AdminDashboardStore().driversOnLeave,
                  builder: (_, onLeave, ___) {
                    final total = present + onLeave;
                    final double percent = total == 0 ? 0 : present / total;
                    return _buildGraphicalCard(
                      title: 'Drivers Present',
                      currentValue: present.toString(),
                      totalValue: '/ $total',
                      percent: percent,
                      icon: Icons.groups_rounded,
                      color: const Color(0xFF10B981), // Green
                      surface: surface,
                      isDark: isDark,
                      width: width,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: AdminDashboardStore().driversOnLeave,
                builder: (_, onLeave, __) => ValueListenableBuilder<int>(
                  valueListenable: AdminDashboardStore().driversPresent,
                  builder: (_, present, ___) {
                    final total = present + onLeave;
                    final double percent = total == 0 ? 0 : onLeave / total;
                    return _buildGraphicalCard(
                      title: 'Drivers On Leave',
                      currentValue: onLeave.toString(),
                      totalValue: '/ $total',
                      percent: percent,
                      icon: Icons.person_off_rounded,
                      color: const Color(0xFFEF4444), // Red
                      surface: surface,
                      isDark: isDark,
                      width: width,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<int>(
          valueListenable: AdminDashboardStore().movingBuses,
          builder: (_, buses, __) {
            const int totalBuses = 20; // Example total
            final double percent = buses / totalBuses;
            return _buildGraphicalCard(
              title: 'Buses Currently Running',
              currentValue: buses.toString(),
              totalValue: ' Active Fleet',
              percent: percent.clamp(0.0, 1.0),
              icon: Icons.directions_bus_rounded,
              color: const Color(0xFF3B82F6), // Blue
              surface: surface,
              isDark: isDark,
              width: width,
            );
          },
        ),
      ],
    );
  }

  Widget _buildGraphicalCard({
    required String title,
    required String currentValue,
    required String totalValue,
    required double percent,
    required IconData icon,
    required Color color,
    required Color surface,
    required bool isDark,
    required double width,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 24,
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: CircularProgressIndicator(
                      value: percent,
                      strokeWidth: 5,
                      backgroundColor: color.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text(
                    '${(percent * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black,
                    ),
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
              const SizedBox(width: 4),
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

  Widget _buildQuickActions(
    BuildContext context,
    Color primaryBlue,
    Color surface,
    bool isDark,
  ) {
    return Row(
      children: [
        _buildActionBtn(
          'New Req',
          Icons.add_box_rounded,
          primaryBlue,
          surface,
          onTap: () async {
            final refresh = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NewRequestScreen()),
            );
            if (refresh == true) {
              if (mounted) {
                context.read<RequestStore>().fetchRequests();
                AdminDashboardStore().fetchStats();
              }
            }
          },
        ),
        const SizedBox(width: 15),
        _buildActionBtn(
          'Track',
          Icons.gps_fixed_rounded,
          Colors.cyan.shade600,
          surface,
        ),
        const SizedBox(width: 15),
        _buildActionBtn(
          'History',
          Icons.history_rounded,
          Colors.blueGrey,
          surface,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MissionHistoryScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionBtn(
    String label,
    IconData icon,
    Color color,
    Color surface, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: color.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationList(Color primaryBlue, Color surface, bool isDark) {
    final notificationProvider = context.watch<NotificationProvider>();
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
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(Icons.notifications_none_rounded, color: Colors.grey.withOpacity(0.5), size: 40),
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

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return "Just Now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${dt.day}/${dt.month}";
  }

  Widget _buildActiveMissions(BuildContext context, Color primaryBlue, bool isDark) {
    final store = context.watch<RequestStore>();
    
    if (store.isLoading && store.requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (store.requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            "No active missions",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    // Show top 2 pending/recently updated requests
    final activeReqs = store.requests.take(2).toList();

    return Column(
      children: activeReqs.map((req) => RequestCard(
        req: req,
        isDark: isDark,
        accentColor: primaryBlue,
      )).toList(),
    );
  }
}
