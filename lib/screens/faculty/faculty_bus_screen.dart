import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tripzo/screens/admin/request/daily_bus_run_details_page.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:google_fonts/google_fonts.dart';

class FacultyBusScreen extends ConsumerStatefulWidget {
  const FacultyBusScreen({super.key});

  @override
  ConsumerState<FacultyBusScreen> createState() => _FacultyBusScreenState();
}

class _FacultyBusScreenState extends ConsumerState<FacultyBusScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  List<dynamic> _runs = [];
  String? _error;
  String _selectedDateFilter = DateFormat('yyyy-MM-dd').format(DateTime.now()); // Default to today's date
  int? _userId;

  final int _infiniteScrollMiddle = 100000;
  late ScrollController _dateScrollController;
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
      _userId = await UserStore.getUserId() ?? 80; // Fallback to 80 if null
      
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

      debugPrint("FacultyBusScreen URL: $url");
      debugPrint("FacultyBusScreen Header Token: $token");

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
          _error = "Connection failed. Please try again.";
          _isLoading = false;
        });
      }
    }
  }

  String _formatShift(String? shiftCode) {
    if (shiftCode == null || shiftCode.isEmpty) return "N/A";
    return shiftCode.replaceAll('_', ' ').split(' ').map((str) {
      if (str.isEmpty) return "";
      return str[0].toUpperCase() + str.substring(1).toLowerCase();
    }).join(' ');
  }

  String _getVehicleNumber(Map<String, dynamic> run) {
    final List<dynamic>? assignments = run['assignment'];
    if (assignments != null && assignments.isNotEmpty) {
      for (var assign in assignments) {
        final vehicle = assign['vehicle'];
        if (vehicle != null && vehicle['vehicle_number'] != null) {
          return vehicle['vehicle_number'].toString();
        }
      }
    }
    return "N/A";
  }

  String? _getBusNumber(Map<String, dynamic> run) {
    final List<dynamic>? assignments = run['assignment'];
    if (assignments != null && assignments.isNotEmpty) {
      for (var assign in assignments) {
        final vehicle = assign['vehicle'];
        if (vehicle != null && vehicle['bus_number'] != null) {
          return vehicle['bus_number'].toString();
        }
      }
    }
    return null;
  }

  String _getDriverName(Map<String, dynamic> run) {
    final List<dynamic>? assignments = run['assignment'];
    if (assignments != null && assignments.isNotEmpty) {
      for (var assign in assignments) {
        final driver = assign['driver'];
        if (driver != null) {
          final user = driver['user'];
          if (user != null && user['name'] != null) {
            return user['name'].toString();
          }
        }
      }
    }
    return "N/A";
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: blue.withValues(alpha: 0.1)),
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
    bool isReached,
    bool isNextReached,
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
                  color: isReached ? blue : Colors.transparent,
                  border: Border.all(
                    color: isReached ? blue : Colors.grey.shade400,
                    width: 2.5,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2, 
                    color: isNextReached ? blue.withValues(alpha: 0.3) : Colors.grey.shade300
                  ),
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
                  color: isReached ? title : sub,
                  fontWeight: isReached ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const Color primaryBlue = Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: primaryBlue,
          onRefresh: _loadData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _buildAnimatedHeader(titleColor, subColor),
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
                                        const Icon(Icons.fast_rewind_rounded, size: 14, color: primaryBlue),
                                        const SizedBox(width: 4),
                                        const Text(
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: _buildDateScroller(primaryBlue, titleColor, subColor, isDark),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false, 
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryBlue)
                    )
                  )
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false, 
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0), 
                      child: Text(
                        _error!, 
                        textAlign: TextAlign.center, 
                        style: TextStyle(color: subColor)
                      )
                    )
                  )
                )
              else if (_runs.isEmpty)
                _buildEmptyState(subColor)
              else
                _buildRunsList(cardColor, titleColor, subColor, isDark),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader(Color titleColor, Color subColor) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Daily Bus Routes",
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: titleColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "View daily campus bus schedules and details.",
              style: TextStyle(color: subColor, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateScroller(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    return Row(
      children: [
        // Fixed ALL option
        GestureDetector(
          onTap: () {
            if (_selectedDateFilter == 'ALL') return;
            setState(() => _selectedDateFilter = 'ALL');
            _loadData();
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
                Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: _selectedDateFilter == 'ALL' ? Colors.white : subColor,
                ),
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
        // Scrolling dates
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
                    _loadData();
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
                          DateFormat('E').format(date).toUpperCase(), // e.g., SAT
                          style: TextStyle(
                            color: isSelected ? Colors.white.withValues(alpha: 0.9) : subColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd').format(date), // e.g., 06
                          style: TextStyle(
                            color: isSelected ? Colors.white : titleColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(date).toUpperCase(), // e.g., JUN
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
          final driverName = _getDriverName(run);


          // Build a card design exactly matching the missions card
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
                      Row(
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
                      
                      // Driver Minimal panel details
                      _buildDriverMinimal(
                        const Color(0xFF6366F1), 
                        driverName, 
                        "Vehicle: $vehicleNo${busNo != null ? " (Bus $busNo)" : ""}", 
                        subColor
                      ),
                      const SizedBox(height: 24),
                      
                      // Timeline sequence stop titles
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
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
