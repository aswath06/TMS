import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Components & Screens
import 'package:tms/components/request_card.dart';
import 'package:tms/components/leave_card.dart';
import 'package:tms/screens/admin/request/ViewAllRequestsPage.dart';
import 'package:tms/screens/admin/request/ViewAllLeavesPage.dart';
import 'package:tms/screens/admin/request/request_detail_screen.dart';
import 'package:tms/screens/faculty/request/new_request_screen.dart';

// Store
import 'package:tms/store/request_store.dart';

class RequestListPage extends StatefulWidget {
  const RequestListPage({super.key});

  @override
  State<RequestListPage> createState() => _RequestListPageState();
}

class _RequestListPageState extends State<RequestListPage> {
  // Mock data for leaves remains here for now as requested
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
    // Initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestStore>().fetchRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RequestStore>(); // Watch the store
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
              onRefresh: () => store.fetchRequests(),
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
                              ViewAllRequestsPage(requests: store.requests),
                        ),
                      ),
                    ),
                    _buildMainContent(store, isDark, primaryBlue),
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

  Widget _buildMainContent(RequestStore store, bool isDark, Color primaryBlue) {
    if (store.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (store.errorMessage != null) {
      return _buildErrorWidget(store.errorMessage!, primaryBlue, store);
    }
    if (store.requests.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text("No requests found."),
        ),
      );
    }

    // Build the list from store data
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: store.requests.length > 3 ? 3 : store.requests.length,
      itemBuilder: (context, index) {
        final req = store.requests[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RequestDetailScreen(request: req),
              ),
            ),
            child: RequestCard(
              req: req,
              isDark: isDark,
              accentColor: primaryBlue,
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(String message, Color primary, RequestStore store) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.red[300])),
          TextButton(
            onPressed: () => store.fetchRequests(),
            child: Text("Retry", style: TextStyle(color: primary)),
          ),
        ],
      ),
    );
  }

  // ... (Other UI helpers like _buildHeader, _buildSectionHeader, etc. remain the same as your original code)
  // [Original UI code for _buildLeaveList, _buildHeader, _buildAddButton, _buildBackgroundDecor, _buildSectionHeader would go here]

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
