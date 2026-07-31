import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import '../../../store/istamil.dart';
import '../../../store/user_store.dart';
import '../../../utils/api_constants.dart';
import '../../admin/fuel/create_fuel_request_page.dart';
import 'driver_fuel_request_page.dart';

class FuelOptionsPage extends StatefulWidget {
  const FuelOptionsPage({Key? key}) : super(key: key);

  @override
  State<FuelOptionsPage> createState() => _FuelOptionsPageState();
}

class _FuelOptionsPageState extends State<FuelOptionsPage> {
  List<dynamic> _pendingLogs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPendingLogs();
  }

  Future<void> _fetchPendingLogs() async {
    try {
      final token = await UserStore.getToken();
      final driverId = await UserStore.getDriverId();
      
      final url = "${ApiConstants.fuelLog}?status=PENDING_ADMIN_APPROVAL&driver_id=$driverId";
      
      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));
      
      debugPrint("Fetch pending URL: $url");
      debugPrint("Fetch pending Status: ${response.statusCode}");
      debugPrint("Fetch pending Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _pendingLogs = data['data'] ?? [];
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching pending logs: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF8F9FA),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          LanguageStore.isTamil ? "எரிபொருள் விருப்பங்கள்" : "Fuel Options",
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Request Fuel Entry moved to Top
            _buildOptionCard(
              context: context,
              title: LanguageStore.isTamil ? "எரிபொருள் கோரிக்கை" : "Fuel Request",
              subtitle: LanguageStore.isTamil ? "எரிபொருள் கோர" : "Request Fuel Entry",
              icon: Icons.gas_meter_outlined,
              color: const Color(0xFF0EA5E9),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverFuelRequestPage()),
                );
                // Refresh list when coming back
                _fetchPendingLogs();
              },
            ),
            const SizedBox(height: 20),
            // Outside Bunk moved Below
            _buildOptionCard(
              context: context,
              title: LanguageStore.isTamil ? "வெளியே எரிபொருள்" : "Outside Bunk",
              subtitle: LanguageStore.isTamil ? "முழுமையான எரிபொருள் பதிவு" : "Complete Fuel Log",
              icon: Icons.local_gas_station_outlined,
              color: const Color(0xFF4F46E5),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateFuelRequestPage()),
                );
              },
            ),
            
            const SizedBox(height: 40),
            
            // Pending History Section
            Text(
              LanguageStore.isTamil ? "நிலுவையில் உள்ள கோரிக்கைகள்" : "Pending Requests",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            
            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ))
            else if (_pendingLogs.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.history_rounded, size: 48, color: Colors.grey.withOpacity(0.2)),
                      const SizedBox(height: 12),
                      Text(
                        LanguageStore.isTamil ? "நிலுவையில் எதுவும் இல்லை" : "No pending requests",
                        style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pendingLogs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final log = _pendingLogs[i];
                  return _buildPendingCard(log);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> log) {
    final vehicle = log['vehicle'];
    final vNum = vehicle != null ? (vehicle['vehicle_number'] ?? 'Unknown') : 'Unknown';
    final volume = log['filled_volume'] ?? log['required_volume'] ?? log['filled_volume_liters'] ?? log['required_volume_liters'] ?? '0';
    final dateStr = log['filled_at'];
    String formattedDate = "N/A";
    if (dateStr != null) {
      try {
        final d = DateTime.parse(dateStr).toLocal();
        formattedDate = DateFormat('MMM dd, yyyy h:mm a').format(d);
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_gas_station_rounded, color: Color(0xFF64748B), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vNum,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$volume L",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0EA5E9),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pending_actions_rounded, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                Text(
                  "DRIVER REQUEST PENDING",
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.orange.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: color.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFCBD5E1),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
