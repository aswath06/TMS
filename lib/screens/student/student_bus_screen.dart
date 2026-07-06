import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripzo/screens/admin/request/daily_bus_run_details_page.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/components/common/structural_loading.dart';

class StudentBusScreen extends ConsumerStatefulWidget {
  const StudentBusScreen({super.key});

  @override
  ConsumerState<StudentBusScreen> createState() => _StudentBusScreenState();
}

class _StudentBusScreenState extends ConsumerState<StudentBusScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  List<dynamic> _runs = [];
  String? _error;
  String _selectedDateFilter = DateFormat('yyyy-MM-dd').format(DateTime.now()); // Default to today's date
  int? _userId;

  // Custom infinite horizontal scrolling calendar controller
  late ScrollController _dateScrollController;
  final int _infiniteScrollMiddle = 10000;
  bool _isScrolledFarFromToday = false;

  late AnimationController _jumpController;
  late Animation<double> _jumpAnimation;
  Timer? _jumpTimer;

  @override
  void initState() {
    super.initState();
    
    // Initialize scrolling controller centered around today
    _dateScrollController = ScrollController(
      initialScrollOffset: (_infiniteScrollMiddle * 68.0) - 100,
    );

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
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (mounted && _selectedDateFilter != todayStr) {
        _jumpController.forward(from: 0.0);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDate(_selectedDateFilter);
      _loadData();
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    _jumpController.dispose();
    _jumpTimer?.cancel();
    super.dispose();
  }

  void _scrollToDate(String dateStr) {
    if (dateStr == 'ALL' || !mounted) return;
    
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
    
    if (_dateScrollController.hasClients) {
      _dateScrollController.jumpTo(todayOffset + (diffDays * 68.0));
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await UserStore.getToken();
      _userId = await UserStore.getUserId() ?? 80;
      
      if (token == null) {
        if (mounted) {
          setState(() {
            _error = "Session expired. Please login again.";
            _isLoading = false;
          });
        }
        return;
      }

      String url = "${ApiConstants.baseUrl}/daily-bus/bus-run/get-all?user_id=$_userId";
      if (_selectedDateFilter != 'ALL') {
        url += "&service_date=$_selectedDateFilter";
      }

      debugPrint("StudentBusScreen URL: $url");

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          setState(() {
            _runs = decoded['data']['runs'] ?? [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = decoded['message'] ?? "Failed to load routes.";
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        setState(() {
          _error = "Session expired. Please login again.";
          _isLoading = false;
        });
      } else {
        String errorMsg = "An unexpected error occurred.";
        try {
          final decoded = json.decode(response.body);
          if (decoded['message'] != null && decoded['message'].toString().trim().isNotEmpty) {
            errorMsg = decoded['message'].toString();
          } else if (decoded['error'] != null && decoded['error'].toString().trim().isNotEmpty) {
            errorMsg = decoded['error'].toString();
          }
        } catch (_) {}
        setState(() {
          _error = errorMsg;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Connection error: $e";
          _isLoading = false;
        });
      }
    }
  }

  String _formatShift(dynamic shiftCode) {
    if (shiftCode == null) return 'FULL DAY';
    final s = shiftCode.toString().replaceAll('_', ' ').toUpperCase();
    if (s == 'FULL DAY') return 'FULL DAY';
    return s;
  }

  String _getVehicleNumber(Map<String, dynamic> run) {
    final assignments = run['assignment'] as List? ?? [];
    if (assignments.isEmpty) return 'No Vehicle';
    final numbers = assignments.map((a) => a['vehicle']?['vehicle_number']?.toString()).whereType<String>().toSet();
    return numbers.isNotEmpty ? numbers.join(', ') : 'No Vehicle';
  }

  String? _getBusNumber(Map<String, dynamic> run) {
    final assignments = run['assignment'] as List? ?? [];
    if (assignments.isEmpty) return null;
    final numbers = assignments.map((a) => a['vehicle']?['bus_number']?.toString()).whereType<String>().toSet();
    return numbers.isNotEmpty ? numbers.join(', ') : null;
  }

  Widget _buildStatusBadge(String status) {
    final String s = status.toUpperCase();
    final Map<String, Map<String, Color>> statusStyles = {
      'PLANNED': {
        'bg': const Color(0xFFFEF3C7),
        'text': const Color(0xFFD97706),
        'border': const Color(0xFFFDE68A),
      },
      'READY': {
        'bg': const Color(0xFFFCE7F3),
        'text': const Color(0xFFBE185D),
        'border': const Color(0xFFFBCFE8),
      },
      'STARTED': {
        'bg': const Color(0xFFDBEAFE),
        'text': const Color(0xFF2563EB),
        'border': const Color(0xFF93C5FD),
      },
      'ARRIVED_CAMPUS': {
        'bg': const Color(0xFFEEF2FF),
        'text': const Color(0xFF6366F1),
        'border': const Color(0xFFC7D2FE),
      },
      'CAMPUS_IN': {
        'bg': const Color(0xFFEEF2FF),
        'text': const Color(0xFF6366F1),
        'border': const Color(0xFFC7D2FE),
      },
      'FN_COMPLETED': {
        'bg': const Color(0xFFD1FAE5),
        'text': const Color(0xFF059669),
        'border': const Color(0xFFA7F3D0),
      },
      'DEPARTED_CAMPUS': {
        'bg': const Color(0xFFFEF3C7),
        'text': const Color(0xFFB45309),
        'border': const Color(0xFFFDE68A),
      },
      'HALTED': {
        'bg': const Color(0xFFFAF5FF),
        'text': const Color(0xFF8B5CF6),
        'border': const Color(0xFFE9D5FF),
      },
      'COMPLETED': {
        'bg': const Color(0xFFD1FAE5),
        'text': const Color(0xFF047857),
        'border': const Color(0xFFA7F3D0),
      },
      'CANCELLED': {
        'bg': const Color(0xFFFFE4E6),
        'text': const Color(0xFFBE123C),
        'border': const Color(0xFFFECDD3),
      },
    };

    final style = statusStyles[s] ??
        {
          'bg': const Color(0xFFF1F5F9),
          'text': const Color(0xFF475569),
          'border': const Color(0xFFE2E8F0),
        };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style['bg'],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style['border']!, width: 1),
      ),
      child: Text(
        s.replaceAll('_', ' '),
        style: TextStyle(
          color: style['text'],
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDriverMinimal(Color blue, String name, String info, Color sub) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: blue.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.directions_bus_rounded, color: blue, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  info,
                  style: TextStyle(
                    color: sub.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleTimelineRow(
    int order,
    String name,
    bool isLast,
    Color blue,
    Color titleColor,
    Color sub,
    bool isPast,
    bool isCompleted,
  ) {
    final Color dotColor = isCompleted
        ? const Color(0xFF10B981)
        : (isPast ? blue : const Color(0xFF94A3B8));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: dotColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: dotColor, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted
                        ? const Color(0xFF10B981)
                        : dotColor.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          "Daily Bus Routes",
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: titleColor,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: primaryBlue,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    "View daily campus bus schedules and details.",
                    style: TextStyle(color: subColor, fontSize: 14),
                  ),
                ),
              ),
              // "Route Dates" + "Jump to Today" section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Route Dates",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                          final bool shouldShowJump = (_selectedDateFilter != todayStr) || _isScrolledFarFromToday;
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
                                      _loadData();
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
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _DateSelectorHeaderDelegate(
                  isDark: isDark,
                  bgColor: bgColor,
                  titleColor: titleColor,
                  subColor: subColor,
                  primaryBlue: primaryBlue,
                  selectedDate: _selectedDateFilter,
                  onDateSelected: (dateStr) {
                    if (_selectedDateFilter == dateStr) return;
                    setState(() {
                      _selectedDateFilter = dateStr;
                    });
                    _loadData();
                    _scrollToDate(dateStr);
                  },
                  scrollController: _dateScrollController,
                  infiniteScrollMiddle: _infiniteScrollMiddle,
                ),
              ),
              if (_isLoading && _runs.isEmpty)
                const SliverToBoxAdapter(
                  child: StructuralLoading(
                    padding: 24,
                    itemCount: 4,
                  ),
                )
              else if (_error != null && _runs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(_error!, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadData,
                            child: const Text("Retry"),
                          )
                        ],
                      ),
                    ),
                  ),
                )
              else if (_runs.isEmpty)
                _buildEmptyState(subColor)
              else
                _buildRunsList(cardColor, titleColor, subColor, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color subColor) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_bus_outlined, size: 64, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            const Text("No bus routes for this date", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Please select another date using the slider above.",
                textAlign: TextAlign.center,
                style: TextStyle(color: subColor, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunsList(Color cardColor, Color titleColor, Color subColor, bool isDark) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final run = _runs[index] as Map<String, dynamic>;
          final status = run['status']?.toString() ?? 'UNKNOWN';
          final runName = run['run_name']?.toString() ?? 'Route';
          final startLoc = run['start_location_name']?.toString() ?? 'N/A';
          final haltLoc = run['halt_location_name']?.toString() ?? 'N/A';
          final shift = _formatShift(run['shift_code']);
          
          final routeData = run['dailyBusRoute'] as Map<String, dynamic>?;
          final routeName = routeData?['route_name']?.toString() ?? 'N/A';
          final maxCapacity = routeData?['max_vehicle_capacity'] ?? 60;
          
          final vehicleNo = _getVehicleNumber(run);
          final busNo = _getBusNumber(run);

          // Build student card matching the supervisor card, but formatted with student properties
          return FadeInWidget(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: GestureDetector(
                onTap: () => _loadRunDetailsAndNavigate(run),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Date + Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF6366F1)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    run['service_date']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildStatusBadge(status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Title: run_name
                      Text(
                        runName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      
                      // Route info + Capacity
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(Icons.directions_bus_outlined, size: 14, color: subColor),
                          const SizedBox(width: 4),
                          Text(
                            "Route: ",
                            style: TextStyle(
                              fontSize: 12,
                              color: subColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            routeName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "•",
                            style: TextStyle(fontSize: 12, color: subColor),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.airline_seat_recline_normal_rounded, size: 14, color: subColor),
                          const SizedBox(width: 4),
                          Text(
                            "Capacity: ",
                            style: TextStyle(
                              fontSize: 12,
                              color: subColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "$maxCapacity Seats",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Vehicle + Bus Panel (Bus Number instead of driver name)
                      _buildDriverMinimal(
                        const Color(0xFF6366F1), 
                        "Bus Number: ${busNo != null && busNo.toLowerCase() != 'null' ? busNo : 'N/A'}", 
                        "Vehicle: $vehicleNo", 
                        subColor
                      ),
                      const SizedBox(height: 24),
                      
                      // Timeline sequence
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
                            shift.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF6366F1),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildSimpleTimelineRow(0, startLoc, false, const Color(0xFF6366F1), titleColor, subColor, true, status.toUpperCase() == 'COMPLETED'),
                      _buildSimpleTimelineRow(1, haltLoc, true, const Color(0xFF6366F1), titleColor, subColor, status.toUpperCase() == 'COMPLETED', status.toUpperCase() == 'COMPLETED'),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        childCount: _runs.length,
      ),
    );
  }

  Future<void> _loadRunDetailsAndNavigate(Map<String, dynamic> run) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyBusRunDetailsPage(runData: run, showEditIcon: false),
      ),
    );
  }
}

class _DateSelectorHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isDark;
  final Color bgColor;
  final Color titleColor;
  final Color subColor;
  final Color primaryBlue;
  final String selectedDate;
  final Function(String) onDateSelected;
  final ScrollController scrollController;
  final int infiniteScrollMiddle;

  _DateSelectorHeaderDelegate({
    required this.isDark,
    required this.bgColor,
    required this.titleColor,
    required this.subColor,
    required this.primaryBlue,
    required this.selectedDate,
    required this.onDateSelected,
    required this.scrollController,
    required this.infiniteScrollMiddle,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          // Fixed ALL option on the LEFT
          GestureDetector(
            onTap: () => onDateSelected('ALL'),
            child: Container(
              width: 65,
              height: 70,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: selectedDate == 'ALL' ? primaryBlue : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selectedDate == 'ALL' ? primaryBlue : titleColor.withValues(alpha: 0.1),
                ),
                boxShadow: selectedDate == 'ALL'
                    ? [BoxShadow(color: primaryBlue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color: selectedDate == 'ALL' ? Colors.white : subColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "ALL",
                    style: TextStyle(
                      color: selectedDate == 'ALL' ? Colors.white : titleColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Scrolling dates
          Expanded(
            child: SizedBox(
              height: 70,
              child: ListView.builder(
                itemExtent: 68.0,
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final date = DateTime.now().add(Duration(days: index - infiniteScrollMiddle));
                  final formattedDateStr = DateFormat('yyyy-MM-dd').format(date);
                  final isSelected = selectedDate == formattedDateStr;
                  return GestureDetector(
                    onTap: () => onDateSelected(formattedDateStr),
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
      ),
    );
  }

  @override
  double get maxExtent => 94.0;

  @override
  double get minExtent => 94.0;

  @override
  bool shouldRebuild(covariant _DateSelectorHeaderDelegate oldDelegate) {
    return selectedDate != oldDelegate.selectedDate;
  }
}

class FadeInWidget extends StatelessWidget {
  final Widget child;
  const FadeInWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
