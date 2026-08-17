import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripzo/screens/driver/driver_task_details_page.dart';

void showEmergencyTaskPopupDialog(BuildContext context, Map<String, dynamic> task) {
  final Map<String, dynamic> rawTask = task['raw'] ?? task;
  final dynamic taskId = rawTask['id'];
  final String title = rawTask['title'] ?? 'Emergency Task';
  final String location = rawTask['location_name'] ?? rawTask['in_campus'] ?? rawTask['from_location'] ?? 'Assigned Location';
  final v = rawTask['vehicle'];
  final String vehicleNo = v is Map ? (v['vehicle_number'] ?? 'Vehicle 56').toString() : (rawTask['vehicle_id'] != null ? "Vehicle #${rawTask['vehicle_id']}" : "Vehicle 56");

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final surface = isDark ? const Color(0xFF1E293B) : Colors.white;

      return AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              "EMERGENCY TASK ASSIGNED!",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFEF4444),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFEF4444)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.directions_bus_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        vehicleNo,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  if (taskId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DriverTaskDetailsPage(
                          taskId: taskId,
                          initialTaskData: rawTask,
                        ),
                      ),
                    );
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      "View Task Details",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
