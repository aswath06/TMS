import 'package:flutter/material.dart';
import 'package:tms/screens/faculty/request/new_request_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
            // bottom: true ensures it respects the system nav bar
            bottom: true,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  _buildHeader(
                    "Aswath",
                    titleColor,
                    subColor,
                    screenWidth,
                    primaryBlue,
                  ),
                  const SizedBox(height: 32),

                  _buildSearchBar(isDark, subColor, surfaceColor, primaryBlue),
                  const SizedBox(height: 36),

                  _buildSectionTitle("Operational Overview", titleColor),
                  const SizedBox(height: 18),
                  _buildStatusCards(
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
                        onPressed: () {},
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

                  // ADDED: Significant bottom gap to ensure the last item
                  // isn't flush against the screen edge.
                  const SizedBox(height: 100),
                ],
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
                  color: primary.withOpacity(0.1),
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
                hintText: "Track Mission ID...",
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

  Widget _buildStatusCards(
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
            "TR-2041",
            "En-route",
            Icons.map_rounded,
            primaryBlue,
            surface,
            isDark,
            width,
          ),
          _buildSummaryCard(
            "Pending",
            "02 Req",
            "Admin Review",
            Icons.watch_later_rounded,
            Colors.orangeAccent,
            surface,
            isDark,
            width,
          ),
          _buildSummaryCard(
            "History",
            "148 km",
            "This week",
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
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
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
              color: accent.withOpacity(0.12),
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NewRequestScreen()),
            );
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
    return Column(
      children: [
        _buildNotifyItem(
          "Mission Started",
          "Driver Assigned for TR-2041.",
          "Just Now",
          Icons.auto_awesome_rounded,
          primaryBlue,
          surface,
        ),
        _buildNotifyItem(
          "Approved",
          "Your recurring shuttle is live.",
          "2h ago",
          Icons.check_circle_rounded,
          Colors.green.shade400,
          surface,
        ),
        _buildNotifyItem(
          "Update",
          "Route TR-2041 schedule modified.",
          "5h ago",
          Icons.info_outline_rounded,
          Colors.orange,
          surface,
        ),
      ],
    );
  }

  Widget _buildNotifyItem(
    String title,
    String body,
    String time,
    IconData icon,
    Color color,
    Color surface,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: color.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
}
