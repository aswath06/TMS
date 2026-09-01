import re

with open('lib/screens/driver/driver_duties_screen.dart', 'r') as f:
    content = f.read()

start_idx = content.find('  Widget _buildActiveRoutesSection(')
end_idx = content.find('  Widget _buildPendingEvCard(', start_idx)

new_content = """  Widget _buildActiveRoutesSection(
    DriverStore store,
    Color titleColor,
    Color surface,
    Color primary,
    bool isDark,
    bool isTamil,
  ) {
    final activeRoutes = store.activeRoutesToComplete;
    if (activeRoutes.isEmpty) return const SizedBox.shrink();

    final validRoutes = activeRoutes.where((route) {
      final tripInstances = route['trip_instances'] as List<dynamic>? ?? [];
      final firstTrip = tripInstances.isNotEmpty ? tripInstances[0] : null;
      final endedAtStr = firstTrip?['ended_at'];
      // Only show this timer if the trip was actually ended by security
      return endedAtStr != null;
    }).toList();

    if (validRoutes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...validRoutes.map(
          (route) => _buildActiveRouteCard(
            route,
            titleColor,
            surface,
            primary,
            isDark,
            isTamil,
          ),
        ),
        const SizedBox(height: 36),
      ],
    );
  }

  Widget _buildActiveRouteCard(
    Map<String, dynamic> route,
    Color titleColor,
    Color surface,
    Color primary,
    bool isDark,
    bool isTamil,
  ) {
    final routeName = route['route_name'] ?? "Unknown Route";
    final tripInstances = route['trip_instances'] as List<dynamic>? ?? [];
    final firstTrip = tripInstances.isNotEmpty ? tripInstances[0] : null;
    final endedAtStr = firstTrip?['ended_at'];

    String remainingStr = "00:00";
    DateTime? referenceTime;
    if (endedAtStr != null) {
      referenceTime = DateTime.tryParse(endedAtStr)?.add(const Duration(minutes: 25));
    }

    if (referenceTime != null) {
      final diff = referenceTime.difference(DateTime.now());
      if (diff.isNegative) {
        remainingStr = "00:00";
      } else {
        final hours = diff.inHours;
        final minutes = diff.inMinutes % 60;
        final seconds = diff.inSeconds % 60;

        if (hours > 0) {
          remainingStr = "$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
        } else {
          remainingStr = "$minutes:${seconds.toString().padLeft(2, '0')}";
        }
      }
    }

    Color accentColor = Colors.orange;
    final diffInMinutes = referenceTime != null
        ? referenceTime.difference(DateTime.now()).inMinutes
        : 99;
    if (diffInMinutes < 5) {
      accentColor = Colors.red;
    } else if (diffInMinutes > 15) {
      accentColor = Colors.green;
    }

    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return GestureDetector(
      onTap: () {
        final List<dynamic> vehicles =
            route['vehicles'] as List<dynamic>? ?? [];
        final String vehicleInfo = vehicles.isNotEmpty
            ? vehicles[0]['vehicle_number'] ?? "N/A"
            : "N/A";

        final List<dynamic> legsList = route['legs'] as List<dynamic>? ?? [];
        final String pickup =
            legsList.isNotEmpty && (legsList[0]['stops'] as List).isNotEmpty
            ? legsList[0]['stops'][0]['stop_name'] ?? "N/A"
            : "N/A";
        final String drop =
            legsList.isNotEmpty && (legsList.last['stops'] as List).isNotEmpty
            ? legsList.last['stops'].last['stop_name'] ?? "N/A"
            : "N/A";

        final List<Map<String, String>> mappedStops = [
          {'location': pickup, 'eta': 'Start'},
          {'location': drop, 'eta': 'End'},
        ];

        final String startTime = legsList.isNotEmpty
            ? legsList[0]['planned_start_at'] ?? ""
            : "";

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MissionDetailsScreen(
              missionTitle: routeName,
              time: _formatDate(startTime),
              driverName: "You",
              driverPhone: "",
              vehicleInfo: vehicleInfo,
              capacity: "${route['passenger_count'] ?? 0} Guests",
              passengerCount: route['passenger_count']?.toString() ?? "0",
              pathType: route['trip_type'] ?? "One-Way",
              stops: mappedStops,
              status: isTamil ? "நடைபெறுகிறது" : "Ongoing",
              statusColor: Colors.orange,
              requestId: route['id'].toString(),
              rawStatus: 3, // ON_TRIP
              creatorName: route['created_by']?['name'] ?? "Admin",
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: accentColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18.5),
                  topRight: Radius.circular(18.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: accentColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isTamil ? "நிலுவையில் உள்ள ஓடோமீட்டர்" : "Pending Odometer Entry",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          remainingStr,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.route_rounded, color: primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routeName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isTamil 
                              ? "படியை சமர்ப்பிக்க கிளிக் செய்யவும்" 
                              : "Tap to complete mission & submit allowance",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios_rounded, color: subColor, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

"""

if start_idx != -1 and end_idx != -1:
    with open('lib/screens/driver/driver_duties_screen.dart', 'w') as f:
        f.write(content[:start_idx] + new_content + content[end_idx:])
    print("Successfully replaced UI logic")
else:
    print(f"Failed to find replacement indices: start_idx={start_idx}, end_idx={end_idx}")
