import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tms/store/VehicleStore.dart';
import 'package:tms/screens/admin/vechiles/add_vehicle_page.dart';
import 'package:tms/components/fleet/vehicle_card.dart';
import 'package:tms/components/fleet/stat_card.dart';

class VehiclePage extends StatefulWidget {
  const VehiclePage({super.key});

  @override
  State<VehiclePage> createState() => _VehiclePageState();
}

class _VehiclePageState extends State<VehiclePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  final TextEditingController _sheetSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleStore>().fetchVehicles().then(
        (_) => _fadeController.forward(),
      );
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _sheetSearchController.dispose();
    super.dispose();
  }

  void _showFilterBottomSheet(VehicleStore store) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

          final categories = store.categories
              .where(
                (c) => c.toLowerCase().contains(
                  _sheetSearchController.text.toLowerCase(),
                ),
              )
              .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.55,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 16, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Filter Fleet",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
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
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: TextField(
                    controller: _sheetSearchController,
                    onChanged: (val) => setModalState(() {}),
                    decoration: InputDecoration(
                      hintText: "Search type...",
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = store.selectedCategories.contains(cat);

                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(cat, style: const TextStyle(fontSize: 15)),
                        activeColor: const Color(0xFF6366F1),
                        dense: true,
                        onChanged: (bool? value) {
                          store.toggleCategory(cat);
                          setModalState(() {});
                        },
                        controlAffinity: ListTileControlAffinity.trailing,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Apply Selection",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<VehicleStore>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          _buildBackgroundDecor(),
          RefreshIndicator(
            onRefresh: () async =>
                await store.fetchVehicles(forceRefresh: true),
            edgeOffset: 100,
            child: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildAnimatedHeader(titleColor, isDark),
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
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: store.isLoading
                        ? const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          )
                        : _buildAnimatedVehicleList(store, isDark),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedHeader(Color titleColor, bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Fleet Monitor",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  "Managing ${context.read<VehicleStore>().totalVehicles} units",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            // Moved Add Button here
            Material(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () =>
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddVehiclePage(),
                      ),
                    ).then(
                      (_) => context.read<VehicleStore>().fetchVehicles(
                        forceRefresh: true,
                      ),
                    ),
                child: const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusGrid(VehicleStore store, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return Row(
      children: [
        Expanded(
          child: FleetStatCard(
            title: "Total",
            value: store.totalVehicles.toString(),
            icon: Icons.apps,
            color: Colors.blue,
            cardColor: cardColor,
            titleColor: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FleetStatCard(
            title: "Active",
            value: store.activeTrucks.toString(),
            icon: Icons.local_shipping,
            color: Colors.orange,
            cardColor: cardColor,
            titleColor: isDark ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildRegistryControls(VehicleStore store, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              onChanged: store.updateSearch,
              decoration: const InputDecoration(
                hintText: "Search plate...",
                prefixIcon: Icon(Icons.search, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: () => _showFilterBottomSheet(store),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.3),
              ),
            ),
            child: const Icon(Icons.tune, color: Color(0xFF6366F1)),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedVehicleList(VehicleStore store, bool isDark) {
    final list = store.filteredVehicles;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);

    if (list.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            "No units found matching selection",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        return VehicleCard(
          vehicle: list[index],
          cardColor: cardColor,
          titleColor: titleColor,
          subColor: Colors.grey,
        );
      }, childCount: list.length),
    );
  }

  Widget _buildBackgroundDecor() => Positioned(
    top: -50,
    right: -50,
    child: CircleAvatar(
      radius: 100,
      backgroundColor: const Color(0xFF6366F1).withOpacity(0.05),
    ),
  );
}
