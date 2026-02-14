import 'package:flutter/material.dart';

class RequestDetailScreen extends StatelessWidget {
  final Map<String, dynamic> request;
  const RequestDetailScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Request Details",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- STATUS HEADER ---
            _buildStatusHeader(request['status'], primaryBlue),
            const SizedBox(height: 24),

            // --- MAIN DETAILS CARD ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _infoRow(
                    Icons.tag_rounded,
                    "Request ID",
                    request['id'],
                    primaryBlue,
                  ),
                  _infoRow(
                    Icons.person_outline_rounded,
                    "Faculty Name",
                    request['faculty'],
                    primaryBlue,
                  ),
                  _infoRow(
                    Icons.calendar_today_rounded,
                    "Travel Date",
                    request['date'],
                    primaryBlue,
                  ),
                  _infoRow(
                    Icons.directions_car_filled_rounded,
                    "Vehicle Type",
                    request['vehicle'],
                    primaryBlue,
                  ),
                  _infoRow(
                    Icons.groups_rounded,
                    "Passengers",
                    "${request['passengers']} / ${request['capacity']}",
                    primaryBlue,
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),

                  // ROUTE SECTION
                  _buildRouteDisplay(
                    request['pickup'],
                    request['drop'],
                    primaryBlue,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- ACTION BUTTONS ---
            if (request['status'] == 'Pending')
              Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      "Reject",
                      Colors.redAccent.withOpacity(0.1),
                      Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionBtn(
                      "Approve",
                      primaryBlue,
                      Colors.white,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(String status, Color primary) {
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'confirmed':
        statusColor = Colors.green;
        break;
      case 'pending':
        statusColor = Colors.orange;
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
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Text(
            status,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: primary),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteDisplay(String pickup, String drop, Color primary) {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.location_on_rounded, color: primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                pickup,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        Container(
          height: 30,
          margin: const EdgeInsets.only(left: 11),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: primary.withOpacity(0.3),
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
          ),
        ),
        Row(
          children: [
            const Icon(Icons.flag_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                drop,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionBtn(String title, Color bg, Color text) {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
