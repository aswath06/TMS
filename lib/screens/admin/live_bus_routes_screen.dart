import 'package:flutter/material.dart';
import 'package:tripzo/screens/driver/assignment_details_screen.dart';
import 'package:intl/intl.dart';
import 'package:tripzo/store/user_store.dart';

class LiveBusRoutesScreen extends StatelessWidget {
  final List<dynamic> adminDailyBusRuns;

  const LiveBusRoutesScreen({super.key, required this.adminDailyBusRuns});

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildAssignmentCard({
    required BuildContext context,
    required dynamic assignment,
    required Color surface,
    required Color primary,
    required Color titleColor,
    required Color subColor,
    required bool isDark,
  }) {
    final shiftCode = assignment['shift_code'] ?? 'UNKNOWN';
    final startTime = _formatDate(assignment['planned_start_time']);
    final endTime = _formatDate(assignment['planned_end_time']);
    final vehicleNumber = assignment['vehicle']?['vehicle_number'] ?? 'Unknown Vehicle';
    final statusStr = assignment['run_status'] ?? 'UNKNOWN';

    final routeCode = assignment['run_data']?['dailyBusRoute']?['route_code'] ?? '';
    final routeName = assignment['run_data']?['dailyBusRoute']?['route_name'] ?? 'Bus Route';

    String startLoc = assignment['start_location_name'] ?? 'Start';
    String haltLoc = assignment['halt_location_name'] ?? 'Halt';

    if (shiftCode == 'EVENING') {
      final temp = startLoc;
      startLoc = haltLoc;
      haltLoc = temp;
    }

    Color statusColor = Colors.blue;
    if (statusStr == 'READY') {
      statusColor = Colors.green;
    } else if (statusStr == 'ONGOING') statusColor = Colors.orange;
    else if (statusStr == 'COMPLETED') statusColor = Colors.grey;

    bool isEnabled = true;
    if (shiftCode == 'EVENING') {
      final validStatuses = ['FN_COMPLETED', 'AN_STARTED', 'DEPARTED_CAMPUS', 'RESUMED_MIDWAY', 'MERGED_HALTED', 'HALTED', 'COMPLETED'];
      if (!validStatuses.contains(statusStr.toUpperCase())) {
        isEnabled = false;
      }
    } else if (shiftCode == 'MORNING') {
      final disabledStatuses = ['FN_COMPLETED', 'AN_STARTED', 'DEPARTED_CAMPUS', 'HALTED'];
      if (disabledStatuses.contains(statusStr.toUpperCase())) {
        isEnabled = false;
      }
    }

    return GestureDetector(
      onTap: isEnabled ? () {
        final Map<String, dynamic> runData = (assignment['run_data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssignmentDetailsScreen(
              assignment: assignment,
              run: runData,
            ),
          ),
        );
      } : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: primary.withValues(alpha: 0.1), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            shiftCode == 'EVENING' ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                            color: primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              routeCode.isNotEmpty ? routeCode : "Bus Route",
                              style: TextStyle(fontWeight: FontWeight.w900, color: primary, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: shiftCode == 'MORNING' ? Colors.orange.withValues(alpha: 0.12) : primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            shiftCode,
                            style: TextStyle(
                              color: shiftCode == 'MORNING' ? Colors.orange : primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                          child: Text(statusStr.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle details and Route Name
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Route Name", style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(routeName, style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: subColor.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.directions_car_rounded, size: 14, color: titleColor),
                              const SizedBox(width: 6),
                              Text(vehicleNumber, style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildTimeline(startLoc, haltLoc, primary, titleColor),
                    const SizedBox(height: 24),
                    // Times
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Planned Start", style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time_filled_rounded, size: 14, color: primary),
                                  const SizedBox(width: 4),
                                  Text(startTime, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: titleColor)),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("Planned End", style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.access_time_filled_rounded, size: 14, color: Colors.orangeAccent),
                                  const SizedBox(width: 4),
                                  Text(endTime, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: titleColor)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(String pickup, String drop, Color primary, Color title) {
    return Row(
      children: [
        Column(
          children: [
            Icon(Icons.radio_button_checked, color: primary, size: 18),
            Container(width: 2, height: 20, color: primary.withValues(alpha: 0.2)),
            Icon(Icons.location_on, color: Colors.redAccent.withValues(alpha: 0.7), size: 18),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickup, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: title), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 18),
              Text(drop, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: title), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return FutureBuilder<int?>(
      future: UserStore.getUserId(),
      builder: (context, snapshot) {
        final currentUserId = snapshot.data;
        
        final filteredRuns = currentUserId != null
            ? adminDailyBusRuns.where((assignment) {
                final driver = assignment['driver'];
                return driver != null && driver['user_id'] == currentUserId;
              }).toList()
            : adminDailyBusRuns;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: titleColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              "Live Bus Routes",
              style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
          body: filteredRuns.isEmpty
              ? Center(
                  child: Text(
                    "No live bus routes available",
                    style: TextStyle(color: subColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredRuns.length,
                  itemBuilder: (context, index) {
                    return _buildAssignmentCard(
                      context: context,
                      assignment: filteredRuns[index],
                      surface: surfaceColor,
                      primary: primaryBlue,
                      titleColor: titleColor,
                      subColor: subColor,
                      isDark: isDark,
                    );
                  },
                ),
        );
      }
    );
  }
}
