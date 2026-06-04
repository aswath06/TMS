import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/screens/security/security_qr_scanner_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';

class SecurityVehicleScreen extends StatefulWidget {
  const SecurityVehicleScreen({super.key});

  @override
  State<SecurityVehicleScreen> createState() => _SecurityVehicleScreenState();
}

class _SecurityVehicleScreenState extends State<SecurityVehicleScreen> {
  static List<Map<String, dynamic>> _cachedApiData = [];
  static int _cachedSelectedIndex = 0;
  static DateTime? _lastFetchTime;

  int _selectedIndex = _cachedSelectedIndex; // 0: Outbound, 1: Inbound, 2: Pending
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _userRole = "";

  List<Map<String, dynamic>> _apiData = List.from(_cachedApiData);
  bool _isLoading = false;
  int _page = 1;
  bool _hasMore = true;
  bool _isFetchingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _fetchRoutes();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isFetchingMore && _hasMore) {
        _fetchMoreRoutes();
      }
    }
  }

  Future<void> _fetchMoreRoutes() async {
    setState(() => _isFetchingMore = true);
    _page++;
    await _fetchRoutesData(isLoadMore: true);
    if (mounted) setState(() => _isFetchingMore = false);
  }

  Future<void> _fetchRoutesData({bool isLoadMore = false, bool force = false}) async {
    if (!mounted) return;
    if (!force && !isLoadMore && _lastFetchTime != null && DateTime.now().difference(_lastFetchTime!).inSeconds < 5) {
      return;
    }
    if (!isLoadMore) {
      setState(() {
        _isLoading = true;
        _page = 1;
        _apiData.clear();
        _hasMore = true;
      });
    }

    try {
      final token = await UserStore.getToken();
      final types = ['OUT_CAMPUS', 'IN_CAMPUS', 'PENDING'];
      final type = types[_selectedIndex];
      final url = ApiConstants.getSecurityRoutes(_page, 10, type);
      
      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final List rawData = body['data']['data'] ?? [];
          final pagination = body['data']['pagination'] ?? {};
          final totalPages = pagination['totalPages'] ?? 1;

          if (_page >= totalPages) {
            _hasMore = false;
          }

          final newItems = rawData.map((e) {
            final List vehicles = e['vehicles'] ?? [];
            final List drivers = e['drivers'] ?? [];
            
            String vNum = 'N/A';
            if (vehicles.isNotEmpty) vNum = vehicles.first['vehicle_number'] ?? 'N/A';
            
            String dName = 'N/A';
            if (drivers.isNotEmpty) dName = drivers.first['name'] ?? drivers.first['driver_name'] ?? 'N/A';

            return {
              "id": e['trip_instance_id']?.toString() ?? e['id']?.toString() ?? '',
              "status": ["Outbound", "Inbound", "Pending"][_selectedIndex],
              "routeName": e['route_name'] ?? 'Unknown Route',
              "purpose": e['purpose'] ?? 'No Purpose',
              "vehicleNumber": vNum,
              "driverName": dName,
              "startLocation": e['start_destination'] ?? 'Unknown',
              "endLocation": e['end_destination'] ?? 'Unknown',
              "startedBy": e['started_by'],
              "startedAt": e['started_at'],
              "endedBy": e['ended_by'],
              "endedAt": e['ended_at'],
            };
          }).toList();

          if (mounted) {
            setState(() {
              if (isLoadMore) {
                _apiData.addAll(newItems);
              } else {
                _apiData = newItems;
              }
              _cachedApiData = List.from(_apiData);
              _cachedSelectedIndex = _selectedIndex;
            });
          }
        }
      }
      if (!isLoadMore) _lastFetchTime = DateTime.now();
    } catch (e) {
      debugPrint("Error fetching routes: $e");
    } finally {
      if (mounted && !isLoadMore) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRoutes({bool force = false}) async {
    await _fetchRoutesData(isLoadMore: false, force: force);
  }

  Future<void> _loadUserRole() async {
    final role = await UserStore.getRole();
    if (mounted) {
      setState(() {
        _userRole = role?.toLowerCase() ?? "";
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subColor = isDark ? Colors.white70 : Colors.black54;
    final Color scaffoldBg =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _fetchRoutes(force: true),
          child: CustomScrollView(
            controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeader(),
            SliverToBoxAdapter(
              child: _buildToggle(isDark, subColor),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: _buildSearchBar(isDark, subColor),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            _buildListSection(isDark, titleColor, subColor, isMobile),
            if (_isFetchingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 40.0, 24.0, 24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Route Monitor",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Track vehicles entering and leaving the campus",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (_userRole == "super admin")
              Container(
                margin: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF6366F1)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SecurityQrScannerScreen()),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(bool isDark, Color subColor) {
    final tabs = ["Outbound", "Inbound", "Pending"];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = _selectedIndex == index;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_selectedIndex != index) {
                    setState(() => _selectedIndex = index);
                    _fetchRoutes(force: true);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6366F1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    tabs[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : subColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color subColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
        decoration: InputDecoration(
          hintText: "Search by vehicle no. or driver...",
          hintStyle: TextStyle(color: subColor, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: subColor),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildListSection(bool isDark, Color titleColor, Color subColor, bool isMobile) {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final statuses = ["Outbound", "Inbound", "Pending"];
    final currentStatus = statuses[_selectedIndex];

    final filteredData = _apiData.where((d) {
      final matchesStatus = d['status'] == currentStatus;
      final query = _searchQuery.toLowerCase();
      final matchesSearch = query.isEmpty ||
          (d['vehicleNumber'] ?? '').toString().toLowerCase().contains(query) ||
          (d['driverName'] ?? '').toString().toLowerCase().contains(query);
      return matchesStatus && matchesSearch;
    }).toList();

    if (filteredData.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_car_filled_outlined,
                  size: 60, color: Colors.grey.withOpacity(0.4)),
              const SizedBox(height: 16),
              Text(
                "No routes $currentStatus",
                style: TextStyle(
                    color: subColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final data = filteredData[index];
            return TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: Duration(milliseconds: 400 + (index * 100)),
              builder: (context, double value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: _buildCard(data, isDark, titleColor, subColor, isMobile),
            );
          },
          childCount: filteredData.length,
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> data, bool isDark, Color titleColor,
      Color subColor, bool isMobile) {
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color primary = const Color(0xFF6366F1);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.route_rounded, color: primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            data['routeName'] ?? 'Unknown Route',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusAnimatedIcon(status: data['status'] ?? ''),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBadge(Icons.directions_car_rounded,
                            data['vehicleNumber'] ?? 'N/A', Colors.orange),
                        _buildBadge(Icons.person_rounded,
                            data['driverName'] ?? 'N/A', Colors.blue),
                        _buildBadge(Icons.assignment_rounded,
                            data['purpose'] ?? 'No Purpose', Colors.purple),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildRouteLocations(data, titleColor, isMobile),
          const SizedBox(height: 20),
          Divider(
              height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
          const SizedBox(height: 20),
          _buildTimelineInfo(data, primary, titleColor, subColor, isMobile),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteLocations(Map<String, dynamic> data, Color titleColor, bool isMobile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(Icons.radio_button_checked, size: 14, color: Colors.green),
            Container(width: 2, height: 20, color: Colors.grey.withOpacity(0.3)),
            const Icon(Icons.location_on, size: 14, color: Colors.redAccent),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['startLocation'] ?? 'Unknown Start',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: titleColor),
                maxLines: isMobile ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Text(
                data['endLocation'] ?? 'Unknown End',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: titleColor),
                maxLines: isMobile ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineInfo(Map<String, dynamic> data, Color primary,
      Color titleColor, Color subColor, bool isMobile) {
    final startChild = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Started By",
                style: TextStyle(
                    fontSize: 11,
                    color: subColor,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                data['startedBy'] ?? 'Pending',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: titleColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (data['startedAt'] != null) ...[
                const SizedBox(height: 2),
                Text(
                  _formatDate(data['startedAt']),
                  style: TextStyle(
                      fontSize: 11,
                      color: subColor,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final endChild = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: (data['endedBy'] != null || data['endedAt'] != null) 
                ? Colors.redAccent 
                : Colors.grey.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Ended By",
                style: TextStyle(
                    fontSize: 11,
                    color: subColor,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                data['endedBy'] != null 
                    ? data['endedBy'] 
                    : (data['endedAt'] != null ? 'Not recorded' : 'Not Ended'),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: (data['endedBy'] != null || data['endedAt'] != null) 
                        ? titleColor 
                        : subColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (data['endedAt'] != null) ...[
                const SizedBox(height: 2),
                Text(
                  _formatDate(data['endedAt']),
                  style: TextStyle(
                      fontSize: 11,
                      color: subColor,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          startChild,
          Container(
            height: 20,
            width: 2,
            color: Colors.grey.withOpacity(0.2),
            margin: const EdgeInsets.only(left: 4, top: 12, bottom: 12),
          ),
          endChild,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: startChild),
        Container(
          height: 40,
          width: 1,
          color: Colors.grey.withOpacity(0.2),
          margin: const EdgeInsets.symmetric(horizontal: 10),
        ),
        Expanded(child: endChild),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return isoDate;
    }
  }
}

class _StatusAnimatedIcon extends StatefulWidget {
  final String status;
  const _StatusAnimatedIcon({required this.status});

  @override
  State<_StatusAnimatedIcon> createState() => _StatusAnimatedIconState();
}

class _StatusAnimatedIconState extends State<_StatusAnimatedIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: widget.status == 'Outbound'
          ? const Offset(0.3, 0.0)
          : widget.status == 'Inbound'
              ? const Offset(-0.3, 0.0)
              : Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    Color iconColor;

    if (widget.status == 'Outbound') {
      iconData = Icons.arrow_forward_rounded; // going out
      iconColor = Colors.orange;
    } else if (widget.status == 'Inbound') {
      iconData = Icons.arrow_back_rounded; // coming in
      iconColor = Colors.green;
    } else {
      iconData = Icons.horizontal_rule_rounded; // stable
      iconColor = Colors.blue;
    }

    if (widget.status == 'Pending') {
      return Icon(iconData, color: iconColor, size: 20);
    }

    return SlideTransition(
      position: _offsetAnimation,
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }
}

