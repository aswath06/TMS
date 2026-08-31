import 'package:tripzo/screens/driver/driver_battery_vehicles_page.dart'
    as tripzo_bv;
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripzo/store/driver_task_store.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/utils/emergency_task_dialog.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/screens/faculty/missions/mission_details_screen.dart';
import 'package:tripzo/screens/admin/request/daily_bus_run_details_page.dart';
import 'package:tripzo/screens/driver/schedule_details_page.dart';
import 'package:tripzo/screens/driver/driver_task_details_page.dart';
import 'package:tripzo/utils/task_icon_helper.dart';
import 'package:shimmer/shimmer.dart';

class DriverRoutesScreen extends ConsumerStatefulWidget {
  const DriverRoutesScreen({super.key});

  @override
  ConsumerState<DriverRoutesScreen> createState() => _DriverRoutesScreenState();
}

class _DriverRoutesScreenState extends ConsumerState<DriverRoutesScreen>
    with SingleTickerProviderStateMixin {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Toggle state
  int _selectedToggleIndex = 0;

  // Date slider state
  late String _selectedDateFilter;
  late ScrollController _dateScrollController;
  final int _infiniteScrollMiddle = 5000;
  late AnimationController _jumpController;
  late Animation<double> _jumpAnimation;
  Timer? _jumpTimer;
  Timer? _taskPollTimer;
  bool _isScrolledFarFromToday = false;

  @override
  void initState() {
    super.initState();
    _initPageData();
  }

  void _initPageData() {
    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _selectedDateFilter = todayStr;

    _dateScrollController = ScrollController(
      initialScrollOffset: (_infiniteScrollMiddle * 68.0) - 100,
    );
    _dateScrollController.addListener(() {
      if (!mounted) return;
      final double listWidth = MediaQuery.of(context).size.width - 48 - 77;
      final double todayOffset =
          (_infiniteScrollMiddle * 68.0) - (listWidth / 2) + 34;
      final bool isFar =
          (_dateScrollController.offset - todayOffset).abs() > (15 * 68.0);

      if (_isScrolledFarFromToday != isFar) {
        setState(() {
          _isScrolledFarFromToday = isFar;
        });
      }
    });

    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _jumpAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -8.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -8.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50.0,
      ),
    ]).animate(_jumpController);

    _jumpTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted &&
          _selectedDateFilter !=
              DateFormat('yyyy-MM-dd').format(DateTime.now())) {
        _jumpController.forward(from: 0.0);
      }
    });

    _taskPollTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (mounted) {
        await ref.read(driverTaskStoreProvider).fetchAllTasks(isRefresh: true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDate(_selectedDateFilter);
      _fetchDataForSelectedDate();
    });
  }

  void _scrollToDate(String dateStr) {
    if (!mounted) return;
    final double listWidth = MediaQuery.of(context).size.width - 48 - 77;
    final double todayOffset =
        (_infiniteScrollMiddle * 68.0) - (listWidth / 2) + 34;

    DateTime selectedDate;
    try {
      selectedDate = DateFormat('yyyy-MM-dd').parse(dateStr);
    } catch (e) {
      selectedDate = DateTime.now();
    }

    final DateTime now = DateTime.now();
    final DateTime todayDate = DateTime(now.year, now.month, now.day);
    final DateTime selDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final int diffDays = selDate.difference(todayDate).inDays;

    _dateScrollController.jumpTo(todayOffset + (diffDays * 68.0));
  }

  Future<void> _fetchDataForSelectedDate() async {
    if (!mounted) return;
    // Refresh missions and profile for Routes
    final driverStore = ref.read(driverStoreProvider);
    await driverStore.fetchMissions();

    if (!mounted) return;
    await driverStore.fetchProfile();

    if (!mounted) return;
    // Fetch Daily Bus Routes for the selected date
    final dailyStore = ref.read(dailyRoutinesStoreProvider);
    await dailyStore.fetchDailyRoutines(
      isRefresh: true,
      date: _selectedDateFilter,
    );

    if (!mounted) return;
    // Fetch API Driver Tasks
    await ref.read(driverTaskStoreProvider).fetchAllTasks(isRefresh: true);

    if (!mounted) return;
    // Fetch Schedules
    final scheduleStore = ref.read(driverSchedulesStoreProvider);
    await scheduleStore.fetchSchedules(
      isRefresh: true,
      date: _selectedDateFilter,
    );

    if (!mounted) return;
    // Fetch Battery Vehicles (EV)
    await ref.read(batteryVehicleStoreProvider).fetchDriverBookings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateScrollController.dispose();
    _jumpController.dispose();
    _jumpTimer?.cancel();
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: isTamil
                      ? "பயண பெயரைத் தேடுக..."
                      : "Search route name...",
                  hintStyle: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.normal,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  ref.read(driverStoreProvider).updateSearch(val);
                },
              )
            : Text(
                isTamil ? "உங்கள் பயணங்கள்" : "My Journeys",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
        actions: [
          _isSearching
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () {
                    if (_searchController.text.isEmpty) {
                      setState(() => _isSearching = false);
                    } else {
                      _searchController.clear();
                      ref.read(driverStoreProvider).updateSearch("");
                    }
                  },
                )
              : IconButton(
                  icon: Icon(
                    Icons.search_rounded,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onPressed: () => setState(() => _isSearching = true),
                ),
        ],
      ),
      body: Column(
        children: [
          // Toggle Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedToggleIndex = 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedToggleIndex == 0
                              ? primaryBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isTamil ? "பயணங்கள்" : "Routes",
                          style: TextStyle(
                            color: _selectedToggleIndex == 0
                                ? Colors.white
                                : subColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedToggleIndex = 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedToggleIndex == 1
                              ? primaryBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isTamil ? "தினசரிப் பேருந்து" : "Daily Bus",
                          style: TextStyle(
                            color: _selectedToggleIndex == 1
                                ? Colors.white
                                : subColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedToggleIndex = 2),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedToggleIndex == 2
                              ? primaryBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isTamil ? "பணி அட்டவணை" : "Schedules",
                          style: TextStyle(
                            color: _selectedToggleIndex == 2
                                ? Colors.white
                                : subColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedToggleIndex = 3),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedToggleIndex == 3
                              ? primaryBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "EV",
                          style: TextStyle(
                            color: _selectedToggleIndex == 3
                                ? Colors.white
                                : subColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Date Slider Segment
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Route Dates",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
                AnimatedBuilder(
                  animation: _jumpAnimation,
                  builder: (context, child) {
                    final String todayStr = DateFormat(
                      'yyyy-MM-dd',
                    ).format(DateTime.now());
                    final bool shouldShowJump =
                        _selectedDateFilter != todayStr ||
                        _isScrolledFarFromToday;
                    return AnimatedOpacity(
                      opacity: shouldShowJump ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Transform.translate(
                        offset: Offset(0, _jumpAnimation.value),
                        child: child,
                      ),
                    );
                  },
                  child: GestureDetector(
                    onTap: () {
                      final String todayStr = DateFormat(
                        'yyyy-MM-dd',
                      ).format(DateTime.now());
                      if (_selectedDateFilter != todayStr) {
                        setState(() => _selectedDateFilter = todayStr);
                        _fetchDataForSelectedDate();
                      }
                      _scrollToDate(todayStr);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.fast_rewind_rounded,
                            size: 14,
                            color: primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Jump to Today",
                            style: TextStyle(
                              color: primaryBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.underline,
                              decorationColor: primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildDateScroller(primaryBlue, titleColor, subColor, isDark),
          const SizedBox(height: 12),

          // Main List
          Expanded(
            child: _selectedToggleIndex == 3
                ? tripzo_bv.DriverBatteryVehiclesPage(
                    dateFilter: _selectedDateFilter,
                  )
                : (_selectedToggleIndex == 2
                      ? _buildScheduleList()
                      : (_selectedToggleIndex == 1
                            ? _buildDailyBusRoutesList()
                            : _buildRouteList())),
          ),
        ],
      ),
    );
  }

  Widget _buildDateScroller(
    Color primaryBlue,
    Color titleColor,
    Color subColor,
    bool isDark,
  ) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (_selectedDateFilter == 'ALL') return;
            setState(() => _selectedDateFilter = 'ALL');
            _fetchDataForSelectedDate();
          },
          child: Container(
            width: 65,
            height: 70,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: _selectedDateFilter == 'ALL'
                  ? primaryBlue
                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedDateFilter == 'ALL'
                    ? primaryBlue
                    : titleColor.withValues(alpha: 0.1),
              ),
              boxShadow: _selectedDateFilter == 'ALL'
                  ? [
                      BoxShadow(
                        color: primaryBlue.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: _selectedDateFilter == 'ALL' ? Colors.white : subColor,
                ),
                const SizedBox(height: 4),
                Text(
                  "ALL",
                  style: TextStyle(
                    color: _selectedDateFilter == 'ALL'
                        ? Colors.white
                        : titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 70,
            child: ListView.builder(
              itemExtent: 68.0,
              controller: _dateScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final date = DateTime.now().add(
                  Duration(days: index - _infiniteScrollMiddle),
                );
                final formattedDateStr = DateFormat('yyyy-MM-dd').format(date);
                final isSelected = _selectedDateFilter == formattedDateStr;
                return GestureDetector(
                  onTap: () {
                    if (_selectedDateFilter == formattedDateStr) return;
                    setState(() => _selectedDateFilter = formattedDateStr);
                    _fetchDataForSelectedDate();
                  },
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryBlue
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? primaryBlue
                            : titleColor.withValues(alpha: 0.1),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryBlue.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(date).toUpperCase(),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.9)
                                : subColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd').format(date),
                          style: TextStyle(
                            color: isSelected ? Colors.white : titleColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(date).toUpperCase(),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.9)
                                : subColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteList() {
    final store = ref.watch(driverStoreProvider);
    final isTamil = LanguageStore.isTamil;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    List<Map<String, dynamic>> list = [];
    final allMissions = List<Map<String, dynamic>>.from(store.missions);

    // Filter by selected date
    list = allMissions.where((m) {
      if (_selectedDateFilter == 'ALL') return true;
      final dateStr = (m['start_datetime'] ?? m['startDate'])?.toString() ?? "";
      if (dateStr.isEmpty) return false;
      try {
        final dt = DateTime.parse(dateStr).toLocal();
        final itemDate = DateFormat('yyyy-MM-dd').format(dt);
        return itemDate == _selectedDateFilter;
      } catch (_) {
        return false;
      }
    }).toList();

    list.sort((a, b) {
      final aTime = DateTime.tryParse(a['start_datetime'] ?? '') ?? DateTime(0);
      final bTime = DateTime.tryParse(b['start_datetime'] ?? '') ?? DateTime(0);
      return aTime.compareTo(bTime);
    });

    // identify search query
    final query = store.searchQuery.toLowerCase().trim();

    // Apply Search Filtering (Frontend)
    if (query.isNotEmpty) {
      list = list.where((m) {
        final String routeName = (m['routeName'] ?? "")
            .toString()
            .toLowerCase();
        final String pickup = (m['startLocation'] ?? "")
            .toString()
            .toLowerCase();
        final String drop = (m['destinationLocation'] ?? "")
            .toString()
            .toLowerCase();
        final String driveId = (m['id'] ?? "").toString().toLowerCase();

        return routeName.contains(query) ||
            pickup.contains(query) ||
            drop.contains(query) ||
            driveId.contains(query);
      }).toList();
    }

    if (store.isLoadingMissions && list.isEmpty) {
      final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
      return _buildSkeletonList(isDark, cardColor);
    }

    if (list.isEmpty) {
      return _buildEmptyState(isSearch: query.isNotEmpty);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchDataForSelectedDate();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: list.length,
        itemBuilder: (context, index) {
          return _buildMissionCard(
            context: context,
            mission: list[index],
            surface: surfaceColor,
            primary: primaryBlue,
            titleColor: titleColor,
            subColor: subColor,
            isDark: isDark,
            isTamil: isTamil,
          );
        },
      ),
    );
  }

  Widget _buildDailyBusRoutesList() {
    final dailyStore = ref.watch(dailyRoutinesStoreProvider);
    final isTamil = LanguageStore.isTamil;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    // identify search query for daily bus routes
    final driverStore = ref.watch(driverStoreProvider);
    final query = driverStore.searchQuery.toLowerCase().trim();

    List<dynamic> list = List.from(dailyStore.runs);

    if (query.isNotEmpty) {
      list = list.where((m) {
        final String name = (m['route']?['name'] ?? "")
            .toString()
            .toLowerCase();
        final String driver = (m['driver']?['name'] ?? "")
            .toString()
            .toLowerCase();
        return name.contains(query) || driver.contains(query);
      }).toList();
    }

    if (dailyStore.isLoading && list.isEmpty) {
      final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
      return _buildSkeletonList(isDark, cardColor);
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              query.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.directions_bus_filled_outlined,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              query.isNotEmpty
                  ? (isTamil
                        ? "பொருத்தமான பேருந்துப் பயணங்கள் எதுவும் இல்லை"
                        : "No matching bus routes found")
                  : (isTamil
                        ? "பேருந்துப் பயணங்கள் இல்லை"
                        : "No daily bus routes for this date"),
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchDataForSelectedDate();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final run = list[index];
          // We can reuse the Daily Bus Run card component, but as driver we'll navigate to AssignmentDetailsScreen
          // Wait, is there a specific card for Driver's Daily Bus Routes?
          // Since the Daily Bus Run card is in DailyRoutinesPage, let's just make it tapable.
          return _buildDailyBusRouteCard(
            context: context,
            run: run,
            cardColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            titleColor: titleColor,
            subColor: subColor,
            primaryBlue: primaryBlue,
            isDark: isDark,
          );
        },
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
    final String time = _formatDate(
      mission['start_datetime'] ?? mission['startDate'],
    );
    final dynamic rawStatusValue = mission['status'];
    final tripStatuses = mission['trip_instance_statuses'] as List?;
    final String? tripStatus = (tripStatuses != null && tripStatuses.isNotEmpty)
        ? tripStatuses[0]['status']?.toString().toUpperCase()
        : null;

    // Status Logic - Using backend status directly as requested
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
                _buildStatusBadgeWidget(backendStatus, displayText: statusStr),
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

  Widget _buildEmptyState({bool isSearch = false}) {
    final bool isTamil = LanguageStore.isTamil;
    String text = "";
    if (isSearch) {
      text = isTamil
          ? "பொருத்தமான பயணங்கள் எதுவும் இல்லை"
          : "No matching journeys found";
    } else {
      text = isTamil ? "பயணங்கள் இல்லை" : "No routes for this date";
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearch ? Icons.search_off_rounded : Icons.subtitles_off_rounded,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "TBD";
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) {
      return dateStr;
    }
  }

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
      final vNumbers = assignments
          .map((a) => a['vehicle']?['vehicle_number'])
          .whereType<String>()
          .toSet();
      if (vNumbers.isNotEmpty) vehicleNo = vNumbers.join(", ");
    }

    final int passengerCount =
        run['campus_in_count'] ?? (run['students'] as List?)?.length ?? 0;

    return GestureDetector(
      onTap: () async {
        if (context.mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  DailyBusRunDetailsPage(runData: run, showEditIcon: false),
            ),
          );
        }
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                _buildStatusBadgeWidget(status),
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
                Icon(
                  Icons.directions_bus_rounded,
                  size: 14,
                  color: primaryBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  "$stopsCount Stops",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.people_alt_rounded,
                  size: 14,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(width: 6),
                Text(
                  "$passengerCount Passengers",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
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

  Widget _buildSkeletonList(bool isDark, Color cardColor) {
    final shimmerBase = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.grey.shade200;
    final shimmerHighlight = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: shimmerBase,
      highlightColor: shimmerHighlight,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            height: 190,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 60,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: 140,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 180,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 100,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleEmptyState({bool isSearch = false}) {
    final bool isTamil = LanguageStore.isTamil;
    String text = "";
    if (isSearch) {
      text = isTamil
          ? "பொருத்தமான அட்டவணை எதுவும் இல்லை"
          : "No matching schedules found";
    } else {
      text = isTamil ? "அட்டவணை இல்லை" : "No schedules for this date";
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearch ? Icons.search_off_rounded : Icons.event_note_rounded,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    final scheduleStore = ref.watch(driverSchedulesStoreProvider);
    final isTamil = LanguageStore.isTamil;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    // identify search query
    final driverStore = ref.watch(driverStoreProvider);
    final query = driverStore.searchQuery.toLowerCase().trim();

    final List<Map<String, dynamic>> dashboardSchedules = [];

    // Filter and add started schedules
    for (var s in scheduleStore.startedSchedules) {
      dashboardSchedules.add(s);
    }
    // Add today's schedules if they are not already in the started list
    for (var s in scheduleStore.todaySchedules) {
      if (!dashboardSchedules.any((item) => item['id'] == s['id'])) {
        dashboardSchedules.add(s);
      }
    }
    // Add selected date schedules if they are not already in the list
    for (var s in scheduleStore.schedules) {
      if (!dashboardSchedules.any((item) => item['id'] == s['id'])) {
        dashboardSchedules.add(s);
      }
    }

    List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(
      dashboardSchedules,
    );

    if (_selectedDateFilter != 'ALL') {
      list = list.where((s) {
        final dutyShift = s['dutyShift'] as Map? ?? {};
        final masterDuty = dutyShift['masterDuty'] as Map? ?? {};
        final String dutyDate = masterDuty['duty_date'] ?? '';
        if (dutyDate.isEmpty) return false;
        try {
          final dt = DateTime.parse(dutyDate).toLocal();
          final itemDate = DateFormat('yyyy-MM-dd').format(dt);
          return itemDate == _selectedDateFilter;
        } catch (_) {
          return false;
        }
      }).toList();
    }

    if (query.isNotEmpty) {
      list = list.where((s) {
        final dutyShift = s['dutyShift'] as Map? ?? {};
        final masterDuty = dutyShift['masterDuty'] as Map? ?? {};
        final category = masterDuty['category'] as Map? ?? {};
        final categoryName = (category['category_name'] ?? "")
            .toString()
            .toLowerCase();
        final shiftName = (dutyShift['shift_name'] ?? "")
            .toString()
            .toLowerCase();

        final vehicles = dutyShift['vehicles'] as List? ?? [];
        bool vehicleMatches = false;
        for (var v in vehicles) {
          final plate = (v['vehicle_number'] ?? "").toString().toLowerCase();
          final details = v['vehicle'] as Map? ?? {};
          final busNum = (details['bus_number'] ?? "").toString().toLowerCase();
          if (plate.contains(query) || busNum.contains(query)) {
            vehicleMatches = true;
            break;
          }
        }

        return categoryName.contains(query) ||
            shiftName.contains(query) ||
            vehicleMatches;
      }).toList();
    }

    if (scheduleStore.isLoading && list.isEmpty) {
      return _buildSkeletonList(isDark, cardColor);
    }

    if (list.isEmpty) {
      return _buildScheduleEmptyState(isSearch: query.isNotEmpty);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchDataForSelectedDate();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final schedule = list[index];
          return _buildScheduleCard(
            context: context,
            schedule: schedule,
            cardColor: cardColor,
            titleColor: titleColor,
            subColor: subColor,
            primaryBlue: primaryBlue,
            isDark: isDark,
            isTamil: isTamil,
          );
        },
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
    final String assignmentStatus = schedule['assignment_status'] ?? 'ASSIGNED';

    final dutyShift = schedule['dutyShift'] as Map<String, dynamic>? ?? {};
    final String shiftStatus = dutyShift['status'] ?? 'PLANNED';
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
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
                      color: accentColor.withValues(alpha: 0.1),
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
                      color: primaryBlue.withValues(alpha: 0.08),
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
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
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
                    color: subColor.withValues(alpha: 0.5),
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
                          ? Colors.white.withValues(alpha: 0.02)
                          : Colors.black.withValues(alpha: 0.015),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.08),
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

  Widget _buildTaskList() {
    final scheduleStore = ref.watch(driverSchedulesStoreProvider);
    final driverStore = ref.watch(driverStoreProvider);
    final isTamil = LanguageStore.isTamil;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final query = driverStore.searchQuery.toLowerCase().trim();
    final List<Map<String, dynamic>> tasksList = [];

    // 1. Schedules as tasks
    for (var s in scheduleStore.startedSchedules) {
      tasksList.add({
        'type': 'SCHEDULE',
        'title':
            s['dutyShift']?['masterDuty']?['category']?['category_name'] ??
            (isTamil ? 'கடமைப் பணி' : 'Duty Task'),
        'subtitle': s['dutyShift']?['shift_name'] ?? 'Shift Task',
        'status': s['dutyShift']?['status'] ?? 'STARTED',
        'date': s['dutyShift']?['masterDuty']?['duty_date'] ?? '',
        'raw': s,
      });
    }
    for (var s in scheduleStore.todaySchedules) {
      if (!tasksList.any(
        (t) => t['type'] == 'SCHEDULE' && t['raw']['id'] == s['id'],
      )) {
        tasksList.add({
          'type': 'SCHEDULE',
          'title':
              s['dutyShift']?['masterDuty']?['category']?['category_name'] ??
              (isTamil ? 'கடமைப் பணி' : 'Duty Task'),
          'subtitle': s['dutyShift']?['shift_name'] ?? 'Shift Task',
          'status': s['dutyShift']?['status'] ?? 'PLANNED',
          'date': s['dutyShift']?['masterDuty']?['duty_date'] ?? '',
          'raw': s,
        });
      }
    }
    for (var s in scheduleStore.schedules) {
      if (!tasksList.any(
        (t) => t['type'] == 'SCHEDULE' && t['raw']['id'] == s['id'],
      )) {
        tasksList.add({
          'type': 'SCHEDULE',
          'title':
              s['dutyShift']?['masterDuty']?['category']?['category_name'] ??
              (isTamil ? 'கடமைப் பணி' : 'Duty Task'),
          'subtitle': s['dutyShift']?['shift_name'] ?? 'Shift Task',
          'status': s['dutyShift']?['status'] ?? 'PLANNED',
          'date': s['dutyShift']?['masterDuty']?['duty_date'] ?? '',
          'raw': s,
        });
      }
    }

    // 3. Daily bus runs as tasks
    for (var run in driverStore.dailyBusRuns) {
      final status = run['status'] ?? 'PLANNED';
      final runTitle = run['bus_number'] != null
          ? "Bus ${run['bus_number']} Task"
          : (isTamil ? "பேருந்து பணி" : "Daily Bus Task");
      tasksList.add({
        'type': 'BUS_RUN',
        'title': runTitle,
        'subtitle':
            "${run['start_location_name'] ?? ''} -> ${run['halt_location_name'] ?? ''}",
        'status': status.toString().toUpperCase(),
        'date': run['duty_date'] ?? '',
        'raw': run,
      });
    }

    // 4. API Driver Tasks (/api/driver-task/get-all)
    final driverTaskStore = ref.watch(driverTaskStoreProvider);
    for (var task in driverTaskStore.tasks) {
      final startsAt = task['starts_at'] ?? '';
      String dateStr = '';
      if (startsAt.isNotEmpty) {
        try {
          dateStr = DateFormat(
            'yyyy-MM-dd',
          ).format(DateTime.parse(startsAt).toLocal());
        } catch (_) {}
      }
      tasksList.add({
        'type': 'API_TASK',
        'title': task['title'] ?? (isTamil ? 'ஓட்டுநர் பணி' : 'Driver Task'),
        'subtitle': task['description'] ?? task['location_name'] ?? '',
        'status': getEffectiveTaskStatus(task),
        'date': dateStr,
        'raw': task,
      });
    }

    // Filter by selected date (keep active tasks like ASSIGNED / IN_PROGRESS / STARTED / PLANNED / OVERDUE always visible)
    List<Map<String, dynamic>> filteredList = tasksList.where((t) {
      final status = (t['status'] ?? '').toString().toUpperCase();
      final bool isActive =
          status == 'ASSIGNED' ||
          status == 'IN_PROGRESS' ||
          status == 'STARTED' ||
          status == 'PLANNED' ||
          status == 'ONGOING' ||
          status == 'OVERDUE';

      if (!isActive && _selectedDateFilter != 'ALL' && t['date'].isNotEmpty) {
        if (t['date'] != _selectedDateFilter) return false;
      }
      if (query.isNotEmpty) {
        final title = (t['title'] ?? '').toString().toLowerCase();
        final sub = (t['subtitle'] ?? '').toString().toLowerCase();
        final st = status.toLowerCase();
        return title.contains(query) ||
            sub.contains(query) ||
            st.contains(query);
      }
      return true;
    }).toList();

    if (scheduleStore.isLoading && filteredList.isEmpty) {
      return _buildSkeletonList(isDark, cardColor);
    }

    if (filteredList.isEmpty) {
      return _buildScheduleEmptyState(isSearch: query.isNotEmpty);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchDataForSelectedDate();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          final task = filteredList[index];
          return _buildTaskCard(
            context: context,
            task: task,
            cardColor: cardColor,
            titleColor: titleColor,
            subColor: subColor,
            primaryBlue: primaryBlue,
            isDark: isDark,
            isTamil: isTamil,
          );
        },
      ),
    );
  }

  Widget _buildTaskCard({
    required BuildContext context,
    required Map<String, dynamic> task,
    required Color cardColor,
    required Color titleColor,
    required Color subColor,
    required Color primaryBlue,
    required bool isDark,
    required bool isTamil,
  }) {
    final String type = task['type'] ?? 'TASK';
    if (type == 'API_TASK') {
      return _buildApiRouteTaskCard(
        context: context,
        task: task,
        cardColor: cardColor,
        titleColor: titleColor,
        subColor: subColor,
        primaryBlue: primaryBlue,
        isDark: isDark,
        isTamil: isTamil,
      );
    }
    final String title = task['title'] ?? 'Task';
    final String subtitle = task['subtitle'] ?? '';
    final String status = task['status'] ?? 'PLANNED';
    final Map<String, dynamic> raw = task['raw'] ?? {};

    IconData typeIcon = Icons.task_alt_rounded;
    Color iconColor = const Color(0xFF8B5CF6);
    if (type == 'MISSION') {
      typeIcon = Icons.explore_rounded;
      iconColor = const Color(0xFF6366F1);
    } else if (type == 'BUS_RUN') {
      typeIcon = Icons.directions_bus_rounded;
      iconColor = const Color(0xFF3B82F6);
    }

    return GestureDetector(
      onTap: () {
        if (type == 'SCHEDULE' && raw['id'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScheduleDetailsPage(scheduleId: raw['id']),
            ),
          );
        } else if (type == 'MISSION' && raw['id'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MissionDetailsScreen(
                missionTitle: raw['title'] ?? 'Mission Task',
                time: raw['start_datetime'] ?? 'TBD',
                driverName: "Driver",
                driverPhone: "",
                vehicleInfo: raw['vehicle_number'] ?? 'Vehicle',
                capacity: "N/A",
                passengerCount: "0",
                pathType: raw['travel_type'] ?? "One-Way",
                stops: [
                  {
                    'location': raw['start_location_name'] ?? 'Start',
                    'eta': 'Start',
                  },
                  {
                    'location': raw['halt_location_name'] ?? 'End',
                    'eta': 'End',
                  },
                ],
                status: (raw['status'] ?? 'PLANNED').toString(),
                statusColor: Colors.indigo,
                requestId: raw['id'].toString(),
                rawStatus: 0,
              ),
            ),
          );
        } else if (type == 'BUS_RUN' && raw['id'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DailyBusRunDetailsPage(runData: raw),
            ),
          );
        } else if (type == 'API_TASK' && raw['id'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DriverTaskDetailsPage(
                taskId: raw['id'],
                initialTaskData: raw,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.04),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(typeIcon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: subColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        status == 'STARTED' ||
                            status == 'ONGOING' ||
                            status == 'IN_PROGRESS'
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : (status == 'COMPLETED' || status == 'VERIFIED'
                              ? Colors.grey.withValues(alpha: 0.12)
                              : primaryBlue.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color:
                          status == 'STARTED' ||
                              status == 'ONGOING' ||
                              status == 'IN_PROGRESS'
                          ? const Color(0xFF10B981)
                          : (status == 'COMPLETED' || status == 'VERIFIED'
                                ? Colors.grey
                                : primaryBlue),
                    ),
                  ),
                ),
                if (type == 'API_TASK' && raw['id'] != null) ...[
                  const SizedBox(height: 8),
                  if (status == 'ASSIGNED' || status == 'PLANNED')
                    ElevatedButton.icon(
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Start Task",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: const Size(90, 34),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        _showStartOdometerDialog(context, ref, raw['id'], raw);
                      },
                    )
                  else if (status == 'STARTED' || status == 'IN_PROGRESS')
                    ElevatedButton.icon(
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Complete",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: const Size(90, 34),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        _showCompleteOdometerDialog(
                          context,
                          ref,
                          raw['id'],
                          raw,
                        );
                      },
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDriverTaskDetailModal(BuildContext context, dynamic taskId) async {
    final taskDetails = await ref
        .read(driverTaskStoreProvider)
        .getTaskById(taskId);
    if (!context.mounted || taskDetails == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final String status = (taskDetails['status'] ?? 'ASSIGNED')
        .toString()
        .toUpperCase();
    final String taskNo =
        taskDetails['task_number'] ?? "DT-${taskDetails['id']}";
    final String title = taskDetails['title'] ?? "Driver Task";
    final String description =
        taskDetails['description'] ?? "No description provided.";
    final String location = taskDetails['location_name'] ?? "Main Bunk";
    final String duration = "${taskDetails['duration_minutes'] ?? 60} mins";
    final String remarks = taskDetails['remarks'] ?? "None";
    final taskType = taskDetails['task_type']?['name'] ?? "General Task";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: titleColor,
                          ),
                        ),
                        Text(
                          "$taskNo • $taskType",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: subColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _buildDetailRow(
                Icons.description_rounded,
                "Description",
                description,
                titleColor,
                subColor,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.location_on_rounded,
                "Location",
                location,
                titleColor,
                subColor,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.timer_rounded,
                "Duration",
                duration,
                titleColor,
                subColor,
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.notes_rounded,
                "Remarks",
                remarks,
                titleColor,
                subColor,
              ),
              const SizedBox(height: 24),
              if (status == 'ASSIGNED' || status == 'PLANNED')
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "Start Task",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final success = await ref
                          .read(driverTaskStoreProvider)
                          .startTask(taskId);
                      if (context.mounted && success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Task started!")),
                        );
                      }
                    },
                  ),
                )
              else if (status == 'STARTED' || status == 'IN_PROGRESS')
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "Complete Task",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final success = await ref
                          .read(driverTaskStoreProvider)
                          .completeTask(taskId);
                      if (context.mounted && success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Task completed!")),
                        );
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color titleColor,
    Color subColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6366F1)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: subColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showStartOdometerDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic taskId,
    Map<String, dynamic> task,
  ) {
    final rawTask = task['raw'] is Map ? task['raw'] : task;
    final vehicleObj = rawTask['vehicle'] ?? task['vehicle'];
    num vehicleOdo = 0;
    if (vehicleObj is Map) {
      vehicleOdo =
          num.tryParse(
            (vehicleObj['odometer'] ??
                    vehicleObj['current_odometer'] ??
                    vehicleObj['last_odometer'] ??
                    0)
                .toString(),
          ) ??
          0;
    } else if (rawTask['vehicle_odometer'] != null ||
        task['vehicle_odometer'] != null) {
      vehicleOdo =
          num.tryParse(
            (rawTask['vehicle_odometer'] ?? task['vehicle_odometer'])
                .toString(),
          ) ??
          0;
    }

    final odoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgSurface = isDark ? const Color(0xFF1E293B) : Colors.white;
        final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final inputBg = isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC);

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: bgSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  "Start Mission Information",
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Please enter the starting details before continuing.",
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: TextField(
                    controller: odoController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                    decoration: InputDecoration(
                      hintText: "Start Odometer",
                      hintStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Icon(
                          Icons.speed_rounded,
                          color: Color(0xFF6366F1),
                          size: 22,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 48),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          "Close",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () async {
                          final odoVal = num.tryParse(
                            odoController.text.trim(),
                          );
                          if (odoVal == null || odoVal <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Please enter a valid Start Odometer reading.",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (vehicleOdo > 0 && odoVal < vehicleOdo) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Start odometer ($odoVal km) cannot be less than vehicle's current odometer ($vehicleOdo km).",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          final success = await ref
                              .read(driverTaskStoreProvider)
                              .startTask(taskId, startOdometer: odoVal);
                          if (context.mounted && success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Task started with Start Odometer: $odoVal km!",
                                ),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          "SUBMIT",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCompleteOdometerDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic taskId,
    Map<String, dynamic> task,
  ) {
    final rawTask = task['raw'] is Map ? task['raw'] : task;
    num startOdo = 0;
    final startOdoRaw =
        rawTask['start_odometer'] ??
        rawTask['startOdometer'] ??
        task['start_odometer'] ??
        task['startOdometer'];
    if (startOdoRaw != null) {
      startOdo = num.tryParse(startOdoRaw.toString()) ?? 0;
    }

    final vehicleObj = rawTask['vehicle'] ?? task['vehicle'];
    num vehicleOdo = 0;
    if (vehicleObj is Map) {
      vehicleOdo =
          num.tryParse(
            (vehicleObj['odometer'] ??
                    vehicleObj['current_odometer'] ??
                    vehicleObj['last_odometer'] ??
                    0)
                .toString(),
          ) ??
          0;
    } else if (rawTask['vehicle_odometer'] != null ||
        task['vehicle_odometer'] != null) {
      vehicleOdo =
          num.tryParse(
            (rawTask['vehicle_odometer'] ?? task['vehicle_odometer'])
                .toString(),
          ) ??
          0;
    }

    final odoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgSurface = isDark ? const Color(0xFF1E293B) : Colors.white;
        final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final inputBg = isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC);

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: bgSurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  "Complete Mission Information",
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Please enter the ending details before completing.",
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: TextField(
                    controller: odoController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                    decoration: InputDecoration(
                      hintText: "End Odometer",
                      hintStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Icon(
                          Icons.speed_rounded,
                          color: Color(0xFF10B981),
                          size: 22,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 48),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          "Close",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () async {
                          final odoVal = num.tryParse(
                            odoController.text.trim(),
                          );
                          if (odoVal == null || odoVal <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Please enter a valid End Odometer reading.",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (startOdo > 0 && odoVal < startOdo) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "End odometer ($odoVal km) cannot be less than start odometer ($startOdo km).",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (vehicleOdo > 0 && odoVal < vehicleOdo) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "End odometer ($odoVal km) cannot be less than vehicle's current odometer ($vehicleOdo km).",
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          final success = await ref
                              .read(driverTaskStoreProvider)
                              .completeTask(taskId, endOdometer: odoVal);
                          if (context.mounted && success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Task completed with End Odometer: $odoVal km!",
                                ),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          "SUBMIT",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildApiRouteTaskCard({
    required BuildContext context,
    required Map<String, dynamic> task,
    required Color cardColor,
    required Color titleColor,
    required Color subColor,
    required Color primaryBlue,
    required bool isDark,
    required bool isTamil,
  }) {
    final Map<String, dynamic> raw = task['raw'] ?? task;
    final dynamic taskId = raw['id'];
    final String title =
        raw['title'] ?? (isTamil ? 'ஓட்டுநர் பணி' : 'Driver Task');
    final String description =
        raw['description'] ?? 'Perform assigned driver task';
    final String location = raw['location_name'] ?? 'Main Bunk';
    final String status = (raw['status'] ?? 'ASSIGNED')
        .toString()
        .toUpperCase();
    final String startsAtStr = raw['starts_at'] ?? '';
    final v = raw['vehicle'];
    final String vehicleNo = v is Map
        ? (v['vehicle_number'] ?? 'Vehicle 56').toString()
        : (raw['vehicle_id'] != null
              ? "Vehicle #${raw['vehicle_id']}"
              : (v != null ? "Vehicle #$v" : "Vehicle 56"));
    final String taskNo =
        raw['task_number'] ?? (taskId != null ? "DT-$taskId" : "DT-TASK");
    final tt =
        raw['task_type'] ??
        raw['taskType'] ??
        raw['category'] ??
        raw['category_name'] ??
        raw['task_category'];
    String taskType = 'Driver Task';
    if (tt is Map) {
      taskType =
          (tt['name'] ?? tt['category_name'] ?? tt['title'] ?? 'Driver Task')
              .toString();
    } else if (tt != null && tt.toString().isNotEmpty) {
      taskType = tt.toString();
    }

    String startTimeText = "10:00 AM";
    DateTime? startDateTime;
    if (startsAtStr.isNotEmpty) {
      try {
        startDateTime = DateTime.parse(startsAtStr).toLocal();
        startTimeText = DateFormat('hh:mm a').format(startDateTime);
      } catch (_) {}
    }

    // Enable Start Task button according to start time
    bool canStart = true;
    String startTimeMessage = "";
    if (startDateTime != null &&
        (status == 'ASSIGNED' || status == 'PLANNED')) {
      final now = DateTime.now();
      if (now.isBefore(startDateTime)) {
        canStart = false;
        startTimeMessage = "Starts at $startTimeText";
      }
    }

    Color statusColor = primaryBlue;
    if (status == 'STARTED' || status == 'IN_PROGRESS') {
      statusColor = const Color(0xFF10B981);
    } else if (status == 'COMPLETED' || status == 'VERIFIED') {
      statusColor = Colors.grey;
    } else if (status == 'CANCELLED') {
      statusColor = const Color(0xFFEF4444);
    }

    final taskTheme = getTaskThemeInfo(
      title,
      taskType,
      "$description $location",
    );

    return GestureDetector(
      onTap: () {
        if (taskId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  DriverTaskDetailsPage(taskId: taskId, initialTaskData: raw),
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
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
              // Header Row: Content Icon, Title, Task Number, Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: taskTheme.bgTint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            taskTheme.icon,
                            color: taskTheme.color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                taskType,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: taskTheme.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location Card UI (In-Campus vs Outer Route Start & End Locations)
              Builder(
                builder: (context) {
                  final String fromLoc = (raw['from_location'] ?? '')
                      .toString();
                  final String toLoc = (raw['to_location'] ?? '').toString();
                  final String inCampus = (raw['in_campus'] ?? '').toString();
                  final bool isInCampus =
                      inCampus.isNotEmpty || (fromLoc.isEmpty && toLoc.isEmpty);

                  if (isInCampus) {
                    final String campusLocName = inCampus.isNotEmpty
                        ? inCampus
                        : location;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              getLocationOrGoalIcon(
                                campusLocName,
                                isStart: true,
                              ),
                              color: const Color(0xFF6366F1),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF6366F1),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "IN-CAMPUS LOCATION",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF6366F1),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  campusLocName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: titleColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final String startLoc = fromLoc.isNotEmpty
                      ? fromLoc
                      : location;
                  final String endLoc = toLoc.isNotEmpty ? toLoc : description;

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.03),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Start Location Pin
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                getLocationOrGoalIcon(startLoc, isStart: true),
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "START LOCATION",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: subColor,
                                    ),
                                  ),
                                  Text(
                                    startLoc,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: titleColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Timeline connector
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 10,
                            top: 4,
                            bottom: 4,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 2,
                                height: 16,
                                color: primaryBlue.withValues(alpha: 0.3),
                              ),
                            ],
                          ),
                        ),
                        // End Location Pin
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                getLocationOrGoalIcon(endLoc, isStart: false),
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "END LOCATION",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: subColor,
                                    ),
                                  ),
                                  Text(
                                    endLoc,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: titleColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Bottom Bar: Time & Vehicle
              Row(
                children: [
                  Icon(
                    Icons.access_time_filled_rounded,
                    size: 14,
                    color: subColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    startTimeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: subColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.directions_bus_rounded, size: 14, color: subColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      vehicleNo,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: subColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
