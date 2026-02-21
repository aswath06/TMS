import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:tms/components/request_card.dart';
import 'package:tms/components/leave_card.dart';
import 'package:tms/screens/admin/request/ViewAllRequestsPage.dart';
import 'package:tms/screens/admin/request/ViewAllLeavesPage.dart';
import 'package:tms/screens/admin/request/request_detail_screen.dart';
import 'package:tms/screens/faculty/request/new_request_screen.dart';

class RequestListPage extends StatefulWidget {
  const RequestListPage({super.key});

  @override
  State<RequestListPage> createState() => _RequestListPageState();
}

class _RequestListPageState extends State<RequestListPage> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String? _error;

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
  ];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  /// Extracts the relevant part of the address (e.g., "Coimbatore, Coimbatore North")
  String _formatAddress(String? address) {
    if (address == null || address.isEmpty) return 'Unknown Location';

    // Split by comma
    List<String> parts = address.split(',');

    if (parts.length >= 2) {
      // Returns "Part1, Part2" (e.g., Coimbatore, Coimbatore North)
      return "${parts[0].trim()}, ${parts[1].trim()}";
    }

    return address;
  }

  Future<void> _fetchRequests() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
          'https://18x50gz9-8055.inc1.devtunnels.ms/request/get-all?page=1&limit=10',
        ),
        headers: {
          'Authorization':
              'TMS eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MSwibmFtZSI6IlN1cmVzaCBLYW5uYW4gUiBWIiwidXNlcl9uYW1lIjoiU3VyZXNoQDA1IiwiZW1haWwiOiJzdXJlc2hrYW5uYW4uY3MyM0BiaXRzYXRoeS5hYy5pbiIsInJvbGUiOiJUcmFuc3BvcnQgQWRtaW4iLCJzZXNzaW9uSWQiOiI5MjE0YTIzMy0wZDg2LTQ1Y2EtYWJiNi0yMTkyMzkzNDhkMzEiLCJ0eXBlIjoiV0VCIiwiaWF0IjoxNzcxNTgzNTU5LCJleHAiOjE3NzE2Njk5NTh9.BVN1XXSntfqi5QbHB5MpKQRExblVyRfBdB9Fj-1U02c',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _requests = List<Map<String, dynamic>>.from(data['items']);
          _isLoading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = 'Server Error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Connection failed. Please check your internet.";
        _isLoading = false;
      });
    }
  }

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
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchRequests,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(titleColor, primaryBlue),
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
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_error != null)
                      _buildErrorWidget(primaryBlue)
                    else if (_requests.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Text("No requests found."),
                        ),
                      )
                    else
                      _buildRequestList(isDark, primaryBlue),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      "Leaves Request",
                      titleColor,
                      primaryBlue,
                      onViewAll: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ViewAllLeavesPage(leaves: _leaves),
                        ),
                      ),
                    ),
                    _buildLeaveList(isDark, primaryBlue),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestList(bool isDark, Color primaryBlue) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _requests.length > 3 ? 3 : _requests.length,
      itemBuilder: (context, index) {
        final req = _requests[index];

        final Map<String, dynamic> formattedReq = {
          'id': 'REQ-${req['id']}',
          'faculty': req['createdBy']?['name'] ?? 'Admin',
          'date': (req['start_datetime'] ?? '').toString().split('T')[0],
          // Apply the address formatting here
          'pickup': _formatAddress(req['startLocation']),
          'drop': _formatAddress(req['destinationLocation']),
          'status': req['status'] ?? 'peding',
          'vehicle': req['routeName'] ?? 'Custom Route',
          'passengers': req['passengerCount'] ?? 0,
          'capacity': 10,
          'intermediateStops': req['intermediateStops'] ?? [],
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    RequestDetailScreen(request: formattedReq),
              ),
            ),
            child: RequestCard(
              req: formattedReq,
              isDark: isDark,
              accentColor: primaryBlue,
            ),
          ),
        );
      },
    );
  }

  // --- UI Helpers ---
  Widget _buildLeaveList(bool isDark, Color primaryBlue) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _leaves.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: LeaveCard(
          leaf: _leaves[index],
          isDark: isDark,
          primaryColor: primaryBlue,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(Color primary) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Text(_error ?? "Error", style: TextStyle(color: Colors.red[300])),
          TextButton(
            onPressed: _fetchRequests,
            child: Text("Retry", style: TextStyle(color: primary)),
          ),
        ],
      ),
    );
  }

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
      child: IconButton(
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NewRequestScreen()),
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
