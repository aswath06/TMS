import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'package:tripzo/store/request_store.dart';
import 'package:tripzo/screens/faculty/missions/mission_details_screen.dart';
import 'package:tripzo/screens/faculty/missions/mission_history_screen.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestStore>().fetchRequests(isRefresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      context.read<RequestStore>().fetchNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF4F46E5);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);

    final store = context.watch<RequestStore>();
    final missionStatuses = [2, 3, 4, 5, 6, 7, 9];
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
                  const SizedBox(height: 6),
                  Text(
                    "Real-time visibility of scheduled legs",
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
                  ? _buildMissionsSkeleton(isDark, cardColor)
                  : RefreshIndicator(
                      onRefresh: () => store.fetchRequests(isRefresh: true),
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
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                itemCount: missions.length + (store.isLoading ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == missions.length) {
                                    return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: CircularProgressIndicator()));
                                  }
                                  final mission = missions[index];
                                  return _buildMissionCard(
                                    context,
                                    cardColor: cardColor,
                                    titleColor: titleColor,
                                    subColor: subColor,
                                    requestId: mission['dbId']?.toString() ?? "",
                                    rawStatus: mission['rawStatus'] ?? 0,
                                    missionTitle: mission['routeName'] ?? "Transport Request",
                                    time: mission['date'] ?? "TBD",
                                    drivers: mission['drivers'] ?? [],
                                    vehicleInfo: mission['vehicle'] ?? "Pending",
                                    capacity: mission['passengers'].toString(),
                                    pathType: mission['travelType'] ?? "One-Way",
                                    duration: mission['approx_duration']?.toString() ?? "0",
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
                                    creatorName: mission['faculty'] ?? "Faculty Member",
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

  // ══════════════════════════════════════════════════════
  //  SHIMMER SKELETON – mirrors mission card list layout
  // ══════════════════════════════════════════════════════
  Widget _buildMissionsSkeleton(bool isDark, Color cardColor) {
    final Color base = isDark ? const Color(0xFF1E293B) : Colors.grey.shade300;
    final Color highlight = isDark ? const Color(0xFF334155) : Colors.grey.shade100;

    Widget bone({
      double width = double.infinity,
      double height = 14,
      double radius = 8,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    Widget skeletonCard() {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time + status badge row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  bone(width: 18, height: 18, radius: 9),
                  const SizedBox(width: 6),
                  bone(width: 90, height: 16, radius: 8),
                ]),
                bone(width: 70, height: 24, radius: 10),
              ],
            ),
            const SizedBox(height: 14),
            // Title
            bone(width: 200, height: 20, radius: 10),
            const SizedBox(height: 12),
            // Creator
            bone(width: 160, height: 12, radius: 6),
            const SizedBox(height: 16),
            // Driver bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  bone(width: 32, height: 32, radius: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bone(width: 110, height: 14, radius: 7),
                        const SizedBox(height: 6),
                        bone(width: 80, height: 11, radius: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Stop sequence label
            bone(width: 120, height: 10, radius: 5),
            const SizedBox(height: 14),
            // Timeline rows
            ...List.generate(3, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    bone(width: 14, height: 14, radius: 7),
                    const SizedBox(width: 16),
                    bone(width: 160, height: 14, radius: 7),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: List.generate(3, (_) => skeletonCard()),
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

  // ... (Keeping your existing helper methods _buildDateBucket, _buildMissionCard, etc.)
  Widget _buildDateBucket(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider(thickness: 1.2)),
        ],
      ),
    );
  }

  Widget _buildMissionCard(
    BuildContext context, {
    required Color cardColor,
    required Color titleColor,
    required Color subColor,
    required String missionTitle,
    required String time,
    required List<dynamic> drivers,
    required String vehicleInfo,
    required String capacity,
    required String pathType,
    required String duration,
    required List<Map<String, String>> detailedStops,
    required String status,
    required Color statusColor,
    required Color primaryBlue,
    required String requestId,
    required int rawStatus,
    required String creatorName,
  }) {
    // Determine primary driver or list
    String driverNameHead = "Driver Assigned";
    String driverPhoneHead = "N/A";
    if (drivers.isNotEmpty) {
      driverNameHead = drivers[0]['name'] ?? "Assigned";
      driverPhoneHead = drivers[0]['phone'] ?? "N/A";
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MissionDetailsScreen(
            missionTitle: missionTitle,
            time: time,
            driverName: driverNameHead,
            driverPhone: driverPhoneHead,
            vehicleInfo: vehicleInfo,
            capacity: capacity,
            passengerCount: capacity,
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
                Icon(Icons.timer_outlined, size: 14, color: subColor),
                const SizedBox(width: 4),
                Text(
                  "Duration: ",
                  style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w600),
                ),
                Text(
                  "$duration mins",
                  style: TextStyle(fontSize: 12, color: titleColor, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (drivers.isEmpty)
              _buildDriverMinimal(primaryBlue, "Pending Driver", vehicleInfo, subColor)
            else
              ...drivers.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildDriverMinimal(primaryBlue, d['name'] ?? "Driver", d['status'] ?? "Assigned", subColor),
              )),
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
