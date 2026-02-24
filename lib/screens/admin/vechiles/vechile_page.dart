import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tms/screens/admin/vechiles/add_vehicle_page.dart';
import 'package:tms/store/VehicleStore.dart';
import 'package:tms/components/fleet/vehicle_card.dart';
import 'package:tms/components/fleet/stat_card.dart';

class VehiclePage extends StatefulWidget {
  const VehiclePage({super.key});

  @override
  State<VehiclePage> createState() => _VehiclePageState();
}

class _VehiclePageState extends State<VehiclePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _sheetSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleStore>().fetchVehicles(forceRefresh: true);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;

      if (maxScroll > 0 && currentScroll >= maxScroll - 200) {
        context.read<VehicleStore>().fetchNextPage();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _sheetSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<VehicleStore>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subColor = isDark ? Colors.white70 : Colors.black54;
    final Color scaffoldBg = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: scaffoldBg,
      // Wrap in SafeArea to ensure content doesn't go under the notch/status bar
      body: SafeArea(
        bottom:
            false, // Keep false if you have a custom bottom nav or FAB padding
        child: RefreshIndicator(
          onRefresh: () => store.fetchVehicles(forceRefresh: true),
          color: const Color(0xFF6366F1),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildAnimatedHeader(titleColor, store),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildStatusGrid(store, isDark),
                    const SizedBox(height: 24),
                    _buildRegistryControls(store, isDark),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
              _buildVehicleListSection(store, isDark, titleColor, subColor),
              _buildPaginationLoader(store),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader(Color titleColor, VehicleStore store) {
    return SliverToBoxAdapter(
      child: Padding(
        // Added extra top padding (40.0) to give the title breathing room
        padding: const EdgeInsets.fromLTRB(24.0, 40.0, 24.0, 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
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
                  "Managing ${store.totalVehicles} units",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            _buildAddButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleListSection(
    VehicleStore store,
    bool isDark,
    Color titleColor,
    Color subColor,
  ) {
    if (store.isLoading && store.filteredVehicles.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    final list = store.filteredVehicles;
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
            child: VehicleCard(
              vehicle: list[index],
              cardColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              titleColor: titleColor,
              subColor: subColor,
            ),
          ),
          childCount: list.length,
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: () {
          // Navigate to the AddVehiclePage
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddVehiclePage()),
          );
        },
        icon: const Icon(Icons.add_box, size: 28, color: Color(0xFF6366F1)),
      ),
    );
  }

  Widget _buildStatusGrid(VehicleStore store, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Row(
      children: [
        Expanded(
          child: FleetStatCard(
            title: "Total Units",
            value: store.totalVehicles.toString(),
            icon: Icons.apps,
            color: Colors.blue,
            cardColor: cardColor,
            titleColor: textColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FleetStatCard(
            title: "Live Active",
            value: store.activeTrucks.toString(),
            icon: Icons.local_shipping,
            color: Colors.orange,
            cardColor: cardColor,
            titleColor: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildRegistryControls(VehicleStore store, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: store.updateSearch,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: "Search plate or type...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildFilterToggle(store),
      ],
    );
  }

  Widget _buildFilterToggle(VehicleStore store) {
    return InkWell(
      onTap: () => _showFilterBottomSheet(store),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.tune, color: Color(0xFF6366F1)),
      ),
    );
  }

  Widget _buildPaginationLoader(VehicleStore store) {
    return SliverToBoxAdapter(
      child: store.isFetchingNextPage
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : const SizedBox.shrink(),
    );
  }

  void _showFilterBottomSheet(VehicleStore store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the height to be dynamic
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final categories = store.categories
              .where(
                (c) => c.toLowerCase().contains(
                  _sheetSearchController.text.toLowerCase(),
                ),
              )
              .toList();

          return Container(
            // 1. Set a smaller maximum height (e.g., 45% of screen instead of 60%)
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize
                  .min, // 2. Important: Tells column to take minimum space
              children: [
                const SizedBox(height: 12),
                _buildHandleBar(),
                _buildFilterHeader(store, setModalState),
                const Divider(height: 1), // Optional: Visual separator
                // 3. This Expanded widget makes the ListView scrollable within the remaining space
                Expanded(
                  child: _buildCategoryList(categories, store, setModalState),
                ),

                const SizedBox(height: 12),
                _buildApplyButton(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // Separate helper for the little grab bar at the top
  Widget _buildHandleBar() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildCategoryList(
    List<String> categories,
    VehicleStore store,
    StateSetter setModalState,
  ) {
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = store.selectedCategories.contains(cat);
        return CheckboxListTile(
          value: isSelected,
          title: Text(cat),
          activeColor: const Color(0xFF6366F1),
          onChanged: (val) {
            store.toggleCategory(cat);
            setModalState(() {});
          },
        );
      },
    );
  }

  Widget _buildFilterHeader(VehicleStore store, StateSetter setModalState) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Filter Fleet",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: () {
              store.toggleCategory("All");
              setModalState(() {});
            },
            child: const Text(
              "Reset",
              style: TextStyle(color: Color(0xFF6366F1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        onPressed: () => Navigator.pop(context),
        child: const Text("Apply Selection"),
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
