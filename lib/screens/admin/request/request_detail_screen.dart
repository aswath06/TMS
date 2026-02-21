import 'package:flutter/material.dart';

class RequestDetailScreen extends StatelessWidget {
  final Map<String, dynamic> request;
  const RequestDetailScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    // Theme and Color configuration
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const Color primaryBlue = Color(0xFF6366F1);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subTextColor = isDark
        ? Colors.white70
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Request Details",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- STATUS HEADER ---
            _buildStatusHeader(request['status'] ?? 'Pending', primaryBlue),
            const SizedBox(height: 24),

            // --- MAIN DETAILS CARD ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _infoRow(
                    Icons.tag_rounded,
                    "Request ID",
                    request['id']?.toString() ?? 'N/A',
                    primaryBlue,
                    subTextColor,
                  ),
                  _infoRow(
                    Icons.person_outline_rounded,
                    "Faculty Name",
                    request['faculty'] ?? 'N/A',
                    primaryBlue,
                    subTextColor,
                  ),
                  _infoRow(
                    Icons.calendar_today_rounded,
                    "Travel Date",
                    request['date'] ?? 'N/A',
                    primaryBlue,
                    subTextColor,
                  ),
                  _infoRow(
                    Icons.directions_car_filled_rounded,
                    "Route Name",
                    request['vehicle'] ?? 'N/A',
                    primaryBlue,
                    subTextColor,
                  ),
                  _infoRow(
                    Icons.groups_rounded,
                    "Passengers",
                    "${request['passengers'] ?? 0} People",
                    primaryBlue,
                    subTextColor,
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Divider(
                      color: primaryBlue.withOpacity(0.1),
                      thickness: 1,
                    ),
                  ),

                  // --- ROUTE SECTION ---
                  _buildRouteDisplay(
                    request['pickup'] ?? 'Unknown Pickup',
                    request['drop'] ?? 'Unknown Destination',
                    request['intermediateStops'] ?? [],
                    primaryBlue,
                    textColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- ACTION BUTTONS ---
            if (request['status'].toString().toLowerCase() == 'pending')
              Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      "Reject",
                      Colors.redAccent.withOpacity(0.1),
                      Colors.redAccent,
                      () => _showActionDialog(context, "Reject"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionBtn(
                      "Approve",
                      primaryBlue,
                      Colors.white,
                      () => _showActionDialog(context, "Approve"),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Helper to show confirmation
  void _showActionDialog(BuildContext context, String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$action Request"),
        content: Text(
          "Are you sure you want to $action this transport request?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close Dialog
              Navigator.pop(context); // Go back to list
            },
            child: Text("Confirm $action"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(String status, Color primary) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'approved':
        statusColor = const Color(0xFF10B981); // Emerald Green
        break;
      case 'pending':
        statusColor = const Color(0xFFF59E0B); // Amber Orange
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444); // Red
        break;
      default:
        statusColor = primary;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Current Status",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: statusColor.withOpacity(0.2)),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    Color primary,
    Color subTextColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteDisplay(
    String pickup,
    String drop,
    List<dynamic> stops,
    Color primary,
    Color textColor,
  ) {
    return Column(
      children: [
        _routePoint(
          Icons.location_on_rounded,
          primary,
          pickup,
          textColor,
          true,
        ),
        ...stops.map((stop) => _routeConnector(primary, stop.toString())),
        _routeConnector(primary, null),
        _routePoint(
          Icons.flag_rounded,
          const Color(0xFFEF4444),
          drop,
          textColor,
          false,
        ),
      ],
    );
  }

  Widget _routePoint(
    IconData icon,
    Color color,
    String text,
    Color textColor,
    bool isBold,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _routeConnector(Color primary, String? stopName) {
    return Row(
      children: [
        Container(
          width: 22,
          alignment: Alignment.center,
          child: Container(
            width: 2,
            height: stopName != null ? 50 : 25,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [primary.withOpacity(0.5), primary.withOpacity(0.05)],
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        if (stopName != null)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "Stop: $stopName",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  // italic: true,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionBtn(
    String title,
    Color bg,
    Color text,
    VoidCallback onTap,
  ) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: title == "Approve"
            ? [
                BoxShadow(
                  color: bg.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: text,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
