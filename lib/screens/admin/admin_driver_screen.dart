import 'package:flutter/material.dart';
import 'package:tms/store/admin_dashboard_store.dart';
import 'package:tms/screens/admin/add_driver_page.dart'; // Import Add Driver Page
import 'package:tms/components/leave_card.dart';

class AdminDriverScreen extends StatefulWidget {
  const AdminDriverScreen({super.key});

  @override
  State<AdminDriverScreen> createState() => _AdminDriverScreenState();
}

class _AdminDriverScreenState extends State<AdminDriverScreen> {
  // Mock data for leaves copied from RequestListPage
  final List<Map<String, dynamic>> _leaves = [
    {
      'driver': 'John Doe',
      'days': '3',
      'from': 'Nov 01',
      'to': 'Nov 03',
      'status': 'Approved',
    },
    {
      'driver': 'Mike Ross',
      'days': '1',
      'from': 'Nov 05',
      'to': 'Nov 05',
      'status': 'Pending',
    },
  ];

  // Mock data for drivers
  final List<Map<String, dynamic>> _drivers = [
    {
      'name': 'John Doe',
      'phone': '+1 234 567 8900',
      'kilometers': '1245 km',
      'image':
          'https://ui-avatars.com/api/?name=John+Doe&background=6366F1&color=fff',
    },
    {
      'name': 'Mike Ross',
      'phone': '+1 987 654 3210',
      'kilometers': '890 km',
      'image':
          'https://ui-avatars.com/api/?name=Mike+Ross&background=10B981&color=fff',
    },
    {
      'name': 'Sarah Smith',
      'phone': '+1 555 123 4567',
      'kilometers': '2304 km',
      'image': null,
    },
    {
      'name': 'David Wilson',
      'phone': '+1 444 987 6543',
      'kilometers': '310 km',
      'image':
          'https://ui-avatars.com/api/?name=David+Wilson&background=EF4444&color=fff',
    },
  ];

  String _sortType = 'A to Z'; // Default sorting

  // Helper to parse 'kilometers' string to double for sorting
  double _parseKm(String kmString) {
    return double.tryParse(kmString.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
  }

  void _sortDrivers(String sortType) {
    setState(() {
      _sortType = sortType;
      if (sortType == 'A to Z') {
        _drivers.sort((a, b) => a['name'].compareTo(b['name']));
      } else if (sortType == 'Z to A') {
        _drivers.sort((a, b) => b['name'].compareTo(a['name']));
      } else if (sortType == 'Max Distance') {
        _drivers.sort(
          (a, b) =>
              _parseKm(b['kilometers']).compareTo(_parseKm(a['kilometers'])),
        );
      } else if (sortType == 'Min Distance') {
        _drivers.sort(
          (a, b) =>
              _parseKm(a['kilometers']).compareTo(_parseKm(b['kilometers'])),
        );
      }
    });
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
        _sortDrivers(title);
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

  @override
  void initState() {
    super.initState();
    useAdminDashboardStore.fetchStats();
    _sortDrivers(_sortType); // Apply default sorting on init
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
          onRefresh: () => useAdminDashboardStore.fetchStats(),
          color: primaryBlue,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildAnimatedHeader(titleColor, primaryBlue),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildStatsGrid(titleColor, surfaceColor, isDark),
                    const SizedBox(height: 24),
                    _buildSectionTitle("Leave Requests", titleColor),
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
                  valueListenable: useAdminDashboardStore.driversPresent,
                  builder: (_, present, __) => ValueListenableBuilder<int>(
                    valueListenable: useAdminDashboardStore.driversAbsent,
                    builder: (_, absent, ___) => Text(
                      "Managing ${present + absent} personnel",
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
            valueListenable: useAdminDashboardStore.driversPresent,
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
            valueListenable: useAdminDashboardStore.driversAbsent,
            builder: (_, absent, ___) => _buildStatCard(
              "Absent",
              absent.toString(),
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
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _leaves.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: LeaveCard(
          leaf: _leaves[index],
          isDark: isDark,
          primaryColor: primaryBlue,
        ),
      ),
    );
  }

  Widget _buildDriverList(bool isDark, Color surfaceColor) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _drivers.length,
      itemBuilder: (context, index) {
        final driver = _drivers[index];
        return Container(
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
                    Text(
                      driver['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      driver['phone'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
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
                        driver['kilometers'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
