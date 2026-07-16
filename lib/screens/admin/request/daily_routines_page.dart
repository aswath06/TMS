import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/screens/admin/request/daily_bus_run_details_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripzo/utils/api_error_parser.dart';
import 'package:tripzo/screens/admin/request/daily_bus_run_download_modal.dart';

class DailyRoutinesListPage extends ConsumerStatefulWidget {
  const DailyRoutinesListPage({super.key});

  @override
  ConsumerState<DailyRoutinesListPage> createState() => _DailyRoutinesListPageState();
}

class _DailyRoutinesListPageState extends ConsumerState<DailyRoutinesListPage> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _selectedDateFilter = '';
  String _selectedFilter = 'ALL';
  final Map<String, bool> _loadingRuns = {};
  bool _isListView = false;

  Future<void> _markRunReadyFromList(Map<String, dynamic> run, Color primaryBlue) async {
    final String runId = run['id']?.toString() ?? '';
    final String serviceDate = run['service_date'] ?? '';
    if (runId.isEmpty || serviceDate.isEmpty) return;

    setState(() {
      _loadingRuns[runId] = true;
    });

    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        _showSnackBar("Session expired. Please log in again.", Colors.red);
        return;
      }

      final url = "${ApiConstants.baseUrl}/daily-bus/bus-runs/$runId/mark-ready";
      
      // Console log request curl
      final String curlCmd = "curl '$url' \\\n"
          "  -H 'accept: */*' \\\n"
          "  -H 'authorization: TMS $token' \\\n"
          "  -H 'content-type: application/json' \\\n"
          "  --data-raw '{\"service_date\":\"$serviceDate\"}'";
      debugPrint("---- [HTTP REQUEST CURL] ----\n$curlCmd\n----------------------------");

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: json.encode({
          "service_date": serviceDate,
        }),
      );

      // Console log HTTP response
      debugPrint(ApiErrorParser.parse(response, fallback: "---- [HTTP RESPONSE STATUS"));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final resData = data['data'] ?? {};
          final int passengers = resData['passengers_copied'] ?? 0;
          final int faculties = resData['faculties_copied'] ?? 0;
          
          _showSnackBar("Run marked as READY. Copied $passengers passengers and $faculties faculties.", Colors.green);
          
          ref.read(dailyRoutinesStoreProvider).fetchDailyRoutines(isRefresh: true);
        } else {
          _showSnackBar(data['message'] ?? "Failed to mark run as ready", Colors.red);
        }
      } else {
        String errorMsg = "An unexpected error occurred.";
        try {
          final Map<String, dynamic> data = json.decode(response.body);
          if (data['message'] != null && data['message'].toString().trim().isNotEmpty) {
            errorMsg = data['message'].toString();
          } else if (data['error'] != null && data['error'].toString().trim().isNotEmpty) {
            errorMsg = data['error'].toString();
          }
        } catch (_) {}
        _showSnackBar(errorMsg, Colors.red);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e", Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _loadingRuns[runId] = false;
        });
      }
    }
  }

  Future<void> _verifyCampusInOtpFromList(String runId, String otp, String type) async {
    final String runKey = runId.toString();
    setState(() => _loadingRuns[runKey] = true);
    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        _showSnackBar("Session expired. Please log in again.", Colors.red);
        return;
      }

      final url = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/$runId/verify-campus-in-otp";
      final bodyData = {
        "otp_code": otp,
        "type": type,
      };

      // Console log request curl
      final String curlCmd = "curl '$url' \\\n"
          "  -H 'accept: */*' \\\n"
          "  -H 'authorization: TMS $token' \\\n"
          "  -H 'content-type: application/json' \\\n"
          "  --data-raw '${json.encode(bodyData)}'";
      debugPrint("---- [HTTP REQUEST CURL] ----\n$curlCmd\n----------------------------");

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(bodyData),
      );

      // Console log HTTP response
      debugPrint(ApiErrorParser.parse(response, fallback: "---- [HTTP RESPONSE STATUS"));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          _showSnackBar("Campus In OTP verified successfully.", Colors.green);
          ref.read(dailyRoutinesStoreProvider).fetchDailyRoutines(isRefresh: true);
        } else {
          _showSnackBar(data['message'] ?? "Verification failed", Colors.red);
        }
      } else {
        String errorMsg = "An unexpected error occurred.";
        try {
          final Map<String, dynamic> data = json.decode(response.body);
          if (data['message'] != null && data['message'].toString().trim().isNotEmpty) {
            errorMsg = data['message'].toString();
          } else if (data['error'] != null && data['error'].toString().trim().isNotEmpty) {
            errorMsg = data['error'].toString();
          }
        } catch (_) {}
        _showSnackBar(errorMsg, Colors.red);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e", Colors.red);
    } finally {
      setState(() => _loadingRuns[runKey] = false);
    }
  }

  void _showVerifyOtpBottomSheetFromList(Map<String, dynamic> run, Color primaryBlue) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    String autoOtp = '';
    final assignments = run['assignment'] as List? ?? [];
    if (assignments.isNotEmpty) {
      final firstV = assignments.firstWhere((a) => a['vehicle']?['vehicle_otp'] != null, orElse: () => null);
      if (firstV != null) {
        autoOtp = firstV['vehicle']['vehicle_otp']?.toString() ?? '';
      }
    }

    final TextEditingController otpController = TextEditingController(text: autoOtp);
    String selectedType = run['status']?.toString().toUpperCase() == 'AN_STARTED' ? 'AN' : 'FN';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Verify Campus In OTP",
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Enter verification OTP to confirm campus arrival.",
                      style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 20),
                    
                    // OTP Text Field
                    TextField(
                      controller: otpController,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: "OTP Code",
                        labelStyle: TextStyle(color: subColor),
                        hintText: "Enter OTP code",
                        prefixIcon: Icon(Icons.vpn_key_rounded, color: primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryBlue, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Shift Type Selection Segment
                    Text(
                      "Shift Type",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subColor),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['FN', 'AN'].map((type) {
                        final bool isSelected = selectedType == type;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() => selectedType = type);
                            },
                            child: Container(
                              margin: EdgeInsets.only(
                                right: type == 'FN' ? 8.0 : 0.0,
                                left: type == 'AN' ? 8.0 : 0.0,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? primaryBlue : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? primaryBlue : Colors.transparent),
                              ),
                              child: Center(
                                child: Text(
                                  type == 'FN' ? "FN (Morning)" : "AN (Evening)",
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : subColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final String otp = otpController.text.trim();
                          if (otp.isEmpty) {
                            _showSnackBar("Please enter the OTP", Colors.orange);
                            return;
                          }
                          Navigator.pop(context);
                          _verifyCampusInOtpFromList(run['id']?.toString() ?? '', otp, selectedType);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          "Verify OTP",
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
        );
      },
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

  final int _infiniteScrollMiddle = 100000;
  late ScrollController _dateScrollController;

  late AnimationController _jumpController;
  late Animation<double> _jumpAnimation;
  Timer? _jumpTimer;
  bool _isScrolledFarFromToday = false;

  bool _isAuthorized = false;
  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
    _checkAuthorization();
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isListView = prefs.getBool('daily_routines_is_list_view') ?? false;
      });
    }
  }

  Future<void> _checkAuthorization() async {
    final role = await UserStore.getRole();
    if (!mounted) return;

    if (role != null && (role.toLowerCase() == 'super admin' || role.toLowerCase() == 'transport admin')) {
      setState(() {
        _isAuthorized = true;
        _checkingAuth = false;
      });
      _initPageData();
    } else {
      setState(() {
        _isAuthorized = false;
        _checkingAuth = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Denied. Super Admin or Transport Admin access only.'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop();
      });
    }
  }

  void _initPageData() {
    _scrollController.addListener(_onScroll);
    
    final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final store = ref.read(dailyRoutinesStoreProvider);
    _selectedDateFilter = store.selectedDate.isNotEmpty ? store.selectedDate : todayStr;
    
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
      
      final store = ref.read(dailyRoutinesStoreProvider);
      if (store.runs.isEmpty || store.selectedDate != _selectedDateFilter) {
        store.fetchDailyRoutines(isRefresh: true, date: _selectedDateFilter);
      }
    });
  }

  @override
  void dispose() {
    if (_isAuthorized) {
      _jumpTimer?.cancel();
      _jumpController.dispose();
      _scrollController.dispose();
      _dateScrollController.dispose();
      _searchController.dispose();
      _debounce?.cancel();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(dailyRoutinesStoreProvider).fetchNextPage();
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(dailyRoutinesStoreProvider).fetchDailyRoutines(isRefresh: true, search: query);
      }
    });
  }

  Widget _buildStatusBadge(String status) {
    final String s = status.toUpperCase();
    Color bgColor;
    Color textColor;
    Color borderColor;

    switch (s) {
      case "PLANNED":
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
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF047857);
        borderColor = const Color(0xFFA7F3D0);
        break;
      case "CANCELLED":
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
        s.replaceAll('_', ' '),
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
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
            ref.read(dailyRoutinesStoreProvider).fetchDailyRoutines(isRefresh: true, date: 'ALL');
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
                    ref.read(dailyRoutinesStoreProvider).fetchDailyRoutines(isRefresh: true, date: formattedDateStr);
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

  Widget _buildSearchBar(bool isDark, Color primaryBlue, Color subColor) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: "Search runs, routes...",
          hintStyle: TextStyle(color: subColor.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildViewToggleButton(Color p, Color t, bool d) {
    return GestureDetector(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _isListView = !_isListView;
        });
        await prefs.setBool('daily_routines_is_list_view', _isListView);
      },
      child: Container(
        height: 54,
        width: 54,
        decoration: BoxDecoration(
          color: d ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: d ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Icon(_isListView ? Icons.view_agenda_rounded : Icons.view_list_rounded, color: p, size: 24),
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
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: d ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
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
                  color: Colors.black.withValues(alpha: 0.15),
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
                  "Filter Routines",
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
                      children: [
                        'ALL',
                        'PLANNED',
                        'READY',
                        'STARTED',
                        'ARRIVED CAMPUS',
                        'FN COMPLETED',
                        'AN STARTED',
                        'DEPARTED CAMPUS',
                        'HALT',
                        'COMPLETED',
                        'MERGED MIDWAY',
                        'RESUMED MIDWAY'
                      ].map((label) {
                        bool isS = _selectedFilter == label;
                        return GestureDetector(
                          onTap: () {
                            if (_selectedFilter == label) return;
                            setState(() => _selectedFilter = label);
                            setModalState(() {});
                            Navigator.pop(context);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isS ? p : (d ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isS ? p : t.withValues(alpha: 0.1), width: 1.5),
                              boxShadow: isS ? [BoxShadow(color: p.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isS ? Colors.white : t.withValues(alpha: 0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListCard(
    BuildContext context,
    Map<String, dynamic> run,
    Color cardColor,
    Color titleColor,
    Color subColor,
    Color primaryBlue,
  ) {
    final String runName = run['run_name'] ?? 'Bus Run';
    final String status = run['status'] ?? 'PENDING';
    
    final bool isMorningConfirmed = run['is_morning_attendance_confirmed'] == true ||
        run['is_morning_attendance_confirmed']?.toString() == 'true' ||
        run['morning_attendance_confirmed'] == true ||
        run['morning_attendance_confirmed']?.toString() == 'true';

    final bool isEveningConfirmed = run['is_evening_attendance_confirmed'] == true ||
        run['is_evening_attendance_confirmed']?.toString() == 'true' ||
        run['evening_attendance_confirmed'] == true ||
        run['evening_attendance_confirmed']?.toString() == 'true';
    
    final assignments = run['assignment'] as List? ?? [];
    
    List<Widget> vehicleWidgets = [];
    if (assignments.isEmpty) {
      vehicleWidgets.add(
        Text(
          "No Vehicle Assigned",
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: titleColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else {
      final Map<int, Map<String, dynamic>> uniqueAssignments = {};
      for (var a in assignments) {
        if (a['vehicle'] != null && a['vehicle']['id'] != null) {
          uniqueAssignments[a['vehicle']['id']] = a;
        }
      }
      
      for (var a in uniqueAssignments.values) {
        var v = a['vehicle'];
        var d = a['driver'];
        String vNo = v['vehicle_number'] ?? "Unknown";
        String bNo = v['bus_number']?.toString() ?? "";
        if (bNo.isNotEmpty && !bNo.toUpperCase().startsWith("BUS NO")) {
          bNo = "BUS NO $bNo";
        }
        String dName = d != null && d['user'] != null && d['user']['name'] != null ? d['user']['name'] : "Unassigned";
        
        vehicleWidgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.directions_bus_rounded, size: 14, color: primaryBlue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        vNo,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (bNo.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, top: 2),
                    child: Text(
                      bNo,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: subColor,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 14, color: subColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
        );
      }
    }

    return GestureDetector(
      onTap: () async {
        if (context.mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DailyBusRunDetailsPage(runData: run),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: titleColor.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    runName.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),
            ...vehicleWidgets,
            if (isMorningConfirmed || isEveningConfirmed)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    if (isMorningConfirmed)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.green, size: 10),
                            SizedBox(width: 4),
                            Text("FN Confirmed", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    if (isEveningConfirmed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.green, size: 10),
                            SizedBox(width: 4),
                            Text("AN Confirmed", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineCard(
    BuildContext context,
    Map<String, dynamic> run,
    Color cardColor,
    Color titleColor,
    Color subColor,
    Color primaryBlue,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String runName = run['run_name'] ?? 'Bus Run';
    final String runCode = run['run_code'] ?? '';
    final String status = run['status'] ?? 'PENDING';
    final String shift = run['shift_code'] ?? 'FULL_DAY';
    final String startLoc = run['start_location_name'] ?? 'Start';
    final String haltLoc = run['halt_location_name'] ?? 'Destination';
    final int stopsCount = (run['runStops'] as List?)?.length ?? 0;

    final bool isMorningConfirmed = run['is_morning_attendance_confirmed'] == true ||
        run['is_morning_attendance_confirmed']?.toString() == 'true' ||
        run['morning_attendance_confirmed'] == true ||
        run['morning_attendance_confirmed']?.toString() == 'true';

    final bool isEveningConfirmed = run['is_evening_attendance_confirmed'] == true ||
        run['is_evening_attendance_confirmed']?.toString() == 'true' ||
        run['evening_attendance_confirmed'] == true ||
        run['evening_attendance_confirmed']?.toString() == 'true';
    
    final assignments = run['assignment'] as List? ?? [];
    String vehicleNo = "No Vehicle Assigned";
    String driverName = "No Driver Assigned";
    if (assignments.isNotEmpty) {
      final vNumbers = assignments.map((a) => a['vehicle']?['vehicle_number']).whereType<String>().toSet();
      final dNames = assignments.map((a) => a['driver']?['user']?['name']).whereType<String>().toSet();
      if (vNumbers.isNotEmpty) vehicleNo = vNumbers.join(", ");
      if (dNames.isNotEmpty) driverName = dNames.join(", ");
    }

    final int passengerCount = run['campus_in_count'] ?? (run['students'] as List?)?.length ?? 0;
    final int maxCapacity = run['dailyBusRoute']?['max_vehicle_capacity'] ?? 36;

    return GestureDetector(
      onTap: () async {
        if (context.mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DailyBusRunDetailsPage(runData: run),
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
                _buildStatusBadge(status),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person_rounded, size: 14, color: subColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                driverName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
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
            const SizedBox(height: 20),
            // Morning Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Morning Shift (FN) Occupancy",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subColor),
                    ),
                    Text(
                      "${run['campus_in_count'] ?? 0} / $maxCapacity Seats",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryBlue),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxCapacity > 0 ? ((run['campus_in_count'] ?? 0) / maxCapacity).clamp(0.0, 1.0) : 0.0,
                    minHeight: 6,
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      (run['campus_in_count'] ?? 0) / maxCapacity > 0.9 ? const Color(0xFFEF4444) : primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Evening Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Evening Shift (AN) Occupancy",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subColor),
                    ),
                    Text(
                      "${run['campus_out_count'] ?? 0} / $maxCapacity Seats",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: maxCapacity > 0 ? ((run['campus_out_count'] ?? 0) / maxCapacity).clamp(0.0, 1.0) : 0.0,
                    minHeight: 6,
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      (run['campus_out_count'] ?? 0) / maxCapacity > 0.9 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.4) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "MORNING CONFIRMATION",
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: subColor.withValues(alpha: 0.6),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              isMorningConfirmed ? Icons.check_circle_rounded : Icons.pending_rounded,
                              size: 14,
                              color: isMorningConfirmed ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isMorningConfirmed ? "Confirmed" : "Pending",
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isMorningConfirmed ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "EVENING CONFIRMATION",
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: subColor.withValues(alpha: 0.6),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              isEveningConfirmed ? Icons.check_circle_rounded : Icons.pending_rounded,
                              size: 14,
                              color: isEveningConfirmed ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isEveningConfirmed ? "Confirmed" : "Pending",
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isEveningConfirmed ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (status.toUpperCase() == 'PLANNED') ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loadingRuns[run['id']?.toString()] == true
                      ? null
                      : () => _markRunReadyFromList(run, primaryBlue),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loadingRuns[run['id']?.toString()] == true
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "Mark Ready",
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ] else if (status.toUpperCase() == 'AN_STARTED') ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loadingRuns[run['id']?.toString()] == true
                      ? null
                      : () => _showVerifyOtpBottomSheetFromList(run, primaryBlue),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loadingRuns[run['id']?.toString()] == true
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.vpn_key_rounded, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "Verify OTP",
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCard(bool isDark, Color cardColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      height: 250,
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
              Container(width: 60, height: 16, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: isDark ? 0.1 : 0.2), borderRadius: BorderRadius.circular(8))),
              Container(width: 80, height: 16, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: isDark ? 0.1 : 0.2), borderRadius: BorderRadius.circular(8))),
            ],
          ),
          const SizedBox(height: 16),
          Container(width: 200, height: 24, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: isDark ? 0.1 : 0.2), borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 8),
          Container(width: 120, height: 14, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: isDark ? 0.1 : 0.2), borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 20),
          Container(width: double.infinity, height: 50, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: isDark ? 0.1 : 0.2), borderRadius: BorderRadius.circular(16))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthorized) {
      return const Scaffold(
        body: Center(
          child: Text("Access Denied."),
        ),
      );
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final store = ref.watch(dailyRoutinesStoreProvider);

    final runs = store.runs.where((run) {
      final String s = (run['status'] ?? "").toString().toUpperCase();
      if (_selectedFilter == 'ALL') return true;
      if (_selectedFilter == 'PLANNED') return s == 'PLANNED';
      if (_selectedFilter == 'READY') return s == 'READY';
      if (_selectedFilter == 'STARTED') return s == 'STARTED';
      if (_selectedFilter == 'ARRIVED CAMPUS') return s == 'ARRIVED_CAMPUS';
      if (_selectedFilter == 'FN COMPLETED') return s == 'FN_COMPLETED';
      if (_selectedFilter == 'AN STARTED') return s == 'AN_STARTED';
      if (_selectedFilter == 'DEPARTED CAMPUS') return s == 'DEPARTED_CAMPUS';
      if (_selectedFilter == 'HALT') return s == 'HALTED';
      if (_selectedFilter == 'COMPLETED') return s == 'COMPLETED';
      if (_selectedFilter == 'MERGED MIDWAY') return s == 'MERGED_HALTED';
      if (_selectedFilter == 'RESUMED MIDWAY') return s == 'RESUMED_MIDWAY';
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
                            Icons.directions_bus_rounded,
                            color: primaryBlue,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Daily Routines",
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          showDailyBusRunDownloadModal(context, primaryBlue, titleColor, subColor, isDark);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.download_rounded, color: primaryBlue, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Monitor and manage scheduled campus bus routines",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildSearchBar(isDark, primaryBlue, subColor)),
                      const SizedBox(width: 12),
                      _buildViewToggleButton(primaryBlue, titleColor, isDark),
                      const SizedBox(width: 12),
                      _buildFilterButton(primaryBlue, titleColor, isDark),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Routine Dates",
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
                                color: primaryBlue.withValues(alpha: 0.1),
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
                          final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
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
                                    if (_selectedDateFilter != todayStr) {
                                      setState(() => _selectedDateFilter = todayStr);
                                      ref.read(dailyRoutinesStoreProvider).fetchDailyRoutines(isRefresh: true, date: todayStr);
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
              child: store.isLoading && store.runs.isEmpty
                  ? ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      itemCount: 3,
                      itemBuilder: (context, index) => _buildSkeletonCard(isDark, cardColor),
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.read(dailyRoutinesStoreProvider).fetchDailyRoutines(isRefresh: true),
                      child: runs.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.25,
                                ),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.directions_bus_filled_rounded, size: 54, color: subColor.withValues(alpha: 0.15)),
                                      const SizedBox(height: 16),
                                      Text(
                                        "No routines found for this date",
                                        style: TextStyle(
                                          color: subColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              itemCount: runs.length + (store.hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == runs.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16.0),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                final run = runs[index];
                                return _isListView 
                                    ? _buildListCard(context, run, cardColor, titleColor, subColor, primaryBlue)
                                    : _buildRoutineCard(context, run, cardColor, titleColor, subColor, primaryBlue);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
