import 'package:flutter/material.dart';

class MissionHistoryScreen extends StatefulWidget {
  const MissionHistoryScreen({super.key});

  @override
  State<MissionHistoryScreen> createState() => _MissionHistoryScreenState();
}

class _MissionHistoryScreenState extends State<MissionHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: _buildHeader(context, titleColor),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildSummaryCard(
                            cardColor,
                            titleColor,
                            subColor,
                            primaryBlue,
                          ),
                          const SizedBox(height: 24),
                          _buildSearchField(isDark, subColor, cardColor),
                          const SizedBox(height: 32),
                          _buildSectionTitle(
                            "Monthly Archives",
                            primaryBlue,
                            titleColor,
                          ),
                          const SizedBox(height: 16),
                          _buildHistoryDateBucket("February 2026", subColor),
                          _buildHistoryCard(
                            title: "VIP Delegation Pickup",
                            date: "Feb 05",
                            driver: "Mark Spencer",
                            pathType: "One-Way",
                            stops: 2,
                            distance: "12.4 km",
                            cardColor: cardColor,
                            titleColor: titleColor,
                            subColor: subColor,
                            primaryBlue: primaryBlue,
                          ),
                          _buildHistoryCard(
                            title: "Faculty Seminar Shuttle",
                            date: "Feb 04",
                            driver: "Sarah Jenkins",
                            pathType: "Multi-Path",
                            stops: 5,
                            distance: "42.0 km",
                            cardColor: cardColor,
                            titleColor: titleColor,
                            subColor: subColor,
                            primaryBlue: primaryBlue,
                          ),
                          _buildHistoryDateBucket("January 2026", subColor),
                          _buildHistoryCard(
                            title: "Campus to Airport",
                            date: "Jan 28",
                            driver: "John Doe",
                            pathType: "Two-Way",
                            stops: 3,
                            distance: "28.5 km",
                            cardColor: cardColor,
                            titleColor: titleColor,
                            subColor: subColor,
                            primaryBlue: primaryBlue,
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color titleColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: titleColor,
            size: 22,
          ),
        ),
        Text(
          "Mission History",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.tune_rounded, color: titleColor.withOpacity(0.6)),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    Color cardColor,
    Color title,
    Color sub,
    Color blue,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("24", "Missions", blue, title),
          _buildStatItem("156", "Stops", blue, title),
          _buildStatItem("1.2k", "Kms", blue, title),
        ],
      ),
    );
  }

  Widget _buildStatItem(String val, String label, Color blue, Color title) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: title,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: blue,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(bool isDark, Color subColor, Color cardColor) {
    return TextField(
      controller: _searchController,
      onChanged: (val) => setState(() => _searchQuery = val),
      decoration: InputDecoration(
        hintText: "Search by mission or driver...",
        hintStyle: TextStyle(color: subColor.withOpacity(0.5), fontSize: 14),
        prefixIcon: Icon(Icons.search_rounded, color: subColor, size: 20),
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color accent, Color titleColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryDateBucket(String month, Color sub) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 16),
      child: Text(
        month.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: sub,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildHistoryCard({
    required String title,
    required String date,
    required String driver,
    required String pathType,
    required int stops,
    required String distance,
    required Color cardColor,
    required Color titleColor,
    required Color subColor,
    required Color primaryBlue,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: TextStyle(
                  color: subColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              _buildPathBadge(pathType, primaryBlue),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 14, color: subColor),
              const SizedBox(width: 6),
              Text(
                driver,
                style: TextStyle(
                  color: subColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                "$stops stops • $distance",
                style: TextStyle(
                  color: subColor.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPathBadge(String type, Color blue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: blue),
      ),
    );
  }

  Widget _buildBackgroundDecor(bool isDark) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: CircleAvatar(
              radius: 140,
              backgroundColor: const Color(
                0xFF6366F1,
              ).withOpacity(isDark ? 0.06 : 0.04),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: const Color(
                0xFFA855F7,
              ).withOpacity(isDark ? 0.04 : 0.02),
            ),
          ),
        ],
      ),
    );
  }
}
