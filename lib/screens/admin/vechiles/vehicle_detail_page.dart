import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/screens/admin/vechiles/vehicle_service_entry_page.dart';
import 'package:tripzo/screens/admin/vechiles/vehicle_fuel_entry_page.dart';

class VehicleDetailScreen extends StatefulWidget {
  final dynamic vehicleId;

  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _vehicleData;
  String? _errorMessage;
  late AnimationController _contentController;

  @override
  void initState() {
    super.initState();
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fetchVehicleDetails();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _fetchVehicleDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String? token = await UserStore.getToken();
      final response = await http.get(
        Uri.parse("${ApiConstants.getVehicleById}${widget.vehicleId}"),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _vehicleData = data['data'];
            _isLoading = false;
          });
          _contentController.forward();
        } else {
          setState(() {
            _errorMessage = data['message'] ?? "Failed to fetch details";
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = "Error: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "An unexpected error occurred: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Vehicle Details",
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildShimmerLoading(isDark, bgColor)
          : _errorMessage != null
              ? _buildErrorState()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildVehicleHero(isDark, surfaceColor, primaryBlue),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle("Specifications", titleColor),
                            const SizedBox(height: 16),
                            _buildInfoGrid(
                              [
                                _InfoItem(Icons.airline_seat_recline_normal, "Capacity", "${_vehicleData!['capacity'] ?? 0} Seats"),
                                _InfoItem(Icons.speed, "Odometer", "${_vehicleData!['current_odometer'] ?? _vehicleData!['current_kilometer'] ?? 0} km"),
                                _InfoItem(Icons.local_gas_station_rounded, "Fuel Type", _vehicleData!['fuel_type'] ?? 'N/A'),
                                _InfoItem(Icons.business_center_rounded, "Ownership", _vehicleData!['ownership_type'] ?? 'N/A'),
                              ],
                              surfaceColor,
                              isDark,
                            ),
                              _buildSectionTitle("Registration & Compliance", titleColor),
                            const SizedBox(height: 16),
                            _buildInfoGrid(
                              [
                                _InfoItem(Icons.verified_user, "Insurance", _formatDate(_vehicleData!['insurance_expiry_date'])),
                                _InfoItem(Icons.science, "Pollution", _formatDate(_vehicleData!['pollution_expiry_date'])),
                                _InfoItem(Icons.description, "RC Date", _formatDate(_vehicleData!['rc_expiry_date'])),
                                _InfoItem(Icons.fact_check, "FC Date", _formatDate(_vehicleData!['fc_expiry_date'])),
                              ],
                              surfaceColor,
                              isDark,
                            ),
                            if (_vehicleData!['default_driver'] != null) ...[
                              const SizedBox(height: 32),
                              _buildSectionTitle("Default Driver", titleColor),
                              const SizedBox(height: 16),
                              _buildDefaultDriver(surfaceColor, isDark, primaryBlue),
                            ],
                            const SizedBox(height: 32),
                            _buildSectionTitle("Fuel Summary", titleColor),
                            const SizedBox(height: 16),
                            _buildFuelSummary(surfaceColor, isDark, primaryBlue),
                            const SizedBox(height: 32),
                            _buildActionButtons(primaryBlue, surfaceColor, isDark),
                            const SizedBox(height: 32),
                            _buildSectionTitle("Service Summary", titleColor),
                            const SizedBox(height: 16),
                            _buildStatsRow(primaryBlue, surfaceColor, isDark),
                            const SizedBox(height: 32),
                            _buildLogSections(surfaceColor, isDark, titleColor),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildVehicleHero(bool isDark, Color surfaceColor, Color primaryBlue) {
    final status = _vehicleData!['status'] ?? 2;
    final bool isActive = status == 2 || status.toString() == '2';
    final Color statusColor = isActive ? Colors.green : Colors.orange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: primaryBlue.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Hero(
            tag: 'vehicle_plate_${widget.vehicleId}',
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [primaryBlue, primaryBlue.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Icon(
                  _getVehicleIcon(_vehicleData!['vehicle_type'] ?? ''),
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _vehicleData!['vehicle_number'] ?? 'N/A',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (_vehicleData!['make'] != null || _vehicleData!['model'] != null)
                ? "${_vehicleData!['make'] ?? ''} ${_vehicleData!['model'] ?? ''}".trim()
                : (_vehicleData!['vehicle_type_name'] ?? _vehicleData!['vehicle_type'] ?? 'Vehicle').toString().toUpperCase(),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_vehicleData!['make'] != null || _vehicleData!['model'] != null)
            Text(
              (_vehicleData!['vehicle_type_name'] ?? _vehicleData!['vehicle_type'] ?? 'Vehicle').toString().toUpperCase(),
              style: TextStyle(
                color: Colors.grey.withOpacity(0.5),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AnimatedStatusDot(isActive: isActive),
                const SizedBox(width: 10),
                Text(
                  isActive ? "ACTIVE" : "IDLE",
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Color primary, Color surface, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _actionCard(
            "Service Entry",
            "Log Maintenance",
            Icons.home_repair_service_rounded,
            const Color(0xFF10B981),
            surface,
            () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VehicleServiceEntryPage(
                    vehicleId: _vehicleData!['id'],
                    vehicleNumber: _vehicleData!['vehicle_number'] ?? 'N/A',
                  ),
                ),
              );
              if (result == true) {
                _fetchVehicleDetails(); // Refresh data on success
              }
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _actionCard(
            "Fuel Entry",
            "Log Refill",
            Icons.local_gas_station_rounded,
            const Color(0xFF3B82F6),
            surface,
            () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VehicleFuelEntryPage(
                    vehicleId: _vehicleData!['id'],
                    vehicleNumber: _vehicleData!['vehicle_number'] ?? 'N/A',
                  ),
                ),
              );
              if (result == true) {
                _fetchVehicleDetails();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _actionCard(String title, String sub, IconData icon, Color color, Color surface, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
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

  Widget _buildInfoGrid(List<_InfoItem> items, Color surfaceColor, bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.1 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(item.icon, size: 14, color: const Color(0xFF6366F1)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.value,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(Color primaryBlue, Color surfaceColor, bool isDark) {
    final fuel = _vehicleData!['fuel_summary'] ?? {};
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "Fuel Refills",
            "${fuel['total_entries'] ?? 0}",
            Icons.local_gas_station,
            Colors.blue,
            surfaceColor,
            isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            "Total Volume",
            "${fuel['total_volume'] ?? 0} L",
            Icons.water_drop,
            Colors.cyan,
            surfaceColor,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, Color surfaceColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogSections(Color surface, bool isDark, Color titleColor) {
    return Column(
      children: [
        _buildExpandingSection("Maintenance History", Icons.build, _buildMaintenanceList(surface, isDark), titleColor),
        const SizedBox(height: 16),
        _buildExpandingSection("Fuel History", Icons.local_gas_station, _buildFuelList(surface, isDark), titleColor),
        const SizedBox(height: 16),
        _buildExpandingSection("Assigned Routes", Icons.route, _buildRoutesList(surface, isDark), titleColor),
      ],
    );
  }

  Widget _buildExpandingSection(String title, IconData icon, Widget content, Color titleColor) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide.none,
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide.none,
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.15),
                  const Color(0xFF8B5CF6).withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: titleColor,
              fontSize: 15,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isDark ? Colors.white54 : Colors.grey,
              size: 20,
            ),
          ),
          children: [
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
              indent: 16,
              endIndent: 16,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: content,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceList(Color surface, bool isDark) {
    final List<dynamic> history = _vehicleData!['maintenance_history'] ?? [];
    if (history.isEmpty) return const Center(child: Text("No maintenance records", style: TextStyle(color: Colors.grey)));
    return Column(
      children: history.map((m) => _buildLogCard(
        m['service_title'] ?? 'Maintenance',
        "₹${m['cost'] ?? 0}",
        _formatTimestamp(m['maintenance_date']),
        isDark,
        Icons.build_circle_rounded,
        const Color(0xFF6366F1),
      )).toList(),
    );
  }

  Widget _buildFuelList(Color surface, bool isDark) {
    final List<dynamic> history = _vehicleData!['fuel_history'] ?? [];
    if (history.isEmpty) return const Center(child: Text("No fuel records", style: TextStyle(color: Colors.grey)));
    return Column(
      children: history.map((f) => _buildLogCard(
        f['bunk_name'] ?? 'Fuel Refill',
        "₹${f['total_cost'] ?? 0}",
        _formatTimestamp(f['date']),
        isDark,
        Icons.local_gas_station_rounded,
        const Color(0xFF3B82F6),
      )).toList(),
    );
  }

  Widget _buildRoutesList(Color surface, bool isDark) {
    final List<dynamic> routes = _vehicleData!['assigned_routes'] ?? [];
    if (routes.isEmpty) return const Center(child: Text("No assigned routes", style: TextStyle(color: Colors.grey)));
    return Column(
      children: routes.map((r) => _buildLogCard(
        r['route_name'] ?? 'Assigned Route',
        r['driver_name'] ?? 'Assigned',
        _formatTimestamp(r['start_time']),
        isDark,
        Icons.route_rounded,
        const Color(0xFFF59E0B),
      )).toList(),
    );
  }

  Widget _buildLogCard(String title, String value, String time, bool isDark, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        boxShadow: isDark ? [] : [
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
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: color,
              fontSize: 16,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark, Color bg) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white10 : Colors.grey[300]!,
      highlightColor: isDark ? Colors.white24 : Colors.grey[100]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32))),
            const SizedBox(height: 24),
            Container(height: 150, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
            const SizedBox(height: 24),
            Container(height: 150, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 80, color: Colors.redAccent),
            const SizedBox(height: 24),
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _fetchVehicleDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text("RETRY CONNECTION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultDriver(Color surfaceColor, bool isDark, Color primaryBlue) {
    final def = _vehicleData!['default_driver'];
    final driver = def['driver'] ?? {};
    final t = isDark ? Colors.white : const Color(0xFF1E293B);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryBlue.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: primaryBlue.withOpacity(0.1),
            child: Icon(Icons.person_rounded, color: primaryBlue, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver['name'] ?? 'Unknown Driver',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: t),
                ),
                Text(
                  "Emp Code: ${driver['employee_code'] ?? 'N/A'}",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone_rounded, size: 14, color: primaryBlue),
                    const SizedBox(width: 6),
                    Text(driver['phone'] ?? 'No contact', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.withOpacity(0.7))),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text("PRIMARY", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.green)),
              ),
              const SizedBox(height: 8),
              Text(
                "ID: ${driver['id'] ?? ''}",
                style: TextStyle(fontSize: 10, color: Colors.grey.withOpacity(0.5), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFuelSummary(Color surfaceColor, bool isDark, Color primaryBlue) {
    final fuel = _vehicleData!['fuel_summary'] ?? {};
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "Total Amount",
            "₹${fuel['total_amount'] ?? 0}",
            Icons.payments_rounded,
            Colors.green,
            surfaceColor,
            isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            "Estimated Mileage",
            "${fuel['estimated_mileage'] ?? 'N/A'} km/L",
            Icons.auto_graph_rounded,
            Colors.purple,
            surfaceColor,
            isDark,
          ),
        ),
      ],
    );
  }

  IconData _getVehicleIcon(String type) {
    type = type.toLowerCase();
    if (type.contains('bus')) return Icons.directions_bus_rounded;
    if (type.contains('car')) return Icons.directions_car_rounded;
    if (type.contains('van')) return Icons.airport_shuttle_rounded;
    return Icons.local_shipping_rounded;
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr.toString());
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr.toString();
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return "TBD";
    try {
      final dt = DateTime.parse(timestamp);
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      return timestamp;
    }
  }
}

class _AnimatedStatusDot extends StatefulWidget {
  final bool isActive;
  const _AnimatedStatusDot({required this.isActive});

  @override
  State<_AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<_AnimatedStatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isActive ? Colors.green : Colors.orange,
            boxShadow: [
              BoxShadow(
                color: (widget.isActive ? Colors.green : Colors.orange).withOpacity(0.5),
                blurRadius: 4 + (_controller.value * 4),
                spreadRadius: _controller.value * 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  _InfoItem(this.icon, this.label, this.value);
}
