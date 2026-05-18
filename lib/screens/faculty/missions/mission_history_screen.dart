import 'package:tripzo/store/dashboard_store.dart';
import 'package:tripzo/store/admin_dashboard_store.dart';
import 'package:tripzo/store/user_store.dart';
import 'mission_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';

class MissionHistoryScreen extends StatefulWidget {
  const MissionHistoryScreen({super.key});

  @override
  State<MissionHistoryScreen> createState() => _MissionHistoryScreenState();
}

class _MissionHistoryScreenState extends State<MissionHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = "";
  String _role = "faculty";
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _initData() async {
    final role = await UserStore.getRole() ?? "faculty";
    if (mounted) {
      setState(() {
        _role = role;
      });
      _fetchHistory(refresh: true);
    }
  }

  Future<void> _fetchHistory({bool refresh = false}) async {
    if (refresh) _currentPage = 1;
    if (_role.toLowerCase().contains('admin')) {
      await useAdminDashboardStore.fetchHistory(page: _currentPage);
    } else {
      await dashboardStore.fetchHistory(page: _currentPage);
    }
  }

  void _loadMore() {
    if (_role.toLowerCase().contains('admin')) {
      if (useAdminDashboardStore.isLoading.value) return;
    } else {
      if (dashboardStore.state.isLoading) return;
    }
    
    setState(() {
      _currentPage++;
    });
    _fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);

    final bool isAdmin = _role.toLowerCase().contains('admin');
    final bool isFacultyLoading = context.watch<DashboardStore>().state.isLoading;

    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: useAdminDashboardStore.history,
      builder: (context, adminHistory, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: useAdminDashboardStore.isLoading,
          builder: (context, isAdminLoading, _) {
            final List<Map<String, dynamic>> historyItems = isAdmin 
                ? adminHistory 
                : context.watch<DashboardStore>().state.history;
            
            final bool isLoading = isAdmin ? isAdminLoading : isFacultyLoading;

            final completedMissions = historyItems
                .where((req) =>
                    req['routeName']
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ||
                    req['pickup']
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ||
                    req['drop']
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()) ||
                    req['vehicle']
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()))
                .toList();

            return Scaffold(
              backgroundColor: bgColor,
              body: Stack(
                children: [
                  _buildBackgroundDecor(isDark),
                  SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: _buildHeader(context, titleColor),
                        ),
                        Expanded(
                          child: isLoading && completedMissions.isEmpty
                              ? _buildHistorySkeleton(isDark)
                              : RefreshIndicator(
                                  onRefresh: () => _fetchHistory(refresh: true),
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    physics: const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics(),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    itemCount: completedMissions.length + 5, // summary, search, title, items, padding
                                    itemBuilder: (context, index) {
                                      if (index == 0) return const SizedBox(height: 20);
                                      if (index == 1) {
                                        return _buildSummaryCard(
                                          cardColor,
                                          titleColor,
                                          subColor,
                                          primaryBlue,
                                          completedMissions.length,
                                        );
                                      }
                                      if (index == 2) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 24),
                                          child: _buildSearchField(isDark, subColor, cardColor),
                                        );
                                      }
                                      if (index == 3) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 32, bottom: 16),
                                          child: _buildSectionTitle(
                                            "Completed Missions",
                                            primaryBlue,
                                            titleColor,
                                          ),
                                        );
                                      }
                                      
                                      // History Cards logic
                                      int cardIdx = index - 4;
                                      if (cardIdx < completedMissions.length) {
                                        final mission = completedMissions[cardIdx];
                                        return GestureDetector(
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => MissionDetailsScreen(
                                                missionTitle: mission['routeName'] ?? "Mission",
                                                time: mission['date'] ?? "TBD",
                                                driverName: "no driver assigned",
                                                driverPhone: "n/a",
                                                vehicleInfo: mission['vehicle'] ?? "n/a",
                                                capacity: mission['passengers'].toString(),
                                                passengerCount: mission['passengers'].toString(),
                                                pathType: "History",
                                                stops: [
                                                  {'location': mission['pickup'] ?? "Start", 'eta': "Start"},
                                                  if (mission['intermediateStops'] is List)
                                                    ...(mission['intermediateStops'] as List).map((s) => {'location': s.toString(), 'eta': "Transit"}),
                                                  {'location': mission['drop'] ?? "End", 'eta': "End"},
                                                ],
                                                status: "Completed",
                                                statusColor: Colors.green,
                                                requestId: mission['dbId']?.toString() ?? "",
                                                rawStatus: mission['rawStatus'] ?? 8,
                                                creatorName: mission['faculty'] ?? "Faculty Member",
                                              ),
                                            ),
                                          ),
                                          child: _buildHistoryCard(
                                            title: mission['routeName'] ?? "Mission",
                                            date: mission['date'] ?? "TBD",
                                            driver: mission['vehicle'] ?? "N/A",
                                            creator: mission['faculty'] ?? "Faculty Member",
                                            pathType: "Completed",
                                            stops: (mission['intermediateStops'] as List).length + 2,
                                            distance: "N/A",
                                            cardColor: cardColor,
                                            titleColor: titleColor,
                                            subColor: subColor,
                                            primaryBlue: primaryBlue,
                                            allowanceNeeded: mission['allowance_needed'],
                                          ),
                                        );
                                      }

                                      // Loading indicator or final padding
                                      if (isLoading && completedMissions.isNotEmpty) {
                                        return const Center(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(vertical: 24),
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      }
                                      
                                      return const SizedBox(height: 40);
                                    },
                                  ),
                                ),
                          ),
                        ],
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

  // ══════════════════════════════════════════════════════════
  //  SHIMMER SKELETON – mirrors the history page structure
  // ══════════════════════════════════════════════════════════
  Widget _buildHistorySkeleton(bool isDark) {
    final Color base = isDark ? const Color(0xFF1E293B) : Colors.grey.shade300;
    final Color highlight = isDark ? const Color(0xFF334155) : Colors.grey.shade100;

    Widget bone({
      double width = double.infinity,
      double height = 14,
      double radius = 8,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    Widget historyCardSkeleton() {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date + badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                bone(width: 90, height: 12, radius: 6),
                bone(width: 65, height: 20, radius: 8),
              ],
            ),
            const SizedBox(height: 12),
            // Title
            bone(width: 180, height: 17, radius: 9),
            const SizedBox(height: 16),
            // Driver + creator row
            Row(
              children: [
                bone(width: 14, height: 14, radius: 7),
                const SizedBox(width: 6),
                bone(width: 100, height: 13, radius: 7),
                const Spacer(),
                bone(width: 80, height: 11, radius: 6),
              ],
            ),
            const SizedBox(height: 8),
            // Stops + distance
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                bone(width: 60, height: 12, radius: 6),
                bone(width: 50, height: 12, radius: 6),
              ],
            ),
          ],
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Summary card skeleton
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(3, (_) {
                  return Column(
                    children: [
                      bone(width: 40, height: 22, radius: 8),
                      const SizedBox(height: 4),
                      bone(width: 50, height: 10, radius: 5),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
            // Search bar skeleton
            bone(height: 48, radius: 20),
            const SizedBox(height: 32),
            // Section title
            bone(width: 170, height: 18, radius: 9),
            const SizedBox(height: 16),
            // History cards
            ...List.generate(4, (_) => historyCardSkeleton()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color titleColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: titleColor,
            size: 22,
          ),
        ),
        Text(
          "Mission History",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.tune_rounded, color: titleColor.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    Color cardColor,
    Color title,
    Color sub,
    Color blue,
    int totalMissions,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(totalMissions.toString(), "Missions", blue, title),
          _buildStatItem("-", "Stops", blue, title), // Could be calculated if needed
          _buildStatItem("-", "Kms", blue, title),
        ],
      ),
    );
  }

  Widget _buildStatItem(String val, String label, Color blue, Color title) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: title,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: blue,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(bool isDark, Color subColor, Color cardColor) {
    return TextField(
      controller: _searchController,
      onChanged: (val) => setState(() => _searchQuery = val),
      decoration: InputDecoration(
        hintText: "Search by mission or driver...",
        hintStyle: TextStyle(color: subColor.withValues(alpha: 0.5), fontSize: 14),
        prefixIcon: Icon(Icons.search_rounded, color: subColor, size: 20),
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color accent, Color titleColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
      ],
    );
  }


  Widget _buildAllowanceBadge(bool allowanceNeeded) {
    if (!allowanceNeeded) return const SizedBox.shrink();
    return Tooltip(
      message: "Allowance Required",
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.payments_outlined,
          color: Colors.green,
          size: 14,
        ),
      ),
    );
  }

  Widget _buildHistoryCard({
    required String title,
    required String date,
    required String driver,
    required String creator,
    required String pathType,
    required int stops,
    required String distance,
    required Color cardColor,
    required Color titleColor,
    required Color subColor,
    required Color primaryBlue,
    bool? allowanceNeeded,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: TextStyle(
                  color: subColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (allowanceNeeded != null) ...[
                    _buildAllowanceBadge(allowanceNeeded),
                    const SizedBox(width: 8),
                  ],
                  _buildPathBadge(pathType, primaryBlue),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 14, color: subColor),
              const SizedBox(width: 6),
              Text(
                driver,
                style: TextStyle(
                  color: subColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Icon(Icons.person_outline_rounded, size: 12, color: subColor.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text(
                creator,
                style: TextStyle(
                  color: subColor.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$stops stops",
                style: TextStyle(
                  color: subColor.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                distance,
                style: TextStyle(
                  color: subColor.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPathBadge(String type, Color blue) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: blue),
      ),
    );
  }

  Widget _buildBackgroundDecor(bool isDark) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: CircleAvatar(
              radius: 140,
              backgroundColor: const Color(
                0xFF6366F1,
              ).withValues(alpha: isDark ? 0.06 : 0.04),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: const Color(
                0xFFA855F7,
              ).withValues(alpha: isDark ? 0.04 : 0.02),
            ),
          ),
        ],
      ),
    );
  }
}
