import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/screens/faculty/missions/mission_details_screen.dart';
import 'package:tripzo/screens/driver/maintenance/accident_page.dart';
import 'package:tripzo/screens/driver/reward_points_history_screen.dart';
import 'package:tripzo/screens/driver/driver_allowance_screen.dart';
import 'package:tripzo/screens/driver/maintenance/complete_fuel_entry_page.dart';
import '../../providers/notification_provider.dart';
import '../../components/notification_bell.dart';
import '../../utils/routes.dart';
import '../main_screen.dart';
import 'dart:async';

class DriverDutiesScreen extends ConsumerStatefulWidget {
  const DriverDutiesScreen({super.key});

  @override
  ConsumerState<DriverDutiesScreen> createState() => _DriverDutiesScreenState();
}

class _DriverDutiesScreenState extends ConsumerState<DriverDutiesScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      useDriverStore.fetchProfile();
      useDriverStore.fetchMissions();
      useDriverStore.fetchRewardPoints();
      useDriverStore.fetchPendingFuelEntries();
      useDriverStore.fetchActiveRoutesToComplete();
      useDriverStore.fetchPendingAllowanceCount();
      ref.read(notificationProviderFamily).fetchNotifications();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
            child: Consumer(
builder: (context, ref, _) {
final store = ref.watch(driverStoreProvider);
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

                // Show only the most immediate upcoming mission on the dashboard
                final priorityMissions = upcoming.take(1).toList();
                final String driverName = profile?['name'] ?? (isTamil ? "ஓட்டுநர்" : "Driver");

                return RefreshIndicator(
                  onRefresh: () async {
                    await store.fetchProfile();
                    await store.fetchMissions();
                    await store.fetchPendingFuelEntries();
                    await store.fetchActiveRoutesToComplete();
                    await store.fetchPendingAllowanceCount();
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
                        _buildActiveRoutesSection(store, titleColor, surfaceColor, primaryBlue, isDark, isTamil),
                        const SizedBox(height: 36),
                        _buildPendingFuelSection(store, titleColor, surfaceColor, primaryBlue, isDark, isTamil),
                        const SizedBox(height: 36),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _buildSectionTitle("${isTamil ? "இன்றைய பணிகள்" : "Your Assignments"} (${upcoming.length})", titleColor),
                            ),
                            const SizedBox(width: 12),
                            if (upcoming.length > 1)
                              GestureDetector(
                                onTap: () {
                                  final mainState = context.findAncestorStateOfType<MainScreenState>();
                                  if (mainState != null) {
                                    mainState.setIndex(1);
                                  }
                                },
                                child: Text(
                                  isTamil ? "அனைத்தையும் பார்" : "View All",
                                  style: TextStyle(
                                    color: primaryBlue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
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
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DriverAllowanceScreen()),
              ),
              child: _statItem(
                label: isTamil ? "படி" : "Allowance",
                value: store.pendingAllowanceCount.toString().padLeft(2, '0'),
                icon: Icons.payments_rounded,
                accentColor: Colors.orangeAccent,
                surface: surface,
                isDark: isDark,
              ),
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
    return Text(
      title, 
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.8),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
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
                title: isTamil ? "விபத்து" : "Accident Entry",
                subtitle: isTamil ? "சம்பவத்தை பதிவு செய்யவும்" : "Report Incident",
                icon: Icons.report_problem_rounded,
                color: const Color(0xFFEF4444),
                isDark: isDark,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccidentPage())),
              ),
            ),
            const SizedBox(width: 16),
            const Spacer(),
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


  Widget _buildPendingFuelSection(DriverStore store, Color titleColor, Color surfaceColor, Color primaryBlue, bool isDark, bool isTamil) {
    if (store.pendingFuelEntries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(isTamil ? "எரிபொருள் பதிவு நிலுவையில் உள்ளது (${store.pendingFuelEntries.length})" : "Fuel Entry Pending (${store.pendingFuelEntries.length})", titleColor),
        const SizedBox(height: 18),
        ...store.pendingFuelEntries.map((entry) => _buildFuelPendingCard(
          entry: entry,
          surface: surfaceColor,
          primary: primaryBlue,
          titleColor: titleColor,
          subColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          isDark: isDark,
          isTamil: isTamil,
        )),
      ],
    );
  }

  Widget _buildFuelPendingCard({
    required Map<String, dynamic> entry,
    required Color surface,
    required Color primary,
    required Color titleColor,
    required Color subColor,
    required bool isDark,
    required bool isTamil,
  }) {
    final vehicleNumber = entry['vehicle']?['vehicle_number'] ?? "N/A";
    final driverName = entry['driver']?['user']?['name'] ?? "N/A";
    final instanceId = entry['instance_id'] ?? "N/A";
    final bunkName = entry['bunk']?['name'] ?? "N/A";
    final fuelType = entry['vehicle']?['fuel_type'] ?? "N/A";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CompleteFuelEntryPage(entry: entry),
          ),
        ).then((result) {
          if (result == true) {
            useDriverStore.fetchPendingFuelEntries();
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: isDark ? 0.1 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_gas_station_rounded, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicleNumber,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: titleColor),
                      ),
                      Text(
                        isTamil ? "வாகன எண்" : "Vehicle Number",
                        style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isTamil ? "நிலுவையில்" : "PENDING",
                    style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
            const Divider(height: 32, thickness: 1),
            Row(
              children: [
                Expanded(
                  child: _buildCardDetail(
                    icon: Icons.person_rounded,
                    label: isTamil ? "ஓட்டுநர்" : "Driver",
                    value: driverName,
                    subColor: subColor,
                    titleColor: titleColor,
                  ),
                ),
                Expanded(
                  child: _buildCardDetail(
                    icon: Icons.tag_rounded,
                    label: isTamil ? "நிகழ்வு ஐடி" : "Instance ID",
                    value: instanceId,
                    subColor: subColor,
                    titleColor: titleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCardDetail(
                    icon: Icons.store_rounded,
                    label: isTamil ? "பங்க் பெயர்" : "Bunk Name",
                    value: bunkName,
                    subColor: subColor,
                    titleColor: titleColor,
                  ),
                ),
                Expanded(
                  child: _buildCardDetail(
                    icon: Icons.local_gas_station_rounded,
                    label: isTamil ? "எரிபொருள் வகை" : "Fuel Type",
                    value: fuelType,
                    subColor: subColor,
                    titleColor: titleColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardDetail({
    required IconData icon,
    required String label,
    required String value,
    required Color subColor,
    required Color titleColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: subColor.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: subColor, fontWeight: FontWeight.w600),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "TBD";
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${dt.day} ${months[dt.month - 1]}, ${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildActiveRoutesSection(DriverStore store, Color titleColor, Color surface, Color primary, bool isDark, bool isTamil) {
    final activeRoutes = store.activeRoutesToComplete;
    if (activeRoutes.isEmpty) return const SizedBox.shrink();

    // Filter routes based on the 15-minute rule
    final validRoutes = activeRoutes.where((route) {
      final tripInstances = route['trip_instances'] as List<dynamic>? ?? [];
      final firstTrip = tripInstances.isNotEmpty ? tripInstances[0] : null;
      final endedAtStr = firstTrip?['ended_at'];
      
      if (endedAtStr != null) {
        final endedAt = DateTime.tryParse(endedAtStr);
        if (endedAt == null) return false;
        // If ended, show only until 15 minutes after the actual end time
        return DateTime.now().isBefore(endedAt.add(const Duration(minutes: 15)));
      } else {
        // If not ended yet (active), show based on planned end time (if available)
        final legs = route['legs'] as List<dynamic>? ?? [];
        if (legs.isEmpty) return true; // Show active trips without legs too
        final lastLeg = legs.last;
        final plannedEndAt = DateTime.tryParse(lastLeg['planned_end_at'] ?? '');
        if (plannedEndAt == null) return true;
        // For ongoing trips, show until planned end + 15 mins (grace period)
        return DateTime.now().isBefore(plannedEndAt.add(const Duration(minutes: 15)));
      }
    }).toList();

    if (validRoutes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...validRoutes.map((route) => _buildActiveRouteCard(route, titleColor, surface, primary, isDark, isTamil)),
      ],
    );
  }

  Widget _buildActiveRouteCard(Map<String, dynamic> route, Color titleColor, Color surface, Color primary, bool isDark, bool isTamil) {
    final routeName = route['route_name'] ?? "Unknown Route";
    final legs = route['legs'] as List<dynamic>? ?? [];
    final lastLeg = legs.isNotEmpty ? legs.last : null;
    final plannedEndAt = lastLeg != null ? DateTime.tryParse(lastLeg['planned_end_at'] ?? '') : null;
    
    String remainingStr = "00:00";
    final tripInstances = route['trip_instances'] as List<dynamic>? ?? [];
    final firstTrip = tripInstances.isNotEmpty ? tripInstances[0] : null;
    final endedAtStr = firstTrip?['ended_at'];
    
    DateTime? referenceTime;
    if (endedAtStr != null) {
      referenceTime = DateTime.tryParse(endedAtStr)?.add(const Duration(minutes: 15));
    } else {
      final lastLeg = legs.isNotEmpty ? legs.last : null;
      if (lastLeg != null) {
        referenceTime = DateTime.tryParse(lastLeg['planned_end_at'] ?? '')?.add(const Duration(minutes: 15));
      }
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
          remainingStr = "${hours}:${minutes.toString().padLeft(2, '0')}";
        } else {
          remainingStr = "${minutes}:${seconds.toString().padLeft(2, '0')}";
        }
      }
    }

    Color accentColor = Colors.orange;
    final diffInMinutes = referenceTime != null ? referenceTime.difference(DateTime.now()).inMinutes : 99;
    if (diffInMinutes < 5) {
      accentColor = Colors.red;
    }

    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return GestureDetector(
      onTap: () {
        final List<dynamic> vehicles = route['vehicles'] as List<dynamic>? ?? [];
        final String vehicleInfo = vehicles.isNotEmpty ? vehicles[0]['vehicle_number'] ?? "N/A" : "N/A";
        
        final List<dynamic> legsList = route['legs'] as List<dynamic>? ?? [];
        final String pickup = legsList.isNotEmpty && (legsList[0]['stops'] as List).isNotEmpty 
            ? legsList[0]['stops'][0]['stop_name'] ?? "N/A" 
            : "N/A";
        final String drop = legsList.isNotEmpty && (legsList.last['stops'] as List).isNotEmpty 
            ? legsList.last['stops'].last['stop_name'] ?? "N/A" 
            : "N/A";
            
        final List<Map<String, String>> mappedStops = [
          {'location': pickup, 'eta': 'Start'},
          {'location': drop, 'eta': 'End'},
        ];

        final String startTime = legsList.isNotEmpty ? legsList[0]['planned_start_at'] ?? "" : "";

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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, color: accentColor, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                routeName,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: titleColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              remainingStr,
              style: TextStyle(
                fontSize: 15, 
                fontWeight: FontWeight.w800, 
                color: accentColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, color: accentColor.withValues(alpha: 0.5), size: 12),
          ],
        ),
      ),
    );
  }
}
