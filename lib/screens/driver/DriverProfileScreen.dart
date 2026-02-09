import 'package:flutter/material.dart';
import 'package:tms/components/profile/info_card.dart';
import 'package:tms/components/profile/profile_hero.dart';
import 'package:tms/screens/setting/settings_page.dart';
import 'package:tms/store/istamil.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final bool isTamil = LanguageStore.isTamil;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    _buildHeader(context, titleColor, isTamil),
                    const SizedBox(height: 30),

                    ProfileHero(
                      name: isTamil ? "ராஜேஷ் குமார்" : "Rajesh Kumar",
                      subtitle: isTamil
                          ? "ஓட்டுநர் • பேருந்து எண்: 12"
                          : "Driver • Bus No: 12",
                      cardColor: cardColor,
                      titleColor: titleColor,
                      subColor: subTitleColor,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 32),

                    _buildSectionTitle(
                      isTamil ? "ஓட்டுநர் விவரங்கள்" : "Driver Details",
                      titleColor,
                    ),
                    const SizedBox(height: 16),
                    _buildDriverGrid(
                      cardColor,
                      titleColor,
                      subTitleColor,
                      isTamil,
                    ),

                    const SizedBox(height: 32),

                    _buildSectionTitle(
                      isTamil ? "வருகை மற்றும் விடுப்பு" : "Attendance & Leave",
                      titleColor,
                    ),
                    const SizedBox(height: 16),
                    _buildLeaveGrid(
                      cardColor,
                      titleColor,
                      subTitleColor,
                      isTamil,
                    ),

                    // --- ADDED PADDING HERE ---
                    // This creates extra space so the bottom bar doesn't cover the content
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

  // --- GRID BUILDERS ---
  Widget _buildDriverGrid(
    Color cardColor,
    Color titleColor,
    Color subColor,
    bool isTamil,
  ) {
    final List<Map<String, dynamic>> items = [
      {
        'title': isTamil ? 'பணியாளர் ஐடி' : 'Employee ID',
        'val': 'DRV-2024-045',
        'icon': Icons.badge_rounded,
        'color': Colors.indigo,
      },
      {
        'title': isTamil ? 'உரிம எண்' : 'License No.',
        'val': 'TN-37-20150004',
        'icon': Icons.shutter_speed_rounded,
        'color': Colors.amber.shade700,
      },
      {
        'title': isTamil ? 'அனுபவம்' : 'Experience',
        'val': isTamil ? '12 ஆண்டுகள்' : '12 Years',
        'icon': Icons.timeline_rounded,
        'color': Colors.green,
      },
      {
        'title': isTamil ? 'தொலைபேசி' : 'Contact Info',
        'val': '+91 98765 43210',
        'icon': Icons.phone_android_rounded,
        'color': Colors.blue,
      },
    ];
    return _renderGrid(items, cardColor, titleColor, subColor);
  }

  Widget _buildLeaveGrid(
    Color cardColor,
    Color titleColor,
    Color subColor,
    bool isTamil,
  ) {
    final List<Map<String, dynamic>> items = [
      {
        'title': isTamil ? 'வருகை சதவீதம்' : 'Attendance',
        'val': '94%',
        'icon': Icons.pie_chart_rounded,
        'color': Colors.teal,
      },
      {
        'title': isTamil ? 'வேலை நாட்கள்' : 'Total Days',
        'val': '240',
        'icon': Icons.calendar_month_rounded,
        'color': Colors.purple,
      },
      {
        'title': isTamil ? 'வருகை தந்தவை' : 'Days Present',
        'val': '226',
        'icon': Icons.check_circle_outline_rounded,
        'color': Colors.green,
      },
      {
        'title': isTamil ? 'விடுப்பு நாட்கள்' : 'Days Absent',
        'val': '14',
        'icon': Icons.cancel_outlined,
        'color': Colors.redAccent,
      },
    ];
    return _renderGrid(items, cardColor, titleColor, subColor);
  }

  Widget _renderGrid(
    List<Map<String, dynamic>> items,
    Color cardColor,
    Color titleColor,
    Color subColor,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => InfoCard(
        title: items[i]['title'],
        value: items[i]['val'],
        icon: items[i]['icon'],
        iconColor: items[i]['color'],
        cardColor: cardColor,
        titleColor: titleColor,
        subColor: subColor,
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildHeader(BuildContext context, Color titleColor, bool isTamil) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          isTamil ? "ஓட்டுநர் விவரம்" : "Driver Profile",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        IconButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
            if (mounted) setState(() {});
          },
          icon: Icon(
            Icons.settings_outlined,
            color: titleColor.withOpacity(0.6),
            size: 26,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
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
