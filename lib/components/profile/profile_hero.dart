import 'package:flutter/material.dart';

class ProfileHero extends StatelessWidget {
  final String name;
  final String subtitle;
  final Color cardColor;
  final Color titleColor;
  final Color subColor;
  final bool isDark;

  const ProfileHero({
    super.key,
    required this.name,
    required this.subtitle,
    required this.cardColor,
    required this.titleColor,
    required this.subColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAvatar(),
          const SizedBox(height: 20),
          Text(
            name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: subColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
        ),
      ),
      child: CircleAvatar(
        radius: 50,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: const Icon(
          Icons.person_rounded,
          size: 55,
          color: Color(0xFF6366F1),
        ),
      ),
    );
  }
}
