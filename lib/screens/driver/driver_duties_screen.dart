import 'package:flutter/material.dart';

class DriverDutiesScreen extends StatelessWidget {
  const DriverDutiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Consistency Colors
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
          // Decorative Background Circle (Top Right)
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // 1. HEADER (Same as Dashboard but with Driver Status)
                  _buildHeader(
                    "Arun", // Pass driver name here
                    titleColor,
                    subColor,
                    screenWidth,
                    primaryBlue,
                  ),
                  const SizedBox(height: 32),

                  // 2. SEARCH BAR (Same as Dashboard)
                  _buildSearchBar(isDark, subColor, surfaceColor, primaryBlue),
                  const SizedBox(height: 36),

                  // 3. TODAY'S ASSIGNMENTS
                  _buildSectionTitle("Today's Assignments", titleColor),
                  const SizedBox(height: 18),
                  _buildDutyCard(
                    context: context,
                    id: "MSN-8821",
                    pickup: "Main Terminal",
                    drop: "Faculty Block B",
                    time: "09:00 AM",
                    vehicle: "BUS-04",
                    status: "Active",
                    statusColor: Colors.orangeAccent,
                    surface: surfaceColor,
                    primary: primaryBlue,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 36),

                  // 4. UPCOMING ASSIGNMENTS
                  _buildSectionTitle("Upcoming", titleColor),
                  const SizedBox(height: 18),
                  _buildDutyCard(
                    context: context,
                    id: "MSN-8825",
                    pickup: "Student Housing",
                    drop: "Sports Complex",
                    time: "02:30 PM",
                    vehicle: "VAN-02",
                    status: "Upcoming",
                    statusColor: Colors.blueAccent,
                    surface: surfaceColor,
                    primary: primaryBlue,
                    isDark: isDark,
                  ),
                  _buildDutyCard(
                    context: context,
                    id: "MSN-8790",
                    pickup: "Gate 1",
                    drop: "Admin Office",
                    time: "04:00 PM",
                    vehicle: "BUS-04",
                    status: "Completed",
                    statusColor: Colors.teal.shade400,
                    surface: surfaceColor,
                    primary: primaryBlue,
                    isDark: isDark,
                  ),

                  const SizedBox(
                    height: 100,
                  ), // Extra space for Bottom Navigation Bar
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Components ---

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
                  "STATUS: On-Duty",
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
              backgroundImage: const NetworkImage(
                "https://ui-avatars.com/api/?name=Driver&background=6366F1&color=fff",
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
                hintText: "Search Missions...",
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

  Widget _buildDutyCard({
    required BuildContext context,
    required String id,
    required String pickup,
    required String drop,
    required String time,
    required String vehicle,
    required String status,
    required Color statusColor,
    required Color surface,
    required Color primary,
    required bool isDark,
  }) {
    bool isActive = status == "Active";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
        ),
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
              Text(
                id,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Column(
                children: [
                  Icon(Icons.radio_button_checked, color: primary, size: 18),
                  Container(
                    width: 2,
                    height: 20,
                    color: primary.withOpacity(0.2),
                  ),
                  Icon(
                    Icons.location_on,
                    color: Colors.redAccent.withOpacity(0.7),
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickup,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      drop,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _iconInfo(Icons.access_time_filled_rounded, time, isDark),
              _iconInfo(Icons.local_shipping_rounded, vehicle, isDark),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                // Action for starting mission
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    "START MISSION",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconInfo(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.white38 : Colors.black26),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }
}
