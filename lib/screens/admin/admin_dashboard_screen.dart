import 'package:flutter/material.dart';
import 'package:tripzo/store/admin_dashboard_store.dart';
import 'package:tripzo/screens/faculty/request/new_request_screen.dart';
import 'package:tripzo/store/faculty_store.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import '../../components/notification_card.dart';
import '../../components/notification_bell.dart';
import '../../utils/routes.dart';
import 'package:tripzo/screens/admin/AdminProfileScreen.dart';
import 'package:tripzo/utils/tab_notification.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'fuel/fuel_price_update_page.dart';
import 'fuel/fuel_page.dart';
import 'admin_allowance_screen.dart';
import 'package:tripzo/screens/driver/assignment_details_screen.dart';
import 'package:tripzo/utils/tab_notification.dart';
import 'package:tripzo/screens/admin/live_bus_routes_screen.dart';
import 'package:tripzo/utils/api_error_parser.dart';

/// Admin Dashboard Screen – mirrors the Faculty dashboard but adds admin‑specific statistics.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  // --- Expiration Section State ---
  int _expirationTabIndex = 0; // 0 for expired, 1 for expiring soon
  String _filterType = "all"; // all, rc, insurance, pollution, fitness
  String _searchQuery = "";
  String _userRole = "";
  
  List<dynamic> _adminDailyBusRuns = [];
  bool _isLoadingAdminBusRuns = false;
  // --------------------------------

  @override
  void initState() {
    super.initState();
    _initData();
    // Trigger stats fetch
    AdminDashboardStore().fetchStats();
    // Trigger profile fetch for name
    if (useFacultyStore.profileData.value == null) {
      useFacultyStore.fetchProfile();
    }

    // Listen for remote logouts
    useFacultyStore.errorMessage.addListener(_handleAuthError);


    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowFuelPopup();
    });
  }

  Future<void> _checkAndShowFuelPopup() async {
    final role = await UserStore.getRole();
    if (role != 'Transport Admin') return;

    final prefs = await SharedPreferences.getInstance();
    final String today = DateTime.now().toIso8601String().split('T')[0];
    final String? dismissedDate = prefs.getString('fuel_price_dismiss_date');

    if (dismissedDate == today) return;

    try {
      final token = await UserStore.getToken();
      final response = await http.get(
        Uri.parse(ApiConstants.fuelBunks),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final bunks = data['data'] as List;
          if (bunks.isNotEmpty && mounted) {
            _showFuelPopup(bunks);
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching bunks for popup: $e");
    }
  }

  void _showFuelPopup(List<dynamic> bunks) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color primaryBlue = const Color(0xFF6366F1);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          contentPadding: const EdgeInsets.all(24),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Update Fuel Price",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: titleColor,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.close_rounded, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Current Bunk Prices",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...bunks.map((bunk) {
                    final p = double.tryParse(bunk['petrol_price']?.toString() ?? '0') ?? 0;
                    final d = double.tryParse(bunk['diesel_price']?.toString() ?? '0') ?? 0;
                    final c = double.tryParse(bunk['cng_price']?.toString() ?? '0') ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bunk['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, color: titleColor)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Petrol: ₹$p", style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
                              Text("Diesel: ₹$d", style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                              Text("CNG: ₹$c", style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF06B6D4))),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final String today = DateTime.now().toIso8601String().split('T')[0];
                await prefs.setString('fuel_price_dismiss_date', today);
                if (mounted) Navigator.pop(context);
              },
              child: Text("Today Same Price", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const FuelPriceUpdatePage()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Update", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _handleAuthError() async {
    if (useFacultyStore.errorMessage.value == "SESSION_EXPIRED") {
      useFacultyStore.errorMessage.removeListener(_handleAuthError);
      await UserStore.clear();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  Future<void> _initData() async {
    final role = await UserStore.getRole();
    if (mounted) {
      setState(() {
        _userRole = role ?? "";
      });
      if (_userRole.toLowerCase() == 'transport admin' || _userRole.toLowerCase() == 'super admin') {
        ref.read(expirationStoreProvider).fetchExpirations();
        _fetchAdminDailyBusRuns();
      }
    }
  }

  Future<void> _fetchAdminDailyBusRuns() async {
    setState(() => _isLoadingAdminBusRuns = true);
    try {
      final token = await UserStore.getToken();
      if (token == null) return;
      
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final userId = await UserStore.getUserId();
      final url = "${ApiConstants.baseUrl}/daily-bus/bus-run/get-all?service_date=$dateStr${userId != null ? '&user_id=$userId' : ''}";
      
      final headers = ApiConstants.getHeaders(token);
      final headersString = headers.entries.map((e) => "--header '${e.key}: ${e.value}'").join(" \\\n");
      debugPrint("--- ADMIN LIVE BUS RUN FETCH ---");
      debugPrint("CURL COMMAND:\ncurl --location '$url' \\\n$headersString");
      
      final response = await http.get(Uri.parse(url), headers: headers);
      
      debugPrint(ApiErrorParser.parse(response, fallback: "RESPONSE"));
      debugPrint("--------------------------------");
      
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          final runs = decoded['data']['runs'] as List? ?? [];
          List<dynamic> flatAssignments = [];
          for (var r in runs) {
            final assignments = r['assignment'] as List? ?? [];
            if (assignments.isEmpty) {
              final newAssign = Map<String, dynamic>.from(r);
              newAssign['run_status'] = r['status'] ?? 'UNKNOWN';
              newAssign['run_data'] = r;
              
              if (r['dailyBusRoute'] != null && r['dailyBusRoute']['vehicle'] != null) {
                newAssign['vehicle'] = r['dailyBusRoute']['vehicle'];
              }
              flatAssignments.add(newAssign);
            } else {
              for (var a in assignments) {
                final newAssign = Map<String, dynamic>.from(a);
                newAssign['run_status'] = a['run_status'] ?? r['status'] ?? 'UNKNOWN';
                newAssign['shift_code'] = a['shift_code'] ?? r['shift_code'];
                newAssign['start_location_name'] = a['start_location_name'] ?? r['start_location_name'];
                newAssign['halt_location_name'] = a['halt_location_name'] ?? r['halt_location_name'];
                newAssign['run_data'] = r;
                
                if (newAssign['vehicle'] == null && r['dailyBusRoute'] != null && r['dailyBusRoute']['vehicle'] != null) {
                  newAssign['vehicle'] = r['dailyBusRoute']['vehicle'];
                }
                
                flatAssignments.add(newAssign);
              }
            }
          }
          flatAssignments.sort((a, b) {
            int runA = (a['run_data']['id'] ?? 0);
            int runB = (b['run_data']['id'] ?? 0);
            if (runA != runB) return runB.compareTo(runA); // Newest runs first
            
            final status = a['run_status']?.toString().toUpperCase() ?? '';
            final shiftA = a['shift_code']?.toString().toUpperCase() ?? '';
            final shiftB = b['shift_code']?.toString().toUpperCase() ?? '';
            
            final eveningFirstStatuses = ['FN_COMPLETED', 'AN_STARTED', 'DEPARTED_CAMPUS', 'RESUMED_MIDWAY', 'MERGED_HALTED', 'HALTED', 'COMPLETED'];
            bool eveningFirst = eveningFirstStatuses.contains(status);
            
            int weightA = shiftA == 'EVENING' ? (eveningFirst ? 0 : 1) : (eveningFirst ? 1 : 0);
            int weightB = shiftB == 'EVENING' ? (eveningFirst ? 0 : 1) : (eveningFirst ? 1 : 0);
            
            return weightA.compareTo(weightB);
          });

          setState(() {
            _adminDailyBusRuns = flatAssignments;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching admin bus runs: $e");
    } finally {
      if (mounted) setState(() => _isLoadingAdminBusRuns = false);
    }
  }

  Future<void> _handleRefresh() async {
    AdminDashboardStore().fetchStats();
    useFacultyStore.fetchProfile();
    await _initData();
  }

  @override
  void dispose() {
    useFacultyStore.errorMessage.removeListener(_handleAuthError);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          // Background decorative circle
          Positioned(
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
          ),
          SafeArea(
            bottom: true,
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: primaryBlue,
              backgroundColor: surfaceColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  FadeInUp(
                    index: 0,
                    child: ValueListenableBuilder(
                      valueListenable: useFacultyStore.profileData,
                      builder: (context, data, _) {
                        return FutureBuilder<String?>(
                          future: UserStore.getName(),
                          builder: (context, snapshot) {
                            final String displayName =
                                data?['name'] ?? snapshot.data ?? "Admin";
                            return _buildHeader(
                              displayName,
                              data?['profile_photo'],
                              titleColor,
                              subColor,
                              screenWidth,
                              primaryBlue,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeInUp(index: 1, child: _buildSearchBar(isDark, subColor, surfaceColor, primaryBlue)),
                  const SizedBox(height: 36),
                  // ==== Graphical Overview ==== //
                  FadeInUp(index: 2, child: _buildSectionTitle('Live Fleet Status', titleColor)),
                  const SizedBox(height: 18),
                  FadeInUp(
                    index: 3,
                    child: _buildGraphicalOverview(
                      primaryBlue,
                      surfaceColor,
                      isDark,
                      screenWidth,
                    ),
                  ),
                  const SizedBox(height: 36),
                  FadeInUp(index: 4, child: _buildSectionTitle('Quick Actions', titleColor)),
                  const SizedBox(height: 18),
                  FadeInUp(
                    index: 5,
                    child: _buildQuickActions(
                      context,
                      primaryBlue,
                      surfaceColor,
                      isDark,
                    ),
                  ),
                  const SizedBox(height: 36),
                  if (_userRole.toLowerCase() == 'transport admin' || _userRole.toLowerCase() == 'super admin') ...[
                    FadeInUp(
                      index: 6,
                      child: _buildExpirationSection(primaryBlue, surfaceColor, isDark, titleColor, subColor),
                    ),
                    const SizedBox(height: 36),
                  ],
                  if (_userRole.toLowerCase() == 'transport admin') ...[
                    FadeInUp(
                      index: 7,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LiveBusRoutesScreen(adminDailyBusRuns: _adminDailyBusRuns),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: primaryBlue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.directions_bus, color: primaryBlue),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Live Bus Routes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor)),
                                      const SizedBox(height: 4),
                                      Text(
                                        _isLoadingAdminBusRuns ? "Loading..." : "${_adminDailyBusRuns.length} Active Routes",
                                        style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Icon(Icons.arrow_forward_ios, size: 16, color: subColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                  FadeInUp(
                    index: 7,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Recent Notifications', titleColor),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
                          child: Text(
                            'See All',
                            style: TextStyle(
                              color: primaryBlue,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FadeInUp(index: 8, child: _buildNotificationList(primaryBlue, surfaceColor, isDark)),
                  const SizedBox(height: 100),
                ],
              ),
            ),
           ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Header, Search, Sections – copied from the faculty dashboard.
  // ---------------------------------------------------------------------
  Widget _buildHeader(
    String name, String? profilePhoto, Color titleColor, Color subColor, double width, Color primary,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: FutureBuilder<String?>(
                  future: UserStore.getRole(),
                  builder: (context, snapshot) {
                    final String role = snapshot.data?.toUpperCase() ?? "ADMIN";
                    return Text(
                      'ROLE: $role',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hello, $name',
                style: TextStyle(
                  fontSize: width * 0.075,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                  letterSpacing: -1.2,
                ),
              ),
            ],
          ),
        ),
        NotificationBell(iconColor: titleColor),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProfileScreen()));
          },
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [primary, primary.withValues(alpha: 0.4)],
              ),
            ),
            child: CircleAvatar(
              radius: width * 0.065,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: width * 0.06,
                backgroundImage: profilePhoto != null 
                    ? NetworkImage(ApiConstants.getImageUrl(profilePhoto))
                    : NetworkImage(
                        'https://ui-avatars.com/api/?name=$name&background=6366F1&color=fff',
                      ) as ImageProvider,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(
    bool isDark,
    Color subColor,
    Color surface,
    Color primary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      height: 60,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: subColor.withValues(alpha: 0.8),
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Track Mission ID...',
                hintStyle: TextStyle(
                  color: subColor.withValues(alpha: 0.5),
                  fontSize: 15,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.tune_rounded, color: primary, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: -0.8,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Graphical Overview
  // ---------------------------------------------------------------------
  Widget _buildGraphicalOverview(
    Color primaryBlue,
    Color surface,
    bool isDark,
    double width,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: AdminDashboardStore().driversPresent,
                builder: (_, present, _) => ValueListenableBuilder<int>(
                  valueListenable: AdminDashboardStore().driversOnLeave,
                  builder: (_, onLeave, _) {
                    final total = present + onLeave;
                    final double percent = total == 0 ? 0 : present / total;
                    return _buildGraphicalCard(
                      title: 'Drivers Present',
                      currentValue: present.toString(),
                      totalValue: '/ $total',
                      percent: percent,
                      icon: Icons.groups_rounded,
                      color: const Color(0xFF10B981), // Green
                      surface: surface,
                      isDark: isDark,
                      width: width,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: AdminDashboardStore().driversOnLeave,
                builder: (_, onLeave, _) => ValueListenableBuilder<int>(
                  valueListenable: AdminDashboardStore().driversPresent,
                  builder: (_, present, _) {
                    final total = present + onLeave;
                    final double percent = total == 0 ? 0 : onLeave / total;
                    return _buildGraphicalCard(
                      title: 'Drivers On Leave',
                      currentValue: onLeave.toString(),
                      totalValue: '/ $total',
                      percent: percent,
                      icon: Icons.person_off_rounded,
                      color: const Color(0xFFEF4444), // Red
                      surface: surface,
                      isDark: isDark,
                      width: width,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<int>(
          valueListenable: AdminDashboardStore().movingBuses,
          builder: (_, buses, _) {
            const int totalBuses = 20; // Example total
            final double percent = buses / totalBuses;
            return _buildGraphicalCard(
              title: 'Buses Currently Running',
              currentValue: buses.toString(),
              totalValue: ' Active Fleet',
              percent: percent.clamp(0.0, 1.0),
              icon: Icons.directions_bus_rounded,
              color: const Color(0xFF3B82F6), // Blue
              surface: surface,
              isDark: isDark,
              width: width,
            );
          },
        ),
      ],
    );
  }

  Widget _buildGraphicalCard({
    required String title,
    required String currentValue,
    required String totalValue,
    required double percent,
    required IconData icon,
    required Color color,
    required Color surface,
    required bool isDark,
    required double width,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: percent),
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return CircularProgressIndicator(
                          value: value,
                          strokeWidth: 5,
                          backgroundColor: color.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          strokeCap: StrokeCap.round,
                        );
                      },
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: percent * 100),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Text(
                        '${value.toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  currentValue,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: width * 0.07,
                    letterSpacing: -1.0,
                    color: isDark ? Colors.white : Colors.black,
                    height: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    totalValue,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    Color primaryBlue,
    Color surface,
    bool isDark,
  ) {
    return Row(
      children: [
        _buildActionBtn(
          'New Req',
          Icons.add_box_rounded,
          primaryBlue,
          surface,
          onTap: () async {
            final refresh = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NewRequestScreen()),
            );
            if (refresh == true) {
              if (mounted) {
                ref.read(requestStoreProvider).fetchRequests();
                AdminDashboardStore().fetchStats();
              }
            }
          },
        ),
        const SizedBox(width: 15),
        _buildActionBtn(
          'Fuel',
          Icons.local_gas_station_rounded,
          const Color(0xFFF59E0B), // Amber 500
          surface,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FuelPage()),
            );
          },
        ),
        const SizedBox(width: 15),
        _buildActionBtn(
          'Allowance',
          Icons.payments_rounded,
          const Color(0xFF0D9488), // Teal 600
          surface,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminAllowanceScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionBtn(
    String label,
    IconData icon,
    Color color,
    Color surface, {
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationList(Color primaryBlue, Color surface, bool isDark) {
    final notificationProvider = ref.watch(notificationProviderFamily);
    final notifications = notificationProvider.notifications;

    if (notificationProvider.isLoading && notifications.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: CircularProgressIndicator(),
      ));
    }

    if (notifications.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(Icons.notifications_none_rounded, color: Colors.grey.withValues(alpha: 0.5), size: 40),
            const SizedBox(height: 12),
            Text(
              "No new notifications",
              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    final recentNotifications = notifications.take(3).toList();
    return Column(
      children: recentNotifications.map((notification) {
        return NotificationCard(
          notification: notification,
          isDashboard: true,
        );
      }).toList(),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return "Just Now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${dt.day}/${dt.month}";
  }

  // ---------------------------------------------------------------------
  // Expiration Section
  // ---------------------------------------------------------------------

  Widget _buildExpirationSection(Color primaryBlue, Color surface, bool isDark, Color titleColor, Color subColor) {
    if (_userRole.toLowerCase() != 'transport admin' && _userRole.toLowerCase() != 'super admin') {
      return const SizedBox.shrink();
    }

    final expStore = ref.watch(expirationStoreProvider);
    if (!expStore.isLoading && expStore.expiredCount == 0 && expStore.expiringSoonCount == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Vehicle Documents', titleColor),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.filter_list_rounded, color: primaryBlue, size: 18),
              ),
              onPressed: () => _showExpirationFilterSheet(primaryBlue, titleColor, subColor, isDark),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildExpirationToggle(primaryBlue, surface, isDark),
        const SizedBox(height: 16),
        _buildExpirationSearchBar(isDark, subColor, surface, primaryBlue),
        const SizedBox(height: 16),
        _buildExpirationList(primaryBlue, surface, isDark, titleColor, subColor),
      ],
    );
  }

  Widget _buildExpirationToggle(Color primary, Color surface, bool isDark) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: _expirationTabIndex == 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.42,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _expirationTabIndex = 0;
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Consumer(builder: (context, ref, _) {
                      final expStore = ref.watch(expirationStoreProvider);
                      return Text(
                        "Expired (${expStore.expiredCount})",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _expirationTabIndex == 0 ? Colors.white : Colors.grey,
                        ),
                      );
                    }),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _expirationTabIndex = 1;
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Consumer(builder: (context, ref, _) {
                      final expStore = ref.watch(expirationStoreProvider);
                      return Text(
                        "Expiring Soon (${expStore.expiringSoonCount})",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _expirationTabIndex == 1 ? Colors.white : Colors.grey,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExpirationFilterSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.filter_list_rounded, color: primaryBlue, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        "Filter Documents",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildFilterChip('all', 'All', Icons.apps_rounded, primaryBlue, titleColor, isDark, setModalState),
                      _buildFilterChip('rc', 'RC', Icons.description_rounded, primaryBlue, titleColor, isDark, setModalState),
                      _buildFilterChip('insurance', 'Insurance', Icons.health_and_safety_rounded, primaryBlue, titleColor, isDark, setModalState),
                      _buildFilterChip('pollution', 'Pollution', Icons.cloud_rounded, primaryBlue, titleColor, isDark, setModalState),
                      _buildFilterChip('fitness', 'Fitness', Icons.build_circle_rounded, primaryBlue, titleColor, isDark, setModalState),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ref.read(expirationStoreProvider).fetchExpirations(filterType: _filterType, searchQuery: _searchQuery);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: Text(
                        "Apply Filter",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon, Color primary, Color titleColor, bool isDark, StateSetter setModalState) {
    final isSelected = _filterType == value;
    return GestureDetector(
      onTap: () {
        setModalState(() {
          _filterType = value;
        });
        setState(() {
          _filterType = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primary : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primary : titleColor.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : primary, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : titleColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpirationSearchBar(bool isDark, Color subColor, Color surface, Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      height: 50,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: subColor.withValues(alpha: 0.8),
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              onChanged: (val) {
                _searchQuery = val;
                ref.read(expirationStoreProvider).fetchExpirations(filterType: _filterType, searchQuery: _searchQuery);
              },
              decoration: InputDecoration(
                hintText: 'Search Vehicle Number...',
                hintStyle: TextStyle(
                  color: subColor.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpirationList(Color primary, Color surface, bool isDark, Color titleColor, Color subColor) {
    final expStore = ref.watch(expirationStoreProvider);

    if (expStore.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final list = expStore.expirationData.where((v) {
      if (_expirationTabIndex == 0) {
        return (v['expired_documents'] as List?)?.isNotEmpty ?? false;
      } else {
        return (v['expiring_soon_documents'] as List?)?.isNotEmpty ?? false;
      }
    }).toList();

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            "No ${_expirationTabIndex == 0 ? 'expired' : 'expiring soon'} documents found.",
            style: TextStyle(color: subColor),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final vehicle = list[index];
        final isExpired = _expirationTabIndex == 0;
        final docs = isExpired ? vehicle['expired_documents'] as List : vehicle['expiring_soon_documents'] as List;
        final Color statusColor = isExpired ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

        // Helper to get icon data
        IconData getIconForDoc(String doc) {
          switch (doc) {
            case 'rc_expiry_date': return Icons.description_rounded;
            case 'insurance_expiry_date': return Icons.health_and_safety_rounded;
            case 'pollution_expiry_date': return Icons.cloud_rounded;
            case 'fc_expiry_date': return Icons.build_circle_rounded;
            default: return Icons.warning_rounded;
          }
        }

        String getLabelForDoc(String doc) {
          switch (doc) {
            case 'rc_expiry_date': return 'RC';
            case 'insurance_expiry_date': return 'Insurance';
            case 'pollution_expiry_date': return 'Pollution';
            case 'fc_expiry_date': return 'Fitness';
            default: return 'Document';
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      vehicle['vehicle_number'] ?? 'Unknown',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: titleColor,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: docs.map<Widget>((doc) {
                      return Icon(getIconForDoc(doc), size: 18, color: statusColor);
                    }).toList(),
                  ),
                ],
              ),
              childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: docs.map<Widget>((doc) {
                    final icon = getIconForDoc(doc);
                    final label = getLabelForDoc(doc);
                    final date = vehicle[doc] ?? 'N/A';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 14, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            "$label: $date",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Daily Bus Routes Card UI Helpers
  // ---------------------------------------------------------------------
  
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

  Widget _buildAssignmentCard({
    required BuildContext context,
    required dynamic assignment,
    required Color surface,
    required Color primary,
    required Color titleColor,
    required Color subColor,
    required bool isDark,
  }) {
    final shiftCode = assignment['shift_code'] ?? 'UNKNOWN';
    final startTime = _formatDate(assignment['planned_start_time']);
    final endTime = _formatDate(assignment['planned_end_time']);
    final vehicleNumber = assignment['vehicle']?['vehicle_number'] ?? 'Unknown Vehicle';
    final statusStr = assignment['run_status'] ?? 'UNKNOWN';

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
    } else if (statusStr == 'ONGOING') statusColor = Colors.orange;
    else if (statusStr == 'COMPLETED') statusColor = Colors.grey;

    bool isEnabled = true;
    if (shiftCode == 'EVENING') {
      final validStatuses = ['FN_COMPLETED', 'AN_STARTED', 'DEPARTED_CAMPUS', 'RESUMED_MIDWAY', 'MERGED_HALTED', 'HALTED', 'COMPLETED'];
      if (!validStatuses.contains(statusStr.toUpperCase())) {
        isEnabled = false;
      }
    } else if (shiftCode == 'MORNING') {
      final disabledStatuses = ['FN_COMPLETED', 'AN_STARTED', 'DEPARTED_CAMPUS', 'HALTED'];
      if (disabledStatuses.contains(statusStr.toUpperCase())) {
        isEnabled = false;
      }
    }

    return GestureDetector(
      onTap: isEnabled ? () {
        final Map<String, dynamic> runData = (assignment['run_data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssignmentDetailsScreen(
              assignment: assignment,
              run: runData,
            ),
          ),
        );
      } : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
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
                Text("Bus Route", style: TextStyle(fontWeight: FontWeight.w900, color: titleColor, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Text(statusStr.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _iconInfo(Icons.wb_sunny_rounded, shiftCode, isDark),
                _iconInfo(Icons.directions_car_rounded, vehicleNumber, isDark),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimeline(startLoc, haltLoc, primary, titleColor),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Planned Start", style: TextStyle(fontSize: 10, color: subColor)),
                    Text(startTime, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: titleColor)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("Planned End", style: TextStyle(fontSize: 10, color: subColor)),
                    Text(endTime, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: titleColor)),
                  ],
                ),
              ],
            )
          ],
        ),
      )),
    );
  }
}

class FadeInUp extends StatelessWidget {
  final Widget child;
  final int index;

  const FadeInUp({super.key, required this.child, required this.index});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 150)),
      curve: Curves.easeOutCubic,
      builder: (context, value, childWidget) {
        return Transform.translate(
          offset: Offset(0, 40 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }
}
