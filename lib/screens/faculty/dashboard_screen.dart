import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/screens/faculty/request/new_request_screen.dart';
import 'package:tripzo/store/faculty_store.dart';
import 'package:tripzo/store/request_store.dart';
import 'package:tripzo/store/dashboard_store.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/screens/faculty/missions/mission_history_screen.dart';
import 'package:tripzo/components/request_card.dart';
import '../../providers/notification_provider.dart';
import '../../components/notification_card.dart';
import '../../components/notification_bell.dart';
import '../../utils/routes.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(requestStoreProvider).fetchRequests();
      dashboardStore.fetchStats();
      if (useFacultyStore.profileData.value == null) {
        useFacultyStore.fetchProfile();
      }
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
    final store = ref.watch(requestStoreProvider);

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
                color: primaryBlue.withValues(alpha: isDark ? 0.1 : 0.05),
              ),
            ),
          ),

          SafeArea(
            bottom: true,
            child: RefreshIndicator(
              onRefresh: () async {
                await store.fetchRequests();
                await dashboardStore.fetchStats();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
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
                            final String displayName = data?['name'] ?? snapshot.data ?? "Faculty";
                            return _buildHeader(
                              displayName,
                              titleColor,
                              subColor,
                              screenWidth,
                              primaryBlue,
                            );
                          },
                        );
                      }
                    ),
                    const SizedBox(height: 32),

                    _buildSearchBar(
                      isDark,
                      subColor,
                      surfaceColor,
                      primaryBlue,
                    ),
                    const SizedBox(height: 36),

                    _buildSectionTitle("Operational Overview", titleColor),
                    const SizedBox(height: 18),
                    
                    // Stats section with Zustand listener
                    _buildStatusCards(
                      ref.watch(dashboardStoreProvider).state,
                      primaryBlue,
                      surfaceColor,
                      isDark,
                      screenWidth,
                    ),
                    
                    const SizedBox(height: 36),

                    _buildSectionTitle("Quick Actions", titleColor),
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
                    _buildNotificationList(primaryBlue, surfaceColor, isDark),
                    const SizedBox(height: 36),
                    _buildSectionTitle("Active Missions", titleColor),
                    const SizedBox(height: 18),
                    _buildActiveMissions(context, primaryBlue, isDark),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "ROLE: Faculty",
                  style: TextStyle(
                    fontSize: 10,
                    color: primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Hello, $name",
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
        NotificationBell(iconColor: titleColor),
        const SizedBox(width: 8),
        Container(
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
                "https://ui-avatars.com/api/?name=$name&background=6366F1&color=fff",
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
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: subColor.withValues(alpha: 0.8),
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Track Mission ID...",
                hintStyle: TextStyle(
                  color: subColor.withValues(alpha: 0.5),
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

  Widget _buildStatusCards(
    DashboardState stats,
    Color primaryBlue,
    Color surface,
    bool isDark,
    double width,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildSummaryCard(
            "Active Now",
            "${stats.activeRoutes.toString().padLeft(2, '0')} Routes",
            "In Progress",
            Icons.map_rounded,
            primaryBlue,
            surface,
            isDark,
            width,
          ),
          _buildSummaryCard(
            "Pending",
            "${stats.pendingRoutes.toString().padLeft(2, '0')} Req",
            "Awaiting Approval",
            Icons.watch_later_rounded,
            Colors.orangeAccent,
            surface,
            isDark,
            width,
          ),
          _buildSummaryCard(
            "Total",
            "${stats.totalRoutes} Req",
            "Assigned Routes",
            Icons.bar_chart_rounded,
            Colors.teal.shade400,
            surface,
            isDark,
            width,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    String sub,
    IconData icon,
    Color accent,
    Color surface,
    bool isDark,
    double width,
  ) {
    return Container(
      width: width * 0.44,
      margin: const EdgeInsets.only(right: 18, bottom: 10),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: width * 0.052,
              letterSpacing: -0.8,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
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
          "New Req",
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
                ref.read(requestStoreProvider).fetchRequests();
                dashboardStore.fetchStats();
              }
            }
          },
        ),
        const SizedBox(width: 15),
        _buildActionBtn(
          "Track",
          Icons.gps_fixed_rounded,
          Colors.cyan.shade600,
          surface,
        ),
        const SizedBox(width: 15),
        _buildActionBtn(
          "History",
          Icons.history_rounded,
          Colors.blueGrey,
          surface,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MissionHistoryScreen()),
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
            border: Border.all(color: color.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
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

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return "Just Now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${dt.day}/${dt.month}";
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

  Widget _buildActiveMissions(BuildContext context, Color primaryBlue, bool isDark) {
    final store = ref.watch(requestStoreProvider);
    
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

    // Show top 2 active missions (same as requested earlier "for the fcauly 2")
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
