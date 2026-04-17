import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/screens/faculty/missions/mission_details_screen.dart';
import 'package:tripzo/screens/driver/maintenance/fuel_page.dart';
import 'package:tripzo/screens/driver/maintenance/service_page.dart';
import 'package:tripzo/screens/driver/maintenance/accident_page.dart';
import 'package:tripzo/screens/driver/reward_points_history_screen.dart';
import '../../providers/notification_provider.dart';
import '../../components/notification_bell.dart';
import '../../utils/routes.dart';

class DriverDutiesScreen extends StatefulWidget {
  const DriverDutiesScreen({super.key});

  @override
  State<DriverDutiesScreen> createState() => _DriverDutiesScreenState();
}

class _DriverDutiesScreenState extends State<DriverDutiesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      useDriverStore.fetchProfile();
      useDriverStore.fetchMissions();
      useDriverStore.fetchRewardPoints();
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isTamil = LanguageStore.isTamil;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark, primaryBlue),
          SafeArea(
            child: Consumer<DriverStore>(
              builder: (context, store, _) {
                final profile = store.profileData.value;
                final allTasksList = List<Map<String, dynamic>>.from(store.missions);
                // Helper to normalize status for filtering
                bool isCompleted(dynamic s) {
                  if (s is int) return s >= 8;
                  if (s is String) return s.toUpperCase() == 'COMPLETED';
                  return false;
                }

                // Filter for non-completed missions and sort by date/time
                final upcoming = allTasksList.where((m) => !isCompleted(m['status'])).toList();
                upcoming.sort((a, b) {
                  final aTime = DateTime.tryParse(a['start_datetime'] ?? '') ?? DateTime(0);
                  final bTime = DateTime.tryParse(b['start_datetime'] ?? '') ?? DateTime(0);
                  return aTime.compareTo(bTime);
                });

                // Show all upcoming missions on the dashboard
                final priorityMissions = upcoming;
                final String driverName = profile?['name'] ?? (isTamil ? "ஓட்டுநர்" : "Driver");

                return RefreshIndicator(
                  onRefresh: () async {
                    await store.fetchProfile();
                    await store.fetchMissions();
                  },
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildHeader(driverName, titleColor, subColor, screenWidth, primaryBlue, isTamil),
                        const SizedBox(height: 32),
                        _buildStatCards(primaryBlue, surfaceColor, isDark, isTamil, allTasksList, profile, store),
                        const SizedBox(height: 36),
                        _buildSectionTitle(isTamil ? "இன்றைய பணிகள்" : "Your Assignments", titleColor),
                        const SizedBox(height: 18),
                        if (store.isLoadingMissions && priorityMissions.isEmpty)
                          const Center(child: CircularProgressIndicator())
                        else if (priorityMissions.isEmpty)
                          _buildEmptyState(subColor, isTamil)
                        else
                          ...priorityMissions.map((m) => _buildMissionCard(
                                context: context,
                                mission: m,
                                surface: surfaceColor,
                                primary: primaryBlue,
                                titleColor: titleColor,
                                subColor: subColor,
                                isDark: isDark,
                                isTamil: isTamil,
                              )),
                        const SizedBox(height: 36),
                        _buildMaintenanceSections(context, isDark, primaryBlue, surfaceColor, titleColor, subColor, isTamil),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color subColor, bool isTamil) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(Icons.assignment_turned_in_rounded, size: 64, color: subColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              isTamil ? "பணிகள் எதுவும் இல்லை" : "No assignments for today",
              style: TextStyle(color: subColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundDecor(bool isDark, Color primaryBlue) {
    return Positioned(
      top: -50,
      right: -50,
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primaryBlue.withValues(alpha: isDark ? 0.1 : 0.05),
        ),
      ),
    );
  }

  Widget _buildHeader(String name, Color titleColor, Color subColor, double width, Color primary, bool isTamil) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isTamil ? "நிலை: பணியில்" : "STATUS: Active Duty",
                  style: TextStyle(fontSize: 10, color: primary, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isTamil ? "வணக்கம், $name" : "Hello, $name",
                style: TextStyle(fontSize: width * 0.07, fontWeight: FontWeight.w900, color: titleColor, letterSpacing: -1.2),
              ),
            ],
          ),
        ),
        // Notification Bell Icon
        NotificationBell(iconColor: titleColor),
        const SizedBox(width: 8),
        Hero(
          tag: 'driver_avatar',
          child: CircleAvatar(
            radius: width * 0.065,
            backgroundColor: primary,
            child: CircleAvatar(
              radius: width * 0.06,
              backgroundImage: NetworkImage("https://ui-avatars.com/api/?name=$name&background=6366F1&color=fff"),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(Color primary, Color surface, bool isDark, bool isTamil, List<Map<String, dynamic>> missionList, Map<String, dynamic>? profile, DriverStore store) {
    // Helper to normalize status for filtering
    bool isCompleted(dynamic s) {
      if (s is int) return s >= 8;
      if (s is String) return s.toUpperCase() == 'COMPLETED';
      return false;
    }
    
    final pendingCount = missionList.where((m) => !isCompleted(m['status'])).length;
    final double rewardValue = double.tryParse((profile?['reward_points'] ?? "150").toString()) ?? 150.0;
    
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RewardPointsHistoryScreen()),
              ),
              child: _statItem(
                label: isTamil ? "வெகுமதி புள்ளிகள்" : "Reward Point",
                value: useDriverStore.totalPoints.toString(),
                animatedValue: useDriverStore.totalPoints.toDouble(),
                icon: Icons.military_tech_rounded,
                accentColor: const Color(0xFFF59E0B),
                surface: surface,
                isDark: isDark,
                statusLabel: isTamil ? "செயலில்" : "ACTIVE",
                statusColor: Colors.green,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _statItem(
              label: isTamil ? "நிலுவையில்" : "Pending",
              value: pendingCount.toString().padLeft(2, '0'),
              icon: Icons.assignment_late_rounded,
              accentColor: Colors.orangeAccent,
              surface: surface,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color surface,
    required bool isDark,
    String? statusLabel,
    Color? statusColor,
    double? animatedValue,
  }) {
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isDark ? 0.05 : 0.03),
              blurRadius: 20,
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor.withValues(alpha: 0.2), accentColor.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                if (statusLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (statusColor ?? accentColor).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: (statusColor ?? accentColor).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: statusColor ?? accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (animatedValue != null)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: animatedValue),
                duration: const Duration(seconds: 2),
                curve: Curves.easeOutExpo,
                builder: (context, val, child) {
                  return Text(
                    val.toInt().toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  );
                },
              )
            else
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.8));
  }

  Widget _buildMissionCard({
    required BuildContext context,
    required Map<String, dynamic> mission,
    required Color surface,
    required Color primary,
    required Color titleColor,
    required Color subColor,
    required bool isDark,
    required bool isTamil,
  }) {
    final String id = "MSN-${mission['id']}";
    final String routeName = mission['routeName'] ?? "Unknown Route";
    final String pickup = mission['startLocation'] ?? 'Unknown';
    final String drop = mission['destinationLocation'] ?? 'Unknown';
    final String time = _formatDate(mission['start_datetime']);
    final dynamic rawStatusValue = mission['status'];
    final tripStatuses = mission['trip_instance_statuses'] as List?;
    final String? tripStatus = (tripStatuses != null && tripStatuses.isNotEmpty) ? tripStatuses[0]['status']?.toString().toUpperCase() : null;
    
    // Status Logic - Using backend status directly as requested (matching My Journey logic)
    final String backendStatus = (mission['status'] ?? "UNKNOWN").toString().toUpperCase();
    String statusStr = backendStatus;
    Color statusColor = Colors.grey;

    if (backendStatus == 'READY' || backendStatus == 'APPROVED' || backendStatus == 'PLANNED' || backendStatus == 'ASSIGNED') {
      if (isTamil) statusStr = "ஒதுக்கப்பட்டது";
      statusColor = Colors.blue;
    } else if (backendStatus == 'ON_TRIP' || backendStatus == 'STARTED' || backendStatus == 'ONGOING') {
      if (isTamil) statusStr = "நடைபெறுகிறது";
      statusColor = Colors.orange;
    } else if (backendStatus == 'COMPLETED' || backendStatus == 'FINISHED') {
      if (isTamil) statusStr = "முடிந்தது";
      statusColor = Colors.green;
    } else if (backendStatus == 'REJECTED' || backendStatus == 'CANCELLED' || backendStatus == 'DRAFT') {
      if (isTamil) statusStr = "ரத்து செய்யப்பட்டது";
      statusColor = backendStatus == 'DRAFT' ? Colors.amber : Colors.red;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MissionDetailsScreen(
            missionTitle: routeName,
            time: time,
            driverName: "You",
            driverPhone: "",
            vehicleInfo: mission['vehiclePlate'] != null 
                ? "${mission['vehicleType'] ?? 'Vehicle'} (${mission['vehiclePlate']})" 
                : "Vehicle #${mission['vehicleAssigned']}",
            capacity: "${mission['passengerCount']} Guests",
            passengerCount: mission['passengerCount']?.toString() ?? "0",
            pathType: mission['travelType'] ?? "One-Way",
            stops: [
              {'location': pickup, 'eta': 'Start'},
              if (mission['intermediateStops'] is List)
                ...(mission['intermediateStops'] as List).map((s) {
                  if (s is Map) return {'location': (s['stop_name'] ?? '').toString(), 'eta': 'Transit'};
                  return {'location': s.toString(), 'eta': 'Transit'};
                }),
              {'location': drop, 'eta': 'End'},
            ],
            status: statusStr,
            statusColor: statusColor,
            requestId: mission['id'].toString(),
            rawStatus: rawStatusValue is int ? rawStatusValue : 0,
            creatorName: mission['createdBy']?['name'] ?? "Admin",
          ),
        ),
      ),
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
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: primary),
                    const SizedBox(width: 6),
                    Text(time, style: TextStyle(fontWeight: FontWeight.w800, color: subColor, fontSize: 13)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Text(statusStr.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(routeName, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: titleColor)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_pin_circle_rounded, size: 14, color: subColor),
                const SizedBox(width: 4),
                Text("${isTamil ? 'உருவாக்கியவர்' : 'Created by'}: ", style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w600)),
                Text(mission['createdBy']?['name'] ?? "Admin", style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 20),
            _buildTimeline(pickup, drop, primary, titleColor),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _iconInfo(Icons.assignment_ind_rounded, id, isDark),
                 _iconInfo(
                  Icons.directions_car_filled_rounded, 
                  mission['vehiclePlate'] ?? "Vehicle #${mission['vehicleAssigned']}", 
                  isDark
                ),
                _iconInfo(Icons.group_rounded, "${mission['passengerCount']} ${isTamil ? 'பயணிகள்' : 'Guests'}", isDark),
              ],
            ),
            // OTP Button removed as per requirement (only show in details screen)
          ],
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

  Widget _iconInfo(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.black26),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black54)),
      ],
    );
  }

  Widget _buildMaintenanceSections(BuildContext context, bool isDark, Color primary, Color surface, Color titleColor, Color subColor, bool isTamil) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(isTamil ? "பராமரிப்பு" : "Maintenance", titleColor),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _buildNavigationCard(
                context: context,
                title: isTamil ? "எரிபொருள்" : "Fuel Entry",
                subtitle: isTamil ? "பதிவு செய்யவும்" : "Log Refill",
                icon: Icons.local_gas_station_rounded,
                color: const Color(0xFF3B82F6),
                isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FuelPage())),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildNavigationCard(
                context: context,
                title: isTamil ? "விபத்து" : "Accident Entry",
                subtitle: isTamil ? "சம்பவத்தை பதிவு செய்யவும்" : "Report Incident",
                icon: Icons.report_problem_rounded,
                color: const Color(0xFFEF4444),
                isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccidentPage())),
              ),
            ),
            // Expanded(
            //   child: _buildNavigationCard(
            //     context: context,
            //     title: isTamil ? "சேவை" : "Service Entry",
            //     subtitle: isTamil ? "பதிவு செய்யவும்" : "Log Maintenance",
            //     icon: Icons.home_repair_service_rounded,
            //     color: const Color(0xFF10B981),
            //     isDark: isDark,
            //     onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ServicePage())),
            //   ),
            // ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }


  String _formatDate(String? dateStr) {
    if (dateStr == null) return "TBD";
    try {
      final dt = DateTime.parse(dateStr);
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${dt.day} ${months[dt.month - 1]}, ${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
    } catch (_) {
      return dateStr;
    }
  }
}
