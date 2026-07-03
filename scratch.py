import re

with open('/Users/aswath/Documents/Tripzo/TMS/lib/screens/driver/driver_routes_screen.dart', 'r') as f:
    content = f.read()

target = """          return DailyRoutinesPage.buildDailyRunCard(
            context,
            run,
            ref,
            Theme.of(context).brightness == Brightness.dark,
            const Color(0xFF6366F1),
            Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A),
            Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            isSuperAdmin: false, 
            isTransportAdmin: false,
          );"""

replacement = """          return _buildDailyBusRouteCard(
            context: context,
            run: run,
            cardColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            titleColor: titleColor,
            subColor: subColor,
            primaryBlue: primaryBlue,
            isDark: isDark,
          );"""

content = content.replace(target, replacement)

card_function = """

  Widget _buildDailyBusRouteCard({
    required BuildContext context,
    required Map<String, dynamic> run,
    required Color cardColor,
    required Color titleColor,
    required Color subColor,
    required Color primaryBlue,
    required bool isDark,
  }) {
    final String runName = run['run_name'] ?? 'Bus Run';
    final String runCode = run['run_code'] ?? '';
    final String status = run['status'] ?? 'PENDING';
    final String shift = run['shift_code'] ?? 'FULL_DAY';
    final String startLoc = run['start_location_name'] ?? 'Start';
    final String haltLoc = run['halt_location_name'] ?? 'Destination';
    final int stopsCount = (run['runStops'] as List?)?.length ?? 0;

    final assignments = run['assignment'] as List? ?? [];
    String vehicleNo = "No Vehicle Assigned";
    if (assignments.isNotEmpty) {
      final vNumbers = assignments.map((a) => a['vehicle']?['vehicle_number']).whereType<String>().toSet();
      if (vNumbers.isNotEmpty) vehicleNo = vNumbers.join(", ");
    }

    final int passengerCount = run['campus_in_count'] ?? (run['students'] as List?)?.length ?? 0;

    // Build Status Badge internally
    Color statusColor = Colors.grey;
    String statusText = status.replaceAll('_', ' ');
    if (status == 'PLANNED') {
      statusColor = Colors.blue;
    } else if (status == 'ONGOING' || status == 'STARTED' || status.contains('STARTED')) {
      statusColor = Colors.orange;
    } else if (status == 'COMPLETED') {
      statusColor = Colors.green;
    }

    return GestureDetector(
      onTap: () async {
        final driverStore = ref.read(driverStoreProvider);
        final profile = driverStore.profile;
        final driverId = profile['id'];

        // Find driver's assignment
        Map<String, dynamic> driverAssignment = {};
        for (var a in assignments) {
          if (a['driver']?['user']?['id'] == driverId || a['driver']?['id'] == driverId) {
            driverAssignment = a as Map<String, dynamic>;
            break;
          }
        }
        if (driverAssignment.isEmpty && assignments.isNotEmpty) {
          driverAssignment = assignments.first as Map<String, dynamic>; // Fallback
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssignmentDetailsScreen(
              assignment: driverAssignment,
              run: run,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    shift.replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: primaryBlue,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              runName,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            if (runCode.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                runCode,
                style: TextStyle(
                  fontSize: 11,
                  color: subColor.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.directions_bus_rounded, size: 14, color: primaryBlue),
                const SizedBox(width: 6),
                Text(
                  "$stopsCount Stops",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: titleColor),
                ),
                const SizedBox(width: 12),
                Icon(Icons.people_alt_rounded, size: 14, color: const Color(0xFF10B981)),
                const SizedBox(width: 6),
                Text(
                  "$passengerCount Passengers",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: titleColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryBlue.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Icon(Icons.car_repair_rounded, size: 14, color: subColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      vehicleNo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: subColor.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 20,
                      color: primaryBlue.withValues(alpha: 0.2),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        startLoc,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        haltLoc,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
"""

content = content.replace("}\n", card_function, 1)

with open('/Users/aswath/Documents/Tripzo/TMS/lib/screens/driver/driver_routes_screen.dart', 'w') as f:
    f.write(content)
print("Updated card implementation.")
