import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tripzo/store/request_store.dart';
import 'package:tripzo/screens/faculty/missions/mission_details_screen.dart';
import 'package:tripzo/screens/faculty/missions/mission_history_screen.dart';
import 'package:tripzo/screens/faculty/request/new_request_screen.dart';

class RequestListPage extends StatefulWidget {
  const RequestListPage({super.key});

  @override
  State<RequestListPage> createState() => _RequestListPageState();
}

class _RequestListPageState extends State<RequestListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestStore>().fetchRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);

    final store = context.watch<RequestStore>();
    
    // Admin sees all requests in this list, or we can filter for missions if preferred.
    // Given the request is to make it similar to "faculty mission page", 
    // we'll focus on similar statuses but maybe show all for admin.
    final missionStatuses = [1, 2, 3, 4, 5, 6, 7, 9]; 
    final missions = store.requests
        .where((req) => missionStatuses.contains(req['rawStatus']))
        .toList();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.explore_rounded,
                            color: primaryBlue,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Missions",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              final refresh = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const NewRequestScreen(),
                                ),
                              );
                              if (refresh == true) {
                                if (mounted) {
                                  context.read<RequestStore>().fetchRequests();
                                }
                              }
                            },
                            icon: Icon(
                              Icons.add_circle_outline_rounded,
                              color: primaryBlue,
                              size: 26,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MissionHistoryScreen(),
                              ),
                            ),
                            icon: Icon(
                              Icons.history_rounded,
                              color: subColor,
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Manage and monitor all fleet missions",
                    style: TextStyle(
                      color: subColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: store.isLoading && missions.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => store.fetchRequests(),
                      child: missions.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.3,
                                ),
                                Center(
                                  child: Text(
                                    "No active missions",
                                    style: TextStyle(
                                      color: subColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              itemCount: missions.length,
                              itemBuilder: (context, index) {
                                final mission = missions[index];
                                return _buildMissionCard(
                                  context,
                                  cardColor: cardColor,
                                  titleColor: titleColor,
                                  subColor: subColor,
                                  requestId: mission['dbId']?.toString() ?? mission['id']?.toString() ?? "",
                                  rawStatus: mission['rawStatus'] ?? 0,
                                  missionTitle: mission['vehicle'] ?? "Transport Request",
                                  time: mission['date'] ?? "TBD",
                                  driverName: mission['driverName'] ?? "No Driver",
                                  driverPhone: mission['driverPhone'] ?? "N/A",
                                  vehicleInfo: mission['vehicleInfo'] ?? mission['vehicle'] ?? "Pending",
                                  capacity: mission['passengers'].toString(),
                                  pathType: "Admin View",
                                  detailedStops: [
                                    {
                                      'location': mission['pickup'] ?? "Start",
                                      'eta': "Start",
                                      'type': 'Pickup',
                                    },
                                    if (mission['intermediateStops'] is List)
                                    ... (mission['intermediateStops'] as List).map((s) => {
                                      'location': s.toString(),
                                      'eta': "Transit",
                                      'type': 'Transit',
                                    }),
                                    {
                                      'location': mission['drop'] ?? "Destination",
                                      'eta': "End",
                                      'type': 'Drop',
                                    },
                                  ],
                                  status: mission['status'] ?? "Active",
                                  statusColor: _getStatusColor(mission['rawStatus']),
                                  primaryBlue: primaryBlue,
                                  creatorName: mission['faculty'] ?? "Unknown Faculty",
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(int? status) {
    switch (status) {
      case 2:
      case 5:
        return Colors.blue;
      case 4:
        return Colors.indigo;
      case 7:
        return Colors.green;
      case 9:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _buildMissionCard(
    BuildContext context, {
    required Color cardColor,
    required Color titleColor,
    required Color subColor,
    required String missionTitle,
    required String time,
    required String driverName,
    required String driverPhone,
    required String vehicleInfo,
    required String capacity,
    required String pathType,
    required List<Map<String, String>> detailedStops,
    required String status,
    required Color statusColor,
    required Color primaryBlue,
    required String requestId,
    required int rawStatus,
    required String creatorName,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MissionDetailsScreen(
            missionTitle: missionTitle,
            time: time,
            driverName: driverName,
            driverPhone: driverPhone,
            vehicleInfo: vehicleInfo,
            capacity: capacity, // Keep for vehicle capacity label if needed
            passengerCount: capacity, // Using the capacity variable which stores passengers count here
            pathType: pathType,
            stops: detailedStops,
            status: status,
            statusColor: statusColor,
            requestId: requestId,
            rawStatus: rawStatus,
            creatorName: creatorName,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
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
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 18, color: primaryBlue),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status.toUpperCase(),
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
              missionTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 14, color: subColor),
                const SizedBox(width: 4),
                Text(
                  "Created by: ",
                  style: TextStyle(
                    fontSize: 12,
                    color: subColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  creatorName,
                  style: TextStyle(
                    fontSize: 12,
                    color: primaryBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDriverMinimal(primaryBlue, driverName, vehicleInfo, subColor),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "STOP SEQUENCE",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  pathType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: primaryBlue,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...detailedStops
                .asMap()
                .entries
                .map(
                  (entry) => _buildSimpleTimelineRow(
                    entry.key,
                    entry.value['location']!,
                    entry.key == detailedStops.length - 1,
                    primaryBlue,
                    titleColor,
                    subColor,
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverMinimal(Color blue, String name, String info, Color sub) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: blue.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: blue,
            child: const Icon(Icons.person, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(info, style: TextStyle(fontSize: 12, color: sub)),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: sub.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleTimelineRow(
    int idx,
    String stop,
    bool isLast,
    Color blue,
    Color title,
    Color sub,
  ) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: idx == 0 ? blue : Colors.transparent,
                  border: Border.all(
                    color: idx == 0 ? blue : Colors.grey.shade400,
                    width: 2.5,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: Colors.grey.shade300),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Text(
                stop,
                style: TextStyle(
                  fontSize: 14,
                  color: idx == 0 ? title : sub,
                  fontWeight: idx == 0 ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
