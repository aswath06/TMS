import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AssignedFacultyCard extends StatelessWidget {
  final Map<String, dynamic> faculty;
  final String shiftName;
  final IconData icon;
  final Color iconColor;
  final bool isDark;
  final Color cardColor;
  final Color titleColor;
  final Color subColor;
  final VoidCallback? onCall;

  const AssignedFacultyCard({
    super.key,
    required this.faculty,
    required this.shiftName,
    required this.icon,
    required this.iconColor,
    required this.isDark,
    required this.cardColor,
    required this.titleColor,
    required this.subColor,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final String phone = faculty['phone']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: iconColor.withOpacity(0.1),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shiftName,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  faculty['name']?.toString() ?? 'N/A',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phone.isNotEmpty ? phone : 'N/A',
                  style: TextStyle(
                    fontSize: 12,
                    color: subColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (phone.isNotEmpty && phone != 'null' && phone != 'N/A' && onCall != null)
            IconButton(
              onPressed: onCall,
              icon: const Icon(Icons.call_rounded, color: Colors.green, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: Colors.green.withOpacity(0.08),
                padding: const EdgeInsets.all(8),
              ),
            ),
        ],
      ),
    );
  }
}

class AssignmentFacultyMiniCard extends StatelessWidget {
  final Map<String, dynamic> faculty;
  final Color accentColor;
  final Color titleColor;
  final Color subColor;
  final VoidCallback? onCall;

  const AssignmentFacultyMiniCard({
    super.key,
    required this.faculty,
    required this.accentColor,
    required this.titleColor,
    required this.subColor,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final String phone = faculty['phone']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: accentColor.withOpacity(0.1),
            child: Icon(Icons.person_rounded, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  faculty['name']?.toString() ?? 'N/A',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: titleColor),
                ),
                const SizedBox(height: 2),
                Text(
                  phone.isNotEmpty ? phone : 'N/A',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subColor),
                ),
              ],
            ),
          ),
          if (phone.isNotEmpty && phone != 'null' && phone != 'N/A' && onCall != null)
            IconButton(
              onPressed: onCall,
              icon: const Icon(Icons.call_rounded, color: Colors.green, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: Colors.green.withOpacity(0.08),
                padding: const EdgeInsets.all(8),
              ),
            ),
        ],
      ),
    );
  }
}

class ShiftFacultySection extends StatelessWidget {
  final Map<String, dynamic>? faculty;
  final bool isDark;
  final Color primaryColor;
  final Color surfaceColor;
  final Color titleColor;
  final Color subColor;
  final String shiftName;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onCall;

  const ShiftFacultySection({
    super.key,
    this.faculty,
    required this.isDark,
    required this.primaryColor,
    required this.surfaceColor,
    required this.titleColor,
    required this.subColor,
    required this.shiftName,
    required this.icon,
    required this.accentColor,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    if (faculty == null) return const SizedBox.shrink();

    final String name = faculty!['name'] ?? faculty!['user']?['name'] ?? 'N/A';
    final String rawPhone = faculty!['phone']?.toString() ?? faculty!['user']?['phone']?.toString() ?? '';
    final String phone = rawPhone.isNotEmpty ? rawPhone : '9876543210';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                "Assigned Faculty ($shiftName)",
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                child: Icon(Icons.person_rounded, color: titleColor.withOpacity(0.7), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: TextStyle(
                        fontSize: 13,
                        color: subColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (phone.isNotEmpty && phone != 'null' && phone != 'N/A' && onCall != null)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: onCall,
                    icon: const Icon(Icons.call_rounded, color: Colors.green, size: 20),
                    tooltip: 'Call Faculty',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
