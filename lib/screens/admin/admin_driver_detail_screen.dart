import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/screens/admin/edit_driver_screen.dart';
import 'package:tripzo/screens/faculty/missions/mission_details_screen.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminDriverDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> driver;

  const AdminDriverDetailScreen({super.key, required this.driver});

  @override
  ConsumerState<AdminDriverDetailScreen> createState() => _AdminDriverDetailScreenState();
}

class _AdminDriverDetailScreenState extends ConsumerState<AdminDriverDetailScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Map<String, dynamic> _driverData;
  Map<String, dynamic>? _dashboardData;
  List<Map<String, dynamic>> _vehicleHistory = [];
  List<Map<String, dynamic>> _leaveHistory = [];
  List<Map<String, dynamic>> _weeklyActivity = [];
  
  bool _isLoading = false;

  // Tabs
  String _activeMainTab = "profile"; // 'profile' | 'graph'
  String _activeSubTab = "profile"; // 'profile' | 'vehicles' | 'allowances' | 'points' | 'leaves' | 'upcoming'

  // Weekly Graph Date
  DateTime _currentWeekMonday = DateTime.now();

  Map<String, dynamic> _asMap(dynamic item) {
    if (item == null) return {};
    if (item is Map<String, dynamic>) return item;
    if (item is Map) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

  @override
  void initState() {
    super.initState();
    _driverData = _asMap(widget.driver);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
    _currentWeekMonday = _getCurrentMonday(DateTime.now());
    _loadFullDetails();
  }

  DateTime _getCurrentMonday(DateTime date) {
    final day = date.weekday;
    final diff = date.day - day + (day == 7 ? 7 : 1);
    return DateTime(date.year, date.month, diff);
  }

  Future<void> _loadFullDetails() async {
    final userId = _driverData['user_id'] ?? _driverData['id'];
    if (userId == null) return;
    final int targetUserId = int.tryParse(userId.toString()) ?? 0;
    if (targetUserId == 0) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final store = ref.read(driverStoreProvider);
    
    // Fetch profile
    final fullProfile = await store.fetchDriverById(targetUserId);
    if (mounted && fullProfile != null) {
      setState(() {
        _driverData = _asMap(fullProfile);
      });
    }

    // Fetch Dashboard data
    final dashData = await store.fetchDriverDashboard(targetUserId);
    
    // Fetch Vehicle History
    final vehHistory = await store.fetchDriverVehicleHistory(targetUserId);

    // Fetch Leave History
    final lveHistory = await store.fetchDriverLeaveHistory(targetUserId);

    // Fetch Weekly Activity
    final dateStr = DateFormat('yyyy-MM-dd').format(_currentWeekMonday);
    final wkActivity = await store.fetchDriverWeeklyKm(targetUserId, dateStr);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (dashData != null) _dashboardData = _asMap(dashData);
        _vehicleHistory = vehHistory.map((e) => _asMap(e)).toList();
        _leaveHistory = lveHistory.map((e) => _asMap(e)).toList();
        _weeklyActivity = wkActivity.map((e) => _asMap(e)).toList();
      });
    }
  }

  Future<void> _loadWeeklyActivity() async {
    final userId = _driverData['user_id'] ?? _driverData['id'];
    if (userId == null) return;
    final int targetUserId = int.tryParse(userId.toString()) ?? 0;

    final dateStr = DateFormat('yyyy-MM-dd').format(_currentWeekMonday);
    final store = ref.read(driverStoreProvider);
    final wkActivity = await store.fetchDriverWeeklyKm(targetUserId, dateStr);

    if (mounted) {
      setState(() {
        _weeklyActivity = wkActivity.map((e) => _asMap(e)).toList();
      });
    }
  }

  void _handleWeekChange(bool isNext) {
    final nowMonday = _getCurrentMonday(DateTime.now());
    if (isNext && _currentWeekMonday.isAfter(nowMonday.subtract(const Duration(days: 1)))) {
      return;
    }
    setState(() {
      _currentWeekMonday = isNext 
          ? _currentWeekMonday.add(const Duration(days: 7)) 
          : _currentWeekMonday.subtract(const Duration(days: 7));
    });
    _loadWeeklyActivity();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = ApiConstants.baseUrl;
    final relative = path.startsWith('/') ? path : '/$path';
    final url = '$base$relative';
    return url.contains('?') ? '$url&v=2' : '$url?v=2';
  }

  void _showFullScreenImage(String imageUrl) {
    if (imageUrl.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            headers: const {'X-Tunnel-Skip-Anti-Phishing-Page': 'true'},
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white, size: 60),
          ),
        ),
      ),
    )));
  }

  Widget _buildAnimatedSection(Widget child, int index) {
    final delay = index * 0.08;
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: Interval(delay > 1.0 ? 1.0 : delay, 1.0, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 35 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color primaryIndigo = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final dp = _asMap(_driverData['driverProfile'] ?? _driverData);
    final dashDriver = _asMap(_dashboardData?['driverData']);

    final String name = _driverData['name'] ?? dashDriver['name'] ?? 'Unknown';
    final String username = _driverData['username'] ?? dashDriver['username'] ?? 'username';
    final String? licenseExpiry = dp['license_expiry_date'] ?? dp['license_expiry'] ?? dashDriver['licenseExpiry'];
    final bool isLicenseExpiring = _checkLicenseExpiring(licenseExpiry);

    int sectionIndex = 0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: titleColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Driver Dashboard",
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryIndigo),
            tooltip: "Refresh Data",
            onPressed: _loadFullDetails,
          ),
          IconButton(
            icon: Icon(Icons.edit, color: primaryIndigo),
            tooltip: "Edit Driver Profile",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditDriverScreen(driver: _driverData),
                ),
              ).then((_) => _loadFullDetails());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFullDetails,
        color: primaryIndigo,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // License Expiring Alert Banner
              if (isLicenseExpiring)
                _buildAnimatedSection(
                  _buildLicenseAlertBanner(licenseExpiry, isDark),
                  sectionIndex++,
                ),

              // Profile Hero Card
              _buildAnimatedSection(
                _buildProfileHero(context, isDark, surfaceColor, primaryIndigo, titleColor, subTextColor, name, username),
                sectionIndex++,
              ),
              const SizedBox(height: 16),

              // Top 5 Key Stats Row
              _buildAnimatedSection(
                _buildTopStatsRow(isDark, surfaceColor, primaryIndigo, dp, dashDriver),
                sectionIndex++,
              ),
              const SizedBox(height: 16),

              // Ongoing Task Banner (If Active)
              if (_dashboardData?['ongoingTask'] != null) ...[
                _buildAnimatedSection(
                  _buildOngoingRouteCard(_asMap(_dashboardData!['ongoingTask']), isDark, surfaceColor, primaryIndigo),
                  sectionIndex++,
                ),
                const SizedBox(height: 16),
              ],

              // Main Mode Switcher: Profile Details vs Weekly Activity Graph
              _buildAnimatedSection(
                _buildMainTabSwitcher(isDark, surfaceColor, primaryIndigo),
                sectionIndex++,
              ),
              const SizedBox(height: 16),

              // Content based on Main Tab Switcher
              if (_activeMainTab == "graph") ...[
                _buildAnimatedSection(
                  _buildWeeklyActivityGraphSection(isDark, surfaceColor, primaryIndigo, titleColor, subTextColor),
                  sectionIndex++,
                ),
              ] else ...[
                // Sub Tabs Bar
                _buildAnimatedSection(
                  _buildSubTabsBar(isDark, surfaceColor, primaryIndigo),
                  sectionIndex++,
                ),
                const SizedBox(height: 16),

                // Sub Tab Content
                if (_activeSubTab == "profile")
                  _buildAnimatedSection(
                    _buildProfileDetailsSubTab(isDark, surfaceColor, primaryIndigo, titleColor, subTextColor, dp, dashDriver),
                    sectionIndex++,
                  )
                else if (_activeSubTab == "vehicles")
                  _buildAnimatedSection(
                    _buildVehicleDriveHistorySubTab(isDark, surfaceColor, primaryIndigo, titleColor, subTextColor),
                    sectionIndex++,
                  )
                else if (_activeSubTab == "allowances")
                  _buildAnimatedSection(
                    _buildAllowancesSubTab(isDark, surfaceColor, primaryIndigo, titleColor, subTextColor),
                    sectionIndex++,
                  )
                else if (_activeSubTab == "points")
                  _buildAnimatedSection(
                    _buildPointsHistorySubTab(isDark, surfaceColor, primaryIndigo, titleColor, subTextColor),
                    sectionIndex++,
                  )
                else if (_activeSubTab == "leaves")
                  _buildAnimatedSection(
                    _buildLeaveLogsSubTab(isDark, surfaceColor, primaryIndigo, titleColor, subTextColor),
                    sectionIndex++,
                  )
                else if (_activeSubTab == "upcoming")
                  _buildAnimatedSection(
                    _buildUpcomingRoutesSubTab(isDark, surfaceColor, primaryIndigo, titleColor, subTextColor),
                    sectionIndex++,
                  ),
              ],

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  bool _checkLicenseExpiring(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    try {
      final expiry = DateTime.parse(dateStr);
      final diff = expiry.difference(DateTime.now()).inDays;
      return diff <= 30;
    } catch (_) {
      return false;
    }
  }

  Widget _buildLicenseAlertBanner(String? expiryDate, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "ALERT FOR DRIVER",
                  style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
                ),
                Text(
                  "Driving License Expires on: ${_formatDate(expiryDate)}",
                  style: const TextStyle(color: Color(0xFFBE123C), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHero(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color primaryIndigo,
    Color titleColor,
    Color subTextColor,
    String name,
    String username,
  ) {
    final store = ref.read(driverStoreProvider);
    final status = _driverData['status'] ?? 1;
    final statusLabel = store.getStatusLabel(status);
    final statusColor = store.getStatusColor(status);
    final profilePhotoUrl = _getImageUrl(_driverData['profile_photo'] ?? _driverData['profile_photo_url']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: profilePhotoUrl.isNotEmpty ? () => _showFullScreenImage(profilePhotoUrl) : null,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryIndigo.withValues(alpha: 0.1),
                    border: Border.all(color: primaryIndigo.withValues(alpha: 0.3), width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (!_isLoading && profilePhotoUrl.isEmpty)
                        Center(
                          child: Text(
                            _getInitials(name),
                            style: TextStyle(
                              color: primaryIndigo,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (!_isLoading && profilePhotoUrl.isNotEmpty)
                        Image.network(
                          profilePhotoUrl,
                          headers: const {'X-Tunnel-Skip-Anti-Phishing-Page': 'true'},
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(Icons.person, color: primaryIndigo, size: 45),
                        ),
                      if (_isLoading)
                        Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(primaryIndigo),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    store.getStatusIcon(status),
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: titleColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "@$username",
            style: TextStyle(
              color: subTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(store.getStatusIcon(status), color: statusColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatsRow(
    bool isDark,
    Color surfaceColor,
    Color primaryIndigo,
    Map<String, dynamic> dp,
    Map<String, dynamic> dashDriver,
  ) {
    final totalKm = dp['total_kilometer_drived'] ?? dp['total_kilometer_drive'] ?? dashDriver['totalKm'] ?? 0;
    final totalRoutes = dp['total_routes'] ?? dashDriver['totalRoutes'] ?? 0;
    final totalLeaves = dashDriver['totalLeaves'] ?? dp['total_leaves'] ?? _leaveHistory.where((l) => l['status'] == 2).length;
    final pointsEarned = _dashboardData?['pointsSummary']?['total_points'] ?? 0;
    final expAtBit = dp['experience_at_Bit'] ?? dashDriver['experience_at_Bit'] ?? '0';

    final stats = [
      {'label': 'Total Distance', 'val': '$totalKm', 'unit': 'KM', 'icon': Icons.trending_up, 'color': const Color(0xFF10B981)},
      {'label': 'Total Routes', 'val': '$totalRoutes', 'unit': 'Runs', 'icon': Icons.location_on_outlined, 'color': const Color(0xFFF97316)},
      {'label': 'Leaves Taken', 'val': '$totalLeaves', 'unit': 'Days', 'icon': Icons.calendar_today_outlined, 'color': const Color(0xFFF43F5E)},
      {'label': 'Points Earned', 'val': '$pointsEarned', 'unit': 'Pts', 'icon': Icons.emoji_events_outlined, 'color': const Color(0xFF0EA5E9)},
      {'label': 'Exp @ BIT', 'val': '$expAtBit', 'unit': expAtBit.toString().contains('year') ? '' : 'Yrs', 'icon': Icons.military_tech_outlined, 'color': const Color(0xFF8B5CF6)},
    ];

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: stats.length,
        itemBuilder: (context, index) {
          final s = stats[index];
          final Color iconColor = s['color'] as Color;
          return Container(
            width: 145,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(s['icon'] as IconData, color: iconColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        s['label'] as String,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              s['val'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if ((s['unit'] as String).isNotEmpty) ...[
                            const SizedBox(width: 3),
                            Text(
                              s['unit'] as String,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: primaryIndigo,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOngoingRouteCard(
    Map<String, dynamic> ongoing,
    bool isDark,
    Color surfaceColor,
    Color primaryIndigo,
  ) {
    final routeName = ongoing['route_name'] ?? ongoing['routeName'] ?? 'Active Route';
    final tripType = ongoing['trip_type'] ?? ongoing['travelType'] ?? 'One Way';
    final vehicleNumber = ongoing['vehicle_number'] ?? ongoing['vehicleNumber'] ?? 'N/A';
    final startLoc = ongoing['startLocation'] ?? 'Start Location';
    final endLoc = ongoing['destinationLocation'] ?? ongoing['endLocation'] ?? 'Destination Location';
    final startDate = _formatDate(ongoing['planned_start_at'] ?? ongoing['startDate']);
    final endDate = _formatDate(ongoing['planned_end_at'] ?? ongoing['endDate']);
    final duration = ongoing['approx_duration'] ?? ongoing['duration'] ?? 'N/A';
    final passengerCount = ongoing['passenger_count'] ?? ongoing['guestCount'] ?? 0;
    final status = ongoing['trip_instance_status'] ?? ongoing['status'] ?? 'Started';
    final creatorPhone = ongoing['creatorPhone'] ?? 'N/A';
    final reqId = (ongoing['route_request_id'] ?? ongoing['id'] ?? ongoing['route_id'] ?? '').toString();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MissionDetailsScreen(
              missionTitle: routeName.toString(),
              time: "$startDate - $endDate",
              driverName: (_driverData['name'] ?? "Driver").toString(),
              driverPhone: (_driverData['phone'] ?? "N/A").toString(),
              vehicleInfo: "$vehicleNumber",
              capacity: "$passengerCount Passengers",
              passengerCount: "$passengerCount",
              pathType: tripType.toString(),
              stops: [
                {'location': startLoc.toString(), 'eta': 'Start'},
                {'location': endLoc.toString(), 'eta': 'End'},
              ],
              status: status.toString(),
              statusColor: const Color(0xFF10B981),
              requestId: reqId,
              rawStatus: 2,
              creatorName: "Transport Admin",
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primaryIndigo.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: primaryIndigo.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 4),
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
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "ON GOING TRIP",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF10B981),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryIndigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: primaryIndigo,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: primaryIndigo, size: 18),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.alt_route, color: primaryIndigo, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    routeName.toString(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "$tripType • $vehicleNumber",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Pass: $passengerCount",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Route Timeline
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          startLoc.toString().split(',')[0],
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          startDate,
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Icon(Icons.arrow_forward, color: primaryIndigo, size: 16),
                      const SizedBox(height: 2),
                      Text(
                        "Est. $duration m",
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: primaryIndigo),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          endLoc.toString().split(',')[0],
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          endDate,
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Creator Contact: $creatorPhone",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse('tel:100');
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.error_outline, color: Color(0xFFE11D48), size: 14),
                      SizedBox(width: 4),
                      Text(
                        "SOS Dispatch",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
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

  Widget _buildMainTabSwitcher(bool isDark, Color surfaceColor, Color primaryIndigo) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeMainTab = "profile"),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _activeMainTab == "profile" ? primaryIndigo : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Profile Details",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _activeMainTab == "profile" ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeMainTab = "graph"),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _activeMainTab == "graph" ? primaryIndigo : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Weekly Activity Graph",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _activeMainTab == "graph" ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyActivityGraphSection(
    bool isDark,
    Color surfaceColor,
    Color primaryIndigo,
    Color titleColor,
    Color subTextColor,
  ) {
    final nowMonday = _getCurrentMonday(DateTime.now());
    final isNextDisabled = _currentWeekMonday.isAfter(nowMonday.subtract(const Duration(days: 1)));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart, color: primaryIndigo, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Weekly Distance & Runs",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: titleColor),
                    onPressed: () => _handleWeekChange(false),
                  ),
                  Text(
                    DateFormat('dd MMM').format(_currentWeekMonday),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryIndigo),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: isNextDisabled ? Colors.grey : titleColor),
                    onPressed: isNextDisabled ? null : () => _handleWeekChange(true),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Bar Chart Visualizer
          SizedBox(
            height: 200,
            child: _buildWeeklyBarChart(isDark, primaryIndigo),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyBarChart(bool isDark, Color primaryIndigo) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Map weekly activity items
    List<double> kmValues = List.filled(7, 0.0);
    List<int> routeValues = List.filled(7, 0);

    for (int i = 0; i < 7; i++) {
      final date = _currentWeekMonday.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      final match = _weeklyActivity.firstWhere(
        (item) => item['date'] == dateStr || item['operation_date'] == dateStr,
        orElse: () => {},
      );

      if (match.isNotEmpty) {
        kmValues[i] = double.tryParse((match['km'] ?? match['total_km'] ?? 0).toString()) ?? 0.0;
        routeValues[i] = int.tryParse((match['routes'] ?? match['total_routes'] ?? 0).toString()) ?? 0;
      }
    }

    double maxKm = kmValues.fold(10.0, (max, v) => v > max ? v : max);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final double km = kmValues[index];
        final int routes = routeValues[index];
        final double heightFactor = (km / maxKm).clamp(0.08, 1.0);

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (km > 0)
              Text(
                "${km.toStringAsFixed(0)}k",
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: primaryIndigo),
              ),
            const SizedBox(height: 4),
            Container(
              width: 24,
              height: 130 * heightFactor,
              decoration: BoxDecoration(
                color: km > 0 ? primaryIndigo : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 4),
              child: routes > 0
                  ? Text(
                      "$routes",
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              days[index],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSubTabsBar(bool isDark, Color surfaceColor, Color primaryIndigo) {
    final tabs = [
      {'id': 'profile', 'label': 'Profile Details'},
      {'id': 'vehicles', 'label': 'Drive History (${_vehicleHistory.length})'},
      {'id': 'allowances', 'label': 'Allowances'},
      {'id': 'points', 'label': 'Points History'},
      {'id': 'leaves', 'label': 'Leave Logs (${_leaveHistory.length})'},
      {'id': 'upcoming', 'label': 'Upcoming Routes'},
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final t = tabs[index];
          final isSelected = _activeSubTab == t['id'];

          return GestureDetector(
            onTap: () => setState(() => _activeSubTab = t['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? primaryIndigo : surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? primaryIndigo : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Center(
                child: Text(
                  t['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- SUB TAB VIEWS ---

  Widget _buildProfileDetailsSubTab(
    bool isDark,
    Color surfaceColor,
    Color primaryIndigo,
    Color titleColor,
    Color subTextColor,
    Map<String, dynamic> dp,
    Map<String, dynamic> dashDriver,
  ) {
    return Column(
      children: [
        // Contact Gateway
        _buildSectionCard(
          title: "Contact Gateway",
          icon: Icons.phone_android,
          color: const Color(0xFF06B6D4),
          isDark: isDark,
          surfaceColor: surfaceColor,
          items: [
            _InfoItem(Icons.phone, "Mobile Number", _driverData['phone'] ?? 'N/A'),
            _InfoItem(Icons.email, "Email Address", _driverData['email'] ?? 'N/A'),
            _InfoItem(Icons.location_on, "Residential Address", dp['address'] ?? _driverData['address'] ?? 'N/A'),
          ],
        ),
        const SizedBox(height: 16),

        // SOS Emergency Contact (If present)
        if ((dp['emergency_contact_name'] ?? _driverData['emergency_contact_name']) != null) ...[
          _buildSOSEmergencyCard(dp, isDark),
          const SizedBox(height: 16),
        ],

        // Personal Information Matrix
        _buildSectionCard(
          title: "Personal Information Matrix",
          icon: Icons.person_outline,
          color: const Color(0xFF10B981),
          isDark: isDark,
          surfaceColor: surfaceColor,
          items: [
            _InfoItem(Icons.badge, "Full Legal Name", _driverData['name'] ?? 'N/A'),
            _InfoItem(Icons.man, "Father's Name", _driverData['father_name'] ?? 'N/A'),
            _InfoItem(Icons.woman, "Mother's Name", _driverData['mother_name'] ?? 'N/A'),
            _InfoItem(Icons.favorite, "Spouse's Name", _driverData['spouse_name'] ?? 'N/A'),
            _InfoItem(Icons.cake, "Date of Birth", _formatDate(_driverData['dob'])),
            _InfoItem(Icons.timeline, "Age", _driverData['age'] != null ? "${_driverData['age']} Yrs" : 'N/A'),
            _InfoItem(Icons.wc, "Gender", _driverData['gender'] ?? 'N/A'),
            _InfoItem(Icons.bloodtype, "Blood Group", dp['blood_group'] ?? 'N/A'),
            _InfoItem(Icons.mosque, "Religion", _driverData['religious'] ?? 'N/A'),
            _InfoItem(Icons.groups, "Caste", _driverData['caste'] ?? 'N/A'),
            _InfoItem(Icons.group_work, "Community", _driverData['community'] ?? 'N/A'),
            _InfoItem(Icons.credit_card, "Aadhaar Identity", _driverData['aadhar_number'] != null ? "[Aadhaar Redacted]" : 'N/A'),
          ],
        ),
        const SizedBox(height: 16),

        // Account & Deployment Context
        _buildSectionCard(
          title: "Account & Deployment Context",
          icon: Icons.tune,
          color: const Color(0xFF3B82F6),
          isDark: isDark,
          surfaceColor: surfaceColor,
          items: [
            _InfoItem(Icons.alternate_email, "System Username", "@${_driverData['username'] ?? 'username'}"),
            _InfoItem(Icons.badge, "Employee Registry ID", "#${dp['employee_code'] ?? 'DRV'}"),
            _InfoItem(Icons.verified_user, "System Status", "${_driverData['status'] ?? 'Active'}"),
            _InfoItem(Icons.directions_bus, "Field Duty Status", "${dp['status'] ?? 'AVAILABLE'}"),
            _InfoItem(Icons.work, "Role", dp['role_type'] ?? 'Driver'),
            _InfoItem(Icons.notifications, "Push Notifications", _driverData['push_notification_enabled'] == true ? 'Active' : 'Disabled'),
            _InfoItem(Icons.access_time, "Last Login", _formatDate(_driverData['last_login_at'])),
            _InfoItem(Icons.calendar_month, "Joining Date", _formatDate(dp['joining_date'])),
            _InfoItem(Icons.work_history, "Exp. @ BIT", "${dp['experience_at_Bit'] ?? '0'} Yrs"),
            _InfoItem(Icons.history, "Total Driving Exp.", "${dp['experience_years'] ?? '0'} Yrs"),
          ],
        ),
        const SizedBox(height: 16),

        // Driving Licence Parameters
        if (dp['license_number'] != null) ...[
          _buildSectionCard(
            title: "Driving Licence Parameters",
            icon: Icons.shield_outlined,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            surfaceColor: surfaceColor,
            items: [
              _InfoItem(Icons.card_membership, "Licence Index Code", dp['license_number'] ?? 'N/A'),
              _InfoItem(Icons.event_busy, "Non-Transport Expiry", _formatDate(dp['non_transport_expiry_date'])),
              _InfoItem(Icons.event, "Transport Expiry", _formatDate(dp['license_expiry_date'] ?? dp['license_expiry'])),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Nominee Details
        if ((dp['nominee_name'] ?? _driverData['nominee_name']) != null) ...[
          _buildSectionCard(
            title: "Nominee Dependency Node",
            icon: Icons.handshake_outlined,
            color: const Color(0xFFF43F5E),
            isDark: isDark,
            surfaceColor: surfaceColor,
            items: [
              _InfoItem(Icons.person, "Nominee Name", dp['nominee_name'] ?? _driverData['nominee_name'] ?? 'N/A'),
              _InfoItem(Icons.cake, "Nominee DOB", _formatDate(dp['nominee_dob'] ?? _driverData['nominee_dob'])),
              _InfoItem(Icons.family_restroom, "Relationship", dp['nominee_relation'] ?? _driverData['nominee_relation'] ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Salary Structure Allocation
        if (dp['salary_basic'] != null) ...[
          _buildSalaryCard(dp, isDark, surfaceColor),
          const SizedBox(height: 16),
        ],

        // Bank Accounts Framework
        if (_driverData['bank_name'] != null || _driverData['sub_bank_name'] != null) ...[
          _buildBankCard(_driverData, isDark, surfaceColor),
          const SizedBox(height: 16),
        ],

        // System Verification Attachments
        _buildAttachmentsSection(isDark, surfaceColor, primaryIndigo, titleColor, dp),
      ],
    );
  }

  Widget _buildSOSEmergencyCard(Map<String, dynamic> dp, bool isDark) {
    final emgName = dp['emergency_contact_name'] ?? _driverData['emergency_contact_name'] ?? 'N/A';
    final emgPhone = dp['emergency_contact_phone'] ?? _driverData['emergency_contact_phone'] ?? 'N/A';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.favorite_border, color: Color(0xFFE11D48), size: 18),
              SizedBox(width: 8),
              Text(
                "SOS EMERGENCY CONTACT",
                style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            emgName.toString(),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF881337)),
          ),
          const Text(
            "Primary Relative / Emergency Contact",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFBE123C)),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final uri = Uri.parse('tel:$emgPhone');
              if (await canLaunchUrl(uri)) launchUrl(uri);
            },
            child: Text(
              emgPhone.toString(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFE11D48), letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryCard(Map<String, dynamic> dp, bool isDark, Color surfaceColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments_outlined, color: Color(0xFF8B5CF6), size: 20),
              SizedBox(width: 8),
              Text(
                "Salary Structure Allocation",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMiniField("Basic Pay Scale", "₹${dp['salary_basic'] ?? 0}", isDark),
              _buildMiniField("Dearness Allowance (DA)", "₹${dp['da'] ?? 0}", isDark),
              _buildMiniField("Special Allowance (SA)", "₹${dp['sa'] ?? 0}", isDark),
              _buildMiniField("EPFO Contribution", "₹${dp['epfo_management_contribution'] ?? 0}", isDark),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Gross Net Salary",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF4338CA)),
                ),
                Text(
                  "₹${dp['gross_salary'] ?? 0}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF3730A3)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankCard(Map<String, dynamic> data, bool isDark, Color surfaceColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_outlined, color: Color(0xFF14B8A6), size: 20),
              SizedBox(width: 8),
              Text(
                "Bank Accounts Framework",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (data['bank_name'] != null) ...[
            const Text(
              "Primary Settlement Account",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0D9488), letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildMiniField("Institution", "${data['bank_name']}", isDark),
                _buildMiniField("Branch", "${data['branch_name'] ?? 'N/A'}", isDark),
                _buildMiniField("Account No", "${data['account_number'] ?? 'N/A'}", isDark),
                _buildMiniField("IFSC Routing Code", "${data['ifsc_code'] ?? 'N/A'}", isDark),
              ],
            ),
          ],
          if (data['sub_bank_name'] != null) ...[
            const SizedBox(height: 16),
            const Text(
              "Secondary Escrow Account",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildMiniField("Institution", "${data['sub_bank_name']}", isDark),
                _buildMiniField("Branch", "${data['sub_bank_branch_name'] ?? 'N/A'}", isDark),
                _buildMiniField("Account No", "${data['sub_account_number'] ?? 'N/A'}", isDark),
                _buildMiniField("IFSC Code", "${data['sub_bank_ifsc_code'] ?? 'N/A'}", isDark),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection(
    bool isDark,
    Color surfaceColor,
    Color primaryIndigo,
    Color titleColor,
    Map<String, dynamic> dp,
  ) {
    final attachments = [
      {'title': 'Profile Photo', 'url': _driverData['profile_photo'] ?? _driverData['profile_photo_url']},
      {'title': 'Aadhaar Card', 'url': _driverData['aadhar_photo']},
      {'title': 'PAN Card', 'url': dp['pan_image']},
      {'title': 'License Front', 'url': dp['licence_image_front']},
      {'title': 'License Back', 'url': dp['licence_image_back']},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_shared_outlined, color: primaryIndigo, size: 20),
              const SizedBox(width: 8),
              Text(
                "System Verification Attachments",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: attachments.length,
              itemBuilder: (context, index) {
                final item = attachments[index];
                final String title = item['title'] as String;
                final String? rawUrl = item['url'] as String?;
                final String url = _getImageUrl(rawUrl);
                final bool hasImage = url.isNotEmpty;

                return GestureDetector(
                  onTap: hasImage ? () => _showFullScreenImage(url) : null,
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: hasImage
                                ? Image.network(
                                    url,
                                    headers: const {'X-Tunnel-Skip-Anti-Phishing-Page': 'true'},
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.broken_image, color: Colors.grey, size: 35),
                                  )
                                : const Center(
                                    child: Icon(Icons.insert_drive_file_outlined, color: Colors.grey, size: 35),
                                  ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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

  // --- SUB TAB 2: DRIVE HISTORY (VEHICLES) ---
  Widget _buildVehicleDriveHistorySubTab(
    bool isDark,
    Color surfaceColor,
    Color primaryIndigo,
    Color titleColor,
    Color subTextColor,
  ) {
    if (_vehicleHistory.isEmpty) {
      return _buildEmptyState("No Drive History Records Found", Icons.directions_bus_outlined, isDark);
    }

    return Column(
      children: _vehicleHistory.map((rawItem) {
        final item = _asMap(rawItem);
        final vehicle = _asMap(item['vehicle']);
        final route = _asMap(item['route']);
        final vNum = vehicle['vehicle_number'] ?? 'N/A';
        final vType = vehicle['vehicle_type'] ?? 'Bus';
        final vCapacity = vehicle['capacity'] ?? 0;
        final rName = route['route_name'] ?? 'N/A';
        final status = item['status'] ?? 'COMPLETED';
        final isCompleted = status == 'COMPLETED';

        final startTime = _formatDate(item['actual_start_at'] ?? item['planned_start_at'] ?? item['start_datetime']);
        final endTime = _formatDate(item['actual_end_at'] ?? item['planned_end_at'] ?? item['end_datetime']);
        final reqId = (item['route_request_id'] ?? route['route_request_id'] ?? route['id'] ?? item['schedule_id'] ?? '').toString();

        return GestureDetector(
          onTap: () {
            final routeName = (route['route_name'] ?? rName).toString();
            final startLoc = (route['start_location'] ?? route['startLocation'] ?? 'Origin').toString();
            final destLoc = (route['destination_location'] ?? route['endLocation'] ?? 'Destination').toString();

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MissionDetailsScreen(
                  missionTitle: routeName,
                  time: "$startTime - $endTime",
                  driverName: (_driverData['name'] ?? "Driver").toString(),
                  driverPhone: (_driverData['phone'] ?? "N/A").toString(),
                  vehicleInfo: "$vType ($vNum)",
                  capacity: "$vCapacity Seats",
                  passengerCount: "$vCapacity",
                  pathType: (route['trip_type'] ?? route['travelType'] ?? "One-Way").toString(),
                  stops: [
                    {'location': startLoc, 'eta': 'Start'},
                    {'location': destLoc, 'eta': 'End'},
                  ],
                  status: status.toString(),
                  statusColor: isCompleted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  requestId: reqId,
                  rawStatus: isCompleted ? 2 : 1,
                  creatorName: "Transport Admin",
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryIndigo.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.directions_car, color: primaryIndigo, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vNum.toString(),
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: titleColor),
                            ),
                            Text(
                              "$vType • $vCapacity Seats",
                              style: TextStyle(fontSize: 10, color: subTextColor, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toString(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? const Color(0xFF15803D) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: subTextColor, size: 18),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: primaryIndigo, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rName.toString(),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: titleColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Start: $startTime", style: TextStyle(fontSize: 10, color: subTextColor)),
                    Text("End: $endTime", style: TextStyle(fontSize: 10, color: subTextColor)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- SUB TAB 3: ALLOWANCES ---
  Widget _buildAllowancesSubTab(
    bool isDark,
    Color surfaceColor,
    Color primaryIndigo,
    Color titleColor,
    Color subTextColor,
  ) {
    final allowanceSummary = _asMap(_dashboardData?['allowanceSummary']);
    final List items = allowanceSummary['items'] is List ? allowanceSummary['items'] : [];
    final totalAllowance = allowanceSummary['total_allowance'] ?? 0;

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total Allowances Allocated",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
              ),
              Text(
                "₹$totalAllowance",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF065F46)),
              ),
            ],
          ),
        ),

        if (items.isEmpty)
          _buildEmptyState("No Allowance Records Found", Icons.payments_outlined, isDark)
        else
          ...items.map((rawItem) {
            final item = _asMap(rawItem);
            final type = item['allowance_type'] ?? 'FOOD ALLOWANCE';
            final mode = item['payment_mode'] ?? 'CASH';
            final amount = item['amount'] ?? 0;
            final reason = item['reason'] ?? 'N/A';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.currency_rupee, color: Color(0xFF059669), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.toString(),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Payment Mode: $mode • Reason: $reason",
                          style: TextStyle(fontSize: 10, color: subTextColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "₹$amount",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // --- SUB TAB 4: POINTS HISTORY ---
  Widget _buildPointsHistorySubTab(
    bool isDark,
    Color surfaceColor,
    Color primaryIndigo,
    Color titleColor,
    Color subTextColor,
  ) {
    final pointsSummary = _asMap(_dashboardData?['pointsSummary']);
    final List history = pointsSummary['history'] is List ? pointsSummary['history'] : [];
    final totalPoints = pointsSummary['total_points'] ?? 0;

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total Reward Points Earned",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
              ),
              Text(
                "$totalPoints Pts",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF075985)),
              ),
            ],
          ),
        ),

        if (history.isEmpty)
          _buildEmptyState("No Points History Records Found", Icons.emoji_events_outlined, isDark)
        else
          ...history.map((rawPt) {
            final pt = _asMap(rawPt);
            final sourceType = pt['source_type']?.toString().replaceAll('_', ' ') ?? 'Reward';
            final reason = pt['reason'] ?? 'No reason provided';
            final points = pt['points'] ?? 0;
            final awardedBy = _asMap(pt['awardedBy'])['name'] ?? 'System';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.stars, color: Color(0xFFD97706), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sourceType.toString().toUpperCase(),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: titleColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "$reason (By: $awardedBy)",
                          style: TextStyle(fontSize: 10, color: subTextColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (points is num && points >= 0) ? const Color(0xFFFEF3C7) : const Color(0xFFFFE4E6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (points is num && points >= 0) ? "+$points" : "$points",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: (points is num && points >= 0) ? const Color(0xFFB45309) : const Color(0xFFE11D48),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // --- SUB TAB 5: LEAVE LOGS ---
  Widget _buildLeaveLogsSubTab(
    bool isDark,
    Color surfaceColor,
    Color primaryIndigo,
    Color titleColor,
    Color subTextColor,
  ) {
    if (_leaveHistory.isEmpty) {
      return _buildEmptyState("No Leave Records Found", Icons.calendar_today_outlined, isDark);
    }

    return Column(
      children: _leaveHistory.map((rawLeave) {
        final leave = _asMap(rawLeave);
        final status = leave['status'] ?? 1;
        final statusText = status == 2 ? 'Approved' : (status == 3 ? 'Rejected' : 'Pending');
        final statusBg = status == 2 ? const Color(0xFFDCFCE7) : (status == 3 ? const Color(0xFFFFE4E6) : const Color(0xFFFEF3C7));
        final statusFg = status == 2 ? const Color(0xFF15803D) : (status == 3 ? const Color(0xFFE11D48) : const Color(0xFFB45309));

        final fromDate = _formatDate(leave['from_date']);
        final toDate = _formatDate(leave['to_date']);
        final reason = leave['reason'] ?? 'N/A';
        final approver = _asMap(leave['approver'])['name'] ?? 'Admin';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "LEAVE REQUEST",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: titleColor, letterSpacing: 0.5),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusFg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("From: $fromDate", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: titleColor)),
                  Icon(Icons.arrow_forward, size: 14, color: subTextColor),
                  Text("To: $toDate", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: titleColor)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Reason: \"$reason\"",
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: subTextColor),
              ),
              if (status == 2 || status == 3) ...[
                const SizedBox(height: 6),
                Text(
                  "Processed by: $approver",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusFg),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- SUB TAB 6: UPCOMING ROUTES ---
  Widget _buildUpcomingRoutesSubTab(
    bool isDark,
    Color surfaceColor,
    Color primaryIndigo,
    Color titleColor,
    Color subTextColor,
  ) {
    final List upcoming = _dashboardData?['upcomingRoutes'] is List ? _dashboardData!['upcomingRoutes'] : [];

    if (upcoming.isEmpty) {
      return _buildEmptyState("No Upcoming Assigned Routes Found", Icons.map_outlined, isDark);
    }

    return Column(
      children: upcoming.map((rawRoute) {
        final route = _asMap(rawRoute);
        final rName = route['route_name'] ?? route['routeName'] ?? 'Route';
        final travelType = route['trip_type'] ?? route['travelType'] ?? 'One Way';
        final distance = route['approx_distance_km'] ?? route['distance'] ?? 0;
        final startLoc = route['startLocation'] ?? 'Origin';
        final destLoc = route['destinationLocation'] ?? 'Destination';
        final startDate = _formatDate(route['planned_start_at'] ?? route['startDate']);
        final reqId = (route['route_request_id'] ?? route['id'] ?? '').toString();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MissionDetailsScreen(
                  missionTitle: rName.toString(),
                  time: startDate,
                  driverName: (_driverData['name'] ?? "Driver").toString(),
                  driverPhone: (_driverData['phone'] ?? "N/A").toString(),
                  vehicleInfo: "Assigned Vehicle",
                  capacity: "Passengers",
                  passengerCount: "0",
                  pathType: travelType.toString(),
                  stops: [
                    {'location': startLoc.toString(), 'eta': 'Start'},
                    {'location': destLoc.toString(), 'eta': 'End'},
                  ],
                  status: "UPCOMING",
                  statusColor: primaryIndigo,
                  requestId: reqId,
                  rawStatus: 1,
                  creatorName: "Transport Admin",
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        rName.toString(),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: primaryIndigo.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "$travelType • ${distance}KM",
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryIndigo),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: subTextColor, size: 18),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.trip_origin, color: primaryIndigo, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "$startLoc ➔ $destLoc",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subTextColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, color: subTextColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      "Scheduled: $startDate",
                      style: TextStyle(fontSize: 10, color: subTextColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- HELPERS ---

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color surfaceColor,
    required List<_InfoItem> items,
  }) {
    final validItems = items.where((i) => i.value != 'N/A' && i.value.isNotEmpty).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: (validItems.isEmpty ? items : validItems).map((item) {
              return _buildMiniField(item.label, item.value, isDark);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniField(String label, String value, bool isDark) {
    return Container(
      width: 155,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "D";
    final parts = name.trim().split(RegExp(r'\s+'));
    String initials = parts.first[0];
    if (parts.length > 1) initials += parts.last[0];
    return initials.toUpperCase();
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr.toString());
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr.toString();
    }
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  _InfoItem(this.icon, this.label, this.value);
}
