import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/screens/admin/vechiles/admin_vehicle_form_screen.dart';
import 'package:tripzo/screens/faculty/missions/mission_details_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'package:open_filex/open_filex.dart';
import 'package:tripzo/utils/api_error_parser.dart';


class VehicleDetailScreen extends StatefulWidget {
  final dynamic vehicleId;

  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _vehicleData;
  String? _errorMessage;
  late AnimationController _contentController;

  // Active Tab: 'details' | 'maintenance' | 'fuel' | 'incident' | 'routes'
  String _activeTab = 'details';

  Map<String, dynamic> _asMap(dynamic item) {
    if (item == null) return {};
    if (item is Map<String, dynamic>) return item;
    if (item is Map) {
      return item.map((key, value) => MapEntry(key.toString(), value));
    }
    return {};
  }

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
      final String url = "${ApiConstants.vehicleDashboard}${widget.vehicleId}";
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _vehicleData = _asMap(data['data']);
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
          _errorMessage = ApiErrorParser.parse(response, fallback: "Error");
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

  int? _getDaysUntil(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      final date = DateTime.parse(dateStr);
      final diff = date.difference(DateTime.now()).inDays;
      return diff;
    } catch (_) {
      return null;
    }
  }

  String _getVehicleAge(String? regDateStr, String? createdAtStr) {
    final dateStr = (regDateStr != null && regDateStr.isNotEmpty) ? regDateStr : createdAtStr;
    if (dateStr == null || dateStr.isEmpty) return "N/A";
    try {
      final registered = DateTime.parse(dateStr);
      final now = DateTime.now();
      int years = now.year - registered.year;
      int months = now.month - registered.month;
      if (months < 0 || (months == 0 && now.day < registered.day)) {
        years--;
        months += 12;
      }
      if (now.day < registered.day && months > 0) {
        months--;
      }
      final finalYears = years < 0 ? 0 : years;
      final finalMonths = months < 0 ? 0 : months;
      return "$finalYears yr $finalMonths mo";
    } catch (_) {
      return "N/A";
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final veh = _asMap(_vehicleData?['vehicleData']);
    final defaultDriver = _asMap(_vehicleData?['defaultDriver']);
    final summary = _asMap(_vehicleData?['summary']);

    // Document Alerts
    final insuranceDays = _getDaysUntil(veh['insurance_expiry_date']);
    final pollutionDays = _getDaysUntil(veh['pollution_expiry_date']);
    final fcDays = _getDaysUntil(veh['fc_expiry_date']);
    final rcDays = _getDaysUntil(veh['rc_expiry_date']);

    final docAlerts = [
      if (insuranceDays != null && insuranceDays <= 10) {'label': 'Insurance', 'days': insuranceDays},
      if (pollutionDays != null && pollutionDays <= 10) {'label': 'Pollution (PUC)', 'days': pollutionDays},
      if (fcDays != null && fcDays <= 10) {'label': 'Fitness Certificate (FC)', 'days': fcDays},
      if (rcDays != null && rcDays <= 10) {'label': 'Registration Certificate (RC)', 'days': rcDays},
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: titleColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Vehicle Dashboard",
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryBlue),
            tooltip: 'Refresh',
            onPressed: _fetchVehicleDetails,
          ),
          if (_vehicleData != null) ...[
            IconButton(
              icon: Icon(Icons.qr_code_2_rounded, color: primaryBlue),
              tooltip: 'Vehicle QR Code',
              onPressed: () => _showQrDialog(context, isDark, primaryBlue),
            ),
            IconButton(
              icon: Icon(Icons.edit_rounded, color: primaryBlue),
              tooltip: 'Edit Vehicle',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminVehicleFormScreen(
                      vehicleData: veh,
                    ),
                  ),
                );
                if (result == true) {
                  _fetchVehicleDetails();
                }
              },
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? _buildShimmerLoading(isDark, bgColor)
          : _errorMessage != null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: _fetchVehicleDetails,
              color: primaryBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Document Expiry Alert Banners
                    if (docAlerts.isNotEmpty)
                      ...docAlerts.map((alert) => _buildDocAlertBanner(alert, isDark)),

                    // Vehicle Hero Card
                    _buildVehicleHeroCard(isDark, surfaceColor, primaryBlue, titleColor, subTextColor, veh),
                    const SizedBox(height: 16),

                    // Key Stat Cards Row
                    _buildTopStatsRow(isDark, surfaceColor, primaryBlue, summary, defaultDriver),
                    const SizedBox(height: 16),

                    // Sliding Sub-Tabs Bar
                    _buildSubTabsBar(isDark, surfaceColor, primaryBlue),
                    const SizedBox(height: 16),

                    // Active Tab Content
                    if (_activeTab == 'details')
                      _buildDetailsTabContent(isDark, surfaceColor, primaryBlue, titleColor, subTextColor, veh)
                    else if (_activeTab == 'maintenance')
                      _buildMaintenanceTabContent(isDark, surfaceColor, primaryBlue, titleColor, subTextColor)
                    else if (_activeTab == 'fuel')
                      _buildFuelTabContent(isDark, surfaceColor, primaryBlue, titleColor, subTextColor)
                    else if (_activeTab == 'incident')
                      _buildIncidentTabContent(isDark, surfaceColor, primaryBlue, titleColor, subTextColor)
                    else if (_activeTab == 'routes')
                      _buildRoutesTabContent(isDark, surfaceColor, primaryBlue, titleColor, subTextColor),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDocAlertBanner(Map<String, dynamic> alert, bool isDark) {
    final int days = alert['days'] as int;
    final String label = alert['label'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$label EXPIRING SOON",
                  style: const TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
                ),
                Text(
                  days <= 0 ? "Document Expired!" : "Expires in $days days",
                  style: const TextStyle(color: Color(0xFFBE123C), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleHeroCard(
    bool isDark,
    Color surfaceColor,
    Color primaryBlue,
    Color titleColor,
    Color subTextColor,
    Map<String, dynamic> veh,
  ) {
    final String status = (veh['status'] ?? 'ACTIVE').toString().toUpperCase();
    final bool isActive = status == 'ACTIVE' || status == '2';
    final Color statusColor = isActive ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final String vNumber = veh['vehicle_number'] ?? 'N/A';
    final String busNumber = veh['bus_number'] ?? '';
    final String vType = _asMap(veh['vehicleType'])['name'] ?? veh['vehicle_type'] ?? 'Vehicle';
    final String capacity = "${veh['capacity'] ?? 0} Seats";
    final String vehicleAge = _getVehicleAge(veh['registration_date'], veh['created_at']);

    final num currentOdo = veh['current_odometer'] ?? 0;
    final num lifetimeDist = veh['total_lifetime_distance'] ?? 0;
    final String? photoUrl = _getVehicleImageUrl(veh);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryBlue.withValues(alpha: 0.1),
                      border: Border.all(color: primaryBlue.withValues(alpha: 0.3), width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: photoUrl != null
                        ? Image.network(
                            ApiConstants.getImageUrl(photoUrl),
                            headers: const {'X-Tunnel-Skip-Anti-Phishing-Page': 'true'},
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(Icons.directions_bus, color: primaryBlue, size: 40),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset('assets/TripZo.png', fit: BoxFit.contain, errorBuilder: (_, error, stack) => Icon(Icons.directions_bus, color: primaryBlue, size: 36)),

                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: surfaceColor, shape: BoxShape.circle),
                    child: _AnimatedStatusDot(isActive: isActive),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      busNumber.isNotEmpty ? "$vNumber ($busNumber)" : vNumber,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            isActive ? "ACTIVE" : "IDLE",
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            vType.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryBlue),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            capacity,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subTextColor),
                          ),
                        ),
                        if (vehicleAge != "N/A")
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              vehicleAge,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subTextColor),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Odometer Readings Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      "PHYSICAL ODOMETER",
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: isDark ? Colors.white54 : const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${NumberFormat('#,##0').format(currentOdo)} KM",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: primaryBlue),
                    ),
                  ],
                ),
                Container(width: 1, height: 30, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                Column(
                  children: [
                    Text(
                      "LIFETIME DISTANCE",
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: isDark ? Colors.white54 : const Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${NumberFormat('#,##0').format(lifetimeDist)} KM",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Actions Buttons Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showResetOdometerDialog,
                  icon: const Icon(Icons.speed, size: 14, color: Color(0xFFE11D48)),
                  label: const Text("Reset Odometer", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE11D48))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: Color(0xFFFECDD3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showQrDialog(context, isDark, primaryBlue),
                  icon: const Icon(Icons.qr_code_2, size: 14, color: Colors.white),
                  label: const Text("Vehicle QR", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatsRow(
    bool isDark,
    Color surfaceColor,
    Color primaryBlue,
    Map<String, dynamic> summary,
    Map<String, dynamic> defaultDriver,
  ) {
    final driverObj = _asMap(defaultDriver['driver']);
    final driverName = driverObj['name'] ?? 'Unassigned';
    final driverPhone = driverObj['phone'] ?? 'N/A';

    final stats = [
      {'label': 'Fuel Logs Recorded', 'val': '${summary['fuel_history_count'] ?? 0}', 'unit': 'Logs', 'icon': Icons.history, 'color': const Color(0xFF3B82F6)},
      {'label': 'Total Fuel Volume', 'val': '${summary['total_fuel_volume'] ?? 0}', 'unit': 'Liters', 'icon': Icons.local_gas_station, 'color': const Color(0xFF10B981)},
      {'label': 'Total Fuel Spent', 'val': '₹${NumberFormat('#,##0').format(summary['total_fuel_amount'] ?? 0)}', 'unit': '', 'icon': Icons.payments_outlined, 'color': const Color(0xFFF59E0B)},
      {'label': 'Default Driver', 'val': driverName, 'unit': driverPhone, 'icon': Icons.person_outline, 'color': const Color(0xFF8B5CF6)},
    ];

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: stats.length,
        itemBuilder: (context, index) {
          final s = stats[index];
          final Color iconColor = s['color'] as Color;

          return Container(
            width: 155,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(s['icon'] as IconData, color: iconColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        s['label'] as String,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s['val'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((s['unit'] as String).isNotEmpty)
                        Text(
                          s['unit'] as String,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: primaryBlue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubTabsBar(bool isDark, Color surfaceColor, Color primaryBlue) {
    final List<Map<String, String>> tabs = [
      {'id': 'details', 'label': 'Details'},
      {'id': 'maintenance', 'label': 'Maintenance'},
      {'id': 'fuel', 'label': 'Fuel Log'},
      {'id': 'incident', 'label': 'Incidents'},
      {'id': 'routes', 'label': 'Routes (Trips)'},
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final t = tabs[index];
          final isSelected = _activeTab == t['id'];

          return GestureDetector(
            onTap: () => setState(() => _activeTab = t['id']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? primaryBlue : surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? primaryBlue : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Center(
                child: Text(
                  t['label']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- SUB TAB 1: DETAILS ---
  Widget _buildDetailsTabContent(
    bool isDark,
    Color surfaceColor,
    Color primaryBlue,
    Color titleColor,
    Color subTextColor,
    Map<String, dynamic> veh,
  ) {
    return Column(
      children: [
        // Vehicle Specifications
        _buildSectionCard(
          title: "Vehicle Specifications",
          icon: Icons.info_outline,
          color: const Color(0xFF3B82F6),
          isDark: isDark,
          surfaceColor: surfaceColor,
          items: [
            _InfoItem(Icons.branding_watermark, "Make", veh['make'] ?? 'N/A'),
            _InfoItem(Icons.directions_car, "Model", veh['model'] ?? 'N/A'),
            _InfoItem(Icons.local_gas_station, "Fuel Type", (veh['fuel_type'] ?? 'N/A').toString().toUpperCase()),
            _InfoItem(Icons.water_drop, "AdBlue Enabled", veh['is_adblue'] == true ? 'Enabled' : 'Disabled'),
            _InfoItem(Icons.business_center, "Ownership", (veh['ownership_type'] ?? 'N/A').toString().toUpperCase()),
            _InfoItem(Icons.airline_seat_recline_normal, "Seat Capacity", "${veh['capacity'] ?? 0} Seats"),
            _InfoItem(Icons.cake, "Vehicle Age", _getVehicleAge(veh['registration_date'], veh['created_at'])),
            _InfoItem(Icons.speed, "Lifetime Distance", "${veh['total_lifetime_distance'] ?? 0} KM"),
          ],
        ),
        const SizedBox(height: 16),

        // Engine & Chassis Parameters
        _buildSectionCard(
          title: "Engine & Chassis Parameters",
          icon: Icons.tune,
          color: const Color(0xFF10B981),
          isDark: isDark,
          surfaceColor: surfaceColor,
          items: [
            _InfoItem(Icons.calendar_month, "Registration Date", _formatDate(veh['registration_date'])),
            _InfoItem(Icons.settings_suggest, "Engine Number", veh['engine_number'] ?? 'N/A'),
            _InfoItem(Icons.qr_code, "Chassis Number", veh['chassis_number'] ?? 'N/A'),
            _InfoItem(Icons.water_drop, "Fuel Tank Capacity", veh['fuel_tank_capacity'] != null ? "${veh['fuel_tank_capacity']} L" : 'N/A'),
          ],
        ),
        const SizedBox(height: 16),

        // Compliance & Document Expiries
        _buildSectionCard(
          title: "Compliance & Expiry Dates",
          icon: Icons.verified_user_outlined,
          color: const Color(0xFFF59E0B),
          isDark: isDark,
          surfaceColor: surfaceColor,
          items: [
            _InfoItem(Icons.event, "Registration Date", _formatDate(veh['registration_date'])),
            _InfoItem(Icons.shield_outlined, "Fitness Certificate (FC)", _formatDate(veh['fc_expiry_date'])),
            _InfoItem(Icons.request_quote, "Tax Valid Upto", _formatDate(veh['tax_valid_upto'])),
            _InfoItem(Icons.verified_user, "Insurance Expiry", _formatDate(veh['insurance_expiry_date'])),
            _InfoItem(Icons.science, "Pollution / PUC", _formatDate(veh['pollution_expiry_date'])),
            _InfoItem(Icons.assignment_turned_in, "Permit Valid Upto", _formatDate(veh['permit_valid_upto'])),
          ],
        ),
      ],
    );
  }

  // --- SUB TAB 2: MAINTENANCE ---
  Widget _buildMaintenanceTabContent(
    bool isDark,
    Color surfaceColor,
    Color primaryBlue,
    Color titleColor,
    Color subTextColor,
  ) {
    final List serviceHistory = _vehicleData?['serviceHistory'] is List ? _vehicleData!['serviceHistory'] : [];

    return Column(
      children: [
        if (serviceHistory.isEmpty)
          _buildEmptyState("No Maintenance History Logs Found", Icons.build_outlined, isDark)
        else
          ...serviceHistory.map((rawM) {
            final m = _asMap(rawM);
            final title = m['service_title'] ?? 'Maintenance';
            final shop = m['shop_name'] ?? 'N/A';
            final cost = m['cost'] ?? 0;
            final desc = m['description'] ?? 'N/A';
            final date = _formatDate(m['maintenance_date']);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title.toString().toUpperCase(),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "₹$cost",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryBlue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.store, size: 14, color: subTextColor),
                      const SizedBox(width: 4),
                      Text(
                        "$shop • $date",
                        style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "\"$desc\"",
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: subTextColor),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // --- SUB TAB 3: FUEL LOG ---
  Widget _buildFuelTabContent(
    bool isDark,
    Color surfaceColor,
    Color primaryBlue,
    Color titleColor,
    Color subTextColor,
  ) {
    final List fuelHistory = _vehicleData?['fuelHistory'] is List ? _vehicleData!['fuelHistory'] : [];

    return Column(
      children: [
        if (fuelHistory.isEmpty)
          _buildEmptyState("No Fuel Logs Recorded", Icons.local_gas_station_outlined, isDark)
        else
          ...fuelHistory.map((rawF) {
            final f = _asMap(rawF);
            final volume = f['volume'] ?? 0;
            final billAmount = f['bill_amount'] ?? 0;
            final odo = f['current_odometer'] ?? 0;
            final bunkName = _asMap(f['bunk'])['name'] ?? 'Gas Station';
            final filledAt = _formatDate(f['filled_at']);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.local_gas_station, color: Color(0xFF059669), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Refuel Session ($volume L)",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor),
                            ),
                            Text(
                              "₹$billAmount",
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Odo: $odo KM • Bunk: $bunkName",
                          style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Filled Date: $filledAt",
                          style: TextStyle(fontSize: 10, color: subTextColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // --- SUB TAB 4: INCIDENTS ---
  Widget _buildIncidentTabContent(
    bool isDark,
    Color surfaceColor,
    Color primaryBlue,
    Color titleColor,
    Color subTextColor,
  ) {
    final List incidentHistory = _vehicleData?['incidentHistory'] is List ? _vehicleData!['incidentHistory'] : [];

    if (incidentHistory.isEmpty) {
      return _buildEmptyState("No Incident Logs Recorded", Icons.warning_amber_outlined, isDark);
    }

    return Column(
      children: incidentHistory.map((rawInc) {
        final inc = _asMap(rawInc);
        final date = _formatDate(inc['incident_date']);
        final desc = inc['description'] ?? 'No details provided';
        final status = inc['status'] ?? 'RECORDED';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "INCIDENT REPORT",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFE11D48), letterSpacing: 0.5),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toString(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text("Date: $date", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: titleColor)),
              const SizedBox(height: 4),
              Text("\"$desc\"", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: subTextColor)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- SUB TAB 5: ROUTES (TRIPS) ---
  Widget _buildRoutesTabContent(
    bool isDark,
    Color surfaceColor,
    Color primaryBlue,
    Color titleColor,
    Color subTextColor,
  ) {
    final List travelHistory = _vehicleData?['travelHistory'] is List ? _vehicleData!['travelHistory'] : [];

    if (travelHistory.isEmpty) {
      return _buildEmptyState("No Drive History / Trip Logs Found", Icons.map_outlined, isDark);
    }

    return Column(
      children: travelHistory.map((rawR) {
        final r = _asMap(rawR);
        final tripLeg = _asMap(r['tripLeg']);
        final tripInstance = _asMap(tripLeg['tripInstance']);
        final routeReq = _asMap(tripInstance['routeRequest']);
        final routeName = (r['route_name'] ?? routeReq['route_name'] ?? 'Route Run').toString();
        final status = (r['status'] ?? 'COMPLETED').toString();
        final isCompleted = status == 'COMPLETED';

        final startTime = _formatDate(r['assigned_from'] ?? tripLeg['planned_start_at']);
        final endTime = _formatDate(r['assigned_to'] ?? tripLeg['planned_end_at']);
        final reqId = (r['route_request_id'] ?? routeReq['id'] ?? r['id'] ?? '').toString();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MissionDetailsScreen(
                  missionTitle: routeName,
                  time: "$startTime - $endTime",
                  driverName: "Assigned Driver",
                  driverPhone: "N/A",
                  vehicleInfo: "Vehicle #${widget.vehicleId}",
                  capacity: "Passengers",
                  passengerCount: "0",
                  pathType: (routeReq['trip_type'] ?? "One-Way").toString(),
                  stops: const [
                    {'location': 'Origin', 'eta': 'Start'},
                    {'location': 'Destination', 'eta': 'End'},
                  ],
                  status: status,
                  statusColor: isCompleted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  requestId: reqId,
                  rawStatus: isCompleted ? 2 : 1,
                  creatorName: "Transport Admin",
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        routeName,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCompleted ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCompleted ? const Color(0xFF15803D) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: subTextColor, size: 18),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Start: $startTime", style: TextStyle(fontSize: 10, color: subTextColor)),
                    Text("End: $endTime", style: TextStyle(fontSize: 10, color: subTextColor)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- HELPERS ---

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color surfaceColor,
    required List<_InfoItem> items,
  }) {
    final validItems = items.where((i) => i.value != 'N/A' && i.value.isNotEmpty).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: (validItems.isEmpty ? items : validItems).map((item) {
              return _buildMiniField(item.label, item.value, isDark);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniField(String label, String value, bool isDark) {
    return Container(
      width: 155,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String? _getVehicleImageUrl(Map<String, dynamic> veh) {
    final keys = ['vehicle_profile_url', 'image', 'vehicle_image', 'photo', 'vehicle_photo', 'avatar', 'picture', 'file', 'image_url', 'logo', 'thumbnail', 'front_image', 'vehicle_front_image'];
    for (var key in keys) {
      if (veh[key] != null && veh[key].toString().isNotEmpty && veh[key].toString() != 'null') {
        return veh[key].toString();
      }
    }
    if (veh['vehicle_type'] is Map && veh['vehicle_type']['image'] != null) {
      return veh['vehicle_type']['image'].toString();
    }
    return null;
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr.toString());
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr.toString();
    }
  }

  Widget _buildShimmerLoading(bool isDark, Color bg) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
            const SizedBox(height: 16),
            Container(height: 90, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
            const SizedBox(height: 16),
            Container(height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? "Error loading vehicle data",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchVehicleDetails,
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetOdometerDialog() {
    final readingCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final Color bg = isDark ? const Color(0xFF1E293B) : Colors.white;
            final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final Color primaryBlue = const Color(0xFF6366F1);

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: bg,
              elevation: 10,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Reset Odometer",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Are you sure you want to force reset the base odometer? This action requires an admin password.",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: readingCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: "New Odometer Reading (KM)",
                        labelStyle: TextStyle(color: primaryBlue),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryBlue)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryBlue.withValues(alpha: 0.5))),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: true,
                      style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: "Admin Password",
                        labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isResetting ? null : () => Navigator.pop(ctx),
                          child: Text("Cancel", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isResetting ? null : () async {
                            final reading = readingCtrl.text.trim();
                            final pass = passwordCtrl.text.trim();
                            if (reading.isEmpty || pass.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields"), backgroundColor: Colors.orange));
                              return;
                            }

                            setStateModal(() => isResetting = true);
                            try {
                              final token = await UserStore.getToken();
                              final response = await http.patch(
                                Uri.parse(ApiConstants.resetOdometer(widget.vehicleId)),
                                headers: ApiConstants.getHeaders(token),
                                body: json.encode({
                                  "reading": num.tryParse(reading) ?? 0,
                                  "password": pass,
                                }),
                              );

                              if (response.statusCode == 200 || response.statusCode == 201) {
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Odometer reset successfully!"), backgroundColor: Colors.green));
                                  _fetchVehicleDetails();
                                }
                              } else {
                                final data = json.decode(response.body);
                                final err = data['message'] ?? "Failed to reset odometer";
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                              }
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                            } finally {
                              if (mounted) setStateModal(() => isResetting = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: isResetting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Force Reset", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showQrDialog(BuildContext context, bool isDark, Color primaryBlue) async {
    final GlobalKey qrKey = GlobalKey();
    final veh = _asMap(_vehicleData?['vehicleData']);
    final otpValue = veh['id'].toString();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Vehicle QR Code",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RepaintBoundary(
                  key: qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primaryBlue.withValues(alpha: 0.4), width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "${veh['vehicle_number'] ?? 'N/A'} - ${veh['bus_number'] ?? 'N/A'}",
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        QrImageView(
                          data: otpValue,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                          eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: primaryBlue),
                          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      RenderRepaintBoundary boundary = qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                      final pngBytes = byteData!.buffer.asUint8List();

                      final directory = await getApplicationDocumentsDirectory();
                      final file = io.File('${directory.path}/vehicle_qr_$otpValue.png');
                      await file.writeAsBytes(pngBytes);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("QR Code Saved!"), backgroundColor: Colors.green));
                      }
                      OpenFilex.open(file.path);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                      }
                    }
                  },
                  icon: const Icon(Icons.download, color: Colors.white, size: 16),
                  label: const Text("Download QR Code", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedStatusDot extends StatefulWidget {
  final bool isActive;
  const _AnimatedStatusDot({required this.isActive});

  @override
  State<_AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<_AnimatedStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
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
            color: widget.isActive ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            boxShadow: [
              BoxShadow(
                color: (widget.isActive ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.5),
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
