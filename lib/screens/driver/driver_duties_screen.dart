import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/battery_vehicle_store.dart';
import 'package:tripzo/utils/toast_utils.dart';
import 'package:tripzo/utils/ev_countdown_timer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/driver_task_store.dart';
import 'package:tripzo/utils/emergency_task_dialog.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/screens/faculty/missions/mission_details_screen.dart';
import 'package:tripzo/screens/driver/maintenance/accident_page.dart';
import 'package:tripzo/screens/driver/maintenance/fuel_options_page.dart';
import 'package:tripzo/screens/driver/reward_points_history_screen.dart';
import 'package:tripzo/screens/driver/driver_allowance_screen.dart';
import 'package:tripzo/screens/driver/maintenance/complete_fuel_entry_page.dart';
import 'package:tripzo/screens/driver/assignment_details_screen.dart';
import 'package:tripzo/utils/tab_notification.dart';
import 'package:tripzo/screens/driver/DriverProfileScreen.dart';
import 'package:tripzo/screens/driver/schedule_details_page.dart';
import 'package:tripzo/store/driver_schedules_store.dart';

import '../../components/notification_bell.dart';
import 'dart:async';

class DriverDutiesScreen extends ConsumerStatefulWidget {
  const DriverDutiesScreen({super.key});

  @override
  ConsumerState<DriverDutiesScreen> createState() => _DriverDutiesScreenState();
}

class _DriverDutiesScreenState extends ConsumerState<DriverDutiesScreen> {
  Timer? _timer;
  Timer? _taskPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      useDriverStore.fetchProfile();
      useDriverStore.fetchMissions();
      useDriverStore.fetchDailyBusRuns();
      useDriverStore.fetchRewardPoints();
      useDriverStore.fetchTodayKm();
      useDriverStore.fetchPendingFuelEntries();
      useDriverStore.fetchActiveRoutesToComplete();
      useDriverStore.fetchPendingAllowanceCount();
      ref.read(notificationProviderFamily).fetchNotifications();
      ref.read(driverSchedulesStoreProvider).fetchSchedules();
      ref.read(batteryVehicleStoreProvider).fetchEvSchedules().then((_) {
        if (mounted)
          ref.read(batteryVehicleStoreProvider).fetchDriverBookings();
      });
      _checkPendingEmergencyTask();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });

    _taskPollTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (mounted) {
        await ref.read(driverTaskStoreProvider).fetchAllTasks(isRefresh: true);
      }
    });
  }

  void _checkPendingEmergencyTask() {
    final store = ref.read(driverTaskStoreProvider);
    if (store.pendingEmergencyTaskPopup != null) {
      final task = store.pendingEmergencyTaskPopup!;
      store.clearEmergencyTaskPopup();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showEmergencyTaskPopupDialog(context, task);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _taskPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DriverTaskStore>(driverTaskStoreProvider, (previous, next) {
      if (next.pendingEmergencyTaskPopup != null) {
        final task = next.pendingEmergencyTaskPopup!;
        next.clearEmergencyTaskPopup();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            showEmergencyTaskPopupDialog(context, task);
          }
        });
      }
    });

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
                final scheduleStore = ref.watch(driverSchedulesStoreProvider);
                final profile = store.profileData.value;
                final List<Map<String, dynamic>> allAssignments = [];
                for (var run in store.dailyBusRuns) {
                  final assignmentsList = run['assignment'] as List? ?? [];
                  for (var a in assignmentsList) {
                    final status = run['status'];
                    if (status?.toString().toUpperCase() == 'COMPLETED')
                      continue;

                    final startLoc = run['start_location_name'] ?? 'Start';
                    final haltLoc = run['halt_location_name'] ?? 'Halt';
                    allAssignments.add({
                      ...a,
                      'run_status': status,
                      'start_location_name': startLoc,
                      'halt_location_name': haltLoc,
                      'run_data': run,
                    });
                  }
                }

                // Sort assignments: Group by run ID, then dynamically order Morning/Evening based on status.
                allAssignments.sort((a, b) {
                  int runA = (a['run_data']['id'] ?? 0);
                  int runB = (b['run_data']['id'] ?? 0);
                  if (runA != runB)
                    return runA.compareTo(
                      runB,
                    ); // Oldest runs first (Today before Tomorrow)

                  final status =
                      a['run_status']?.toString().toUpperCase() ?? '';
                  final shiftA =
                      a['shift_code']?.toString().toUpperCase() ?? '';
                  final shiftB =
                      b['shift_code']?.toString().toUpperCase() ?? '';

                  final eveningFirstStatuses = [
                    'FN_COMPLETED',
                    'AN_STARTED',
                    'DEPARTED_CAMPUS',
                    'RESUMED_MIDWAY',
                    'MERGED_HALTED',
                    'HALTED',
                    'COMPLETED',
                  ];
                  bool eveningFirst = eveningFirstStatuses.contains(status);

                  int weightA = shiftA == 'EVENING'
                      ? (eveningFirst ? 0 : 1)
                      : (eveningFirst ? 1 : 0);
                  int weightB = shiftB == 'EVENING'
                      ? (eveningFirst ? 0 : 1)
                      : (eveningFirst ? 1 : 0);

                  return weightA.compareTo(weightB);
                });

                final now = DateTime.now();
                final List<Map<String, dynamic>> todayMissions = store.missions
                    .where((m) {
                      final dtStr = m['start_datetime'];
                      if (dtStr == null) return false;
                      try {
                        final dt = DateTime.parse(dtStr).toLocal();
                        final backendStatus = (m['status'] ?? "UNKNOWN")
                            .toString()
                            .toUpperCase();
                        final isStarted =
                            backendStatus == 'STARTED' ||
                            backendStatus == 'ON_TRIP' ||
                            backendStatus == 'ONGOING';
                        return (dt.year == now.year &&
                                dt.month == now.month &&
                                dt.day == now.day) ||
                            isStarted;
                      } catch (_) {
                        return false;
                      }
                    })
                    .toList();

                final List<Map<String, dynamic>> dashboardSchedules = [];
                // Prepend started schedules (except completed ones)
                for (var s in scheduleStore.startedSchedules) {
                  final dutyShift = s['dutyShift'] as Map? ?? {};
                  final String shiftStatus = (dutyShift['status'] ?? 'PLANNED')
                      .toString()
                      .toUpperCase();
                  if (shiftStatus != 'COMPLETED') {
                    dashboardSchedules.add(s);
                  }
                }
                // Prepend today's schedules (except completed ones and already started ones)
                for (var s in scheduleStore.todaySchedules) {
                  final dutyShift = s['dutyShift'] as Map? ?? {};
                  final String shiftStatus = (dutyShift['status'] ?? 'PLANNED')
                      .toString()
                      .toUpperCase();
                  if (shiftStatus != 'COMPLETED' &&
                      !dashboardSchedules.any(
                        (item) => item['id'] == s['id'],
                      )) {
                    dashboardSchedules.add(s);
                  }
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await store.fetchProfile();
                    await store.fetchMissions();
                    await store.fetchDailyBusRuns();
                    await store.fetchPendingFuelEntries();
                    await store.fetchActiveRoutesToComplete();
                    await store.fetchPendingAllowanceCount();
                    await ref
                        .read(driverSchedulesStoreProvider)
                        .fetchSchedules(isRefresh: true);
                    await ref
                        .read(batteryVehicleStoreProvider)
                        .fetchEvSchedules();
                    ref.read(batteryVehicleStoreProvider).fetchDriverBookings();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.06,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildHeader(
                          profile?['name'] ?? (isTamil ? "ஓட்டுநர்" : "Driver"),
                          profile?['profile_photo'],
                          titleColor,
                          subColor,
                          screenWidth,
                          primaryBlue,
                          isTamil,
                        ),
                        const SizedBox(height: 32),

                        _buildPendingEvBookingsSection(
                          ref,
                          primaryBlue,
                          surfaceColor,
                          titleColor,
                          subColor,
                          isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildStatCards(
                          primaryBlue,
                          surfaceColor,
                          isDark,
                          isTamil,
                          profile,
                          store,
                        ),
                        const SizedBox(height: 16),
                        _buildKilometerCard(
                          store,
                          surfaceColor,
                          isDark,
                          isTamil,
                        ),
                        const SizedBox(height: 36),
                        _buildActiveRoutesSection(
                          store,
                          titleColor,
                          surfaceColor,
                          primaryBlue,
                          isDark,
                          isTamil,
                        ),
                        _buildPendingFuelSection(
                          store,
                          titleColor,
                          surfaceColor,
                          primaryBlue,
                          isDark,
                          isTamil,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _buildSectionTitle(
                                "${isTamil ? "இன்றைய பணிகள்" : "Your Assignments"} (${allAssignments.length + todayMissions.length + dashboardSchedules.length})",
                                titleColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (store.isLoadingBusRuns &&
                            allAssignments.isEmpty &&
                            dashboardSchedules.isEmpty)
                          const Center(child: CircularProgressIndicator())
                        else if (allAssignments.isEmpty &&
                            dashboardSchedules.isEmpty)
                          _buildEmptyState(subColor, isTamil)
                        else ...[
                          ...dashboardSchedules.map(
                            (s) => _buildScheduleCard(
                              context: context,
                              schedule: s,
                              cardColor: surfaceColor,
                              titleColor: titleColor,
                              subColor: subColor,
                              primaryBlue: primaryBlue,
                              isDark: isDark,
                              isTamil: isTamil,
                            ),
                          ),
                          ...allAssignments.map(
                            (a) => _buildAssignmentCard(
                              context: context,
                              assignment: a,
                              surface: surfaceColor,
                              primary: primaryBlue,
                              titleColor: titleColor,
                              subColor: subColor,
                              isDark: isDark,
                              isTamil: isTamil,
                            ),
                          ),
                        ],
                        const SizedBox(height: 36),
                        _buildMaintenanceSections(
                          context,
                          isDark,
                          primaryBlue,
                          surfaceColor,
                          titleColor,
                          subColor,
                          isTamil,
                        ),
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
            Icon(
              Icons.assignment_turned_in_rounded,
              size: 64,
              color: subColor.withValues(alpha: 0.3),
            ),
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
    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -40,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primaryBlue.withValues(alpha: isDark ? 0.15 : 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 100,
          left: -80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.orangeAccent.withValues(alpha: isDark ? 0.08 : 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    String name,
    String? profilePhoto,
    Color titleColor,
    Color subColor,
    double width,
    Color primary,
    bool isTamil,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  border: Border.all(color: primary.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_rounded, color: primary, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      "STATUS: ON DUTY",
                      style: TextStyle(
                        fontSize: 10,
                        color: primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Welcome Back,",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: subColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: width * 0.07,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Notification Bell Icon
        NotificationBell(iconColor: titleColor),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DriverProfileScreen()),
            );
          },
          child: Hero(
            tag: 'driver_avatar',
            child: CircleAvatar(
              radius: width * 0.065,
              backgroundColor: primary,
              child: CircleAvatar(
                radius: width * 0.06,
                backgroundImage: profilePhoto != null
                    ? NetworkImage(ApiConstants.getImageUrl(profilePhoto))
                    : NetworkImage(
                            "https://ui-avatars.com/api/?name=$name&background=6366F1&color=fff",
                          )
                          as ImageProvider,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(
    Color primary,
    Color surface,
    bool isDark,
    bool isTamil,
    Map<String, dynamic>? profile,
    DriverStore store,
  ) {
    final double rewardValue =
        double.tryParse((profile?['reward_points'] ?? "150").toString()) ??
        150.0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RewardPointsHistoryScreen(),
                ),
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
                MaterialPageRoute(
                  builder: (context) => const DriverAllowanceScreen(),
                ),
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

  Widget _buildKilometerCard(
    DriverStore store,
    Color surface,
    bool isDark,
    bool isTamil,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [Colors.white, const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(isDark ? 0.15 : 0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.15),
                  const Color(0xFF8B5CF6).withOpacity(0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.speed_rounded,
              color: Color(0xFF6366F1),
              size: 36,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isTamil ? "இன்றைய கி.மீ" : "Today's Distance",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        store.todayTotalKm.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          "KM",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
        gradient: LinearGradient(
          colors: [
            surface,
            isDark ? const Color(0xFF1E293B).withOpacity(0.8) : Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(isDark ? 0.15 : 0.08),
            blurRadius: 24,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withOpacity(0.2),
                      accentColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              if (statusLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (statusColor ?? accentColor).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (statusColor ?? accentColor).withValues(
                        alpha: 0.2,
                      ),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: statusColor ?? accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (animatedValue != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: animatedValue),
                duration: const Duration(seconds: 2),
                curve: Curves.easeOutExpo,
                builder: (context, val, child) {
                  return Text(
                    val.toInt().toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                  );
                },
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                maxLines: 1,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w700,
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
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: -0.8,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  Widget _buildAssignmentCard({
    required BuildContext context,
    required Map<String, dynamic> assignment,
    required Color surface,
    required Color primary,
    required Color titleColor,
    required Color subColor,
    required bool isDark,
    required bool isTamil,
  }) {
    final shiftCode = assignment['shift_code'] ?? 'UNKNOWN';
    final startTime = _formatDate(assignment['planned_start_time']);
    final endTime = _formatDate(assignment['planned_end_time']);
    final vehicleNumber =
        assignment['vehicle']?['vehicle_number'] ?? 'Unknown Vehicle';
    final statusStr = assignment['run_status'] ?? 'UNKNOWN';

    final routeCode =
        assignment['run_data']?['dailyBusRoute']?['route_code'] ?? '';
    final String? runName = assignment['run_data']?['run_name']?.toString();
    final String? runCode = assignment['run_data']?['run_code']?.toString();

    String routeName = "Unnamed Route";
    if (runName != null && runName.trim().isNotEmpty && runName != 'null') {
      routeName = runName;
    } else if (runCode != null &&
        runCode.trim().isNotEmpty &&
        runCode != 'null') {
      routeName = runCode;
    }

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
    } else if (statusStr == 'ONGOING')
      statusColor = Colors.orange;
    else if (statusStr == 'COMPLETED')
      statusColor = Colors.grey;

    bool isEnabled = true;
    if (shiftCode == 'EVENING') {
      final validStatuses = [
        'FN_COMPLETED',
        'AN_STARTED',
        'DEPARTED_CAMPUS',
        'RESUMED_MIDWAY',
        'MERGED_HALTED',
        'HALTED',
        'COMPLETED',
      ];
      if (!validStatuses.contains(statusStr.toUpperCase())) {
        isEnabled = false;
      }
    }

    return GestureDetector(
      onTap: isEnabled
          ? () {
              final Map<String, dynamic> runData =
                  (assignment['run_data'] as Map?)?.cast<String, dynamic>() ??
                  <String, dynamic>{};
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AssignmentDetailsScreen(
                    assignment: assignment,
                    run: runData,
                  ),
                ),
              );
            }
          : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: primary.withValues(alpha: 0.1),
              width: 1.5,
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            shiftCode == 'EVENING'
                                ? Icons.nights_stay_rounded
                                : Icons.wb_sunny_rounded,
                            color: primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              routeCode.isNotEmpty
                                  ? routeCode
                                  : (isTamil ? "பணி" : "Bus Route"),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: primary,
                                fontSize: 16,
                              ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: shiftCode == 'MORNING'
                                ? Colors.orange.withValues(alpha: 0.12)
                                : primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            shiftCode,
                            style: TextStyle(
                              color: shiftCode == 'MORNING'
                                  ? Colors.orange
                                  : primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusStr.toUpperCase(),
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
                              Text(
                                isTamil ? "பாதை" : "Route Name",
                                style: TextStyle(
                                  color: subColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                routeName,
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: subColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.directions_car_rounded,
                                size: 14,
                                color: titleColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                vehicleNumber,
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
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
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isTamil
                                    ? "திட்டமிட்ட தொடக்கம்"
                                    : "Planned Start",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_filled_rounded,
                                    size: 14,
                                    color: primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    startTime,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: titleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isTamil ? "திட்டமிட்ட முடிவு" : "Planned End",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_filled_rounded,
                                    size: 14,
                                    color: Colors.orangeAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    endTime,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: titleColor,
                                    ),
                                  ),
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
    final String? tripStatus = (tripStatuses != null && tripStatuses.isNotEmpty)
        ? tripStatuses[0]['status']?.toString().toUpperCase()
        : null;

    // Status Logic - Using backend status directly as requested (matching My Journey logic)
    final String backendStatus = (mission['status'] ?? "UNKNOWN")
        .toString()
        .toUpperCase();
    String statusStr = backendStatus;
    Color statusColor = Colors.grey;

    if (backendStatus == 'READY' ||
        backendStatus == 'APPROVED' ||
        backendStatus == 'PLANNED' ||
        backendStatus == 'ASSIGNED') {
      if (isTamil) statusStr = "ஒதுக்கப்பட்டது";
      statusColor = Colors.blue;
    } else if (backendStatus == 'ON_TRIP' ||
        backendStatus == 'STARTED' ||
        backendStatus == 'ONGOING') {
      if (isTamil) statusStr = "நடைபெறுகிறது";
      statusColor = Colors.orange;
    } else if (backendStatus == 'COMPLETED' || backendStatus == 'FINISHED') {
      if (isTamil) statusStr = "முடிந்தது";
      statusColor = Colors.green;
    } else if (backendStatus == 'REJECTED' ||
        backendStatus == 'CANCELLED' ||
        backendStatus == 'DRAFT') {
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
                  if (s is Map)
                    return {
                      'location': (s['stop_name'] ?? '').toString(),
                      'eta': 'Transit',
                    };
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
                    Text(
                      time,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: subColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusStr.toUpperCase(),
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
            const SizedBox(height: 18),
            Text(
              routeName,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.person_pin_circle_rounded,
                  size: 14,
                  color: subColor,
                ),
                const SizedBox(width: 4),
                Text(
                  "${isTamil ? 'உருவாக்கியவர்' : 'Created by'}: ",
                  style: TextStyle(
                    fontSize: 12,
                    color: subColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  mission['createdBy']?['name'] ?? "Admin",
                  style: TextStyle(
                    fontSize: 12,
                    color: primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
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
                  mission['vehiclePlate'] ??
                      "Vehicle #${mission['vehicleAssigned']}",
                  isDark,
                ),
                _iconInfo(
                  Icons.group_rounded,
                  "${mission['passengerCount']} ${isTamil ? 'பயணிகள்' : 'Guests'}",
                  isDark,
                ),
              ],
            ),
            // OTP Button removed as per requirement (only show in details screen)
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(
    String pickup,
    String drop,
    Color primary,
    Color title,
  ) {
    return Row(
      children: [
        Column(
          children: [
            Icon(Icons.radio_button_checked, color: primary, size: 18),
            Container(
              width: 2,
              height: 20,
              color: primary.withValues(alpha: 0.2),
            ),
            Icon(
              Icons.location_on,
              color: Colors.redAccent.withValues(alpha: 0.7),
              size: 18,
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pickup,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: title,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 18),
              Text(
                drop,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: title,
                ),
                overflow: TextOverflow.ellipsis,
              ),
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
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildMaintenanceSections(
    BuildContext context,
    bool isDark,
    Color primary,
    Color surface,
    Color titleColor,
    Color subColor,
    bool isTamil,
  ) {
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
                subtitle: isTamil ? "எரிபொருள் பதிவு" : "Log Refuel",
                icon: Icons.local_gas_station_rounded,
                color: const Color(0xFFF59E0B),
                isDark: isDark,
                surface: surface,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FuelOptionsPage()),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildNavigationCard(
                context: context,
                title: isTamil ? "விபத்து" : "Accident Entry",
                subtitle: isTamil
                    ? "சம்பவத்தை பதிவு செய்யவும்"
                    : "Report Incident",
                icon: Icons.report_problem_rounded,
                color: const Color(0xFFEF4444),
                isDark: isDark,
                surface: surface,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AccidentPage()),
                ),
              ),
            ),
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
    required Color surface,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.05 : 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingFuelSection(
    DriverStore store,
    Color titleColor,
    Color surfaceColor,
    Color primaryBlue,
    bool isDark,
    bool isTamil,
  ) {
    if (store.pendingFuelEntries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          isTamil
              ? "எரிபொருள் பதிவு நிலுவையில் உள்ளது (${store.pendingFuelEntries.length})"
              : "Fuel Entry Pending (${store.pendingFuelEntries.length})",
          titleColor,
        ),
        const SizedBox(height: 18),
        ...store.pendingFuelEntries.map(
          (entry) => _buildFuelPendingCard(
            entry: entry,
            surface: surfaceColor,
            primary: primaryBlue,
            titleColor: titleColor,
            subColor: isDark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B),
            isDark: isDark,
            isTamil: isTamil,
          ),
        ),
        const SizedBox(height: 36),
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

    String rawFluidType = entry['fluid_type']?.toString() ?? "";
    String vFuelType = entry['vehicle']?['fuel_type']?.toString() ?? "DIESEL";
    final fuelType = rawFluidType == "AD_BLUE" ? "AdBlue" : vFuelType;

    Color themeColor = Colors.orange;
    if (fuelType.toUpperCase() == "ADBLUE" ||
        fuelType.toUpperCase() == "AD_BLUE") {
      themeColor = Colors.blue;
    } else if (fuelType.toUpperCase() == "PETROL") {
      themeColor = Colors.green;
    } else if (fuelType.toUpperCase() == "CNG") {
      themeColor = Colors.teal;
    }

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
          border: Border.all(
            color: themeColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: isDark ? 0.1 : 0.05),
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
                    color: themeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_gas_station_rounded,
                    color: themeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicleNumber,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                        ),
                      ),
                      Text(
                        isTamil ? "வாகன எண்" : "Vehicle Number",
                        style: TextStyle(
                          fontSize: 11,
                          color: subColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isTamil ? "நிலுவையில்" : "PENDING",
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
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
                style: TextStyle(
                  fontSize: 10,
                  color: subColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
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
      final months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      return "${dt.day} ${months[dt.month - 1]}, ${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildActiveRoutesSection(
    DriverStore store,
    Color titleColor,
    Color surface,
    Color primary,
    bool isDark,
    bool isTamil,
  ) {
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
        return DateTime.now().isBefore(
          endedAt.add(const Duration(minutes: 15)),
        );
      } else {
        // If not ended yet (active), show based on planned end time (if available)
        final legs = route['legs'] as List<dynamic>? ?? [];
        if (legs.isEmpty) return true; // Show active trips without legs too
        final lastLeg = legs.last;
        final plannedEndAt = DateTime.tryParse(lastLeg['planned_end_at'] ?? '');
        if (plannedEndAt == null) return true;
        // For ongoing trips, show until planned end + 15 mins (grace period)
        return DateTime.now().isBefore(
          plannedEndAt.add(const Duration(minutes: 15)),
        );
      }
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
    final legs = route['legs'] as List<dynamic>? ?? [];
    final lastLeg = legs.isNotEmpty ? legs.last : null;
    final plannedEndAt = lastLeg != null
        ? DateTime.tryParse(lastLeg['planned_end_at'] ?? '')
        : null;

    String remainingStr = "00:00";
    final tripInstances = route['trip_instances'] as List<dynamic>? ?? [];
    final firstTrip = tripInstances.isNotEmpty ? tripInstances[0] : null;
    final endedAtStr = firstTrip?['ended_at'];

    DateTime? referenceTime;
    if (endedAtStr != null) {
      referenceTime = DateTime.tryParse(
        endedAtStr,
      )?.add(const Duration(minutes: 15));
    } else {
      final lastLeg = legs.isNotEmpty ? legs.last : null;
      if (lastLeg != null) {
        referenceTime = DateTime.tryParse(
          lastLeg['planned_end_at'] ?? '',
        )?.add(const Duration(minutes: 15));
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
          remainingStr = "$hours:${minutes.toString().padLeft(2, '0')}";
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, color: accentColor, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                routeName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
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
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: accentColor.withValues(alpha: 0.5),
              size: 12,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard({
    required BuildContext context,
    required Map<String, dynamic> schedule,
    required Color cardColor,
    required Color titleColor,
    required Color subColor,
    required Color primaryBlue,
    required bool isDark,
    required bool isTamil,
  }) {
    final int scheduleId = schedule['id'] ?? 0;
    final String assignmentType = schedule['assignment_type'] ?? 'PRIMARY';

    final dutyShift = schedule['dutyShift'] as Map<String, dynamic>? ?? {};
    String shiftStatus = dutyShift['status'] ?? 'PLANNED';
    final String shiftName = dutyShift['shift_name'] ?? 'FN';
    final String shiftCode = dutyShift['shift_code'] ?? 'FN';
    final String shiftStart = dutyShift['shift_start'] ?? '06:00:00';
    final String shiftEnd = dutyShift['shift_end'] ?? '14:00:00';
    final String shiftTime =
        "${_formatTimeOfDay(shiftStart)} - ${_formatTimeOfDay(shiftEnd)}";

    final masterDuty = dutyShift['masterDuty'] as Map<String, dynamic>? ?? {};
    final String dutyDate = masterDuty['duty_date'] ?? '';
    final category = masterDuty['category'] as Map<String, dynamic>? ?? {};
    final String categoryName =
        category['category_name'] ??
        (isTamil ? 'கடமை அட்டவணை' : 'Duty Schedule');

    final vehicles = dutyShift['vehicles'] as List? ?? [];
    final int assignedVehicles = vehicles.length;
    final int vehiclesWithOdometer = vehicles.where((v) {
      final odo = v['odometer'] as Map<String, dynamic>?;
      return odo != null &&
          odo['start_odometer'] != null &&
          odo['start_odometer'].toString().isNotEmpty;
    }).length;

    final drivers = dutyShift['drivers'] as List? ?? [];
    final bool anyDriverStarted = drivers.any(
      (d) =>
          d['assignment_status'] == 'STARTED' ||
          d['assignment_status'] == 'COMPLETED',
    );
    final bool allDriversStarted =
        drivers.isNotEmpty &&
        drivers.every(
          (d) =>
              d['assignment_status'] == 'STARTED' ||
              d['assignment_status'] == 'COMPLETED',
        );

    if (shiftStatus == 'STARTED') {
      if (!allDriversStarted) {
        shiftStatus = 'ONGOING';
      }
    } else if (shiftStatus == 'PLANNED') {
      if (anyDriverStarted) {
        shiftStatus = 'ONGOING';
      } else {
        shiftStatus = 'PENDING';
      }
    }

    Color accentColor = primaryBlue;
    if (shiftCode == 'FN') {
      accentColor = const Color(0xFF6366F1);
    } else if (shiftCode == 'AN') {
      accentColor = const Color(0xFFF59E0B);
    } else {
      accentColor = const Color(0xFF10B981);
    }

    return GestureDetector(
      onTap: () {
        if (scheduleId > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScheduleDetailsPage(scheduleId: scheduleId),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      categoryName,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadgeWidget(shiftStatus),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          shiftName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      assignmentType,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.04),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: subColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(dutyDate.isNotEmpty ? dutyDate : null),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 16, color: subColor),
                        const SizedBox(width: 8),
                        Text(
                          shiftTime,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (vehicles.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  isTamil ? "ஒதுக்கப்பட்ட வாகனங்கள்" : "ASSIGNED VEHICLES",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: subColor.withOpacity(0.5),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                ...vehicles.map((v) {
                  final vehicleNum = v['vehicle_number'] ?? 'N/A';
                  final details = v['vehicle'] as Map<String, dynamic>? ?? {};
                  final busNum = details['bus_number'] ?? '';
                  final make = details['make'] ?? '';
                  final model = details['model'] ?? '';
                  final capacity = details['capacity'] ?? 0;

                  final bool isCar =
                      capacity <= 7 ||
                      busNum.toString().toLowerCase().contains('car') ||
                      model.toString().toLowerCase().contains('crysta') ||
                      make.toString().toLowerCase().contains('marazzo');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.02)
                          : Colors.black.withOpacity(0.015),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.04)
                            : Colors.black.withOpacity(0.03),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isCar
                                ? Icons.directions_car_filled_rounded
                                : Icons.directions_bus_rounded,
                            size: 20,
                            color: primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                busNum.isNotEmpty
                                    ? busNum
                                    : (make.isNotEmpty
                                          ? "$make $model"
                                          : (isTamil ? "வாகனம்" : "Vehicle")),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isTamil
                                    ? "ஆசனங்கள்: $capacity • $model"
                                    : "Capacity: $capacity • $model",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFE2E8F0),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            vehicleNum,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadgeWidget(String status, {String? displayText}) {
    final String s = status.toUpperCase();
    Color bgColor;
    Color textColor;
    Color borderColor;

    switch (s) {
      case "PLANNED":
      case "APPROVED":
      case "ASSIGNED":
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        borderColor = const Color(0xFFFDE68A);
        break;
      case "READY":
        bgColor = const Color(0xFFFCE7F3);
        textColor = const Color(0xFFBE185D);
        borderColor = const Color(0xFFFBCFE8);
        break;
      case "STARTED":
      case "ON_TRIP":
      case "ONGOING":
        bgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF2563EB);
        borderColor = const Color(0xFF93C5FD);
        break;
      case "ARRIVED_CAMPUS":
      case "CAMPUS_IN":
        bgColor = const Color(0xFFEEF2FF);
        textColor = const Color(0xFF6366F1);
        borderColor = const Color(0xFFC7D2FE);
        break;
      case "FN_COMPLETED":
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF059669);
        borderColor = const Color(0xFFA7F3D0);
        break;
      case "RESUMED_MIDWAY":
      case "MERGED_HALTED":
      case "DEPARTED_CAMPUS":
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFB45309);
        borderColor = const Color(0xFFFDE68A);
        break;
      case "HALTED":
        bgColor = const Color(0xFFFAF5FF);
        textColor = const Color(0xFF8B5CF6);
        borderColor = const Color(0xFFE9D5FF);
        break;
      case "COMPLETED":
      case "FINISHED":
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF047857);
        borderColor = const Color(0xFFA7F3D0);
        break;
      case "CANCELLED":
      case "REJECTED":
        bgColor = const Color(0xFFFFE4E6);
        textColor = const Color(0xFFBE123C);
        borderColor = const Color(0xFFFECDD3);
        break;
      default:
        bgColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF475569);
        borderColor = const Color(0xFFE2E8F0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        (displayText ?? status).replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "TBD";
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final minStr = minute.toString().padLeft(2, '0');
        return "$displayHour:$minStr $period";
      }
      return timeStr;
    } catch (_) {
      return timeStr;
    }
  }

  String _evGetLocName(
    dynamic b,
    String key,
    String idKey,
    List<dynamic> locations,
  ) {
    if (b[key] is String) return b[key];
    if (b[key] is Map && b[key]['name'] != null) return b[key]['name'];
    final locId = b[idKey] ?? (b[key] is Map ? b[key]['id'] : null);
    if (locId != null) {
      final loc = locations.firstWhere(
        (l) => l['id'].toString() == locId.toString(),
        orElse: () => null,
      );
      if (loc != null && loc['name'] != null) return loc['name'];
    }
    return 'Unknown';
  }

  String _evGetPassengerName(dynamic b) {
    if (b['requestUser'] != null && b['requestUser']['name'] != null) {
      return b['requestUser']['name'];
    }
    return b['passenger_name'] ?? b['employee_code'] ?? 'Unknown Passenger';
  }

  String _evGetPassengerPhone(dynamic b) {
    if (b['requestUser'] != null) {
      if (b['requestUser']['phone_number'] != null &&
          b['requestUser']['phone_number'].toString().isNotEmpty)
        return b['requestUser']['phone_number'].toString();
      if (b['requestUser']['phone'] != null &&
          b['requestUser']['phone'].toString().isNotEmpty)
        return b['requestUser']['phone'].toString();
      if (b['requestUser']['mobile'] != null &&
          b['requestUser']['mobile'].toString().isNotEmpty)
        return b['requestUser']['mobile'].toString();
    }
    if (b['passenger_phone'] != null &&
        b['passenger_phone'].toString().isNotEmpty)
      return b['passenger_phone'].toString();
    return 'N/A';
  }

  Widget _buildPendingEvBookingsSection(
    WidgetRef ref,
    Color primaryBlue,
    Color cardColor,
    Color textColor,
    Color subColor,
    bool isDark,
  ) {
    final evStore = ref.watch(batteryVehicleStoreProvider);
    final pendingBookings = evStore.driverBookings.where((b) {
      final status = (b['status'] ?? '').toString().toUpperCase();
      final rStatus = (b['response_status'] ?? '').toString().toUpperCase();
      return status == 'REQUESTED' &&
          rStatus != 'EXPIRED' &&
          rStatus != 'ACCEPTED' &&
          rStatus != 'REJECTED';
    }).toList();

    if (pendingBookings.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            "New EV Requests",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        ...pendingBookings.map((b) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "EV Booking",
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "PENDING",
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Column(
                        children: [
                          Icon(Icons.trip_origin, color: primaryBlue, size: 16),
                          Container(
                            width: 2,
                            height: 24,
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                          const Icon(
                            Icons.location_on,
                            color: Colors.green,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _evGetLocName(
                                b,
                                'fromLocation',
                                'from_location_id',
                                evStore.evLocations,
                              ),
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _evGetLocName(
                                b,
                                'toLocation',
                                'to_location_id',
                                evStore.evLocations,
                              ),
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.person, size: 16, color: primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _evGetPassengerName(b),
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.phone, size: 16, color: subColor),
                      const SizedBox(width: 4),
                      Text(
                        _evGetPassengerPhone(b),
                        style: TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        try {
                          await ref
                              .read(batteryVehicleStoreProvider)
                              .acceptRide(b['id'].toString());
                          if (mounted)
                            showTopToast(context, "Trip Accepted Successfully");
                        } catch (e) {
                          if (mounted)
                            showTopToast(context, e.toString(), isError: true);
                        }
                      },
                      child: const Text(
                        'Accept',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}
