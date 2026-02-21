import 'package:flutter/material.dart';

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

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
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
                  backgroundColor: accentColor.withOpacity(0.1),
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
                      Text(
                        req['faculty'] ?? 'N/A',
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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
                      color: accentColor.withOpacity(0.2),
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
                Text(
                  req['date'] ?? '',
                  style: TextStyle(
                    color: subColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Footer: Capacity & Guests
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFooterItem(
                  Icons.group_outlined,
                  "${req['passengers'] ?? 0} Guests",
                  subColor,
                ),
                _buildFooterItem(
                  Icons.directions_car_filled_outlined,
                  "${req['vehicle'] ?? 'Vehicle'} (${req['capacity'] ?? '0'})",
                  subColor,
                ),
              ],
            ),
          ),
        ],
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
    // Normalize status for comparison
    final String s = status.toLowerCase();

    Color bColor;
    if (s == 'pending') {
      bColor = Colors.orange; // Yellow/Orange for pending
    } else if (s == 'rejected' || s == 'cancelled') {
      bColor = Colors.red; // Red for negative states
    } else {
      bColor = Colors.green; // Green for Approved/Confirmed/Success
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        // Capitalize first letter for display
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          color: bColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
