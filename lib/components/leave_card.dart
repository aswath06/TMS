import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/store/request_store.dart';
import 'package:tripzo/utils/toast_utils.dart';


class LeaveCard extends ConsumerWidget {
  final Map<String, dynamic> leaf;
  final bool isDark;
  final Color primaryColor;

  const LeaveCard({
    super.key,
    required this.leaf,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return GestureDetector(
      onTap: () => _showLeaveDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.transparent : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: primaryColor.withOpacity(0.1),
              child: Icon(
                Icons.airline_seat_recline_extra_rounded,
                color: primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leaf['driver'] ?? 'Unknown Driver',
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${leaf['from']} - ${leaf['to']} (${leaf['days']} Days)",
                    style: TextStyle(
                      color: subColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            _buildStatusBadge(leaf['status'] ?? 'Pending'),
          ],
        ),
      ),
    );
  }

  void _showLeaveDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LeaveDetailBottomSheet(
        leaf: leaf,
        isDark: isDark,
        primaryColor: primaryColor,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bColor = (status == 'Approved' || status == 'Confirmed')
        ? Colors.green
        : status == 'Pending'
        ? Colors.orange
        : status == 'Rejected'
        ? Colors.red
        : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: bColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _LeaveDetailBottomSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> leaf;
  final bool isDark;
  final Color primaryColor;

  const _LeaveDetailBottomSheet({
    required this.leaf,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  ConsumerState<_LeaveDetailBottomSheet> createState() => _LeaveDetailBottomSheetState();
}

class _LeaveDetailBottomSheetState extends ConsumerState<_LeaveDetailBottomSheet> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = widget.isDark ? const Color(0xFF0F172A) : Colors.white;
    final Color titleColor = widget.isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subColor = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color cardColor = widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    final rawStatus = widget.leaf['rawStatus'];
    final bool isPending = rawStatus == 1 || widget.leaf['status'] == 'Pending';

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Leave Details",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusBadge(widget.leaf['status'] ?? 'Pending'),
            ],
          ),
          const SizedBox(height: 24),

          // Driver Info Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: widget.primaryColor.withOpacity(0.1),
                  child: Text(
                    (widget.leaf['driver'] ?? "U")[0].toUpperCase(),
                    style: TextStyle(
                      color: widget.primaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.leaf['driver'] ?? 'Unknown Driver',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      Text(
                        widget.leaf['driver_full']?['email'] ?? 'No email available',
                        style: TextStyle(
                          fontSize: 13,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Details Grid
          _buildInfoRow(Icons.calendar_today_rounded, "Duration", "${widget.leaf['from']} - ${widget.leaf['to']} (${widget.leaf['days']} Days)", titleColor, subColor),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.category_rounded, "Leave Type", _getLeaveTypeName(widget.leaf['leave_type']), titleColor, subColor),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.comment_rounded, "Reason", widget.leaf['reason'] ?? 'No reason provided', titleColor, subColor),
          const SizedBox(height: 24),

          // Approver Info (if available)
          if (widget.leaf['approver'] != null) ...[
            const Divider(),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.verified_user_rounded, color: Colors.green.shade400, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Approved by ${widget.leaf['approver']?['name']}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (widget.leaf['approved_at'] != null)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 4),
                child: Text(
                  "on ${_formatTimestamp(widget.leaf['approved_at'])}",
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
              ),
          ] else if (isPending) ...[
            const Divider(),
            const SizedBox(height: 24),
            if (_isUpdating)
              const Center(child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateStatus(context, 3), // Reject
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        foregroundColor: Colors.red,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.red.withOpacity(0.2)),
                        ),
                      ),
                      child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateStatus(context, 2), // Approve
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text("Approve", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
          ],
          
          const SizedBox(height: 12),
          Text(
            "Submitted on ${_formatTimestamp(widget.leaf['created_at'])}",
            style: TextStyle(fontSize: 11, color: subColor.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, int status) async {
    setState(() => _isUpdating = true);
    
    // Capture the messenger before the async call to avoid context issues
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final store = ref.read(requestStoreProvider);

    final success = await store.updateLeaveStatus(widget.leaf['id'], status);

    if (mounted) {
      setState(() => _isUpdating = false);
      if (success) {
        showTopToast(
          context,
          "Leave ${status == 2 ? 'Approved' : 'Rejected'} successfully",
        );
        navigator.pop(); // Close detail view
      } else {
        showTopToast(
          context,
          store.leavesErrorMessage ?? "Failed to update status",
          isError: true,
        );
      }
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color titleColor, Color subColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.primaryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: widget.primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(fontSize: 15, color: titleColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getLeaveTypeName(dynamic type) {
    switch (type) {
      case 1: return "Sick Leave";
      case 2: return "Casual Leave";
      case 3: return "Emergency";
      case 4: return "Other";
      default: return "Regular";
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "Unknown date";
    try {
      final DateTime dt = DateTime.parse(timestamp.toString());
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dt.toUtc());
    } catch (e) {
      return timestamp.toString();
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bColor = (status == 'Approved' || status == 'Confirmed')
        ? Colors.green
        : status == 'Pending'
        ? Colors.orange
        : status == 'Rejected'
        ? Colors.red
        : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: bColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
