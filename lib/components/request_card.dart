import 'package:flutter/material.dart';
import 'package:tripzo/screens/faculty/missions/mission_details_screen.dart';

class RequestCard extends StatelessWidget {
  final Map<String, dynamic> req;
  final bool isDark;
  final Color accentColor;

  const RequestCard({
    super.key,
    required this.req,
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    final String s = (req['route_request_status'] ?? req['status'] ?? 'Pending').toString().toUpperCase();
    Color bColor;
    if (s == 'STARTED' || s == 'ONGOING') {
      bColor = Colors.orange;
    } else if (s == 'COMPLETED') {
      bColor = Colors.green;
    } else if (s == 'CANCELLED' || s == 'REJECTED') {
      bColor = Colors.red;
    } else if (s == 'DRAFT' || s == 'SUBMITTED') {
      bColor = Colors.blue;
    } else if (s == 'APPROVED' || s == 'PLANNED') {
      bColor = Colors.green;
    } else {
      bColor = Colors.grey;
    }

    return GestureDetector(
      onTap: () {
        final driversList = req['drivers'] as List? ?? [];
        final String drName = driversList.isNotEmpty
            ? driversList.map((d) => d['name'] ?? 'Driver').join(', ')
            : 'No driver assigned';
        final String drPhone = driversList.isNotEmpty
            ? driversList.map((d) => d['phone'] ?? '').where((p) => p.isNotEmpty).join(', ')
            : 'No phone available';
        final String vInfo = req['vehicleInfo'] ?? req['vehicle'] ?? 'No vehicle assigned';
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MissionDetailsScreen(
              missionTitle: req['routeName'] ?? 'Unknown Route',
              time: req['date'] ?? '',
              driverName: drName,
              driverPhone: drPhone,
              vehicleInfo: vInfo,
              capacity: req['passengers'] != null ? "${req['passengers']} Guests" : "N/A",
              pathType: 'ONE WAY',
              status: req['status'] ?? 'Pending',
              statusColor: bColor,
              requestId: req['dbId']?.toString() ?? req['id']?.toString() ?? '',
              rawStatus: req['rawStatus'] ?? 1,
              creatorName: req['faculty'] ?? 'Staff Member',
              stops: [
                {'location': req['pickup'] ?? 'Unknown', 'eta': 'Start'},
                if (req['intermediateStops'] is List)
                  ...(req['intermediateStops'] as List).map((s) => {'location': s.toString(), 'eta': 'Transit'}),
                {'location': req['drop'] ?? 'Unknown', 'eta': 'End'},
              ],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
          // Header: Faculty & ID
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: accentColor.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.person_pin_rounded,
                    size: 18,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              req['routeName'] ?? 'Unknown Route',
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            req['date'] ?? '',
                            style: TextStyle(
                              color: subColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.person_rounded,
                                size: 12,
                                color: subColor.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                req['drivers'] != null && (req['drivers'] as List).isNotEmpty
                                    ? (req['drivers'] as List)
                                        .map((d) => d['name'] ?? 'Driver')
                                        .join(', ')
                                    : 'No Driver Assigned',
                                style: TextStyle(
                                  color: subColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        req['id'] ?? 'N/A',
                        style: TextStyle(
                          color: subColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _buildStatusBadge(req['status'] ?? 'Pending'),
              ],
            ),
          ),
          const Divider(height: 1),
          // Body: Route Timeline
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Icon(
                      Icons.radio_button_checked_rounded,
                      size: 16,
                      color: accentColor,
                    ),
                    Container(
                      width: 2,
                      height: 35,
                      color: accentColor.withValues(alpha: 0.2),
                    ),
                    Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: accentColor,
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req['pickup'] ?? 'Unknown',
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        req['drop'] ?? 'Unknown',
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Footer: Capacity & Guests
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFooterItem(
                  Icons.person_pin_rounded,
                  req['faculty'] ?? 'Staff Member',
                  subColor,
                ),
                _buildFooterItem(
                  Icons.group_outlined,
                  "${req['passengers'] ?? 0} Guests",
                  subColor,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildFooterItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final String s = status.toUpperCase();

    // Premium Color Mapping based on Tailwind tokens provided by user
    final Map<String, Map<String, Color>> statusStyles = {
      'DRAFT': {
        'bg': const Color(0xFFFFFBEB),
        'text': const Color(0xFFF59E0B),
        'border': const Color(0xFFFDE68A),
      },
      'SUBMITTED': {
        'bg': const Color(0xFFFAF5FF),
        'text': const Color(0xFFA855F7),
        'border': const Color(0xFFE9D5FF),
      },
      'PLANNED': {
        'bg': const Color(0xFFFDF2F8),
        'text': const Color(0xFFEC4899),
        'border': const Color(0xFFFBCFE8),
      },
      'REJECTED': {
        'bg': const Color(0xFFFDF2F8),
        'text': const Color(0xFFEC4899),
        'border': const Color(0xFFFBCFE8),
      },
      'APPROVED': {
        'bg': const Color(0xFFFDF2F8),
        'text': const Color(0xFFEC4899),
        'border': const Color(0xFFFBCFE8),
      },
      'STARTED': {
        'bg': const Color(0xFFDBEAFE),
        'text': const Color(0xFF2563EB),
        'border': const Color(0xFF93C5FD),
      },
      'ONGOING': {
        'bg': const Color(0xFFEEF2FF),
        'text': const Color(0xFF6366F1),
        'border': const Color(0xFFC7D2FE),
      },
      'COMPLETED': {
        'bg': const Color(0xFFECFDF5),
        'text': const Color(0xFF10B981),
        'border': const Color(0xFFA7F3D0),
      },
      'CANCELLED': {
        'bg': const Color(0xFFFEF2F2),
        'text': Colors.red,
        'border': const Color(0xFFFECACA),
      },
    };

    final style = statusStyles[s] ??
        {
          'bg': Colors.grey.withValues(alpha: 0.1),
          'text': Colors.grey,
          'border': Colors.grey.withValues(alpha: 0.2),
        };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style['bg'],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style['border']!, width: 1),
      ),
      child: Text(
        s,
        style: TextStyle(
          color: style['text'],
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
