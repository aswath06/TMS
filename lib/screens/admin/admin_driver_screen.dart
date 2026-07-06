import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';
import 'package:tripzo/store/admin_dashboard_store.dart';
import 'package:tripzo/store/driver_store.dart';
// Import Add Driver Page
import 'package:tripzo/screens/admin/request/view_all_leaves_page.dart';
import 'package:tripzo/screens/admin/admin_driver_detail_screen.dart';
import 'package:tripzo/components/leave_card.dart';
import 'package:tripzo/utils/api_constants.dart';

class AdminDriverScreen extends ConsumerStatefulWidget {
  const AdminDriverScreen({super.key});

  @override
  ConsumerState<AdminDriverScreen> createState() => _AdminDriverScreenState();
}

class _AdminDriverScreenState extends ConsumerState<AdminDriverScreen> {
  String _sortType = 'A to Z'; // Default sorting
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final String _searchText = '';

  // Driver search and filter variables
  final TextEditingController _driverSearchController = TextEditingController();
  String _driverFilter = 'All'; // All, Available, Assigned, On Trip, On Leave
  DateTime? _selectedDriverDate;
  final bool _isDriverSearchVisible = false; // Visibility state for search bar
  Timer? _searchDebounce;

  // Helper to parse 'kilometers' string to double for sorting
  double _parseKm(String kmString) {
    return double.tryParse(kmString.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
  }

  int _calculateExperience(Map<String, dynamic>? dp) {
    if (dp == null) return 0;
    final joiningDateStr = dp['joining_date']?.toString() ?? dp['created_at']?.toString();
    if (joiningDateStr != null && joiningDateStr.isNotEmpty) {
      try {
        final startDate = DateTime.parse(joiningDateStr);
        final now = DateTime.now();
        int experience = now.year - startDate.year;
        if (now.month < startDate.month || (now.month == startDate.month && now.day < startDate.day)) {
          experience--;
        }
        return experience < 0 ? 0 : experience;
      } catch (e) {
        return int.tryParse(dp['experience_years']?.toString() ?? '0') ?? 0;
      }
    }
    return int.tryParse(dp['experience_years']?.toString() ?? '0') ?? 0;
  }

  void _sortLocalDrivers(List<Map<String, dynamic>> list, String sortType) {
    if (sortType == 'A to Z') {
      list.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    } else if (sortType == 'Z to A') {
      list.sort((a, b) => (b['name'] ?? '').compareTo(a['name'] ?? ''));
    } else if (sortType == 'Max Distance') {
      list.sort(
        (a, b) => _parseKm(
          b['driverProfile']?['total_kilometer_drived']?.toString() ?? '0',
        ).compareTo(_parseKm(a['driverProfile']?['total_kilometer_drived']?.toString() ?? '0')),
      );
    } else if (sortType == 'Min Distance') {
      list.sort(
        (a, b) => _parseKm(
          a['driverProfile']?['total_kilometer_drived']?.toString() ?? '0',
        ).compareTo(_parseKm(b['driverProfile']?['total_kilometer_drived']?.toString() ?? '0')),
      );
    } else if (sortType == 'Max Experience') {
      list.sort(
        (a, b) => _calculateExperience(b['driverProfile']).compareTo(_calculateExperience(a['driverProfile'])),
      );
    } else if (sortType == 'Min Experience') {
      list.sort(
        (a, b) => _calculateExperience(a['driverProfile']).compareTo(_calculateExperience(b['driverProfile'])),
      );
    }
  }

  void _showFilterModal(BuildContext context, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryBlue = const Color(0xFF6366F1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow dynamic height
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Filter & Sort",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildRadioOption(
                      "A to Z",
                      setModalState,
                      primaryBlue,
                      surfaceColor,
                    ),
                    _buildRadioOption(
                      "Z to A",
                      setModalState,
                      primaryBlue,
                      surfaceColor,
                    ),
                    _buildRadioOption(
                      "Max Distance",
                      setModalState,
                      primaryBlue,
                      surfaceColor,
                    ),
                    _buildRadioOption(
                      "Min Distance",
                      setModalState,
                      primaryBlue,
                      surfaceColor,
                    ),
                    _buildRadioOption(
                      "Max Experience",
                      setModalState,
                      primaryBlue,
                      surfaceColor,
                    ),
                    _buildRadioOption(
                      "Min Experience",
                      setModalState,
                      primaryBlue,
                      surfaceColor,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRadioOption(
    String title,
    StateSetter setModalState,
    Color primaryBlue,
    Color surfaceColor,
  ) {
    final isSelected = _sortType == title;
    return GestureDetector(
      onTap: () {
        setModalState(() {
          _sortType = title;
        });
        ref.read(driverStoreProvider).setSortType(title); // Update store's sort type
        Navigator.pop(context); // Close after selection
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primaryBlue.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? primaryBlue
                    : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: primaryBlue, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDriverDate(BuildContext context) async {
    final DateTime? picked = await CustomDateTimePicker.show(
      context,
      initialDate: _selectedDriverDate ?? DateTime.now(),
      minDate: DateTime(2000),
      showTime: false,
    );
    if (picked != null && picked != _selectedDriverDate) {
      setState(() {
        _selectedDriverDate = picked;
      });
    }
  }

  void _showDriverFilterModal(BuildContext context, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryBlue = const Color(0xFF6366F1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow dynamic height
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Filter Drivers",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildDriverFilterChip(
                          "All",
                          Icons.group_outlined,
                          setModalState,
                          primaryBlue,
                          surfaceColor,
                        ),
                        _buildDriverFilterChip(
                          "Available",
                          useDriverStore.getStatusIcon(1),
                          setModalState,
                          primaryBlue,
                          surfaceColor,
                        ),
                        _buildDriverFilterChip(
                          "Assigned",
                          useDriverStore.getStatusIcon(2),
                          setModalState,
                          primaryBlue,
                          surfaceColor,
                        ),
                        _buildDriverFilterChip(
                          "On Trip",
                          useDriverStore.getStatusIcon(3),
                          setModalState,
                          primaryBlue,
                          surfaceColor,
                        ),
                        _buildDriverFilterChip(
                          "On Leave",
                          useDriverStore.getStatusIcon(4),
                          setModalState,
                          primaryBlue,
                          surfaceColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      "Today's Overview",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModalStat(
                            "Present Today",
                            AdminDashboardStore().driversPresent.value.toString(),
                            Icons.check_circle_rounded,
                            const Color(0xFF10B981),
                            surfaceColor,
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModalStat(
                            "On Leave",
                            AdminDashboardStore().driversOnLeave.value.toString(),
                            Icons.cancel_rounded,
                            const Color(0xFFEF4444),
                            surfaceColor,
                            isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalStat(
    String title,
    String value,
    IconData icon,
    Color color,
    Color surfaceColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverFilterChip(
    String title,
    IconData icon,
    StateSetter setModalState,
    Color primaryBlue,
    Color surfaceColor,
  ) {
    final isSelected = _driverFilter == title;
    return GestureDetector(
      onTap: () {
        setModalState(() {
          _driverFilter = title;
        });
        setState(() {});
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : surfaceColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? primaryBlue : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black54),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    AdminDashboardStore().fetchStats();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final driverStore = ref.read(driverStoreProvider);
      final requestStore = ref.read(requestStoreProvider);

      // Only fetch if data is missing or empty to avoid redundant loading on navigation
      if (driverStore.drivers.isEmpty) {
        driverStore.fetchDrivers();
      }

      if (requestStore.leaves.isEmpty) {
        requestStore.fetchLeaves(page: 1, limit: 10);
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(driverStoreProvider).fetchNextPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _driverSearchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-sort if the theme changes and affects how sorting might be perceived (though not strictly necessary for this logic)
    // Or if any other dependency change requires re-evaluation of the sorted list.
    // For now, just ensure initial sort is applied.
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await AdminDashboardStore().fetchStats();
            await ref.read(driverStoreProvider).fetchDrivers(forceRefresh: true);
            await ref.read(requestStoreProvider).fetchLeaves(page: 1, limit: 10);
          },
          color: primaryBlue,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildAnimatedHeader(titleColor, primaryBlue),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSummaryCard(isDark),
                    const SizedBox(height: 24),
                    _buildLeaveSectionHeader(titleColor, primaryBlue, isDark),
                    _buildLeaveList(isDark, primaryBlue),
                    const SizedBox(height: 24),
                    _buildDriverSectionHeader(
                      "Drivers",
                      titleColor,
                      primaryBlue,
                      isDark,
                    ),
                    _buildControls(isDark),
                    const SizedBox(height: 16),
                    _buildDriverList(isDark, surfaceColor),
                    const SizedBox(height: 120),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader(Color titleColor, Color primaryBlue) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 40.0, 24.0, 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Driver Manager",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Consumer(
                  builder: (context, ref, child) {
                    final store = ref.watch(driverStoreProvider);
                    return Text(
                      "Managing ${store.totalDrivers} personnel",
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    return Consumer(
      builder: (context, ref, child) {
        final store = ref.watch(driverStoreProvider);
        return ValueListenableBuilder<int>(
          valueListenable: AdminDashboardStore().driversPresent,
          builder: (_, present, _) => ValueListenableBuilder<int>(
            valueListenable: AdminDashboardStore().driversOnLeave,
            builder: (_, onLeave, _) {
              final int total = store.totalDrivers;
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [Colors.white, const Color(0xFFF8FAFC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            blurRadius: 25,
                            offset: const Offset(0, 12),
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Total Personnel",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "$total Drivers",
                            style: const TextStyle(
                              color: Color(0xFF6366F1),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        Icons.check_circle_rounded,
                        "Present Today",
                        present.toString(),
                        const Color(0xFF10B981),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                    Expanded(
                      child: _buildSummaryItem(
                        Icons.cancel_rounded,
                        "On Leave",
                        onLeave.toString(),
                        const Color(0xFFEF4444),
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
      },
    );
  }

  Widget _buildSummaryItem(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveSectionHeader(
    Color titleColor,
    Color primaryBlue,
    bool isDark,
  ) {
    return Consumer(
builder: (context, ref, child) {
final store = ref.watch(requestStoreProvider);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Leave Requests",
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ViewAllLeavesPage(leaves: store.leaves),
                    ),
                  );
                },
                child: Text(
                  "View All",
                  style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, Color titleColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildLeaveList(bool isDark, Color primaryBlue) {
    return Consumer(
builder: (context, ref, child) {
final store = ref.watch(requestStoreProvider);
        if (store.isLoadingLeaves && store.leaves.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (store.leaves.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                "No leave requests found.",
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          );
        }

        if (store.leavesErrorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                store.leavesErrorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        // Filter for pending leaves only
        final pendingLeaves = store.leaves
            .where((leave) => leave['status'] == 'Pending')
            .toList();

        if (pendingLeaves.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                "No pending leave requests.",
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          );
        }

        // Show only first 3 pending leaves
        final displayLeaves = pendingLeaves.take(3).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: displayLeaves.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: LeaveCard(
              leaf: displayLeaves[index],
              isDark: isDark,
              primaryColor: primaryBlue,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDriverSectionHeader(
    String title,
    Color titleColor,
    Color primaryBlue,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildControls(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : const Color(0xFF6366F1).withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _driverSearchController,
        onChanged: (val) {
          if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 500), () {
            ref.read(driverStoreProvider).setDriverSearchQuery(val);
            ref.read(driverStoreProvider).fetchDrivers(forceRefresh: true);
          });
        },
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: "Search drivers by name or phone...",
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[400],
          ),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
          suffixIcon: InkWell(
            onTap: () => _showFilterModal(context, isDark),
            child: const Icon(Icons.tune, color: Color(0xFF6366F1)),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildDriverList(bool isDark, Color surfaceColor) {
    return Consumer(
builder: (context, ref, child) {
final store = ref.watch(driverStoreProvider);
        if (store.isLoading && store.drivers.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (store.drivers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                "No drivers found.",
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          );
        }

        // No local searching, handled by backend
        final filteredDrivers = store.drivers;

        final sortedDrivers = List<Map<String, dynamic>>.from(filteredDrivers);
        if (store.sortType != 'Default') {
          _sortLocalDrivers(sortedDrivers, store.sortType);
        }

        return Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: sortedDrivers.length,
              itemBuilder: (context, index) {
                final driver = sortedDrivers[index];
                return FadeInWidget(
                  child: _buildDriverCard(driver, isDark, surfaceColor),
                );
              },
            ),
            if (store.isFetchingNextPage)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDriverCard(
    Map<String, dynamic> driver,
    bool isDark,
    Color surfaceColor,
  ) {
    final store = ref.read(driverStoreProvider);
    final status = driver['status'] ?? 'AVAILABLE';
    final statusLabel = store.getStatusLabel(status);
    final statusColor = store.getStatusColor(status);

    final dp = driver['driverProfile'] ?? driver;
    final String kmDisplay = "${dp['total_kilometer_drive'] ?? dp['total_kilometer_drived'] ?? 0} km";
    final String employeeCode = dp['employee_code'] ?? 'N/A';
    final int experience = _calculateExperience(dp);
    final int routes = int.tryParse(dp['total_routes']?.toString() ?? '0') ?? 0;
    final String bloodGroup = dp['blood_group'] ?? 'N/A';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdminDriverDetailScreen(driver: driver),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDriverAvatar(driver, isDark),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  driver['name'] ?? 'Unknown',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      store.getStatusIcon(status),
                                      size: 12,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      statusLabel,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                driver['phone'] ?? 'No Phone',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : const Color(0xFFF8FAFC),
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.03),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildQuickStat(
                      Icons.history,
                      "$experience Yrs",
                      "Exp",
                      isDark,
                    ),
                    _buildQuickStat(
                      Icons.speed,
                      kmDisplay,
                      "Distance",
                      isDark,
                    ),
                    _buildQuickStat(
                      Icons.route_outlined,
                      "$routes",
                      "Routes",
                      isDark,
                    ),
                    _buildQuickStat(
                      Icons.bloodtype_outlined,
                      bloodGroup,
                      "Blood",
                      isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(
    IconData icon,
    String value,
    String label,
    bool isDark,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: const Color(0xFF6366F1).withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverAvatar(Map<String, dynamic> driver, bool isDark) {
    String? imageUrl = driver['profile_photo'] ?? driver['image'];
    if (imageUrl != null && imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      imageUrl = '${ApiConstants.baseUrl}$imageUrl';
    }
    final String name = driver['name'] ?? '';

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: NetworkImage(imageUrl),
        backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
      );
    }

    // Calculate initials
    String initials = '';
    final List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isNotEmpty) {
      initials += parts.first.isNotEmpty ? parts.first[0] : '';
      if (parts.length > 1) {
        initials += parts.last.isNotEmpty ? parts.last[0] : '';
      }
    }

    return CircleAvatar(
      radius: 26,
      backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF6366F1),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
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
