import 'package:flutter/material.dart';
import 'package:tms/components/profile/info_card.dart';
import 'package:tms/components/profile/profile_hero.dart';
import 'package:tms/screens/settings_page.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                    _buildHeader(context, titleColor),
                    const SizedBox(height: 30),
                    ProfileHero(
                      name: "Dr. Sarah Jenkins",
                      subtitle: "Senior Professor • Dept. of CSE",
                      cardColor: cardColor,
                      titleColor: titleColor,
                      subColor: subTitleColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 32),
                    _buildSectionTitle("Faculty Details", titleColor),
                    const SizedBox(height: 16),
                    _buildMenuGrid(cardColor, titleColor, subTitleColor),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGrid(Color cardColor, Color titleColor, Color subColor) {
    final List<Map<String, dynamic>> items = [
      {
        'title': 'Employee ID',
        'val': 'FAC-2024-082',
        'icon': Icons.badge_rounded,
        'color': Colors.indigo,
      },
      {
        'title': 'Designation',
        'val': 'Associate Head',
        'icon': Icons.work_outline_rounded,
        'color': Colors.amber.shade700,
      },
      {
        'title': 'Office Ext.',
        'val': '+91 422 1234',
        'icon': Icons.phone_in_talk_rounded,
        'color': Colors.green,
      },
      {
        'title': 'Official Email',
        'val': 's.jenkins@bits.edu',
        'icon': Icons.alternate_email_rounded,
        'color': Colors.blue,
      },
    ];

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

  Widget _buildHeader(BuildContext context, Color titleColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Faculty Profile",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          ),
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
