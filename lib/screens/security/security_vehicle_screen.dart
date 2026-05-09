import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tripzo/store/VehicleStore.dart';
import 'package:tripzo/components/fleet/vehicle_card.dart';
import 'package:tripzo/screens/admin/vechiles/vehicle_detail_page.dart';

class SecurityVehicleScreen extends StatefulWidget {
  const SecurityVehicleScreen({super.key});

  @override
  State<SecurityVehicleScreen> createState() => _SecurityVehicleScreenState();
}

class _SecurityVehicleScreenState extends State<SecurityVehicleScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

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
    _searchController.dispose();
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
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => store.fetchVehicles(forceRefresh: true),
          color: const Color(0xFF6366F1),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildHeader(),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: _buildSearchBar(store, isDark),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              _buildVehicleListSection(store, isDark, titleColor, subColor),
              _buildPaginationLoader(store),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Vehicle Monitor",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6366F1),
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Search vehicles by registration number",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(VehicleStore store, bool isDark) {
    return TextField(
      controller: _searchController,
      onChanged: store.updateSearch,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        hintText: "Enter Vehicle Number...",
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
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
        child: Center(child: Text("No vehicles found")),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: TweenAnimationBuilder(
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
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VehicleDetailScreen(
                          vehicleId: list[index]['id'],
                        ),
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
          ),
          childCount: list.length,
        ),
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
}
