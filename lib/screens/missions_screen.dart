import 'package:flutter/material.dart';

class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dynamic theme colors
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF4F46E5);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor:
          Colors.transparent, // Inherits background from MainScreen
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. HEADER (Operational Awareness) ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.explore_rounded, color: primaryBlue, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        "Missions",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Real-time visibility of scheduled legs",
                    style: TextStyle(
                      color: subColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // --- 2. MISSIONS LIST (FR-3.4 Date Buckets) ---
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                children: [
                  _buildDateBucket("Today • Feb 06", primaryBlue),
                  _buildMissionCard(
                    context,
                    cardColor: cardColor,
                    titleColor: titleColor,
                    subColor: subColor,
                    missionTitle: "Airport Reception",
                    time: "09:00 AM",
                    driverName: "John Doe",
                    vehicleInfo: "White Innova (TN-01-AV-1234)",
                    stops: [
                      "Main Campus (Pickup)",
                      "Terminal 2",
                      "Faculty Guest House (Drop)",
                    ],
                    status: "Active",
                    statusColor: Colors.blue,
                    primaryBlue: primaryBlue,
                  ),

                  const SizedBox(height: 28),

                  _buildDateBucket("Monday • Feb 10", primaryBlue),
                  _buildMissionCard(
                    context,
                    cardColor: cardColor,
                    titleColor: titleColor,
                    subColor: subColor,
                    missionTitle: "Conference Shuttle",
                    time: "07:30 AM",
                    driverName: "Robert Smith",
                    vehicleInfo: "SML Bus (TN-01-BQ-5678)",
                    stops: [
                      "Housing Block A",
                      "Admin Square",
                      "Convention Center",
                    ],
                    status: "Scheduled",
                    statusColor: Colors.green,
                    primaryBlue: primaryBlue,
                  ),

                  // Bottom spacing for CustomBottomBar clearance
                  const SizedBox(height: 110),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for FR-3.4: Date bucket grouping
  Widget _buildDateBucket(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(thickness: 1.2)),
        ],
      ),
    );
  }

  // Helper for FR-3.7: Journey Visualization (One Card -> Many Legs)
  Widget _buildMissionCard(
    BuildContext context, {
    required Color cardColor,
    required Color titleColor,
    required Color subColor,
    required String missionTitle,
    required String time,
    required String driverName,
    required String vehicleInfo,
    required List<String> stops,
    required String status,
    required Color statusColor,
    required Color primaryBlue,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Time and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 18, color: primaryBlue),
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
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
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
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
          const SizedBox(height: 12),
          Text(
            missionTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),

          // Resource Section (Vehicle/Driver Aware)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryBlue.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: primaryBlue,
                  child: const Icon(
                    Icons.person,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        vehicleInfo,
                        style: TextStyle(fontSize: 12, color: subColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Timeline Stop Sequence (FR-3.7 Journey Visualization)
          const Text(
            "ORDERED STOP SEQUENCE",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.grey,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ...stops.asMap().entries.map((entry) {
            int idx = entry.key;
            String stop = entry.value;
            bool isLast = idx == stops.length - 1;

            return IntrinsicHeight(
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: idx == 0 ? primaryBlue : Colors.transparent,
                          border: Border.all(
                            color: idx == 0
                                ? primaryBlue
                                : Colors.grey.shade400,
                            width: 2.5,
                          ),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: Colors.grey.shade300,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                      child: Text(
                        stop,
                        style: TextStyle(
                          fontSize: 14,
                          color: idx == 0 ? titleColor : subColor,
                          fontWeight: idx == 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
