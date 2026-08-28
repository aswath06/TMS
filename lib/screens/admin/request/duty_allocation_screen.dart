import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripzo/screens/admin/request/duty_allocation_details_screen.dart';

class DutyAllocationScreen extends ConsumerStatefulWidget {
  const DutyAllocationScreen({super.key});

  @override
  ConsumerState<DutyAllocationScreen> createState() => _DutyAllocationScreenState();
}

class _DutyAllocationScreenState extends ConsumerState<DutyAllocationScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _selectedFilter = 'ALL';
  String _selectedDateFilter = 'ALL';

  final int _infiniteScrollMiddle = 100000;
  late ScrollController _dateScrollController;
  late AnimationController _jumpController;
  late Animation<double> _jumpAnimation;
  Timer? _jumpTimer;
  bool _isScrolledFarFromToday = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
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
      final double listWidth = MediaQuery.of(context).size.width - 48 - 77;
      final double todayOffset = (_infiniteScrollMiddle * 68.0) - (listWidth / 2) + 34;
      
      DateTime selectedDate;
      try {
        selectedDate = DateFormat('yyyy-MM-dd').parse(_selectedDateFilter);
      } catch (e) {
        selectedDate = DateTime.now();
      }
      
      final DateTime now = DateTime.now();
      final DateTime todayDate = DateTime(now.year, now.month, now.day);
      final DateTime selDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      final int diffDays = selDate.difference(todayDate).inDays;
      
      _dateScrollController.jumpTo(todayOffset + (diffDays * 68.0));
      
      final store = ref.read(scheduleDutyStoreProvider);
      if (store.masterSchedules.isEmpty && !store.isLoading) {
        store.fetchMasterSchedules(isRefresh: true, fromDate: _selectedDateFilter, toDate: _selectedDateFilter);
      }
    });
  }

  @override
  void dispose() {
    _jumpTimer?.cancel();
    _jumpController.dispose();
    _scrollController.dispose();
    _dateScrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    // Implement pagination if needed
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(scheduleDutyStoreProvider).fetchMasterSchedules(isRefresh: true, search: query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final store = ref.watch(scheduleDutyStoreProvider);
    
    final schedules = store.masterSchedules.where((req) {
      final String s = (req['status'] ?? "").toString().toUpperCase();
      
      if (_selectedFilter == 'ALL') return true;
      if (_selectedFilter == 'PLANNED') return s == 'PLANNED';
      if (_selectedFilter == 'READY') return s == 'READY';
      if (_selectedFilter == 'ONGOING') return s == 'ONGOING' || s == 'STARTED';
      if (_selectedFilter == 'COMPLETED') return s == 'COMPLETED';
      
      return true;
    }).toList();

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
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: titleColor,
                                size: 24,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.assignment_ind_rounded,
                            color: primaryBlue,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Duty Allocation",
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
                            onPressed: () {
                              ref.read(scheduleDutyStoreProvider).fetchMasterSchedules(isRefresh: true);
                            },
                            icon: Icon(
                              Icons.refresh_rounded,
                              color: primaryBlue,
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Manage and monitor all duty schedules",
                    style: TextStyle(
                      color: subColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildSearchBar(isDark, primaryBlue, subColor)),
                      const SizedBox(width: 12),
                      _buildFilterButton(primaryBlue, titleColor, isDark),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Schedule Dates",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                          if (_selectedFilter != 'ALL') ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _selectedFilter,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: primaryBlue,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Builder(
                        builder: (context) {
                          final bool shouldShowJump = (_selectedDateFilter != DateFormat('yyyy-MM-dd').format(DateTime.now())) || _isScrolledFarFromToday;
                          return AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: shouldShowJump ? 1.0 : 0.0,
                            child: AnimatedBuilder(
                              animation: _jumpAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, _jumpAnimation.value),
                                  child: child,
                                );
                              },
                              child: IgnorePointer(
                                ignoring: !shouldShowJump,
                                child: GestureDetector(
                                  onTap: () {
                                    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                                    if (_selectedDateFilter != todayStr) {
                                      setState(() => _selectedDateFilter = todayStr);
                                      ref.read(scheduleDutyStoreProvider).fetchMasterSchedules(isRefresh: true, fromDate: todayStr, toDate: todayStr);
                                    }
                                    
                                    final double listWidth = MediaQuery.of(context).size.width - 48 - 77;
                                    final double offset = (_infiniteScrollMiddle * 68.0) - (listWidth / 2) + 34;
                                    _dateScrollController.animateTo(offset, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
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
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDateScroller(primaryBlue, titleColor, subColor, isDark),
                ],
              ),
            ),
            Expanded(
              child: store.isLoading && schedules.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => store.fetchMasterSchedules(isRefresh: true),
                      child: schedules.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.3,
                                ),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.assignment_ind_rounded, size: 48, color: subColor.withOpacity(0.2)),
                                      const SizedBox(height: 16),
                                      Text(
                                        _selectedFilter == 'ALL' ? "No active schedules" : "No $_selectedFilter schedules found",
                                        style: TextStyle(
                                          color: subColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              itemCount: schedules.length,
                              itemBuilder: (context, index) {
                                return _buildScheduleCard(schedules[index], cardColor, titleColor, subColor, primaryBlue);
                              },
                            ),
                    ),
            ),
          ],
        ),
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
            ref.read(scheduleDutyStoreProvider).fetchMasterSchedules(isRefresh: true, fromDate: '', toDate: '');
          },
          child: Container(
            width: 65,
            height: 70,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: _selectedDateFilter == 'ALL' ? primaryBlue : (isDark ? const Color(0xFF1E293B) : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedDateFilter == 'ALL' ? primaryBlue : titleColor.withOpacity(0.1),
              ),
              boxShadow: _selectedDateFilter == 'ALL'
                  ? [BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
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
                    ref.read(scheduleDutyStoreProvider).fetchMasterSchedules(isRefresh: true, fromDate: formattedDateStr, toDate: formattedDateStr);
                  },
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryBlue : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? primaryBlue : titleColor.withOpacity(0.1),
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(date).toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.white.withOpacity(0.9) : subColor,
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
                            color: isSelected ? Colors.white.withOpacity(0.9) : subColor,
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

  Widget _buildSearchBar(bool isDark, Color primaryBlue, Color subColor) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: "Search schedules...",
          hintStyle: TextStyle(
            color: subColor.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: subColor),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: subColor),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged("");
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildFilterButton(Color p, Color t, bool d) {
    return GestureDetector(
      onTap: () => _showFilterBottomSheet(p, t, d),
      child: Container(
        height: 54,
        width: 54,
        decoration: BoxDecoration(
          color: d ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: d ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Icon(Icons.tune_rounded, color: p, size: 24),
      ),
    );
  }

  void _showFilterBottomSheet(Color p, Color t, bool d) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: d ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Filter Schedules",
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: t,
                  ),
                ),
                const SizedBox(height: 24),
                StatefulBuilder(
                  builder: (context, setModalState) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: ['ALL', 'PLANNED', 'READY', 'ONGOING', 'COMPLETED'].map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return ChoiceChip(
                          label: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? Colors.white : t,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedFilter = filter);
                              Navigator.pop(context);
                            }
                          },
                          backgroundColor: d ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          selectedColor: p,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        );
                      }).toList(),
                    );
                  }
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    final String s = status.toUpperCase();
    final Map<String, Map<String, Color>> statusStyles = {
      'PLANNED': {
        'bg': const Color(0xFFFDF2F8),
        'text': const Color(0xFFEC4899),
        'border': const Color(0xFFFBCFE8),
      },
      'READY': {
        'bg': const Color(0xFFFFFBEB),
        'text': const Color(0xFFF59E0B),
        'border': const Color(0xFFFDE68A),
      },
      'STARTED': {
        'bg': const Color(0xFFDBEAFE),
        'text': const Color(0xFF2563EB),
        'border': const Color(0xFF93C5FD),
      },
      'ONGOING': {
        'bg': const Color(0xFFEEF2FF),
        'text': const Color(0xFF6366F1),
        'border': const Color(0xFFC7D2FE),
      },
      'COMPLETED': {
        'bg': const Color(0xFFECFDF5),
        'text': const Color(0xFF10B981),
        'border': const Color(0xFFA7F3D0),
      },
    };

    final style = statusStyles[s] ??
        {
          'bg': Colors.grey.withOpacity(0.1),
          'text': Colors.grey,
          'border': Colors.grey.withOpacity(0.2),
        };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style['bg'],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style['border']!, width: 1),
      ),
      child: Text(
        s,
        style: TextStyle(
          color: style['text'],
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildScheduleCard(
    Map<String, dynamic> schedule,
    Color cardColor,
    Color titleColor,
    Color subColor,
    Color primaryBlue,
  ) {
    final status = schedule['status'] ?? 'UNKNOWN';
    final name = schedule['schedule_name'] ?? schedule['template']?['name'] ?? 'Unnamed Schedule';
    final dutyDateStr = schedule['duty_date'];
    
    String formattedDate = dutyDateStr ?? 'N/A';
    if (dutyDateStr != null) {
      try {
        final date = DateTime.parse(dutyDateStr);
        formattedDate = DateFormat('MMM dd, yyyy').format(date);
      } catch (e) {
        // ignore
      }
    }

    final shifts = schedule['masterShifts'] as List? ?? [];
    int totalDrivers = 0;
    int totalVehicles = 0;
    
    for (var shift in shifts) {
      final drivers = shift['drivers'] as List? ?? [];
      final vehicles = shift['vehicles'] as List? ?? [];
      totalDrivers += drivers.length;
      totalVehicles += vehicles.length;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DutyAllocationDetailsScreen(schedule: schedule),
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
                    Icon(Icons.calendar_today_rounded, size: 18, color: primaryBlue),
                    const SizedBox(width: 6),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people_outline_rounded, size: 14, color: subColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "$totalDrivers Drivers Assigned",
                              style: TextStyle(
                                fontSize: 13,
                                color: subColor,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.directions_bus_filled_rounded, size: 14, color: subColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "$totalVehicles Vehicles Mapped",
                              style: TextStyle(
                                fontSize: 13,
                                color: subColor,
                                fontWeight: FontWeight.w600,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.swap_calls_rounded, color: primaryBlue, size: 16),
                      const SizedBox(height: 4),
                      Text(
                        "${shifts.length} Shifts",
                        style: TextStyle(
                          color: primaryBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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

  Widget _buildInfoChip(Color color, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
