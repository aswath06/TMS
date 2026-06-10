import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/store/fleet_monitor_store.dart';
import 'package:tripzo/components/fleet/vehicle_card.dart';
import 'package:tripzo/screens/admin/vechiles/vehicle_detail_page.dart';

class VehiclePage extends ConsumerStatefulWidget {
  const VehiclePage({super.key});

  @override
  ConsumerState<VehiclePage> createState() => _VehiclePageState();
}

class _VehiclePageState extends ConsumerState<VehiclePage> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Inside', 'Outside'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fleetMonitorStoreProvider).fetchFleetData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> _getFilteredList(FleetMonitorStore store) {
    List<dynamic> combined = [];
    if (_selectedFilter == 'All') {
      combined = [...store.insideVehicles, ...store.outsideVehicles];
    } else if (_selectedFilter == 'Inside') {
      combined = [...store.insideVehicles];
    } else {
      combined = [...store.outsideVehicles];
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      combined = combined.where((v) {
        final plate = (v['vehicle_number'] ?? '').toString().toLowerCase();
        final type = (v['make'] ?? '').toString().toLowerCase();
        final model = (v['model'] ?? '').toString().toLowerCase();
        return plate.contains(q) || type.contains(q) || model.contains(q);
      }).toList();
    }
    return combined;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subColor = isDark ? Colors.white70 : Colors.black54;
    final Color scaffoldBg = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);

    final store = ref.watch(fleetMonitorStoreProvider);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.read(fleetMonitorStoreProvider).fetchFleetData(forceRefresh: true),
          color: const Color(0xFF6366F1),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildAnimatedHeader(),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSummaryCard(isDark, store),
                    const SizedBox(height: 24),
                    _buildControls(isDark),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
              _buildVehicleListSection(isDark, titleColor, subColor, store),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 40.0, 24.0, 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Fleet Monitor",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6366F1),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Real-time campus tracking",
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark, FleetMonitorStore store) {
    if (store.isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    final int total = store.insideCount + store.outsideCount;

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
          color: const Color(0xFF6366F1).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
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
                "Total Fleet",
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
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$total Vehicles",
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
                  Icons.business,
                  "Inside Campus",
                  store.insideCount.toString(),
                  Colors.green,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey.withOpacity(0.2),
              ),
              Expanded(
                child: _buildSummaryItem(
                  Icons.directions_car,
                  "Outside Campus",
                  store.outsideCount.toString(),
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
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

  Widget _buildControls(bool isDark) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.2)
                    : const Color(0xFF6366F1).withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: "Search plate or type...",
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF6366F1)),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              _buildFilterPill('All', 'All', isDark),
              _buildFilterPill('Inside', 'Inside', isDark),
              _buildFilterPill('Outside', 'Outside', isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(String title, String filter, bool isDark) {
    final bool isSelected = _selectedFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = filter;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleListSection(
    bool isDark,
    Color titleColor,
    Color subColor,
    FleetMonitorStore store,
  ) {
    if (store.isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    if (store.error.isNotEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text(store.error, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    final list = _getFilteredList(store);
    if (list.isEmpty) {
      return const SliverFillRemaining(
        child: Center(child: Text("No units found")),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => FadeInWidget(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          VehicleDetailScreen(vehicleId: list[index]['id']),
                    ),
                  );
                },
                child: VehicleCard(
                  vehicle: list[index],
                  cardColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  titleColor: titleColor,
                  subColor: subColor,
                ),
              ),
            ),
          ),
          childCount: list.length,
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
