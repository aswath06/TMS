import 'package:flutter/material.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF4F46E5);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Transport Requests",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                    ),
                  ),
                  Text(
                    "Submit and track your travel details",
                    style: TextStyle(color: subColor, fontSize: 15),
                  ),
                ],
              ),
            ),

            // --- REQUEST LIST ---
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildRequestCard(
                    context,
                    id: "TR-8821",
                    type: "Official Visit",
                    status: "Pending",
                    statusColor: Colors.orange,
                    date: "Requested: Feb 05",
                    isEditable: true,
                  ),
                  _buildRequestCard(
                    context,
                    id: "TR-7742",
                    type: "Guest Pickup",
                    status: "Approved",
                    statusColor: Colors.green,
                    date: "Approved: Feb 04",
                    isEditable: false, // FR-3.2.4 Read-only post approval
                  ),
                  _buildRequestCard(
                    context,
                    id: "TR-6610",
                    type: "Field Trip",
                    status: "Clarification Needed",
                    statusColor: Colors.red,
                    date: "Updated: Feb 03",
                    isEditable: true,
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      // Floating Action Button for FR-3.2.2 Detail Submission
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton.extended(
          onPressed: () {},
          backgroundColor: primaryBlue,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            "New Request",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(
    BuildContext context, {
    required String id,
    required String type,
    required String status,
    required Color statusColor,
    required String date,
    required bool isEditable,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isEditable
            ? Border.all(
                color: const Color(0xFF4F46E5).withOpacity(0.3),
                width: 1,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                id,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4F46E5),
                ),
              ),
              _buildStatusBadge(status, statusColor),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            type,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            date,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEditable ? "Tap to edit details" : "Locked (View Only)",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isEditable
                      ? const Color(0xFF4F46E5)
                      : Colors.grey.shade400,
                ),
              ),
              Icon(
                isEditable
                    ? Icons.edit_note_rounded
                    : Icons.lock_outline_rounded,
                size: 20,
                color: isEditable
                    ? const Color(0xFF4F46E5)
                    : Colors.grey.shade400,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
