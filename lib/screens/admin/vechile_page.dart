import 'package:flutter/material.dart';
import 'package:tms/components/profile/info_card.dart';
import 'package:tms/screens/admin/add_vehicle_page.dart';

class VehiclePage extends StatelessWidget {
  const VehiclePage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        onPressed: () => _navigateToAddVehicle(context),
        label: const Text(
          "Add Vehicle",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, titleColor),
                    const SizedBox(height: 30),
                    _buildSectionTitle("Operational Status (47)", titleColor),
                    const SizedBox(height: 16),
                    _buildStatusGrid(cardColor, titleColor, subTitleColor),
                    const SizedBox(height: 32),
                    _buildSectionTitle("Vehicle Registry", titleColor),
                    const SizedBox(height: 16),
                    _buildVehicleList(cardColor, titleColor, subTitleColor),
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAddVehicle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddVehiclePage()),
    );
  }

  Widget _buildHeader(BuildContext context, Color titleColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Vehicle Monitor",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        IconButton(
          onPressed: () => _navigateToAddVehicle(context),
          icon: Icon(
            Icons.add_circle_outline_rounded,
            color: titleColor.withOpacity(0.6),
            size: 26,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusGrid(Color cardColor, Color titleColor, Color subColor) {
    final List<Map<String, dynamic>> stats = [
      {
        't': 'Active',
        'v': '24',
        'i': Icons.check_circle_rounded,
        'c': Colors.green,
      },
      {'t': 'Moving', 'v': '12', 'i': Icons.bolt_rounded, 'c': Colors.blue},
      {
        't': 'Standby',
        'v': '08',
        'i': Icons.access_time_rounded,
        'c': Colors.amber.shade700,
      },
      {
        't': 'Inactive',
        'v': '03',
        'i': Icons.dangerous_rounded,
        'c': Colors.red,
      },
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: stats.length,
      itemBuilder: (context, i) => InfoCard(
        title: stats[i]['t'],
        value: stats[i]['v'],
        icon: stats[i]['i'],
        iconColor: stats[i]['c'],
        cardColor: cardColor,
        titleColor: titleColor,
        subColor: subColor,
      ),
    );
  }

  Widget _buildVehicleList(Color cardColor, Color titleColor, Color subColor) {
    final List<Map<String, dynamic>> vehicles = [
      {
        'no': 'TS-09-EA-1234',
        'status': 'Moving',
        'type': 'Bus',
        'km': '12,450',
      },
      {
        'no': 'TS-09-FB-5678',
        'status': 'Active',
        'type': 'Staff Car',
        'km': '8,210',
      },
    ];
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: vehicles.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final v = vehicles[index];
        final Color statusColor = _getStatusColor(v['status']);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.directions_bus_filled_rounded,
                  color: statusColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v['no'],
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      "${v['type']} • ${v['km']} km",
                      style: TextStyle(fontSize: 13, color: subColor),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(v['status'], statusColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Moving':
        return Colors.blue;
      case 'Active':
        return Colors.green;
      case 'Inactive':
        return Colors.red;
      case 'Standby':
        return Colors.amber.shade700;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
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
              ).withOpacity(isDark ? 0.06 : 0.04),
            ),
          ),
        ],
      ),
    );
  }
}
