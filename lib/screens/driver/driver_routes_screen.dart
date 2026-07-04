import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tripzo/store/providers.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/daily_routines_store.dart';
import 'package:tripzo/store/istamil.dart'; 
import 'package:tripzo/screens/faculty/missions/mission_details_screen.dart';
import 'package:tripzo/screens/admin/request/daily_routines_page.dart';
import 'package:tripzo/screens/driver/assignment_details_screen.dart';
import 'package:tripzo/screens/admin/request/daily_bus_run_details_page.dart';
import 'package:shimmer/shimmer.dart';



class DriverRoutesScreen extends ConsumerStatefulWidget {
  const DriverRoutesScreen({super.key});

  @override
  ConsumerState<DriverRoutesScreen> createState() => _DriverRoutesScreenState();


}

class _DriverRoutesScreenState extends ConsumerState<DriverRoutesScreen> with SingleTickerProviderStateMixin {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Toggle state
  bool _isDailyBusRoutes = false;

  // Date slider state
  late String _selectedDateFilter;
  late ScrollController _dateScrollController;
  final int _infiniteScrollMiddle = 5000;
  late AnimationController _jumpController;
  late Animation<double> _jumpAnimation;
  Timer? _jumpTimer;
  bool _isScrolledFarFromToday = false;

  @override
  void initState() {
    super.initState();
    _initPageData();
  }

  void _initPageData() {
    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _selectedDateFilter = todayStr;
    
    _dateScrollController = ScrollController(initialScrollOffset: (_infiniteScrollMiddle * 68.0) - 100);
    _dateScrollController.addListener(() {
      if (!mounted) return;
      final double listWidth = MediaQuery.of(context).size.width - 48 - 77;
      final double todayOffset = (_infiniteScrollMiddle * 68.0) - (listWidth / 2) + 34;
      final bool isFar = (_dateScrollController.offset - todayOffset).abs() > (15 * 68.0);
      
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
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0).chain(CurveTween(curve: Curves.easeOut)), weight: 50.0),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50.0),
    ]).animate(_jumpController);

    _jumpTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _selectedDateFilter != DateFormat('yyyy-MM-dd').format(DateTime.now())) {
        _jumpController.forward(from: 0.0);
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
    final double todayOffset = (_infiniteScrollMiddle * 68.0) - (listWidth / 2) + 34;
    
    DateTime selectedDate;
    try {
      selectedDate = DateFormat('yyyy-MM-dd').parse(dateStr);
    } catch (e) {
      selectedDate = DateTime.now();
    }
    
    final DateTime now = DateTime.now();
    final DateTime todayDate = DateTime(now.year, now.month, now.day);
    final DateTime selDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
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
    if (dailyStore.selectedDate != _selectedDateFilter || dailyStore.runs.isEmpty) {
      await dailyStore.fetchDailyRoutines(isRefresh: true, date: _selectedDateFilter);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateScrollController.dispose();
    _jumpController.dispose();
    _jumpTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isTamil = LanguageStore.isTamil;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: isTamil ? "பயண பெயரைத் தேடுக..." : "Search route name...",
                  hintStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  ref.read(driverStoreProvider).updateSearch(val);
                },
              )
            : Text(
                isTamil ? "உங்கள் பயணங்கள்" : "My Journeys",
                style: TextStyle(color: titleColor, fontWeight: FontWeight.w900),
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
                  icon: Icon(Icons.search_rounded, color: titleColor),
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
                color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isDailyBusRoutes = false),
                      child: Container(
                        decoration: BoxDecoration(
                          color: !_isDailyBusRoutes ? primaryBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isTamil ? "பயணங்கள்" : "Routes",
                          style: TextStyle(
                            color: !_isDailyBusRoutes ? Colors.white : subColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isDailyBusRoutes = true),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _isDailyBusRoutes ? primaryBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isTamil ? "தினசரிப் பேருந்துப் பயணங்கள்" : "Daily Bus Routes",
                          style: TextStyle(
                            color: _isDailyBusRoutes ? Colors.white : subColor,
                            fontWeight: FontWeight.bold,
                          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Route Dates",
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: titleColor),
                ),
                AnimatedBuilder(
                  animation: _jumpAnimation,
                  builder: (context, child) {
                    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                    final bool shouldShowJump = _selectedDateFilter != todayStr || _isScrolledFarFromToday;
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
                      final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                      if (_selectedDateFilter != todayStr) {
                        setState(() => _selectedDateFilter = todayStr);
                        _fetchDataForSelectedDate();
                      }
                      _scrollToDate(todayStr);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(Icons.fast_rewind_rounded, size: 14, color: primaryBlue),
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
            child: _isDailyBusRoutes ? _buildDailyBusRoutesList() : _buildRouteList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateScroller(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
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
              color: _selectedDateFilter == 'ALL' ? primaryBlue : (isDark ? const Color(0xFF1E293B) : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedDateFilter == 'ALL' ? primaryBlue : titleColor.withValues(alpha: 0.1),
              ),
              boxShadow: _selectedDateFilter == 'ALL'
                  ? [BoxShadow(color: primaryBlue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_rounded, size: 20, color: _selectedDateFilter == 'ALL' ? Colors.white : subColor),
                const SizedBox(height: 4),
                Text(
                  "ALL",
                  style: TextStyle(
                    color: _selectedDateFilter == 'ALL' ? Colors.white : titleColor,
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
                final date = DateTime.now().add(Duration(days: index - _infiniteScrollMiddle));
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
                      color: isSelected ? primaryBlue : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? primaryBlue : titleColor.withValues(alpha: 0.1),
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: primaryBlue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(date).toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.white.withValues(alpha: 0.9) : subColor,
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
                            color: isSelected ? Colors.white.withValues(alpha: 0.9) : subColor,
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
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
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
        final String routeName = (m['routeName'] ?? "").toString().toLowerCase();
        final String pickup = (m['startLocation'] ?? "").toString().toLowerCase();
        final String drop = (m['destinationLocation'] ?? "").toString().toLowerCase();
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
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    
    // identify search query for daily bus routes
    final driverStore = ref.watch(driverStoreProvider);
    final query = driverStore.searchQuery.toLowerCase().trim();

    List<dynamic> list = List.from(dailyStore.runs);

    if (query.isNotEmpty) {
      list = list.where((m) {
        final String name = (m['route']?['name'] ?? "").toString().toLowerCase();
        final String driver = (m['driver']?['name'] ?? "").toString().toLowerCase();
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
              query.isNotEmpty ? Icons.search_off_rounded : Icons.directions_bus_filled_outlined,
              size: 64,
              color: Colors.grey.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              query.isNotEmpty 
                ? (isTamil ? "பொருத்தமான பேருந்துப் பயணங்கள் எதுவும் இல்லை" : "No matching bus routes found") 
                : (isTamil ? "பேருந்துப் பயணங்கள் இல்லை" : "No daily bus routes for this date"), 
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)
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
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
    final String time = _formatDate(mission['start_datetime'] ?? mission['startDate']);
    final dynamic rawStatusValue = mission['status'];
    final tripStatuses = mission['trip_instance_statuses'] as List?;
    final String? tripStatus = (tripStatuses != null && tripStatuses.isNotEmpty) ? tripStatuses[0]['status']?.toString().toUpperCase() : null;
    
    // Status Logic - Using backend status directly as requested
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
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
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
                _buildStatusBadgeWidget(backendStatus, displayText: statusStr),
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
            Container(width: 2, height: 20, color: primary.withOpacity(0.2)),
            Icon(Icons.location_on, color: Colors.redAccent.withOpacity(0.7), size: 18),
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

  Widget _buildEmptyState({bool isSearch = false}) {
    final bool isTamil = LanguageStore.isTamil;
    String text = "";
    if (isSearch) {
      text = isTamil ? "பொருத்தமான பயணங்கள் எதுவும் இல்லை" : "No matching journeys found";
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
            color: Colors.grey.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
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
      final vNumbers = assignments.map((a) => a['vehicle']?['vehicle_number']).whereType<String>().toSet();
      if (vNumbers.isNotEmpty) vehicleNo = vNumbers.join(", ");
    }

    final int passengerCount = run['campus_in_count'] ?? (run['students'] as List?)?.length ?? 0;


    return GestureDetector(
      onTap: () async {
        if (context.mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DailyBusRunDetailsPage(runData: run, showEditIcon: false),
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
    final shimmerBase = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200;
    final shimmerHighlight = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade100;

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
}
