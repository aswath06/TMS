import 'package:flutter/material.dart';
import 'package:tms/components/request_card.dart';
import 'package:tms/components/leave_card.dart';
import 'package:tms/screens/admin/request/ViewAllRequestsPage.dart';
import 'package:tms/screens/admin/request/ViewAllLeavesPage.dart'; // Import the new page
import 'package:tms/screens/faculty/request/new_request_screen.dart';

class RequestListPage extends StatefulWidget {
  const RequestListPage({super.key});

  @override
  State<RequestListPage> createState() => _RequestListPageState();
}

class _RequestListPageState extends State<RequestListPage> {
  final List<Map<String, dynamic>> _requests = [
    {
      'id': 'REQ-8821',
      'faculty': 'Dr. Sarah Jenkins',
      'date': 'Oct 24, 2023',
      'pickup': 'Central Station, NY',
      'drop': 'JFK Airport, Terminal 4',
      'status': 'Pending',
      'vehicle': 'Mini Sedan',
      'capacity': 4,
      'passengers': 2,
    },
    {
      'id': 'REQ-7652',
      'faculty': 'Prof. James Wilson',
      'date': 'Oct 28, 2023',
      'pickup': 'Grand Hyatt Hotel',
      'drop': 'City Tour Loop',
      'status': 'Confirmed',
      'vehicle': 'Luxury SUV',
      'capacity': 7,
      'passengers': 4,
    },
    {
      'id': 'REQ-1234',
      'faculty': 'Dr. Alice Brown',
      'date': 'Nov 02, 2023',
      'pickup': 'University Gate 1',
      'drop': 'Tech Park South',
      'status': 'Completed',
      'vehicle': 'Bus',
      'capacity': 30,
      'passengers': 15,
    },
  ];

  // Mock data with 4 items to trigger the "View All" logic (> 3)
  final List<Map<String, dynamic>> _leaves = [
    {
      'driver': 'John Doe',
      'days': '3',
      'from': 'Nov 01',
      'to': 'Nov 03',
      'status': 'Approved',
    },
    {
      'driver': 'Mike Ross',
      'days': '1',
      'from': 'Nov 05',
      'to': 'Nov 05',
      'status': 'Pending',
    },
    {
      'driver': 'Harvey Specter',
      'days': '2',
      'from': 'Nov 07',
      'to': 'Nov 08',
      'status': 'Approved',
    },
    {
      'driver': 'Rachel Zane',
      'days': '5',
      'from': 'Nov 10',
      'to': 'Nov 15',
      'status': 'Pending',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color primaryBlue = const Color(0xFF6366F1);

    // Logic for Request Section (Show 2)
    final int requestDisplayCount = _requests.length > 2 ? 2 : _requests.length;

    // Logic for Leaves Section (Show 3)
    final int leaveDisplayCount = _leaves.length > 3 ? 3 : _leaves.length;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(titleColor, primaryBlue),

                  // --- REQUESTS SECTION ---
                  _buildSectionHeader(
                    "Active Requests",
                    titleColor,
                    primaryBlue,
                    onViewAll: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ViewAllRequestsPage(requests: _requests),
                      ),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: requestDisplayCount,
                    itemBuilder: (context, index) => RequestCard(
                      req: _requests[index],
                      isDark: isDark,
                      accentColor: primaryBlue,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- LEAVES SECTION ---
                  _buildSectionHeader(
                    "Leaves Request",
                    titleColor,
                    primaryBlue,
                    onViewAll: () {
                      // Navigate only if count > 3 (or always allow navigation to see full history)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ViewAllLeavesPage(leaves: _leaves),
                        ),
                      );
                    },
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: leaveDisplayCount,
                    itemBuilder: (context, index) => LeaveCard(
                      leaf: _leaves[index],
                      isDark: isDark,
                      primaryColor: primaryBlue,
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Methods (Headers, etc.) remain as they were in your previous code...
  Widget _buildSectionHeader(
    String title,
    Color titleColor,
    Color primaryBlue, {
    required VoidCallback onViewAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          TextButton(
            onPressed: onViewAll,
            child: Text(
              "View All",
              style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color titleColor, Color primaryBlue) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "TRANSPORT SYSTEM",
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                  color: primaryBlue.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Dashboard",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
            ],
          ),
          _buildAddButton(primaryBlue),
        ],
      ),
    );
  }

  Widget _buildAddButton(Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewRequestScreen()),
          ),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundDecor(bool isDark) {
    return Positioned(
      top: -80,
      right: -80,
      child: CircleAvatar(
        radius: 180,
        backgroundColor: const Color(
          0xFF6366F1,
        ).withOpacity(isDark ? 0.05 : 0.03),
      ),
    );
  }
}
