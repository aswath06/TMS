import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tripzo/store/admin_dashboard_store.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/request_store.dart';
import 'package:tripzo/screens/admin/add_driver_page.dart'; // Import Add Driver Page
import 'package:tripzo/screens/admin/request/ViewAllLeavesPage.dart';
import 'package:tripzo/screens/admin/admin_driver_detail_screen.dart';
import 'package:tripzo/components/leave_card.dart';

class AdminDriverScreen extends StatefulWidget {
  const AdminDriverScreen({super.key});

  @override
  State<AdminDriverScreen> createState() => _AdminDriverScreenState();
}

class _AdminDriverScreenState extends State<AdminDriverScreen> {
  String _sortType = 'A to Z'; // Default sorting
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  // Driver search and filter variables
  final TextEditingController _driverSearchController = TextEditingController();
  String _driverFilter = 'All'; // All, Available, Assigned, On Trip, On Leave
  DateTime? _selectedDriverDate;

  // Helper to parse 'kilometers' string to double for sorting
  double _parseKm(String kmString) {
    return double.tryParse(kmString.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
  }

  void _sortLocalDrivers(List<Map<String, dynamic>> list, String sortType) {
    if (sortType == 'A to Z') {
      list.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    } else if (sortType == 'Z to A') {
      list.sort((a, b) => (b['name'] ?? '').compareTo(a['name'] ?? ''));
    } else if (sortType == 'Max Distance') {
      list.sort(
        (a, b) => _parseKm(
          b['kilometers']?.toString() ?? '0',
        ).compareTo(_parseKm(a['kilometers']?.toString() ?? '0')),
      );
    } else if (sortType == 'Min Distance') {
      list.sort(
        (a, b) => _parseKm(
          a['kilometers']?.toString() ?? '0',
        ).compareTo(_parseKm(b['kilometers']?.toString() ?? '0')),
      );
    }
  }

  void _showFilterModal(BuildContext context, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryBlue = const Color(0xFF6366F1);

    showModalBottomSheet(
      context: context,
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
                  const SizedBox(height: 24),
                ],
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
        Provider.of<DriverStore>(
          context,
          listen: false,
        ).setSortType(title); // Update store's sort type
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
                ? primaryBlue.withOpacity(0.5)
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDriverDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
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
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
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
      Provider.of<DriverStore>(
        context,
        listen: false,
      ).fetchDrivers(forceRefresh: true);
      Provider.of<RequestStore>(
        context,
        listen: false,
      ).fetchLeaves(page: 1, limit: 10);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        Provider.of<DriverStore>(context, listen: false).fetchNextPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
            await Provider.of<DriverStore>(
              context,
              listen: false,
            ).fetchDrivers(forceRefresh: true);
            await Provider.of<RequestStore>(
              context,
              listen: false,
            ).fetchLeaves(page: 1, limit: 10);
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
                    _buildStatsGrid(titleColor, surfaceColor, isDark),
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
                ValueListenableBuilder<int>(
                  valueListenable: AdminDashboardStore().driversPresent,
                  builder: (_, present, __) => ValueListenableBuilder<int>(
                    valueListenable: AdminDashboardStore().driversOnLeave,
                    builder: (_, onLeave, ___) => Text(
                      "Managing ${present + onLeave} personnel",
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            _buildAddButton(primaryBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(Color primaryBlue) {
    return Container(
      decoration: BoxDecoration(
        color: primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDriverPage()),
          );
        },
        icon: Icon(Icons.add_box, size: 28, color: primaryBlue),
      ),
    );
  }

  Widget _buildStatsGrid(Color titleColor, Color surfaceColor, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: AdminDashboardStore().driversPresent,
            builder: (_, present, __) => _buildStatCard(
              "Present Today",
              present.toString(),
              Icons.check_circle_rounded,
              const Color(0xFF10B981),
              surfaceColor,
              isDark,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: AdminDashboardStore().driversOnLeave,
            builder: (_, onLeave, ___) => _buildStatCard(
              "On Leave",
              onLeave.toString(),
              Icons.cancel_rounded,
              const Color(0xFFEF4444),
              surfaceColor,
              isDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    Color surfaceColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 20,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveSectionHeader(
    Color titleColor,
    Color primaryBlue,
    bool isDark,
  ) {
    return Consumer<RequestStore>(
      builder: (context, store, child) {
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
    return Consumer<RequestStore>(
      builder: (context, store, child) {
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          InkWell(
            onTap: () => _showFilterModal(context, isDark),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.tune, color: primaryBlue, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverSearchBar(bool isDark, Color surfaceColor) {
    final primaryBlue = const Color(0xFF6366F1);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _driverSearchController,
                    decoration: InputDecoration(
                      hintText: 'Search drivers by name or phone...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey.shade500,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedDriverDate != null)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${_selectedDriverDate!.day}/${_selectedDriverDate!.month}/${_selectedDriverDate!.year}",
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.calendar_today,
                              color: _selectedDriverDate != null
                                  ? primaryBlue
                                  : Colors.grey.shade500,
                              size: 20,
                            ),
                            onPressed: () => _selectDriverDate(context),
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showDriverFilterModal(context, isDark),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primaryBlue.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(Icons.tune, color: primaryBlue, size: 20),
                ),
              ),
            ],
          ),
          if (_driverFilter != 'All') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: primaryBlue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Filter: $_driverFilter",
                    style: TextStyle(
                      color: primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _driverFilter = 'All';
                      });
                    },
                    child: Icon(Icons.close, color: primaryBlue, size: 16),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDriverList(bool isDark, Color surfaceColor) {
    return Consumer<DriverStore>(
      builder: (context, store, child) {
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

        // Apply local sorting
        final sortedDrivers = List<Map<String, dynamic>>.from(store.drivers);
        _sortLocalDrivers(sortedDrivers, store.sortType);

        return Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: sortedDrivers.length,
              itemBuilder: (context, index) {
                final driver = sortedDrivers[index];
                return _buildDriverCard(driver, isDark, surfaceColor);
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
    final store = Provider.of<DriverStore>(context, listen: false);
    final status = driver['status'] ?? 1;
    final statusLabel = store.getStatusLabel(status);
    final statusColor = store.getStatusColor(status);

    final String kmDisplay = "${driver['total_kilometer_drive'] ?? 0} km";

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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: statusColor.withOpacity(0.2),
                          ),
                        ),
                        child: Icon(
                          store.getStatusIcon(status),
                          size: 16,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    driver['phone'] ?? 'No Phone',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  "Distance",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.speed, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      kmDisplay,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverAvatar(Map<String, dynamic> driver, bool isDark) {
    final String? imageUrl = driver['image'];
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
      backgroundColor: const Color(0xFF6366F1).withOpacity(0.15),
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
