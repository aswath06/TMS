import 'package:flutter/material.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Media Query for responsiveness
    final Size size = MediaQuery.of(context).size;
    final double horizontalPadding = size.width * 0.06;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme Colors
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color primaryIndigo = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Visual decorative elements
          _buildBackgroundDecor(isDark, size),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ADAPTIVE HEADER ---
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    20,
                    horizontalPadding,
                    10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              "Requests",
                              style: TextStyle(
                                fontSize: size.width > 400 ? 32 : 28,
                                fontWeight: FontWeight.w900,
                                color: titleColor,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          _buildQuickStatBadge("2 Active", primaryIndigo),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Manage your active transport requests",
                        style: TextStyle(
                          color: subColor,
                          fontSize: size.width > 400 ? 15 : 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 20,
                    ),
                    children: [
                      _buildSectionTitle(
                        "In Progress",
                        primaryIndigo,
                        titleColor,
                      ),
                      const SizedBox(height: 16),
                      _buildRequestCard(
                        context,
                        id: "TR-8821",
                        type: "Official Visit",
                        status: "Pending",
                        statusColor: Colors.orange,
                        date: "Feb 05, 2026",
                        cardColor: cardColor,
                        titleColor: titleColor,
                        subColor: subColor,
                        accent: primaryIndigo,
                        screenWidth: size.width,
                      ),

                      const SizedBox(height: 32),

                      _buildSectionTitle(
                        "Requires Attention",
                        Colors.redAccent,
                        titleColor,
                      ),
                      const SizedBox(height: 16),
                      _buildRequestCard(
                        context,
                        id: "TR-6610",
                        type: "Field Trip",
                        status: "Clarification",
                        statusColor: Colors.red,
                        date: "Feb 03, 2026",
                        cardColor: cardColor,
                        titleColor: titleColor,
                        subColor: subColor,
                        accent: primaryIndigo,
                        screenWidth: size.width,
                      ),

                      // Padding to ensure content isn't hidden by Bottom Bar & FAB
                      SizedBox(height: size.height * 0.2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // --- ACTION BUTTON (MOVED TO BOTTOM RIGHT) ---
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Container(
        // Margin adjusted to sit perfectly above your 72px high CustomBottomBar
        margin: const EdgeInsets.only(bottom: 90, right: 8),
        child: FloatingActionButton.extended(
          onPressed: () {},
          elevation: 6,
          backgroundColor: primaryIndigo,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          label: const Text(
            "NEW",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              fontSize: 13,
            ),
          ),
          // Using a slightly more circular shape for the corner aesthetic
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildSectionTitle(String title, Color accent, Color titleColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatBadge(String text, Color blue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: blue,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildRequestCard(
    BuildContext context, {
    required String id,
    required String type,
    required String status,
    required Color statusColor,
    required String date,
    required Color cardColor,
    required Color titleColor,
    required Color subColor,
    required Color accent,
    required double screenWidth,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: () {},
          child: Padding(
            padding: EdgeInsets.all(screenWidth > 400 ? 24 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      id,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: accent,
                        fontSize: 14,
                      ),
                    ),
                    _buildStatusBadge(status, statusColor),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  type,
                  style: TextStyle(
                    fontSize: screenWidth > 400 ? 20 : 18,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: subColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: TextStyle(
                        color: subColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(height: 1, thickness: 0.5),
                ),
                Row(
                  children: [
                    Icon(Icons.edit_note_rounded, size: 20, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      "Tap to modify request",
                      style: TextStyle(
                        fontSize: screenWidth > 400 ? 13 : 12,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: subColor.withOpacity(0.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildBackgroundDecor(bool isDark, Size size) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -size.height * 0.08,
            right: -size.width * 0.15,
            child: CircleAvatar(
              radius: size.width * 0.35,
              backgroundColor: const Color(
                0xFF6366F1,
              ).withOpacity(isDark ? 0.06 : 0.04),
            ),
          ),
          Positioned(
            bottom: size.height * 0.1,
            left: -size.width * 0.1,
            child: CircleAvatar(
              radius: size.width * 0.2,
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
