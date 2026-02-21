import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tms/components/profile/info_card.dart';
import 'package:tms/screens/admin/request/add_vehicle_page.dart';
import 'package:tms/store/VehicleStore.dart';

class VehiclePage extends StatefulWidget {
  const VehiclePage({super.key});

  @override
  State<VehiclePage> createState() => _VehiclePageState();
}

class _VehiclePageState extends State<VehiclePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Safety check: ensure provider exists before fetching
        try {
          context.read<VehicleStore>().fetchVehicles();
        } catch (e) {
          debugPrint("Provider Error: VehicleStore not found in tree. $e");
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // This will now work correctly as long as main.dart has the Provider
    final store = context.watch<VehicleStore>();
    final bool isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDarkTheme
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final Color cardColor = isDarkTheme
        ? const Color(0xFF1E293B)
        : Colors.white;
    final Color titleColor = isDarkTheme
        ? Colors.white
        : const Color(0xFF1E293B);
    final Color subTitleColor = isDarkTheme
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundDecor(),
          RefreshIndicator(
            onRefresh: () => store.fetchVehicles(),
            color: const Color(0xFF6366F1),
            child: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHeader(context, titleColor),
                        const SizedBox(height: 25),
                        _buildSectionTitle("Quick Stats", titleColor),
                        const SizedBox(height: 16),
                        _buildStatusGrid(
                          store,
                          cardColor,
                          titleColor,
                          subTitleColor,
                        ),
                        const SizedBox(height: 32),
                        _buildSectionTitle("Vehicle Registry", titleColor),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSearchBar(
                                store,
                                cardColor,
                                subTitleColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildFilterDropdown(store, cardColor, titleColor),
                          ],
                        ),
                        const SizedBox(height: 24),
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
                        : _buildVehicleList(
                            store,
                            cardColor,
                            titleColor,
                            subTitleColor,
                          ),
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

  // --- UI Components ---

  Widget _buildSearchBar(VehicleStore store, Color cardColor, Color subColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
        ],
      ),
      child: TextField(
        onChanged: (val) => store.updateSearch(val),
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
        ),
        decoration: InputDecoration(
          hintText: "Search TN-03...",
          hintStyle: TextStyle(color: subColor.withOpacity(0.5)),
          prefixIcon: Icon(Icons.search_rounded, color: subColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    VehicleStore store,
    Color cardColor,
    Color titleColor,
  ) {
    final categories = ["All", "Van", "Sedan", "Electric Car", "Bus", "Truck"];
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: PopupMenuButton<String>(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          Icons.filter_list_rounded,
          color: store.selectedCategory == "All"
              ? const Color(0xFF6366F1)
              : Colors.orange,
        ),
        onSelected: store.updateCategory,
        itemBuilder: (ctx) => categories
            .map(
              (c) => PopupMenuItem(
                value: c,
                child: Text(
                  c,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildVehicleList(
    VehicleStore store,
    Color cardColor,
    Color titleColor,
    Color subColor,
  ) {
    final list = store.filteredVehicles;
    if (list.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(top: 40),
            child: Text(
              "No vehicles found",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        return _VehicleCard(
          vehicle: list[index],
          cardColor: cardColor,
          titleColor: titleColor,
          subColor: subColor,
        );
      }, childCount: list.length),
    );
  }

  Widget _buildStatusGrid(
    VehicleStore store,
    Color card,
    Color title,
    Color sub,
  ) {
    return Row(
      children: [
        Expanded(
          child: InfoCard(
            title: "Live",
            value: store.totalVehicles.toString(),
            icon: Icons.sensors,
            iconColor: Colors.blue,
            cardColor: card,
            titleColor: title,
            subColor: sub,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InfoCard(
            title: "Capacity",
            value: store.totalCapacity.toString(),
            icon: Icons.groups,
            iconColor: Colors.green,
            cardColor: card,
            titleColor: title,
            subColor: sub,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Color titleColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Fleet Monitor",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: titleColor,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddVehiclePage()),
          ),
          icon: const Icon(
            Icons.add_circle_rounded,
            color: Color(0xFF6366F1),
            size: 40,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color color) => Text(
    title,
    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
  );

  Widget _buildBackgroundDecor() => Positioned(
    top: -100,
    left: -50,
    child: CircleAvatar(
      radius: 125,
      backgroundColor: const Color(0xFF6366F1).withOpacity(0.05),
    ),
  );
}

class _VehicleCard extends StatelessWidget {
  final dynamic vehicle;
  final Color cardColor, titleColor, subColor;
  const _VehicleCard({
    required this.vehicle,
    required this.cardColor,
    required this.titleColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    final String type = vehicle['vehicle_type'] ?? "Truck";
    final String plate = vehicle['vehicle_number'] ?? "N/A";
    final String capacity = (vehicle['capacity'] ?? "0").toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getIcon(type), color: Colors.indigo),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plate,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "$type • $capacity Seats",
                  style: TextStyle(color: subColor, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  IconData _getIcon(String type) {
    type = type.toLowerCase();
    if (type.contains('bus')) return Icons.directions_bus;
    if (type.contains('car') || type.contains('sedan'))
      return Icons.directions_car;
    if (type.contains('van')) return Icons.airport_shuttle;
    return Icons.local_shipping;
  }
}
