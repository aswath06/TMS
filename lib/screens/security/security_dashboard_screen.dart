import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/store/faculty_store.dart';
import 'package:tripzo/store/VehicleStore.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/components/common/structural_loading.dart';
import '../../components/notification_bell.dart';

class SecurityDashboardScreen extends StatefulWidget {
  const SecurityDashboardScreen({super.key});

  @override
  State<SecurityDashboardScreen> createState() => _SecurityDashboardScreenState();
}

class _SecurityDashboardScreenState extends State<SecurityDashboardScreen> {
  static int _cachedOutCampusCount = 0;
  static int _cachedInCampusCount = 0;
  static List<dynamic> _cachedOutCampusList = [];
  static List<dynamic> _cachedInCampusList = [];
  static DateTime? _lastFetchTime;

  int _outCampusCount = _cachedOutCampusCount;
  int _inCampusCount = _cachedInCampusCount;
  List<dynamic> _outCampusList = _cachedOutCampusList;
  List<dynamic> _inCampusList = _cachedInCampusList;
  String _selectedCategory = 'OUT_CAMPUS';
  bool _isLoadingData = false;
  
  int _page = 1;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (useFacultyStore.profileData.value == null) {
      useFacultyStore.fetchProfile();
    }
    _fetchDashboardData();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingData && !_isFetchingMore && _hasMore) {
        _fetchMoreData();
      }
    }
  }

  Future<void> _fetchMoreData() async {
    setState(() => _isFetchingMore = true);
    _page++;
    await _fetchDashboardData(isLoadMore: true);
    if (mounted) setState(() => _isFetchingMore = false);
  }

  Future<void> _fetchDashboardData({bool force = false, bool isLoadMore = false}) async {
    if (!mounted) return;
    if (!force && !isLoadMore && _lastFetchTime != null && DateTime.now().difference(_lastFetchTime!).inSeconds < 5) {
      return;
    }
    if (!isLoadMore) {
      setState(() {
        _isLoadingData = true;
        _page = 1;
        _hasMore = true;
      });
    }
    
    try {
      final token = await UserStore.getToken();
      
      final res = await http.get(
        Uri.parse(ApiConstants.getSecurityRoutes(_page, 20, 'PENDING')),
        headers: ApiConstants.getHeaders(token),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        
        // Handle pagination for any paginated lists (if the API supports it here)
        final pagination = body['data']?['pagination'] ?? {};
        final totalPages = pagination['totalPages'] ?? 1;
        if (_page >= totalPages) {
          _hasMore = false;
        }

        final summary = body['data']?['vehicle_summary'] ?? {};
        
        final newOutList = summary['outside_vehicles'] ?? [];
        final newInList = summary['inside_vehicles'] ?? [];

        if (isLoadMore) {
          _outCampusList.addAll(newOutList);
          _inCampusList.addAll(newInList);
        } else {
          _outCampusCount = summary['outside_count'] ?? 0;
          _inCampusCount = summary['inside_count'] ?? 0;
          _outCampusList = newOutList;
          _inCampusList = newInList;
        }

        _cachedOutCampusCount = _outCampusCount;
        _cachedInCampusCount = _inCampusCount;
        _cachedOutCampusList = _outCampusList;
        _cachedInCampusList = _inCampusList;
      }
      if (!isLoadMore) _lastFetchTime = DateTime.now();
    } catch (e) {
      debugPrint("Error fetching dashboard data: $e");
    } finally {
      if (mounted && !isLoadMore) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
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
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryBlue.withOpacity(isDark ? 0.1 : 0.05),
              ),
            ),
          ),
          SafeArea(
            bottom: true,
            child: RefreshIndicator(
              onRefresh: () => _fetchDashboardData(force: true),
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    ValueListenableBuilder(
                      valueListenable: useFacultyStore.profileData,
                      builder: (context, data, _) {
                        return FutureBuilder<String?>(
                          future: UserStore.getName(),
                          builder: (context, snapshot) {
                            final String displayName =
                                data?['name'] ?? snapshot.data ?? "Security";
                            return _buildHeader(
                              displayName,
                              titleColor,
                              subColor,
                              screenWidth,
                              primaryBlue,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 36),
                    _buildSectionTitle('Campus Vehicle Stats', titleColor),
                    const SizedBox(height: 18),
                    _buildStatsSection(primaryBlue, surfaceColor, isDark, screenWidth),
                    const SizedBox(height: 24),
                    _buildSelectedList(titleColor, subColor, isDark, surfaceColor),
                    if (_isFetchingMore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
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

  Widget _buildHeader(
    String name,
    Color titleColor,
    Color subColor,
    double width,
    Color primary,
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
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: FutureBuilder<String?>(
                  future: UserStore.getRole(),
                  builder: (context, snapshot) {
                    final String role = snapshot.data?.toUpperCase() ?? "SECURITY";
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
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [primary, primary.withOpacity(0.4)],
            ),
          ),
          child: CircleAvatar(
            radius: width * 0.065,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: width * 0.06,
              backgroundImage: NetworkImage(
                'https://ui-avatars.com/api/?name=$name&background=6366F1&color=fff',
              ),
            ),
          ),
        ),
      ],
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

  Widget _buildStatsSection(
    Color primaryBlue,
    Color surface,
    bool isDark,
    double width,
  ) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = 'OUT_CAMPUS';
              });
            },
            child: _buildStatCard(
              title: 'Outside Campus',
              value: _outCampusCount,
              icon: Icons.directions_car_rounded,
              color: primaryBlue,
              surface: surface,
              isDark: isDark,
              isSelected: _selectedCategory == 'OUT_CAMPUS',
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = 'IN_CAMPUS';
              });
            },
            child: _buildStatCard(
              title: 'Inside Campus',
              value: _inCampusCount,
              icon: Icons.local_parking_rounded,
              color: primaryBlue,
              surface: surface,
              isDark: isDark,
              isSelected: _selectedCategory == 'IN_CAMPUS',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
    required Color surface,
    required bool isDark,
    required bool isSelected,
  }) {
    final Color bgColor = isSelected ? color : surface;
    final Color textColor = isSelected ? Colors.white : (isDark ? Colors.white : Colors.black);
    final Color iconBgColor = isSelected ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1);
    final Color iconColor = isSelected ? Colors.white : color;
    final Color subTextColor = isSelected ? Colors.white70 : Colors.grey;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected ? color : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          width: 1,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
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
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 20),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: const Duration(seconds: 1),
            builder: (context, val, child) {
              return Text(
                val.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  letterSpacing: -1.0,
                  color: textColor,
                  height: 1,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: subTextColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedList(Color titleColor, Color subColor, bool isDark, Color surfaceColor) {
    final String title = _selectedCategory == 'OUT_CAMPUS' ? 'Outside Campus Vehicles' : 'Inside Campus Vehicles';

    if (_isLoadingData && _outCampusList.isEmpty && _inCampusList.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(title, titleColor),
          const SizedBox(height: 16),
          const StructuralLoading(itemCount: 3),
        ],
      );
    }

    final List<dynamic> list = _selectedCategory == 'OUT_CAMPUS' ? _outCampusList : _inCampusList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title, titleColor),
        const SizedBox(height: 16),
        if (list.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                "No vehicles found.",
                style: TextStyle(color: subColor, fontSize: 16),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final item = list[index];
              
              final vehicleNumber = item['vehicle_number'] ?? 'Unknown Vehicle';
              final make = item['make'] ?? 'Unknown Make';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_car_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicleNumber,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.precision_manufacturing_rounded, size: 14, color: subColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  make,
                                  style: TextStyle(
                                    fontSize: 14,
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
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
