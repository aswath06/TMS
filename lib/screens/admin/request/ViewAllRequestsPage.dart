import 'package:flutter/material.dart';

class ViewAllRequestsPage extends StatefulWidget {
  final List<Map<String, dynamic>> requests;

  const ViewAllRequestsPage({super.key, required this.requests});

  @override
  State<ViewAllRequestsPage> createState() => _ViewAllRequestsPageState();
}

class _ViewAllRequestsPageState extends State<ViewAllRequestsPage> {
  late List<Map<String, dynamic>> _filteredRequests;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredRequests = widget.requests;
  }

  /// Helper to get consistent colors for status throughout the app
  Color _getStatusColor(String status) {
    final s = status.toUpperCase();
    if (s == 'STARTED' || s == 'ONGOING') return const Color(0xFF6366F1);
    if (s == 'COMPLETED') return const Color(0xFF10B981);
    if (s == 'CANCELLED' || s == 'REJECTED') return const Color(0xFF64748B);
    if (s == 'DRAFT') return const Color(0xFFF59E0B);
    return const Color(0xFFEC4899); // Pink for Approved/Planned
  }

  Widget _buildAllowanceBadge(bool allowanceNeeded) {
    if (!allowanceNeeded) return const SizedBox.shrink();
    return Tooltip(
      message: "Allowance Required",
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.payments_outlined,
          color: Colors.green,
          size: 14,
        ),
      ),
    );
  }

  void _filterRequests(String query) {
    setState(() {
      _filteredRequests = widget.requests
          .where(
            (req) =>
                (req['faculty'] ?? "").toLowerCase().contains(
                  query.toLowerCase(),
                ) ||
                (req['id'] ?? "").toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

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
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: titleColor),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(cardColor, titleColor, primaryBlue, isDark),
          Expanded(
            child: _filteredRequests.isEmpty
                ? _buildEmptyState(titleColor)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filteredRequests.length,
                    itemBuilder: (context, index) {
                      return _buildEnhancedRequestCard(
                        _filteredRequests[index],
                        isDark,
                        primaryBlue,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(
    Color cardColor,
    Color titleColor,
    Color primaryBlue,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _filterRequests,
          style: TextStyle(color: titleColor),
          decoration: InputDecoration(
            hintText: "Search faculty or ID...",
            hintStyle: TextStyle(
              color: titleColor.withValues(alpha: 0.4),
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: primaryBlue,
              size: 22,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: titleColor.withValues(alpha: 0.4),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _filterRequests("");
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }

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
    final String status = req['status'] ?? "Pending";
    final Color statusColor = _getStatusColor(status);

    return Container(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: acc.withValues(alpha: 0.1),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status.toUpperCase() == 'COMPLETED' && req['allowance_needed'] != null) ...[
                      _buildAllowanceBadge(req['allowance_needed']),
                      const SizedBox(width: 8),
                    ],
                    _buildStatusBadge(status),
                  ],
                ),
              ],
            ),
          ),
          if (req['drivers'] != null && (req['drivers'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.person_rounded, size: 14, color: acc.withValues(alpha: 0.7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Drivers: " + (req['drivers'] as List).map((d) => d['name'] ?? "Driver").join(", "),
                      style: TextStyle(
                        color: subColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimeline(acc),
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
          _buildFooter(req, subColor, acc),
        ],
      ),
    );
  }

  Widget _buildTimeline(Color acc) {
    return Column(
      children: [
        Icon(Icons.radio_button_checked_rounded, size: 18, color: acc),
        Container(width: 2, height: 35, color: acc.withValues(alpha: 0.2)),
        Icon(Icons.location_on_rounded, size: 20, color: acc),
      ],
    );
  }

  Widget _buildFooter(Map<String, dynamic> req, Color subColor, Color acc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: acc.withValues(alpha: 0.05),
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
            "${req['vehicle'] ?? 'Not Assigned'} (${req['capacity'] ?? 'N/A'} seats)",
            subColor,
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
    final String s = status.toUpperCase();
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
        'bg': const Color(0xFFF8FAFC),
        'text': const Color(0xFF64748B),
        'border': const Color(0xFFE2E8F0),
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

  Widget _buildEmptyState(Color titleColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 60,
            color: titleColor.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            "No requests found",
            style: TextStyle(
              color: titleColor.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
