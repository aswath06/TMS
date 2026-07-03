import json

file_path = "/Users/aswath/Documents/Tripzo/TMS/lib/screens/driver/driver_routes_screen.dart"
with open(file_path, "r") as f:
    content = f.read()

# Replace AppBar
old_appbar = """      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: _isSearching"""

new_appbar = """      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: _isSearching"""

content = content.replace(old_appbar, new_appbar)

# Replace _buildDailyBusRunCard
import re

start_marker = "  Widget _buildDailyBusRunCard({"
end_marker = "  Widget _buildMissionCard({"

start_idx = content.find(start_marker)
end_idx = content.find(end_marker)

old_card = content[start_idx:end_idx]

new_card = """  Widget _buildDailyBusRunCard({
    required BuildContext context,
    required Map<String, dynamic> run,
    required Color surface,
    required Color primary,
    required Color titleColor,
    required Color subColor,
    required bool isDark,
    required bool isTamil,
  }) {
    final status = run['status']?.toString() ?? 'UNKNOWN';
    final runName = run['run_name']?.toString() ?? 'Route';
    final startLoc = run['start_location_name']?.toString() ?? 'N/A';
    final haltLoc = run['halt_location_name']?.toString() ?? 'N/A';
    
    final routeData = run['dailyBusRoute'] as Map<String, dynamic>?;
    final routeName = routeData?['route_name']?.toString() ?? 'N/A';
    final maxCapacity = routeData?['max_vehicle_capacity'] ?? 60;
    
    final assignmentsList = run['assignment'] as List? ?? [];
    String vehicleNumber = 'N/A';
    if (assignmentsList.isNotEmpty) {
      vehicleNumber = assignmentsList[0]['vehicle']?['vehicle_number'] ?? 'N/A';
    }

    Color statusColor = Colors.grey;
    if (status == 'READY') {
      statusColor = Colors.blue;
    } else if (status == 'ONGOING') {
      statusColor = Colors.orange;
    } else if (status == 'COMPLETED') {
      statusColor = Colors.green;
    }

    Map<String, dynamic>? activeAssignment;
    if (assignmentsList.isNotEmpty) {
      final morning = assignmentsList.firstWhere(
        (a) => a['shift_code']?.toString().toUpperCase() == 'MORNING' || a['shift_code']?.toString().toUpperCase() == 'FN', 
        orElse: () => null
      );
      final evening = assignmentsList.firstWhere(
        (a) => a['shift_code']?.toString().toUpperCase() == 'EVENING' || a['shift_code']?.toString().toUpperCase() == 'AN', 
        orElse: () => null
      );
      
      final runStatus = status.toUpperCase();
      final eveningFirstStatuses = ['FN_COMPLETED', 'AN_STARTED', 'DEPARTED_CAMPUS', 'HALTED', 'COMPLETED'];
      if (eveningFirstStatuses.contains(runStatus)) {
        activeAssignment = evening ?? morning;
      } else {
        activeAssignment = morning ?? evening;
      }
    }

    return GestureDetector(
      onTap: activeAssignment != null ? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssignmentDetailsScreen(
              assignment: activeAssignment!,
              run: run,
            ),
          ),
        );
      } : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 18, color: primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          run['service_date']?.toString() ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(runName, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: titleColor)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.directions_bus_outlined, size: 14, color: subColor),
                const SizedBox(width: 4),
                Text(
                  isTamil ? "பாதை: " : "Route: ",
                  style: TextStyle(
                    fontSize: 12,
                    color: subColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  routeName,
                  style: TextStyle(
                    fontSize: 12,
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "•",
                  style: TextStyle(fontSize: 12, color: subColor),
                ),
                const SizedBox(width: 8),
                Icon(Icons.airline_seat_recline_normal_rounded, size: 14, color: subColor),
                const SizedBox(width: 4),
                Text(
                  isTamil ? "திறன்: " : "Capacity: ",
                  style: TextStyle(
                    fontSize: 12,
                    color: subColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "$maxCapacity ${isTamil ? 'இடங்கள்' : 'Seats'}",
                  style: TextStyle(
                    fontSize: 12,
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _iconInfo(
              Icons.directions_car_filled_rounded, 
              vehicleNumber, 
              isDark
            ),
            const SizedBox(height: 24),
            _buildTimeline(startLoc, haltLoc, primary, titleColor),
          ],
        ),
      ),
    );
  }

"""

content = content[:start_idx] + new_card + content[end_idx:]

with open(file_path, "w") as f:
    f.write(content)
