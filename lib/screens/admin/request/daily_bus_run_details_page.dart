import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:intl/intl.dart';
import 'package:tripzo/screens/admin/request/edit_vehicle_driver_page.dart';

class DailyBusRunDetailsPage extends StatefulWidget {
  final Map<String, dynamic> runData;
  const DailyBusRunDetailsPage({super.key, required this.runData});

  @override
  State<DailyBusRunDetailsPage> createState() => _DailyBusRunDetailsPageState();
}

class _DailyBusRunDetailsPageState extends State<DailyBusRunDetailsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, dynamic> _run;
  bool _isLoading = false;
  bool _isLoadingAction = false;
  final TextEditingController _studentSearchController = TextEditingController();
  String _studentSearchQuery = '';
  String? _selectedGenderFilter;
  String? _selectedBatchFilter;
  String? _selectedDeptFilter;

  @override
  void initState() {
    super.initState();
    _run = widget.runData;
    _tabController = TabController(length: 3, vsync: this);
    _studentSearchController.addListener(() {
      setState(() {
        _studentSearchQuery = _studentSearchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }

  Future<void> _refreshDetails() async {
    setState(() => _isLoading = true);
    try {
      final String? token = await UserStore.getToken();
      if (token == null) return;

      final String serviceDate = _run['service_date'] ?? '';
      if (serviceDate.isEmpty) return;

      final url = "${ApiConstants.baseUrl}/daily-bus/bus-run/get-all?page=1&limit=50&service_date=$serviceDate";
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> runs = data['data']?['runs'] ?? [];
          final freshRun = runs.firstWhere((r) => r['id'] == _run['id'], orElse: () => null);
          if (freshRun != null) {
            setState(() {
              _run = Map<String, dynamic>.from(freshRun);
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error refreshing details: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markRunReady() async {
    setState(() => _isLoadingAction = true);
    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        _showSnackBar("Session expired. Please log in again.", Colors.red);
        return;
      }

      final String runId = _run['id']?.toString() ?? '';
      final String serviceDate = _run['service_date'] ?? '';

      if (runId.isEmpty || serviceDate.isEmpty) {
        _showSnackBar("Invalid run details", Colors.red);
        return;
      }

      final url = "${ApiConstants.baseUrl}/daily-bus/bus-runs/$runId/mark-ready";
      
      // Console log request curl
      final String curlCmd = "curl '$url' \\\n"
          "  -H 'accept: */*' \\\n"
          "  -H 'authorization: TMS $token' \\\n"
          "  -H 'content-type: application/json' \\\n"
          "  --data-raw '{\"service_date\":\"$serviceDate\"}'";
      debugPrint("---- [HTTP REQUEST CURL] ----\n$curlCmd\n----------------------------");

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: json.encode({
          "service_date": serviceDate,
        }),
      );

      // Console log HTTP response
      debugPrint("---- [HTTP RESPONSE STATUS: ${response.statusCode}] ----\n${response.body}\n----------------------------");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final resData = data['data'] ?? {};
          final int passengers = resData['passengers_copied'] ?? 0;
          final int faculties = resData['faculties_copied'] ?? 0;
          
          _showSnackBar("Run marked as READY. Copied $passengers passengers and $faculties faculties.", Colors.green);
          
          await _refreshDetails();
        } else {
          _showSnackBar(data['message'] ?? "Failed to mark run as ready", Colors.red);
        }
      } else {
        _showSnackBar("Server error: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e", Colors.red);
    } finally {
      setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _verifyCampusInOtp(String otp, String type) async {
    setState(() => _isLoadingAction = true);
    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        _showSnackBar("Session expired. Please log in again.", Colors.red);
        return;
      }

      final String runId = _run['id']?.toString() ?? '';
      if (runId.isEmpty) return;

      final url = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/$runId/verify-campus-in-otp";
      final bodyData = {
        "otp_code": otp,
        "type": type,
      };

      // Console log request curl
      final String curlCmd = "curl '$url' \\\n"
          "  -H 'accept: */*' \\\n"
          "  -H 'authorization: TMS $token' \\\n"
          "  -H 'content-type: application/json' \\\n"
          "  --data-raw '${json.encode(bodyData)}'";
      debugPrint("---- [HTTP REQUEST CURL] ----\n$curlCmd\n----------------------------");

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(bodyData),
      );

      // Console log HTTP response
      debugPrint("---- [HTTP RESPONSE STATUS: ${response.statusCode}] ----\n${response.body}\n----------------------------");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          _showSnackBar("Campus In OTP verified successfully.", Colors.green);
          await _refreshDetails();
        } else {
          _showSnackBar(data['message'] ?? "Verification failed", Colors.red);
        }
      } else {
        _showSnackBar("Server error: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e", Colors.red);
    } finally {
      setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _submitMorningOdometer(int odometer, int passengerCount, bool allowanceNeeded) async {
    setState(() => _isLoadingAction = true);
    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        _showSnackBar("Session expired. Please log in again.", Colors.red);
        return;
      }

      final String runId = _run['id']?.toString() ?? '';
      if (runId.isEmpty) return;

      final url = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/$runId/morning-odometer";
      final bodyData = {
        "end_odometer": odometer,
        "passenger_count": passengerCount,
        "allowance_needed": allowanceNeeded,
      };

      // Console log request curl
      final String curlCmd = "curl -X PATCH '$url' \\\n"
          "  -H 'accept: */*' \\\n"
          "  -H 'authorization: TMS $token' \\\n"
          "  -H 'content-type: application/json' \\\n"
          "  --data-raw '${json.encode(bodyData)}'";
      debugPrint("---- [HTTP REQUEST CURL] ----\n$curlCmd\n----------------------------");

      final response = await http.patch(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(bodyData),
      );

      // Console log HTTP response
      debugPrint("---- [HTTP RESPONSE STATUS: ${response.statusCode}] ----\n${response.body}\n----------------------------");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          _showSnackBar("Morning odometer details updated successfully.", Colors.green);
          await _refreshDetails();
        } else {
          _showSnackBar(data['message'] ?? "Odometer submission failed", Colors.red);
        }
      } else {
        _showSnackBar("Server error: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e", Colors.red);
    } finally {
      setState(() => _isLoadingAction = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _makePhoneCall(String phone) async {
    if (phone.isEmpty) return;
    final Uri url = Uri.parse("tel:${phone.trim()}");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Could not launch phone call: $e");
      _showSnackBar("Could not initiate call. Please call $phone manually.", Colors.orange);
    }
  }

  Widget _buildStatusBadge(String status) {
    final String s = status.toUpperCase();
    Color bgColor;
    Color textColor;
    Color borderColor;

    switch (s) {
      case "PLANNED":
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        borderColor = const Color(0xFFFDE68A);
        break;
      case "READY":
        bgColor = const Color(0xFFFCE7F3);
        textColor = const Color(0xFFBE185D);
        borderColor = const Color(0xFFFBCFE8);
        break;
      case "STARTED":
        bgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF2563EB);
        borderColor = const Color(0xFF93C5FD);
        break;
      case "ARRIVED_CAMPUS":
      case "CAMPUS_IN":
        bgColor = const Color(0xFFEEF2FF);
        textColor = const Color(0xFF6366F1);
        borderColor = const Color(0xFFC7D2FE);
        break;
      case "FN_COMPLETED":
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF059669);
        borderColor = const Color(0xFFA7F3D0);
        break;
      case "DEPARTED_CAMPUS":
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFB45309);
        borderColor = const Color(0xFFFDE68A);
        break;
      case "HALTED":
        bgColor = const Color(0xFFFAF5FF);
        textColor = const Color(0xFF8B5CF6);
        borderColor = const Color(0xFFE9D5FF);
        break;
      case "COMPLETED":
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF047857);
        borderColor = const Color(0xFFA7F3D0);
        break;
      case "CANCELLED":
        bgColor = const Color(0xFFFFE4E6);
        textColor = const Color(0xFFBE123C);
        borderColor = const Color(0xFFFECDD3);
        break;
      default:
        bgColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF475569);
        borderColor = const Color(0xFFE2E8F0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Text(
        s.replaceAll('_', ' '),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAssignmentsTab(bool isDark, Color titleColor, Color subColor, Color primaryBlue, Color cardColor) {
    final assignments = _run['assignment'] as List? ?? [];
    if (assignments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.5,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_ind_rounded, size: 48, color: subColor.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                Text("No assignments active for this run", style: TextStyle(color: subColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshDetails,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: assignments.length,
      itemBuilder: (context, index) {
        final assign = assignments[index];
        final String shiftCode = assign['shift_code'] ?? 'GENERAL';
        final String plannedStart = assign['planned_start_time'] ?? '';
        final String plannedEnd = assign['planned_end_time'] ?? '';
        final String startFormatted = plannedStart.isNotEmpty ? DateFormat('hh:mm a').format(DateTime.parse(plannedStart)) : 'N/A';
        final String endFormatted = plannedEnd.isNotEmpty ? DateFormat('hh:mm a').format(DateTime.parse(plannedEnd)) : 'N/A';
        
        final vehicle = assign['vehicle'] as Map<String, dynamic>?;
        final driver = assign['driver'] as Map<String, dynamic>?;
        final driverUser = driver?['user'] as Map<String, dynamic>?;
        final String phone = driverUser?['phone'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border(
              left: BorderSide(color: primaryBlue, width: 5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Combined Header showing Shift Name and Times
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.06),
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${shiftCode.replaceAll('_', ' ')} SHIFT",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          color: primaryBlue,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Text(
                      "$startFormatted - $endFormatted",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: titleColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle section title
                    Row(
                      children: [
                        Icon(Icons.directions_bus_rounded, color: primaryBlue, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "Vehicle Information",
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor),
                        ),
                      ],
                    ),
                    const Divider(height: 20, thickness: 0.8),
                    if (vehicle != null) ...[
                      _buildDetailRow(Icons.tag_rounded, "Vehicle Number", vehicle['vehicle_number'] ?? 'N/A', isDark, titleColor, subColor),
                      _buildDetailRow(Icons.bus_alert_rounded, "Make & Model", "${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}".trim(), isDark, titleColor, subColor),
                      _buildDetailRow(Icons.local_gas_station_rounded, "Fuel Type", vehicle['fuel_type'] ?? 'N/A', isDark, titleColor, subColor),
                      _buildDetailRow(Icons.airline_seat_recline_normal_rounded, "Capacity", "${vehicle['capacity'] ?? 'N/A'} Seats", isDark, titleColor, subColor),
                      _buildDetailRow(Icons.vpn_key_rounded, "Vehicle OTP", vehicle['vehicle_otp'] ?? 'N/A', isDark, titleColor, subColor, isOtp: true),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text("No vehicle details available", style: TextStyle(color: subColor, fontSize: 13)),
                      ),
                    ],

                    const SizedBox(height: 12),
                    // Divider between Vehicle and Driver
                    Container(
                      height: 1,
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    ),
                    const SizedBox(height: 20),

                    // Driver section title with Call Button on the right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_pin_rounded, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Driver Information",
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor),
                            ),
                          ],
                        ),
                        if (phone.isNotEmpty)
                          IconButton(
                            onPressed: () => _makePhoneCall(phone),
                            icon: const Icon(Icons.call_rounded, color: Colors.green, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.green.withValues(alpha: 0.1),
                              padding: const EdgeInsets.all(8),
                            ),
                          )
                      ],
                    ),
                    const Divider(height: 20, thickness: 0.8),
                    if (driver != null) ...[
                      _buildDetailRow(Icons.person_rounded, "Driver Name", driverUser?['name'] ?? 'N/A', isDark, titleColor, subColor),
                      _buildDetailRow(Icons.pin_rounded, "Employee Code", driver['employee_code'] ?? 'N/A', isDark, titleColor, subColor),
                      _buildDetailRow(Icons.credit_card_rounded, "License Number", driver['license_number'] ?? 'N/A', isDark, titleColor, subColor),
                      _buildDetailRow(Icons.timeline_rounded, "Experience", "${driver['experience_years'] ?? '0'} Years", isDark, titleColor, subColor),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text("No driver details assigned", style: TextStyle(color: subColor, fontSize: 13)),
                      ),
                    ],
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

  Widget _buildTimelineTab(bool isDark, Color titleColor, Color subColor, Color primaryBlue) {
    final stops = _run['runStops'] as List? ?? [];
    if (stops.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.5,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_rounded, size: 48, color: subColor.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                Text("No stops mapped for this routine", style: TextStyle(color: subColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

    final sortedStops = List<Map<String, dynamic>>.from(stops.map((s) => Map<String, dynamic>.from(s)));
    sortedStops.sort((a, b) => (a['stop_order'] ?? 0).compareTo(b['stop_order'] ?? 0));

    return RefreshIndicator(
      onRefresh: _refreshDetails,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        itemCount: sortedStops.length,
      itemBuilder: (context, index) {
        final stop = sortedStops[index];
        final String stopName = stop['stop_name'] ?? 'Stop';
        final int order = stop['stop_order'] ?? (index + 1);
        final String pickupTime = stop['pickup_plan_time'] ?? '';
        final String dropTime = stop['drop_plan_time'] ?? '';
        
        final pickupTimeFormatted = pickupTime.isNotEmpty ? DateFormat('hh:mm a').format(DateTime.parse("2020-01-01 $pickupTime")) : 'N/A';
        final dropTimeFormatted = dropTime.isNotEmpty ? DateFormat('hh:mm a').format(DateTime.parse("2020-01-01 $dropTime")) : 'N/A';

        final bool isFirst = index == 0;
        final bool isLast = index == sortedStops.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isFirst ? const Color(0xFF10B981) : (isLast ? const Color(0xFFEF4444) : primaryBlue),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: (isFirst ? const Color(0xFF10B981) : (isLast ? const Color(0xFFEF4444) : primaryBlue)).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        isFirst ? Icons.home_rounded : (isLast ? Icons.flag_rounded : Icons.location_on_rounded),
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: primaryBlue.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryBlue.withValues(alpha: 0.05)),
                    boxShadow: [
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
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isFirst ? const Color(0xFF10B981) : (isLast ? const Color(0xFFEF4444) : primaryBlue)).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "Stop $order",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: isFirst ? const Color(0xFF10B981) : (isLast ? const Color(0xFFEF4444) : primaryBlue),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              stopName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.arrow_upward_rounded, size: 12, color: const Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text("Pickup: $pickupTimeFormatted", style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 16),
                          Icon(Icons.arrow_downward_rounded, size: 12, color: const Color(0xFFEF4444)),
                          const SizedBox(width: 4),
                          Text("Drop: $dropTimeFormatted", style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
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

  Widget _buildPassengersTab(bool isDark, Color titleColor, Color subColor, Color primaryBlue, Color cardColor) {
    final studentsList = _run['students'] as List? ?? [];
    if (studentsList.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.5,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_rounded, size: 48, color: subColor.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                Text("No student passengers assigned", style: TextStyle(color: subColor, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

    final filteredStudents = studentsList.where((stud) {
      final s = stud['student'] as Map<String, dynamic>?;
      final user = s?['user'] as Map<String, dynamic>?;
      final String name = (user?['name'] ?? '').toString().toLowerCase();
      final String roll = (s?['roll_number'] ?? '').toString().toLowerCase();
      final String dept = (s?['department'] ?? '').toString().toLowerCase();
      final String morningAtt = (stud['morning_attendance_status'] ?? '').toString().toLowerCase();
      final String eveningAtt = (stud['evening_attendance_status'] ?? '').toString().toLowerCase();

      final bool matchesText = _studentSearchQuery.isEmpty ||
          name.contains(_studentSearchQuery) ||
          roll.contains(_studentSearchQuery) ||
          dept.contains(_studentSearchQuery) ||
          morningAtt.contains(_studentSearchQuery) ||
          eveningAtt.contains(_studentSearchQuery);

      final bool matchesGender = _selectedGenderFilter == null ||
          s?['gender']?.toString().toUpperCase() == _selectedGenderFilter;

      final bool matchesBatch = _selectedBatchFilter == null ||
          s?['academic_year']?.toString() == _selectedBatchFilter;

      final bool matchesDept = _selectedDeptFilter == null ||
          s?['department']?.toString() == _selectedDeptFilter;

      return matchesText && matchesGender && matchesBatch && matchesDept;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _studentSearchController,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Search passengers by name, dept, roll...",
                      hintStyle: TextStyle(color: subColor.withValues(alpha: 0.5), fontSize: 13, fontWeight: FontWeight.w500),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: subColor),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showPassengerFilterBottomSheet(studentsList),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_selectedGenderFilter != null || _selectedBatchFilter != null || _selectedDeptFilter != null)
                        ? primaryBlue
                        : (isDark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.filter_list_rounded,
                    color: (_selectedGenderFilter != null || _selectedBatchFilter != null || _selectedDeptFilter != null)
                        ? Colors.white
                        : primaryBlue,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshDetails,
            child: filteredStudents.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.4,
                      alignment: Alignment.center,
                      child: Text(
                        "No matching passengers found",
                        style: TextStyle(color: subColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final stud = filteredStudents[index];
                      final s = stud['student'] as Map<String, dynamic>?;
                      final user = s?['user'] as Map<String, dynamic>?;
                      final String name = user?['name'] ?? 'Student';
                      final String roll = s?['roll_number'] ?? '';
                      final String registerNumber = s?['register_number'] ?? '';
                      final String dept = s?['department'] ?? '';
                      final String academicYear = s?['academic_year'] ?? '';
                      final String gender = s?['gender'] ?? '';
                      final String phone = user?['phone'] ?? '';
                      final String email = user?['email'] ?? '';
                      
                      final String morningAtt = stud['morning_attendance_status'] ?? 'ABSENT';
                      final String eveningAtt = stud['evening_attendance_status'] ?? 'ABSENT';

                      final boardingStop = stud['boardingStop']?['stop_name'] ?? 'N/A';
                      final dropStop = stud['dropStop']?['stop_name'] ?? 'N/A';

                      final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primaryBlue.withValues(alpha: 0.04)),
                          boxShadow: [
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
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: primaryBlue.withValues(alpha: 0.1),
                                  child: Text(
                                    initial,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: primaryBlue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: titleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (phone.isNotEmpty && phone != 'N/A')
                                  IconButton(
                                    onPressed: () => _makePhoneCall(phone),
                                    icon: const Icon(Icons.call_rounded, color: Colors.green, size: 14),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.green.withValues(alpha: 0.08),
                                      padding: const EdgeInsets.all(6),
                                    ),
                                  )
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (roll.isNotEmpty && roll != 'N/A')
                                  _buildStudentBadge(Icons.assignment_ind_rounded, "Roll: $roll", primaryBlue),
                                if (registerNumber.isNotEmpty && registerNumber != 'N/A')
                                  _buildStudentBadge(Icons.app_registration_rounded, "Reg: $registerNumber", Colors.teal),
                                if (dept.isNotEmpty && dept != 'N/A')
                                  _buildStudentBadge(Icons.school_rounded, dept, Colors.orange),
                                if (academicYear.isNotEmpty && academicYear != 'N/A')
                                  _buildStudentBadge(Icons.calendar_month_rounded, "Batch: $academicYear", Colors.purple),
                                if (gender.isNotEmpty && gender != 'N/A')
                                  _buildStudentBadge(
                                    gender.toUpperCase() == 'FEMALE' ? Icons.female_rounded : Icons.male_rounded,
                                    gender,
                                    gender.toUpperCase() == 'FEMALE' ? Colors.pink : Colors.blue,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildAttendanceStatus("Morning Attendance", morningAtt),
                                _buildAttendanceStatus("Evening Attendance", eveningAtt),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, thickness: 0.8),
                            const SizedBox(height: 8),
                            if (email.isNotEmpty && email != 'N/A') ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: primaryBlue.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: primaryBlue.withValues(alpha: 0.1), width: 1),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.alternate_email_rounded, size: 13, color: primaryBlue),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: primaryBlue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            Row(
                              children: [
                                Icon(Icons.login_rounded, size: 12, color: subColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "Boarding: $boardingStop",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: titleColor.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.logout_rounded, size: 12, color: subColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "Drop: $dropStop",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: titleColor.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showPassengerFilterBottomSheet(List<dynamic> studentsList) {
    final Set<String> genders = {};
    final Set<String> batches = {};
    final Set<String> depts = {};

    for (var stud in studentsList) {
      final s = stud['student'] as Map<String, dynamic>?;
      if (s != null) {
        final g = s['gender']?.toString().toUpperCase();
        if (g != null && g.isNotEmpty) genders.add(g);

        final b = s['academic_year']?.toString();
        if (b != null && b.isNotEmpty) batches.add(b);

        final d = s['department']?.toString();
        if (d != null && d.isNotEmpty) depts.add(d);
      }
    }

    final genderList = genders.toList()..sort();
    final batchList = batches.toList()..sort();
    final deptList = depts.toList()..sort();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final Color t = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color sub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        final Color primaryBlue = const Color(0xFF6366F1);
        final Color modalBg = isDark ? const Color(0xFF1E293B) : Colors.white;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              decoration: BoxDecoration(
                color: modalBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Filter Passengers",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: t,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedGenderFilter = null;
                            _selectedBatchFilter = null;
                            _selectedDeptFilter = null;
                          });
                          setState(() {});
                        },
                        child: Text(
                          "Reset All",
                          style: TextStyle(
                            color: primaryBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (genderList.isNotEmpty) ...[
                    Text(
                      "GENDER",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: sub,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: genderList.map((g) {
                        final isSelected = _selectedGenderFilter == g;
                        return ChoiceChip(
                          label: Text(g),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              _selectedGenderFilter = selected ? g : null;
                            });
                            setState(() {});
                          },
                          selectedColor: primaryBlue.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: isSelected ? primaryBlue : t,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (batchList.isNotEmpty) ...[
                    Text(
                      "BATCH (ACADEMIC YEAR)",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: sub,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: batchList.map((b) {
                        final isSelected = _selectedBatchFilter == b;
                        return ChoiceChip(
                          label: Text(b),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              _selectedBatchFilter = selected ? b : null;
                            });
                            setState(() {});
                          },
                          selectedColor: primaryBlue.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: isSelected ? primaryBlue : t,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (deptList.isNotEmpty) ...[
                    Text(
                      "DEPARTMENT",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: sub,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: deptList.map((d) {
                          final isSelected = _selectedDeptFilter == d;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(d),
                              selected: isSelected,
                              onSelected: (selected) {
                                setModalState(() {
                                  _selectedDeptFilter = selected ? d : null;
                                });
                                setState(() {});
                              },
                              selectedColor: primaryBlue.withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: isSelected ? primaryBlue : t,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        "Apply Filters",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceStatus(String label, String status) {
    final String s = status.toUpperCase();
    final bool isPresent = s == 'PRESENT';
    final Color color = isPresent ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(s, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          ],
        )
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark, Color titleColor, Color subColor, {bool isOtp = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: subColor),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w600)),
          const Spacer(),
          isOtp
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              : Text(value, style: TextStyle(fontSize: 13, color: titleColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showVerifyOtpBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark, {String defaultType = 'FN'}) {
    String autoOtp = '';
    final assignments = _run['assignment'] as List? ?? [];
    if (assignments.isNotEmpty) {
      final firstV = assignments.firstWhere((a) => a['vehicle']?['vehicle_otp'] != null, orElse: () => null);
      if (firstV != null) {
        autoOtp = firstV['vehicle']['vehicle_otp']?.toString() ?? '';
      }
    }

    final TextEditingController otpController = TextEditingController(text: autoOtp);
    String selectedType = defaultType;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Verify Campus In OTP",
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Enter verification OTP to confirm campus arrival.",
                      style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 20),
                    
                    // OTP Text Field
                    TextField(
                      controller: otpController,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: "OTP Code",
                        labelStyle: TextStyle(color: subColor),
                        hintText: "Enter OTP code",
                        prefixIcon: Icon(Icons.vpn_key_rounded, color: primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryBlue, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Shift Type Selection Segment
                    Text(
                      "Shift Type",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subColor),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['FN', 'AN'].map((type) {
                        final bool isSelected = selectedType == type;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setModalState(() => selectedType = type);
                            },
                            child: Container(
                              margin: EdgeInsets.only(
                                right: type == 'FN' ? 8.0 : 0.0,
                                left: type == 'AN' ? 8.0 : 0.0,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? primaryBlue : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? primaryBlue : Colors.transparent),
                              ),
                              child: Center(
                                child: Text(
                                  type == 'FN' ? "FN (Morning)" : "AN (Evening)",
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : subColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final String otp = otpController.text.trim();
                          if (otp.isEmpty) {
                            _showSnackBar("Please enter the OTP", Colors.orange);
                            return;
                          }
                          Navigator.pop(context);
                          _verifyCampusInOtp(otp, selectedType);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          "Verify OTP",
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
        );
      },
    );
  }

  void _showEndMorningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    final TextEditingController odometerController = TextEditingController();
    final TextEditingController passengerController = TextEditingController();
    bool allowanceNeeded = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "End Morning Run",
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Submit final shift details for morning routine.",
                      style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 20),

                    // Odometer Field
                    TextField(
                      controller: odometerController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: "End Odometer Reading",
                        labelStyle: TextStyle(color: subColor),
                        hintText: "Enter odometer value",
                        prefixIcon: Icon(Icons.speed_rounded, color: primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryBlue, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Passengers Count Field
                    TextField(
                      controller: passengerController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: "Passenger Count",
                        labelStyle: TextStyle(color: subColor),
                        hintText: "Enter passenger count",
                        prefixIcon: Icon(Icons.people_rounded, color: primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryBlue, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Allowance needed segment
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Allowance Needed",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Select if driver allowance is needed",
                              style: TextStyle(fontSize: 10, color: subColor, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => setModalState(() => allowanceNeeded = true),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: allowanceNeeded ? const Color(0xFF10B981) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "Yes",
                                  style: TextStyle(
                                    color: allowanceNeeded ? Colors.white : subColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setModalState(() => allowanceNeeded = false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: !allowanceNeeded ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "No",
                                  style: TextStyle(
                                    color: !allowanceNeeded ? Colors.white : subColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final String oStr = odometerController.text.trim();
                          final String pStr = passengerController.text.trim();
                          if (oStr.isEmpty || pStr.isEmpty) {
                            _showSnackBar("Please fill in all odometer details", Colors.orange);
                            return;
                          }
                          final int? odometerVal = int.tryParse(oStr);
                          final int? passengerVal = int.tryParse(pStr);
                          if (odometerVal == null || passengerVal == null) {
                            _showSnackBar("Invalid numeric values", Colors.orange);
                            return;
                          }
                          Navigator.pop(context);
                          _submitMorningOdometer(odometerVal, passengerVal, allowanceNeeded);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          "Submit End Details",
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomButton(String text, IconData icon, Color primaryBlue, bool isDark, VoidCallback? onPressed) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoadingAction
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final String runName = _run['run_name'] ?? 'Bus Run';
    final String runCode = _run['run_code'] ?? '';
    final String status = _run['status'] ?? 'PENDING';
    final String routeName = _run['dailyBusRoute']?['route_name'] ?? 'Route';
    final String routeCode = _run['dailyBusRoute']?['route_code'] ?? 'Route';

    final String s = status.toUpperCase();
    final bool isPlanned = s == 'PLANNED';
    final bool isStarted = s == 'STARTED' || s == 'ONGOING' || s == 'RUNNING' || s == 'AN_STARTED';
    final bool isCampusIn = s == 'CAMPUS_IN' || s == 'ARRIVED_CAMPUS';
    final bool isEditable = s == 'PLANNED' ||
        s == 'READY' ||
        s == 'STARTED' ||
        s == 'ARRIVED_CAMPUS' ||
        s == 'CAMPUS_IN' ||
        s == 'FN_COMPLETED';

    Widget? bottomBar;
    if (isPlanned) {
      bottomBar = _buildBottomButton("Mark Run Ready", Icons.check_circle_rounded, primaryBlue, isDark, _isLoadingAction ? null : _markRunReady);
    } else if (isStarted) {
      bottomBar = _buildBottomButton(
        "Verify Campus In OTP",
        Icons.vpn_key_rounded,
        primaryBlue,
        isDark,
        _isLoadingAction
            ? null
            : () => _showVerifyOtpBottomSheet(
                  primaryBlue,
                  titleColor,
                  subColor,
                  isDark,
                  defaultType: s == 'AN_STARTED' ? 'AN' : 'FN',
                ),
      );
    } else if (isCampusIn) {
      bottomBar = _buildBottomButton("End Morning", Icons.offline_pin_rounded, primaryBlue, isDark, _isLoadingAction ? null : () => _showEndMorningBottomSheet(primaryBlue, titleColor, subColor, isDark));
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor, size: 24),
                      ),
                      Text(
                        "Routine Details",
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: titleColor),
                      ),
                      if (_isLoading)
                        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      else if (isEditable)
                        GestureDetector(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditVehicleDriverPage(run: _run),
                              ),
                            );
                            if (result == true) {
                              _refreshDetails();
                            }
                          },
                          child: Icon(Icons.edit_rounded, color: primaryBlue, size: 24),
                        )
                      else
                        const SizedBox(width: 24),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              runName,
                              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "$routeName • $routeCode",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryBlue),
                            ),
                            if (runCode.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                runCode,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: subColor.withValues(alpha: 0.7)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),
                ],
              ),
            ),
            // Custom sliding segments TabBar Layout
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: primaryBlue.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: primaryBlue,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: subColor,
                labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800),
                unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: "Assignments"),
                  Tab(text: "Timeline"),
                  Tab(text: "Passengers"),
                ],
              ),
            ),
            // Tab View Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAssignmentsTab(isDark, titleColor, subColor, primaryBlue, cardColor),
                  _buildTimelineTab(isDark, titleColor, subColor, primaryBlue),
                  _buildPassengersTab(isDark, titleColor, subColor, primaryBlue, cardColor),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}
