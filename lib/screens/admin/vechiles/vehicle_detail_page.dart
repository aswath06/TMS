import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/screens/admin/vechiles/admin_vehicle_form_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'package:open_filex/open_filex.dart';

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

      // --- DEBUG LOGGING ---
      String curl = "curl --location '$url' \\\n";
      ApiConstants.getHeaders(token).forEach((key, value) {
        curl += "--header '$key: $value' \\\n";
      });
      debugPrint("================= API DEBUG =================");
      debugPrint("CURL:\n$curl");
      debugPrint("RESPONSE STATUS: ${response.statusCode}");
      debugPrint("RESPONSE BODY: ${response.body}");
      debugPrint("===========================================");
      // ---------------------

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
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
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
        actions: [

          if (_vehicleData != null)
            IconButton(
              icon: Icon(Icons.edit_rounded, color: primaryBlue),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminVehicleFormScreen(
                      vehicleData: _vehicleData!['vehicleData'],
                    ),
                  ),
                );
                if (result == true) {
                  _fetchVehicleDetails();
                }
              },
            ),
          const SizedBox(width: 8),
        ],
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
                            _InfoItem(
                              Icons.airline_seat_recline_normal,
                              "Capacity",
                              "${_vehicleData!['vehicleData']['capacity'] ?? 0} Seats",
                            ),
                            _InfoItem(
                              Icons.speed,
                              "Odometer",
                              "${_vehicleData!['vehicleData']['current_odometer'] ?? 0} km",
                            ),
                            _InfoItem(
                              Icons.local_gas_station_rounded,
                              "Fuel Type",
                              _vehicleData!['vehicleData']['fuel_type'] ??
                                  'N/A',
                            ),
                            _InfoItem(
                              Icons.business_center_rounded,
                              "Ownership",
                              _vehicleData!['vehicleData']['ownership_type'] ??
                                  'N/A',
                            ),
                          ],
                          surfaceColor,
                          isDark,
                        ),
                        const SizedBox(height: 16),
                        _buildSectionTitle("Technical Details", titleColor),
                        const SizedBox(height: 16),
                        _buildInfoGrid(
                          [
                            _InfoItem(
                              Icons.settings_suggest,
                              "Engine No.",
                              _vehicleData!['vehicleData']['engine_number'] ?? 'N/A',
                            ),
                            _InfoItem(
                              Icons.qr_code,
                              "Chassis No.",
                              _vehicleData!['vehicleData']['chassis_number'] ?? 'N/A',
                            ),
                            _InfoItem(
                              Icons.water_drop,
                              "Tank Cap.",
                              _vehicleData!['vehicleData']['fuel_tank_capacity'] != null
                                  ? "${_vehicleData!['vehicleData']['fuel_tank_capacity']} L"
                                  : 'N/A',
                            ),
                            _InfoItem(
                              Icons.cake,
                              "Vehicle Age",
                              _vehicleData!['vehicleData']['vehicle_age'] ?? 'N/A',
                            ),
                          ],
                          surfaceColor,
                          isDark,
                        ),
                        _buildSectionTitle(
                          "Registration & Compliance",
                          titleColor,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoGrid(
                          [
                            _InfoItem(
                              Icons.verified_user,
                              "Insurance",
                              _formatDate(
                                _vehicleData!['vehicleData']['insurance_expiry_date'],
                              ),
                            ),
                            _InfoItem(
                              Icons.science,
                              "Pollution",
                              _formatDate(
                                _vehicleData!['vehicleData']['pollution_expiry_date'],
                              ),
                            ),
                            _InfoItem(
                              Icons.description,
                              "Registration Date",
                              _formatDate(
                                _vehicleData!['vehicleData']['registration_date'],
                              ),
                            ),
                            _InfoItem(
                              Icons.fact_check,
                              "FC Date",
                              _formatDate(
                                _vehicleData!['vehicleData']['fc_expiry_date'],
                              ),
                            ),
                            _InfoItem(
                              Icons.request_quote,
                              "Tax Valid",
                              _formatDate(
                                _vehicleData!['vehicleData']['tax_valid_upto'],
                              ),
                            ),
                            _InfoItem(
                              Icons.assignment_turned_in,
                              "Permit Valid",
                              _formatDate(
                                _vehicleData!['vehicleData']['permit_valid_upto'],
                              ),
                            ),
                          ],
                          surfaceColor,
                          isDark,
                        ),
                        const SizedBox(height: 32),
                        _buildSectionTitle("Summary Statistics", titleColor),
                        const SizedBox(height: 16),
                        _buildSummaryStatistics(surfaceColor, isDark),
                        if (_vehicleData!['defaultDriver'] != null) ...[
                          const SizedBox(height: 32),
                          _buildSectionTitle("Default Driver", titleColor),
                          const SizedBox(height: 16),
                          _buildDefaultDriver(
                            surfaceColor,
                            isDark,
                            primaryBlue,
                          ),
                        ],
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

  Future<void> _showQrDialog(BuildContext context, bool isDark, Color primaryBlue) async {
    final GlobalKey qrKey = GlobalKey();
    final TextEditingController passwordCtrl = TextEditingController();
    bool obscureText = true;

    final vehicle = _vehicleData!['vehicleData'];
    final otpValue = vehicle['id'].toString(); // Using ID as mock OTP

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.qr_code_2, color: Colors.orange.shade400),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Vehicle OTP Management",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Dashed Box
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.indigo.withValues(alpha: 0.2),
                            width: 1.5,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.refresh, color: Color(0xFF6366F1), size: 16),
                                  label: const Text("Reset", style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      RenderRepaintBoundary boundary = qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                                      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                                      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                                      final pngBytes = byteData!.buffer.asUint8List();

                                      final directory = await getApplicationDocumentsDirectory();
                                      final file = io.File('${directory.path}/vehicle_otp_$otpValue.png');
                                      await file.writeAsBytes(pngBytes);
                                      
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Branded QR Code Downloaded!"), backgroundColor: Colors.green));
                                      }
                                      OpenFilex.open(file.path);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving QR: $e"), backgroundColor: Colors.red));
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.download, color: Colors.white, size: 16),
                                  label: const Text("Download PDF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            RepaintBoundary(
                              key: qrKey,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                                    width: 2.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      "${vehicle['vehicle_number'] ?? 'N/A'} - ${vehicle['bus_number'] ?? 'N/A'} - TYPE : ${(vehicle['fuel_type'] ?? 'UNKNOWN').toString().toUpperCase()}",
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    QrImageView(
                                      data: otpValue,
                                      version: QrVersions.auto,
                                      size: 220.0,
                                      backgroundColor: Colors.white,
                                      embeddedImage: const AssetImage('assets/TripZo.png'),
                                      embeddedImageStyle: const QrEmbeddedImageStyle(
                                        size: Size(50, 50),
                                      ),
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Color(0xFF6366F1),
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.circle,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Reset OTP Section
                      Text(
                        "Generate New OTP",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Please enter your password to confirm generating a new OTP for this vehicle. This will invalidate the old OTP.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "ADMIN PASSWORD *",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: passwordCtrl,
                        obscureText: obscureText,
                        decoration: InputDecoration(
                          hintText: "Enter your password",
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          suffixIcon: IconButton(
                            icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                obscureText = !obscureText;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            // Mocking reset action
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP Reset successfully!"), backgroundColor: Colors.green));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade500,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Reset OTP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: Text("Close", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      }
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

  Widget _buildVehicleHero(bool isDark, Color surfaceColor, Color primaryBlue) {
    final veh = _vehicleData!['vehicleData'] ?? {};
    final status = veh['status'] ?? 'ACTIVE';
    final bool isActive = status == 'ACTIVE' || status.toString() == '2';
    final Color statusColor = isActive ? Colors.green : Colors.orange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primaryBlue.withValues(alpha: 0.2), width: 4),
                gradient: LinearGradient(
                  colors: [primaryBlue, primaryBlue.withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                image: _getVehicleImageUrl(veh) != null
                    ? DecorationImage(
                        image: NetworkImage(ApiConstants.getImageUrl(_getVehicleImageUrl(veh)!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _getVehicleImageUrl(veh) == null
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Image.asset(
                        'assets/TripZo.png',
                        fit: BoxFit.contain,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            veh['bus_number'] != null && veh['bus_number'].toString().trim().isNotEmpty
                ? "${veh['vehicle_number'] ?? 'N/A'} (${veh['bus_number']})"
                : veh['vehicle_number'] ?? 'N/A',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (veh['make'] != null || veh['model'] != null)
                ? "${veh['make'] ?? ''} ${veh['model'] ?? ''}".trim()
                : (veh['vehicleType']?['name'] ??
                          veh['vehicle_type'] ??
                          'Vehicle')
                      .toString()
                      .toUpperCase(),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (veh['make'] != null || veh['model'] != null)
            Text(
              (veh['vehicleType']?['name'] ?? veh['vehicle_type'] ?? 'Vehicle')
                  .toString()
                  .toUpperCase(),
              style: TextStyle(
                color: Colors.grey.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
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

  Widget _buildInfoGrid(
    List<_InfoItem> items,
    Color surfaceColor,
    bool isDark,
  ) {
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
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
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
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      item.icon,
                      size: 14,
                      color: const Color(0xFF6366F1),
                    ),
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
    final summary = _vehicleData!['summary'] ?? {};
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "Fuel Refills",
            "${summary['fuel_history_count'] ?? 0}",
            Icons.local_gas_station,
            Colors.blue,
            surfaceColor,
            isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            "Completed Trips",
            "${summary['completed_trip_count'] ?? 0}",
            Icons.route_rounded,
            Colors.cyan,
            surfaceColor,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color surfaceColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
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
                colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
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
        _buildExpandingSection(
          "Fuel History",
          Icons.local_gas_station,
          _buildFuelList(surface, isDark),
          titleColor,
        ),
        const SizedBox(height: 16),
        _buildExpandingSection(
          "Assigned Routes",
          Icons.route,
          _buildRoutesList(surface, isDark),
          titleColor,
        ),
      ],
    );
  }

  Widget _buildExpandingSection(
    String title,
    IconData icon,
    Widget content,
    Color titleColor,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
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
                  const Color(0xFF6366F1).withValues(alpha: 0.15),
                  const Color(0xFF8B5CF6).withValues(alpha: 0.08),
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
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.08),
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
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.1),
              indent: 16,
              endIndent: 16,
            ),
            Padding(padding: const EdgeInsets.all(16), child: content),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceList(Color surface, bool isDark) {
    final List<dynamic> history = _vehicleData!['serviceHistory'] ?? [];
    if (history.isEmpty) {
      return const Center(
        child: Text(
          "No maintenance records",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return Column(
      children: history
          .map(
            (m) => _buildLogCard(
              m['service_title'] ?? m['service_type'] ?? 'Maintenance',
              "₹${m['final_cost'] ?? m['estimated_cost'] ?? 0}",
              _formatTimestamp(m['service_date'] ?? m['created_at']),
              isDark,
              Icons.build_circle_rounded,
              const Color(0xFF6366F1),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFuelList(Color surface, bool isDark) {
    final List<dynamic> history = _vehicleData!['fuelHistory'] ?? [];
    if (history.isEmpty) {
      return const Center(
        child: Text("No fuel records", style: TextStyle(color: Colors.grey)),
      );
    }
    return Column(
      children: history.map((f) {
        final String bunkName = f['bunk']?['name'] ?? 'Unknown Bunk';
        final String cost = "₹${f['bill_amount'] ?? 0}";
        final String date = _formatTimestamp(f['filled_at']);
        final String volume = "${f['volume'] ?? 0} L";
        final String odometer = "${f['current_odometer'] ?? 0} km";
        final String filledBy = f['filledByUser']?['name'] ?? 'Unknown';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.local_gas_station_rounded,
                            color: Color(0xFF3B82F6),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bunkName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                date,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    cost,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF3B82F6),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFuelDetail(Icons.water_drop_outlined, "Volume", volume),
                  _buildFuelDetail(Icons.speed_rounded, "Odometer", odometer),
                  _buildFuelDetail(
                    Icons.person_outline_rounded,
                    "Filled By",
                    filledBy,
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFuelDetail(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(
    String title,
    String value,
    String time,
    bool isDark,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
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
              color: color.withValues(alpha: 0.1),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
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
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
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
            const Icon(
              Icons.wifi_off_rounded,
              size: 80,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _fetchVehicleDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "RETRY CONNECTION",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultDriver(
    Color surfaceColor,
    bool isDark,
    Color primaryBlue,
  ) {
    final def = _vehicleData!['defaultDriver'];
    final driver = def['driver'] ?? {};
    final t = isDark ? Colors.white : const Color(0xFF1E293B);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: primaryBlue.withValues(alpha: 0.1),
            child: Icon(Icons.person_rounded, color: primaryBlue, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver['name'] ?? 'Unknown Driver',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: t,
                  ),
                ),
                Text(
                  "Emp Code: ${driver['employee_code'] ?? 'N/A'}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.phone_rounded, size: 14, color: primaryBlue),
                    const SizedBox(width: 6),
                    Text(
                      driver['phone'] ?? 'No contact',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: t.withValues(alpha: 0.7),
                      ),
                    ),
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
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "PRIMARY",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "ID: ${driver['id'] ?? ''}",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.withValues(alpha: 0.5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFuelSummary(Color surfaceColor, bool isDark, Color primaryBlue) {
    final summary = _vehicleData!['summary'] ?? {};
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "Total Fuel Cost",
            "₹${summary['total_fuel_amount'] ?? 0}",
            Icons.payments_rounded,
            Colors.green,
            surfaceColor,
            isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            "Trips Count",
            "${summary['completed_trip_count'] ?? 0}",
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

  Widget _buildSummaryStatistics(Color surface, bool isDark) {
    final summary = _vehicleData!['summary'] ?? {};

    final int completedTrips = summary['completed_trip_count'] ?? 0;
    final int fuelCount = summary['fuel_history_count'] ?? 0;
    final double fuelAmount = (summary['total_fuel_amount'] ?? 0.0).toDouble();
    final double mileage = (summary['average_mileage'] ?? 0.0).toDouble();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryStatCard(
                surface,
                isDark,
                Icons.route,
                "Completed Trips",
                completedTrips.toString(),
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryStatCard(
                surface,
                isDark,
                Icons.local_gas_station,
                "Fuel Logs",
                fuelCount.toString(),
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSummaryStatCard(
                surface,
                isDark,
                Icons.currency_rupee,
                "Total Fuel Cost",
                "₹${fuelAmount.toStringAsFixed(2)}",
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryStatCard(
                surface,
                isDark,
                Icons.speed,
                "Avg Mileage",
                "${mileage.toStringAsFixed(2)} km/l",
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryStatCard(
    Color surface,
    bool isDark,
    IconData icon,
    String title,
    String value,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutesList(Color surface, bool isDark) {
    final List<dynamic> routes = _vehicleData!['travelHistory'] ?? [];
    if (routes.isEmpty) {
      return const Center(
        child: Text("No assigned routes", style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: routes.map((r) {
        final tripLeg = r['tripLeg'] ?? {};
        final tripInstance = tripLeg['tripInstance'] ?? {};
        final routeReq = tripInstance['routeRequest'] ?? {};

        final String routeName = routeReq['route_name'] ?? 'Unknown Route';

        final String startTimeStr = tripLeg['planned_start_at'] ?? '';
        final String endTimeStr = tripLeg['planned_end_at'] ?? '';

        DateTime? startDt;
        DateTime? endDt;
        try {
          if (startTimeStr.isNotEmpty) startDt = DateTime.parse(startTimeStr);
          if (endTimeStr.isNotEmpty) endDt = DateTime.parse(endTimeStr);
        } catch (_) {}

        final String startMonthDay = startDt != null
            ? DateFormat('d MMM').format(startDt)
            : '';
        final String startTimeFormatted = startDt != null
            ? DateFormat('HH:mm').format(startDt)
            : '';
        final String endMonthDay = endDt != null
            ? DateFormat('d MMM').format(endDt)
            : '';

        final String headerDate = startMonthDay;

        final String tripType =
            routeReq['trip_type']?.toString().replaceAll('_', ' ') ??
            'ROUND TRIP';
        final String distance = "${routeReq['approx_distance_km'] ?? 0} KM";
        final String status = r['status'] ?? 'COMPLETED';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    headerDate,
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildRouteTag(tripType, const Color(0xFF6366F1)),
                  _buildRouteTag(distance, const Color(0xFF10B981)),
                  _buildRouteTag(status, const Color(0xFF10B981)),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black12 : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "FROM",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            routeName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(
                        Icons.sync_alt_rounded,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            "TO",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            routeName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Flex(
                    direction: Axis.horizontal,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      (constraints.constrainWidth() / 8).floor(),
                      (index) => SizedBox(
                        width: 4,
                        height: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    startTimeFormatted,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    " until ",
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                  Text(
                    endMonthDay,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRouteTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
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
            color: widget.isActive ? Colors.green : Colors.orange,
            boxShadow: [
              BoxShadow(
                color: (widget.isActive ? Colors.green : Colors.orange)
                    .withValues(alpha: 0.5),
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
