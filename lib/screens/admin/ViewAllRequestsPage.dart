import 'package:flutter/material.dart';

class ViewAllRequestsPage extends StatelessWidget {
  final List<Map<String, dynamic>> requests;

  const ViewAllRequestsPage({super.key, required this.requests});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: titleColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "All Transport Requests",
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        physics: const BouncingScrollPhysics(),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          return _buildEnhancedRequestCard(
            requests[index],
            isDark,
            primaryBlue,
          );
        },
      ),
    );
  }

  // REUSABLE CARD WIDGET (Matching the dashboard style)
  Widget _buildEnhancedRequestCard(
    Map<String, dynamic> req,
    bool isDark,
    Color acc,
  ) {
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: acc.withOpacity(0.1),
                  child: Icon(Icons.school_rounded, size: 18, color: acc),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req['faculty'] ?? "Faculty Member",
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        req['id'] ?? "N/A",
                        style: TextStyle(
                          color: subColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(req['status']),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Icon(
                      Icons.radio_button_checked_rounded,
                      size: 18,
                      color: acc,
                    ),
                    Container(
                      width: 2,
                      height: 35,
                      color: acc.withOpacity(0.2),
                    ),
                    Icon(Icons.location_on_rounded, size: 20, color: acc),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req['pickup'] ?? "Unknown Pickup",
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        req['drop'] ?? "Unknown Drop",
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
                  req['date'] ?? "",
                  style: TextStyle(
                    color: subColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: acc.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFooterItem(
                  Icons.people_outline_rounded,
                  "${req['passengers'] ?? 0} Guests",
                  subColor,
                ),
                _buildFooterItem(
                  Icons.directions_bus_filled_rounded,
                  "${req['vehicle'] ?? 'Vehicle'} (${req['capacity'] ?? 'N/A'} seats)",
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
    Color bColor = (status == 'Confirmed' || status == 'Approved')
        ? Colors.green
        : (status == 'Pending' ? Colors.orange : Colors.blue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: bColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
