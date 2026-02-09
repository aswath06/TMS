import 'package:flutter/material.dart';
import 'package:tms/store/istamil.dart'; // Ensure this path is correct

class DriverDutiesScreen extends StatelessWidget {
  const DriverDutiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isTamil = LanguageStore.isTamil;
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
          // Decorative Background Circle
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

                  // 1. HEADER
                  _buildHeader(
                    isTamil ? "அருண்" : "Arun",
                    titleColor,
                    subColor,
                    screenWidth,
                    primaryBlue,
                    isTamil,
                  ),
                  const SizedBox(height: 32),

                  // 2. SEARCH BAR
                  _buildSearchBar(
                    isDark,
                    subColor,
                    surfaceColor,
                    primaryBlue,
                    isTamil,
                  ),
                  const SizedBox(height: 32),

                  // 3. STATS SECTION
                  _buildStatCards(primaryBlue, surfaceColor, isDark, isTamil),
                  const SizedBox(height: 36),

                  // 4. TODAY'S ASSIGNMENTS
                  _buildSectionTitle(
                    isTamil ? "இன்றைய பணிகள்" : "Today's Assignments",
                    titleColor,
                  ),
                  const SizedBox(height: 18),
                  _buildDutyCard(
                    context: context,
                    id: "MSN-8821",
                    pickup: isTamil ? "முதன்மை முனையம்" : "Main Terminal",
                    drop: isTamil ? "பேராசிரியர் பிளாக் B" : "Faculty Block B",
                    time: "09:00 AM",
                    vehicle: "BUS-04",
                    status: isTamil ? "செயலில் உள்ளது" : "Active",
                    statusColor: Colors.orangeAccent,
                    surface: surfaceColor,
                    primary: primaryBlue,
                    isDark: isDark,
                    isTamil: isTamil,
                  ),

                  const SizedBox(height: 36),

                  // 5. UPCOMING ASSIGNMENTS
                  _buildSectionTitle(
                    isTamil ? "வரவிருப்பவை" : "Upcoming",
                    titleColor,
                  ),
                  const SizedBox(height: 18),
                  _buildDutyCard(
                    context: context,
                    id: "MSN-8825",
                    pickup: isTamil ? "மாணவர் விடுதி" : "Student Housing",
                    drop: isTamil ? "விளையாட்டு வளாகம்" : "Sports Complex",
                    time: "02:30 PM",
                    vehicle: "VAN-02",
                    status: isTamil ? "வரவிருக்கிறது" : "Upcoming",
                    statusColor: Colors.blueAccent,
                    surface: surfaceColor,
                    primary: primaryBlue,
                    isDark: isDark,
                    isTamil: isTamil,
                  ),
                  _buildDutyCard(
                    context: context,
                    id: "MSN-8790",
                    pickup: isTamil ? "நுழைவாயில் 1" : "Gate 1",
                    drop: isTamil ? "நிர்வாக அலுவலகம்" : "Admin Office",
                    time: "04:00 PM",
                    vehicle: "BUS-04",
                    status: isTamil ? "முடிந்தது" : "Completed",
                    statusColor: Colors.teal.shade400,
                    surface: surfaceColor,
                    primary: primaryBlue,
                    isDark: isDark,
                    isTamil: isTamil,
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(
    Color primary,
    Color surface,
    bool isDark,
    bool isTamil,
  ) {
    return Row(
      children: [
        _statItem(
          label: isTamil ? "நிலுவையில்" : "Pending",
          value: "03",
          icon: Icons.assignment_late_rounded,
          accentColor: Colors.orangeAccent,
          surface: surface,
          isDark: isDark,
        ),
        const SizedBox(width: 16),
        _statItem(
          label: isTamil ? "வருகை" : "Attendance",
          value: "98%",
          icon: Icons.verified_user_rounded,
          accentColor: Colors.tealAccent.shade700,
          surface: surface,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _statItem({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color surface,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    String name,
    Color titleColor,
    Color subColor,
    double width,
    Color primary,
    bool isTamil,
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
                  isTamil ? "நிலை: பணியில்" : "STATUS: On-Duty",
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
                isTamil ? "வணக்கம், $name" : "Hello, $name",
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
        CircleAvatar(
          radius: width * 0.065,
          backgroundColor: primary,
          child: CircleAvatar(
            radius: width * 0.06,
            backgroundImage: const NetworkImage(
              "https://ui-avatars.com/api/?name=Driver&background=6366F1&color=fff",
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
    bool isTamil,
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
                hintText: isTamil
                    ? "பணிகளைத் தேடுங்கள்..."
                    : "Search Missions...",
                hintStyle: TextStyle(
                  color: subColor.withOpacity(0.5),
                  fontSize: 15,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          Icon(Icons.tune_rounded, color: primary, size: 20),
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
    required bool isTamil,
  }) {
    // Logic check for active status in either language
    bool isActive = status == "Active" || status == "செயலில் உள்ளது";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
        ),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  isTamil ? "பணி தொடங்கப்பட்டது..." : "MISSION STARTED...",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1,
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
