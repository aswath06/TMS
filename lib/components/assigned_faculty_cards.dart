import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StaffRoleHelper {
  static String getRoleName(Map<String, dynamic>? faculty) {
    if (faculty == null) return 'Faculty';
    if (faculty['user_id'] == -1 || faculty['id'] == -1) return 'Admin Handover';

    dynamic role = faculty['role'] ??
        faculty['role_name'] ??
        faculty['user_role'] ??
        faculty['user']?['role'] ??
        faculty['user']?['role_name'] ??
        faculty['type'];

    String roleStr = '';
    if (role is Map) {
      roleStr = (role['name'] ?? role['code'] ?? role['title'] ?? '').toString();
    } else if (role != null) {
      roleStr = role.toString();
    }

    if (roleStr.isEmpty) {
      final des = faculty['designation']?.toString().trim();
      if (des != null && des.isNotEmpty && des != 'null' && des != 'N/A') {
        roleStr = des;
      }
    }

    if (roleStr.isEmpty) {
      if (faculty.containsKey('intern') || faculty['is_intern'] == true) {
        roleStr = 'Intern';
      } else if (faculty.containsKey('nonTeachingStaff') ||
          faculty.containsKey('non_teaching_staff') ||
          faculty.containsKey('nonTeaching') ||
          faculty.containsKey('non_teaching') ||
          faculty['is_non_teaching'] == true) {
        roleStr = 'Non-Teaching';
      } else {
        roleStr = 'Faculty';
      }
    }

    final lower = roleStr.toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (lower.contains('non teaching') || lower.contains('nonteaching') || lower.contains('staff')) {
      return 'Non-Teaching';
    } else if (lower.contains('intern')) {
      return 'Intern';
    } else if (lower.contains('admin')) {
      return 'Admin';
    } else if (lower.contains('student')) {
      return 'Student';
    } else if (lower.contains('faculty') || lower.contains('teaching') || lower.contains('prof')) {
      return 'Faculty';
    } else if (roleStr.isNotEmpty && roleStr != 'null') {
      return roleStr[0].toUpperCase() + roleStr.substring(1);
    }
    return 'Faculty';
  }

  static Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'intern':
        return Colors.teal;
      case 'non-teaching':
      case 'non teaching':
      case 'staff':
        return const Color(0xFF0284C7);
      case 'admin':
      case 'admin handover':
      case 'transport admin':
        return Colors.amber.shade800;
      case 'faculty':
      default:
        return const Color(0xFF7C3AED);
    }
  }

  static IconData getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'intern':
        return Icons.assignment_ind_rounded;
      case 'non-teaching':
      case 'non teaching':
      case 'staff':
        return Icons.badge_rounded;
      case 'admin':
      case 'admin handover':
      case 'transport admin':
        return Icons.admin_panel_settings_rounded;
      case 'faculty':
      default:
        return Icons.school_rounded;
    }
  }

  static Widget buildRoleBadge(String role, {double fontSize = 10, EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2)}) {
    final color = getRoleColor(role);
    final icon = getRoleIcon(role);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.24), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 1, color: color),
          const SizedBox(width: 4),
          Text(
            role,
            style: GoogleFonts.outfit(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

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
    final String rawPhone = faculty['phone']?.toString() ??
        faculty['user']?['phone']?.toString() ??
        faculty['mobile']?.toString() ??
        faculty['role_details']?['phone_number']?.toString() ??
        '';
    final String phone = rawPhone.isNotEmpty && rawPhone != 'null' ? rawPhone : '';
    final String name = faculty['name']?.toString() ?? faculty['user']?['name']?.toString() ?? 'N/A';
    final String role = StaffRoleHelper.getRoleName(faculty);
    final String dept = faculty['department']?.toString() ??
        faculty['dept']?.toString() ??
        faculty['user']?['department']?.toString() ??
        '';
    final String designation = faculty['designation']?.toString() ??
        faculty['user']?['designation']?.toString() ??
        '';

    String subInfo = '';
    if (designation.isNotEmpty && designation != 'null' && designation != 'N/A') {
      subInfo = designation;
      if (dept.isNotEmpty && dept != 'null' && dept != 'N/A') {
        subInfo = "$subInfo • $dept";
      }
    } else if (dept.isNotEmpty && dept != 'null' && dept != 'N/A') {
      subInfo = dept;
    }

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
        crossAxisAlignment: CrossAxisAlignment.center,
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
                Row(
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
                    const SizedBox(width: 8),
                    StaffRoleHelper.buildRoleBadge(role),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
                if (subInfo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subInfo,
                    style: TextStyle(
                      fontSize: 11,
                      color: subColor.withOpacity(0.85),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 12, color: subColor),
                    const SizedBox(width: 4),
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
    final String rawPhone = faculty['phone']?.toString() ??
        faculty['user']?['phone']?.toString() ??
        faculty['mobile']?.toString() ??
        faculty['role_details']?['phone_number']?.toString() ??
        '';
    final String phone = rawPhone.isNotEmpty && rawPhone != 'null' ? rawPhone : '';
    final String name = faculty['name']?.toString() ?? faculty['user']?['name']?.toString() ?? 'N/A';
    final String role = StaffRoleHelper.getRoleName(faculty);
    final String dept = faculty['department']?.toString() ??
        faculty['dept']?.toString() ??
        faculty['user']?['department']?.toString() ??
        '';

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
            backgroundColor: StaffRoleHelper.getRoleColor(role).withOpacity(0.12),
            child: Icon(StaffRoleHelper.getRoleIcon(role), color: StaffRoleHelper.getRoleColor(role), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: titleColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    StaffRoleHelper.buildRoleBadge(role, fontSize: 9, padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (dept.isNotEmpty && dept != 'null' && dept != 'N/A') ...[
                      Flexible(
                        child: Text(
                          dept,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subColor.withOpacity(0.85)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(" • ", style: TextStyle(fontSize: 11, color: subColor)),
                    ],
                    Text(
                      phone.isNotEmpty ? phone : 'N/A',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subColor),
                    ),
                  ],
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
    final String rawPhone = faculty!['phone']?.toString() ??
        faculty!['user']?['phone']?.toString() ??
        faculty!['mobile']?.toString() ??
        faculty!['role_details']?['phone_number']?.toString() ??
        '';
    final String phone = rawPhone.isNotEmpty && rawPhone != 'null' ? rawPhone : '';
    final String role = StaffRoleHelper.getRoleName(faculty);
    final String dept = faculty!['department']?.toString() ??
        faculty!['dept']?.toString() ??
        faculty!['user']?['department']?.toString() ??
        '';
    final String designation = faculty!['designation']?.toString() ??
        faculty!['user']?['designation']?.toString() ??
        '';

    String subInfo = '';
    if (designation.isNotEmpty && designation != 'null' && designation != 'N/A') {
      subInfo = designation;
      if (dept.isNotEmpty && dept != 'null' && dept != 'N/A') {
        subInfo = "$subInfo • $dept";
      }
    } else if (dept.isNotEmpty && dept != 'null' && dept != 'N/A') {
      subInfo = dept;
    }

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
              Expanded(
                child: Text(
                  "Assigned In-Charge ($shiftName)",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: StaffRoleHelper.getRoleColor(role).withOpacity(0.12),
                child: Icon(StaffRoleHelper.getRoleIcon(role), color: StaffRoleHelper.getRoleColor(role), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StaffRoleHelper.buildRoleBadge(role),
                      ],
                    ),
                    if (subInfo.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subInfo,
                        style: TextStyle(
                          fontSize: 12,
                          color: subColor.withOpacity(0.85),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 13, color: subColor),
                        const SizedBox(width: 4),
                        Text(
                          phone.isNotEmpty ? phone : 'N/A',
                          style: TextStyle(
                            fontSize: 13,
                            color: subColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
                    tooltip: 'Call In-Charge',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
