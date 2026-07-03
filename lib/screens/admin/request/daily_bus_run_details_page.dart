import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:intl/intl.dart';
import 'package:tripzo/screens/admin/request/edit_vehicle_driver_page.dart';
import 'package:tripzo/screens/faculty/faculty_scan_otp_screen.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

class DailyBusRunDetailsPage extends StatefulWidget {
  final Map<String, dynamic> runData;
  final bool showEditIcon;
  const DailyBusRunDetailsPage({super.key, required this.runData, this.showEditIcon = true});

  @override
  State<DailyBusRunDetailsPage> createState() => _DailyBusRunDetailsPageState();
}

class _DailyBusRunDetailsPageState extends State<DailyBusRunDetailsPage> with TickerProviderStateMixin {
  late Map<String, dynamic> _run;
  bool _isLoading = false;
  bool _isLoadingAction = false;
  final TextEditingController _studentSearchController = TextEditingController();
  String _studentSearchQuery = '';
  String? _selectedGenderFilter;
  String? _selectedBatchFilter;
  String? _selectedDeptFilter;
  String _attendanceSearchQuery = '';
  int _attendanceSessionIndex = 0;
  int _passengerTypeIndex = 0;
  String? _selectedAttendanceTypeFilter;
  String? _selectedAttendanceStatusFilter;
  String? _selectedAttendanceDeptFilter;
  final Set<String> _loadingPresentKeys = {};
  String? _userRole;
  int? _loggedInUserId;
  bool _localAttendanceConfirmed = false;


  String _formatTimeOnly(dynamic dtStr) {
    if (dtStr == null || dtStr.toString().isEmpty || dtStr == 'null') return 'N/A';
    try {
      final DateTime dt = DateTime.parse(dtStr.toString()).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return dtStr.toString();
    }
  }

  String _formatDateOnly(dynamic dtStr) {
    if (dtStr == null || dtStr.toString().isEmpty || dtStr == 'null') return 'N/A';
    try {
      final DateTime dt = DateTime.parse(dtStr.toString()).toLocal();
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (e) {
      return dtStr.toString();
    }
  }

  Widget _buildStatTile(String label, String value, String subText, Color accentColor, Color titleColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: titleColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            subText,
            style: TextStyle(fontSize: 9, color: subColor.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOdoTile(String label, double? odoVal, bool isDark, Color titleColor, Color subColor, {bool isHighlight = false, Color? highlightColor}) {
    final displayVal = odoVal != null && odoVal > 0 ? "${odoVal.toStringAsFixed(1)} km" : "N/A";
    final Color bgColor = isHighlight 
        ? (highlightColor?.withValues(alpha: 0.08) ?? Colors.transparent)
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC));
    final Color borderColor = isHighlight
        ? (highlightColor?.withValues(alpha: 0.2) ?? Colors.transparent)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: subColor, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            displayVal,
            style: GoogleFonts.outfit(
              fontSize: 12, 
              fontWeight: FontWeight.w900, 
              color: isHighlight ? (highlightColor ?? titleColor) : titleColor
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildVerifierWidget(dynamic verifier, bool isDark, Color titleColor, Color subColor, Color primaryBlue) {
    if (verifier == null || verifier == 'null') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_user_rounded, color: subColor.withValues(alpha: 0.3), size: 20),
            const SizedBox(width: 10),
            Text(
              "Not Verified Yet",
              style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    String name = 'N/A';
    String roleStr = 'N/A';
    if (verifier is Map) {
      name = verifier['name'] ?? verifier['username'] ?? 'N/A';
      roleStr = verifier['role'] is Map 
          ? (verifier['role']?['name'] ?? 'N/A') 
          : (verifier['role']?.toString() ?? 'N/A');
    } else {
      name = verifier.toString();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_rounded, color: Colors.green, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Verified By",
                  style: TextStyle(fontSize: 10, color: subColor, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              roleStr,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _run = widget.runData;
    _localAttendanceConfirmed = false;
    _studentSearchController.addListener(() {
      setState(() {
        _studentSearchQuery = _studentSearchController.text.toLowerCase().trim();
      });
    });
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await UserStore.getRole();
    final userId = await UserStore.getUserId();
    
    // Fetch full detailed run information while the shimmer skeleton is showing
    await _refreshDetails();

    if (mounted) {
      setState(() {
        _userRole = role;
        _loggedInUserId = userId;
      });
    }
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    super.dispose();
  }

  Future<void> _refreshDetails() async {
    setState(() => _isLoading = true);
    try {
      final String? token = await UserStore.getToken();
      if (token == null) return;

      final String runId = _run['id']?.toString() ?? '';
      if (runId.isEmpty) return;

      final url = "${ApiConstants.baseUrl}/daily-bus/bus-run-id/$runId";
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final Map<String, dynamic> freshRun = Map<String, dynamic>.from(data['data']);
          setState(() {
            _run = freshRun;
          });
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
        String errorMsg = "An unexpected error occurred.";
        try {
          final Map<String, dynamic> data = json.decode(response.body);
          if (data['message'] != null && data['message'].toString().trim().isNotEmpty) {
            errorMsg = data['message'].toString();
          } else if (data['error'] != null && data['error'].toString().trim().isNotEmpty) {
            errorMsg = data['error'].toString();
          }
        } catch (_) {}
        _showSnackBar(errorMsg, Colors.red);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e", Colors.red);
    } finally {
      setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _confirmAttendance() async {
    setState(() => _isLoadingAction = true);
    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        _showSnackBar("Session expired. Please log in again.", Colors.red);
        return;
      }

      final String runId = _run['id']?.toString() ?? '';
      if (runId.isEmpty) return;

      final url = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/$runId/confirm-attendance";

      // Console log request curl
      final String curlCmd = "curl -X PATCH '$url' \\\n"
          "  -H 'accept: */*' \\\n"
          "  -H 'authorization: TMS $token' \\\n"
          "  -H 'content-type: application/json'";
      debugPrint("---- [HTTP REQUEST CURL] ----\n$curlCmd\n----------------------------");

      final response = await http.patch(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      // Console log HTTP response
      debugPrint("---- [HTTP RESPONSE STATUS: ${response.statusCode}] ----\n${response.body}\n----------------------------");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          _showSnackBar("Attendance confirmed successfully.", Colors.green);
          setState(() {
            _localAttendanceConfirmed = true;
          });
          await _refreshDetails();
        } else {
          _showSnackBar(data['message'] ?? "Confirmation failed", Colors.red);
        }
      } else {
        String errorMsg = "An unexpected error occurred.";
        try {
          final Map<String, dynamic> data = json.decode(response.body);
          if (data['message'] != null && data['message'].toString().trim().isNotEmpty) {
            errorMsg = data['message'].toString();
          } else if (data['error'] != null && data['error'].toString().trim().isNotEmpty) {
            errorMsg = data['error'].toString();
          }
        } catch (_) {}
        _showSnackBar(errorMsg, Colors.red);
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
        String errorMsg = "An unexpected error occurred.";
        try {
          final Map<String, dynamic> data = json.decode(response.body);
          if (data['message'] != null && data['message'].toString().trim().isNotEmpty) {
            errorMsg = data['message'].toString();
          } else if (data['error'] != null && data['error'].toString().trim().isNotEmpty) {
            errorMsg = data['error'].toString();
          }
        } catch (_) {}
        _showSnackBar(errorMsg, Colors.red);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e", Colors.red);
    } finally {
      setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _submitMorningOdometer(int odometer, int? passengerCount, bool allowanceNeeded) async {
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
      final Map<String, dynamic> bodyData = {
        "end_odometer": odometer,
        "allowance_needed": allowanceNeeded,
      };
      if (passengerCount != null) {
        bodyData["passenger_count"] = passengerCount;
      }

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
        String errorMsg = "An unexpected error occurred.";
        try {
          final Map<String, dynamic> data = json.decode(response.body);
          if (data['message'] != null && data['message'].toString().trim().isNotEmpty) {
            errorMsg = data['message'].toString();
          } else if (data['error'] != null && data['error'].toString().trim().isNotEmpty) {
            errorMsg = data['error'].toString();
          }
        } catch (_) {}
        _showSnackBar(errorMsg, Colors.red);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e", Colors.red);
    } finally {
      setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _markPassengerPresent(String type, int targetUserId) async {
    final String key = "${type.toUpperCase()}_$targetUserId";
    setState(() {
      _loadingPresentKeys.add(key);
    });
    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        _showSnackBar("Session expired. Please log in again.", Colors.red);
        return;
      }

      final String runId = _run['id']?.toString() ?? '';
      if (runId.isEmpty) return;

      final url = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/$runId/mark-present";
      final bodyData = {
        "type": type,
        "targetUserId": targetUserId,
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
          _showSnackBar("Passenger marked present successfully.", Colors.green);
          await _refreshDetails();
        } else {
          _showSnackBar(data['message'] ?? "Failed to mark present", Colors.red);
        }
      } else {
        String errorMsg = "An unexpected error occurred.";
        try {
          final Map<String, dynamic> data = json.decode(response.body);
          if (data['message'] != null && data['message'].toString().trim().isNotEmpty) {
            errorMsg = data['message'].toString();
          } else if (data['error'] != null && data['error'].toString().trim().isNotEmpty) {
            errorMsg = data['error'].toString();
          }
        } catch (_) {}
        _showSnackBar(errorMsg, Colors.red);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e", Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _loadingPresentKeys.remove(key);
        });
      }
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
    final assignments = List.from(_run['assignment'] ?? []);
    assignments.sort((a, b) {
      final String codeA = (a['shift_code'] ?? '').toString().toLowerCase();
      final String codeB = (b['shift_code'] ?? '').toString().toLowerCase();
      
      final bool isMorningA = codeA.contains('morning') || codeA.contains('fn');
      final bool isMorningB = codeB.contains('morning') || codeB.contains('fn');
      
      if (isMorningA && !isMorningB) return -1;
      if (!isMorningA && isMorningB) return 1;
      return 0;
    });
    if (assignments.isEmpty) {
      return SingleChildScrollView(
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
      );
    }

    return ListView.builder(
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
            border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
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
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
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
                    // Vehicle Section Header
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
                    const SizedBox(height: 12),
                    
                    if (vehicle != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildGridItem(Icons.tag_rounded, "Vehicle Number", vehicle['vehicle_number'] ?? 'N/A', primaryBlue, titleColor, subColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildGridItem(Icons.directions_bus_rounded, "Bus Number", vehicle['bus_number']?.toString() ?? 'N/A', primaryBlue, titleColor, subColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildGridItem(Icons.info_outline_rounded, "Make & Model", "${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}".trim().isEmpty ? 'N/A' : "${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''}".trim(), primaryBlue, titleColor, subColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildGridItem(Icons.airline_seat_recline_normal_rounded, "Capacity", "${vehicle['capacity'] ?? 'N/A'} Seats", primaryBlue, titleColor, subColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildGridItem(Icons.local_gas_station_rounded, "Fuel Type", vehicle['fuel_type'] ?? 'N/A', primaryBlue, titleColor, subColor),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                      if (vehicle['vehicle_otp'] != null && vehicle['vehicle_otp'].toString().isNotEmpty && vehicle['vehicle_otp'] != 'null') ...[
                        const SizedBox(height: 12),
                        _buildOtpRow(Icons.vpn_key_rounded, "Vehicle OTP", vehicle['vehicle_otp'].toString(), Colors.green, titleColor, subColor),
                      ],
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text("No vehicle details available", style: TextStyle(color: subColor, fontSize: 13)),
                      ),
                    ],

                    const SizedBox(height: 20),
                    // Divider between Vehicle and Driver
                    Container(
                      height: 1,
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    ),
                    const SizedBox(height: 20),

                    // Driver Section Header
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
                    const SizedBox(height: 12),

                    if (driver != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                                  child: const Icon(Icons.person_rounded, color: Colors.orange, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        driverUser?['name'] ?? 'Driver Name',
                                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: titleColor),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        driverUser?['username'] ?? '',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subColor),
                                      ),
                                    ],
                                  ),
                                ),
                                if (phone.isNotEmpty && phone != 'N/A')
                                  IconButton(
                                    onPressed: () => _makePhoneCall(phone),
                                    icon: const Icon(Icons.call_rounded, color: Colors.green, size: 16),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.green.withValues(alpha: 0.08),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, thickness: 0.8),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.credit_card_rounded, size: 12, color: subColor),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          "License: ${driver['license_number'] ?? 'N/A'}",
                                          style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "${driver['experience_years'] ?? '0'} Yrs Exp",
                                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
    );
  }

  String _formatTime12Hour(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty || timeStr == 'N/A') return 'N/A';
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final int hour = int.parse(parts[0]);
        final int minute = int.parse(parts[1]);
        final dummyDate = DateTime(2026, 1, 1, hour, minute);
        return DateFormat('hh:mm a').format(dummyDate);
      }
    } catch (_) {}

    try {
      final DateTime dt = DateTime.parse(timeStr).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {}

    return timeStr;
  }

  Widget _buildStopCard({
    required String title,
    required String stopName,
    required String time,
    required String order,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required Color titleColor,
    required Color subColor,
    required Color cardColor,
  }) {
    final String displayTime = _formatTime12Hour(time);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: titleColor.withValues(alpha: 0.9),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Icon(Icons.location_on_rounded, color: titleColor.withValues(alpha: 0.6), size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stopName,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 16, color: iconColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "SCHEDULED TIME",
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: subColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayTime,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: iconColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tag_rounded, size: 16, color: titleColor.withValues(alpha: 0.5)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "STOP ORDER",
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: subColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "#$order",
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMyDetailsTab(bool isDark, Color titleColor, Color subColor, Color primaryBlue, Color cardColor, String morningStatus, String eveningStatus) {
    final myDetails = _run['my_details'] as Map<String, dynamic>?;
    final boardingStop = myDetails?['boardingStop'] as Map<String, dynamic>?;
    final dropStop = myDetails?['dropStop'] as Map<String, dynamic>?;

    final assignedFaculty = _run['assignedFaculty'] ?? 
                            _run['assigned_faculty'] ?? 
                            myDetails?['assignedFaculty'] ?? 
                            myDetails?['assigned_faculty'];

    final int? assignedFacultyUserId = _run['assigned_faculty_user_id'] != null
        ? int.tryParse(_run['assigned_faculty_user_id'].toString())
        : null;

    final assignments = List.from(_run['assignment'] ?? []);
    Map<String, dynamic>? driver;
    Map<String, dynamic>? driverUser;
    if (assignments.isNotEmpty) {
      final assign = assignments.first;
      driver = assign['driver'] as Map<String, dynamic>?;
      driverUser = driver?['user'] as Map<String, dynamic>?;
    }
    final String? driverName = driverUser?['name']?.toString();
    final String? driverUsername = driverUser?['username']?.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Shift Attendance Card
          Text(
            "Shift Attendance",
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildAttendanceStatusColumn(
                    "Morning Shift",
                    morningStatus,
                    isDark,
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                Expanded(
                  child: _buildAttendanceStatusColumn(
                    "Evening Shift",
                    eveningStatus,
                    isDark,
                  ),
                ),
              ],
            ),
          ),

          if (assignedFacultyUserId == 421) ...[
            if (assignedFaculty != null) ...[
              const SizedBox(height: 28),
              Text(
                "Assigned Faculty",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                      child: Icon(Icons.supervisor_account_rounded, color: titleColor.withValues(alpha: 0.7), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignedFaculty['name']?.toString() ?? 'N/A',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            assignedFaculty['phone']?.toString() ?? 'N/A',
                            style: TextStyle(
                              fontSize: 12,
                              color: subColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (assignedFaculty['phone'] != null &&
                        assignedFaculty['phone'].toString().isNotEmpty &&
                        assignedFaculty['phone'].toString() != 'null')
                      IconButton(
                        onPressed: () => _makePhoneCall(assignedFaculty['phone'].toString()),
                        icon: const Icon(Icons.call_rounded, color: Colors.green, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green.withValues(alpha: 0.08),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ] else ...[
            if (driverName != null) ...[
              const SizedBox(height: 28),
              Text(
                "Driver",
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                      child: Icon(Icons.person_rounded, color: titleColor.withValues(alpha: 0.7), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driverName,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            driverUsername ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: subColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 28),

          Text(
            "My Stop Details",
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 16),
          if (boardingStop != null) ...[
            _buildStopCard(
              title: "Boarding Stop (Pick up)",
              stopName: boardingStop['stop_name']?.toString() ?? 'N/A',
              time: boardingStop['pickup_plan_time']?.toString() ?? 'N/A',
              order: boardingStop['stop_order']?.toString() ?? 'N/A',
              icon: Icons.login_rounded,
              iconColor: primaryBlue,
              isDark: isDark,
              titleColor: titleColor,
              subColor: subColor,
              cardColor: cardColor,
            ),
            const SizedBox(height: 16),
          ],
          if (dropStop != null) ...[
            _buildStopCard(
              title: "Drop Stop",
              stopName: dropStop['stop_name']?.toString() ?? 'N/A',
              time: dropStop['drop_plan_time']?.toString() ?? 'N/A',
              order: dropStop['stop_order']?.toString() ?? 'N/A',
              icon: Icons.logout_rounded,
              iconColor: const Color(0xFFEF4444),
              isDark: isDark,
              titleColor: titleColor,
              subColor: subColor,
              cardColor: cardColor,
            ),
          ],
          if (boardingStop == null && dropStop == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  "No stop details assigned.",
                  style: TextStyle(color: subColor, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value, Color titleColor, Color subColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: subColor.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: subColor.withValues(alpha: 0.6),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceStatusColumn(String title, String status, bool isDark) {
    final String s = status.toUpperCase();
    Color statusColor;
    IconData icon;
    String statusLabel = s;

    if (s == 'PRESENT') {
      statusColor = Colors.green;
      icon = Icons.check_circle_rounded;
    } else if (s == 'ABSENT') {
      statusColor = Colors.red;
      icon = Icons.cancel_rounded;
    } else {
      statusColor = Colors.amber;
      icon = Icons.pending_rounded;
      statusLabel = 'PENDING';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(icon, color: statusColor, size: 20),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusLabel,
                style: GoogleFonts.outfit(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAssignmentsTabForNormalFaculty(bool isDark, Color titleColor, Color subColor, Color primaryBlue, Color cardColor) {
    final List assignments = _run['assignment'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Shift Assignments",
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 16),
          if (assignments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  "No assignments for this run.",
                  style: TextStyle(color: subColor, fontSize: 14),
                ),
              ),
            )
          else
            ...assignments.map((assignMap) {
              final Map<String, dynamic> assign = Map<String, dynamic>.from(assignMap);
              final String shiftCode = (assign['shift_code'] ?? 'UNKNOWN').toString().toUpperCase();
              
              final String plannedStart = assign['planned_start_time'] ?? '';
              final String plannedEnd = assign['planned_end_time'] ?? '';
              final String startFormatted = plannedStart.isNotEmpty ? DateFormat('hh:mm a').format(DateTime.parse(plannedStart)) : 'N/A';
              final String endFormatted = plannedEnd.isNotEmpty ? DateFormat('hh:mm a').format(DateTime.parse(plannedEnd)) : 'N/A';

              final vehicle = assign['vehicle'] as Map?;
              final driver = assign['driver'] as Map?;
              final driverUser = driver?['user'] as Map?;

              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 16,
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
                        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryBlue.withValues(alpha: 0.08),
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
                          // Vehicle Section Header
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
                          const SizedBox(height: 12),
                          
                          if (vehicle != null) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _buildGridItem(Icons.tag_rounded, "Vehicle Number", vehicle['vehicle_number'] ?? 'N/A', primaryBlue, titleColor, subColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildGridItem(Icons.directions_bus_rounded, "Bus Number", vehicle['bus_number']?.toString() ?? 'N/A', primaryBlue, titleColor, subColor),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildGridItem(Icons.login_rounded, "Planned Start", startFormatted, primaryBlue, titleColor, subColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildGridItem(Icons.logout_rounded, "Planned End", endFormatted, primaryBlue, titleColor, subColor),
                                ),
                              ],
                            ),
                          ] else ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text("No vehicle details available", style: TextStyle(color: subColor, fontSize: 13)),
                            ),
                          ],

                          const SizedBox(height: 20),
                          // Divider between Vehicle and Driver
                          Container(
                            height: 1,
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                          ),
                          const SizedBox(height: 20),

                          // Driver Section Header
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
                          const SizedBox(height: 12),

                          if (driver != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.orange.withValues(alpha: 0.1),
                                    child: const Icon(Icons.person_rounded, color: Colors.orange, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          driverUser?['name'] ?? 'Driver Name',
                                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: titleColor),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          driverUser?['username'] ?? '',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
            }),
        ],
      ),
    );
  }

  Widget _buildVehicleTab(bool isDark, Color titleColor, Color subColor, Color primaryBlue, Color cardColor) {
    final odoReadings = _run['odometerReadings'] as List? ?? [];
    final campusInVerifier = _run['campusInVerifiedBy'] ?? _run['campus_in_verified_by'];
    final campusOutVerifier = _run['campusOutVerifiedBy'] ?? _run['campus_out_verified_by'];

    // Parse Odometer Readings
    double? startOdo;
    double? campusInOdo;
    double? campusOutOdo;
    double? haltOdo;

    for (var reading in odoReadings) {
      final String type = (reading['reading_type'] ?? '').toString().toUpperCase();
      final double val = double.tryParse((reading['odometer_reading'] ?? '0').toString()) ?? 0.0;
      if (type == 'START') {
        startOdo = val;
      } else if (type == 'CAMPUS_IN') {
        campusInOdo = val;
      } else if (type == 'CAMPUS_OUT') {
        campusOutOdo = val;
      } else if (type == 'HALT') {
        haltOdo = val;
      }
    }

    // Morning Time Taken
    String morningTimeTaken = 'N/A';
    if (_run['actual_start_at'] != null && _run['actual_campus_in_time'] != null) {
      final DateTime? start = DateTime.tryParse(_run['actual_start_at'].toString());
      final DateTime? campusIn = DateTime.tryParse(_run['actual_campus_in_time'].toString());
      if (start != null && campusIn != null) {
        final diff = campusIn.difference(start);
        final hrs = diff.inHours;
        final mins = diff.inMinutes % 60;
        morningTimeTaken = hrs > 0 ? "$hrs hrs $mins mins" : "$mins mins";
      }
    }

    // Morning Distance Covered
    double morningDistance = 0.0;
    if (startOdo != null && campusInOdo != null && startOdo > 0 && campusInOdo > 0) {
      morningDistance = campusInOdo - startOdo;
    }

    // Evening Time Taken (only if actual_halt_time is not null)
    String eveningTimeTaken = 'N/A';
    bool hasHalt = _run['actual_halt_time'] != null && _run['actual_halt_time'].toString().isNotEmpty && _run['actual_halt_time'].toString() != 'null';
    if (hasHalt && _run['actual_campus_out_time'] != null) {
      final DateTime? campusOut = DateTime.tryParse(_run['actual_campus_out_time'].toString());
      final DateTime? halt = DateTime.tryParse(_run['actual_halt_time'].toString());
      if (campusOut != null && halt != null) {
        final diff = halt.difference(campusOut);
        final hrs = diff.inHours;
        final mins = diff.inMinutes % 60;
        eveningTimeTaken = hrs > 0 ? "$hrs hrs $mins mins" : "$mins mins";
      }
    }

    // Evening Distance Covered
    double eveningDistance = 0.0;
    if (hasHalt && campusOutOdo != null && haltOdo != null && campusOutOdo > 0 && haltOdo > 0) {
      eveningDistance = haltOdo - campusOutOdo;
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Morning Trip Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
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
                  // Card Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryBlue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.wb_sunny_rounded, color: primaryBlue, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Morning Trip",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: titleColor,
                              ),
                            ),
                          ],
                        ),
                        if (morningDistance > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryBlue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${morningDistance.toStringAsFixed(2)} km",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: primaryBlue,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  
                  // Grid for Timestamps and Duration
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildStatTile("Start Time", _formatTimeOnly(_run['actual_start_at']), _formatDateOnly(_run['actual_start_at']), primaryBlue, titleColor, subColor)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildStatTile("Campus In", _formatTimeOnly(_run['actual_campus_in_time']), _formatDateOnly(_run['actual_campus_in_time']), Colors.green, titleColor, subColor)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildStatTile("Duration", morningTimeTaken, "Time taken", Colors.orange, titleColor, subColor)),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Odometer Readings Header
                        Text(
                          "Odometer Readings",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildOdoTile("Start Odo", startOdo, isDark, titleColor, subColor),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildOdoTile("Campus In Odo", campusInOdo, isDark, titleColor, subColor),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildOdoTile("Distance", morningDistance > 0 ? morningDistance : null, isDark, titleColor, subColor, isHighlight: true, highlightColor: primaryBlue),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        
                        // Passengers Count Row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.people_alt_rounded, color: subColor, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Campus In Count",
                                    style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Text(
                                _run['campus_in_count']?.toString() ?? '0',
                                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: titleColor),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),
                        
                        // Verification Footer Stamp
                        _buildVerifierWidget(campusInVerifier, isDark, titleColor, subColor, primaryBlue),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Evening Trip Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.1)),
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
                  // Card Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.nights_stay_rounded, color: Colors.orange, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Evening Trip",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: titleColor,
                              ),
                            ),
                          ],
                        ),
                        if (hasHalt && eveningDistance > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${eveningDistance.toStringAsFixed(2)} km",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  
                  // Grid for Timestamps and Duration
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildStatTile("Campus Out", _formatTimeOnly(_run['actual_campus_out_time']), _formatDateOnly(_run['actual_campus_out_time']), Colors.orange, titleColor, subColor)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildStatTile("Halt Time", hasHalt ? _formatTimeOnly(_run['actual_halt_time']) : "N/A", hasHalt ? _formatDateOnly(_run['actual_halt_time']) : "Pending", hasHalt ? Colors.red : subColor, titleColor, subColor)),
                            const SizedBox(width: 8),
                            Expanded(child: _buildStatTile("Duration", hasHalt ? eveningTimeTaken : "N/A", hasHalt ? "Time taken" : "Pending", hasHalt ? Colors.blue : subColor, titleColor, subColor)),
                          ],
                        ),
                        
                        if (hasHalt) ...[
                          const SizedBox(height: 16),
                          
                          // Odometer Readings Header
                          Text(
                            "Odometer Readings",
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          Row(
                            children: [
                              Expanded(
                                child: _buildOdoTile("Campus Out Odo", campusOutOdo, isDark, titleColor, subColor),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildOdoTile("Halt Odometer", haltOdo, isDark, titleColor, subColor),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildOdoTile("Distance", eveningDistance > 0 ? eveningDistance : null, isDark, titleColor, subColor, isHighlight: true, highlightColor: Colors.orange),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 16),
                        
                        // Passengers Count Row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.people_alt_rounded, color: subColor, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Campus Out Count",
                                    style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Text(
                                _run['campus_out_count']?.toString() ?? '0',
                                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: titleColor),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),
                        
                        // Verification Footer Stamp
                        _buildVerifierWidget(campusOutVerifier, isDark, titleColor, subColor, Colors.orange),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildTimelineTab(bool isDark, Color titleColor, Color subColor, Color primaryBlue) {
    final stops = _run['runStops'] as List? ?? [];
    if (stops.isEmpty) {
      return SingleChildScrollView(
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
      );
    }

    final sortedStops = List<Map<String, dynamic>>.from(stops.map((s) => Map<String, dynamic>.from(s)));
    sortedStops.sort((a, b) => (a['stop_order'] ?? 0).compareTo(b['stop_order'] ?? 0));

    return ListView.builder(
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
    );
  }

  Widget _buildPassengersTab(bool isDark, Color titleColor, Color subColor, Color primaryBlue, Color cardColor) {
    final studentsList = _run['students'] as List? ?? [];
    final facultiesList = _run['faculties'] as List? ?? [];

    if (studentsList.isEmpty && facultiesList.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.5,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_rounded, size: 48, color: subColor.withValues(alpha: 0.2)),
              const SizedBox(height: 12),
              Text("No passengers assigned", style: TextStyle(color: subColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    final filteredPassengers = (_passengerTypeIndex == 0 ? studentsList : facultiesList).where((item) {
      String name = '';
      String code = '';
      String dept = '';
      if (_passengerTypeIndex == 0) {
        final s = item['student'] as Map?;
        name = s?['user']?['name']?.toString() ?? '';
        code = s?['roll_number']?.toString() ?? '';
        dept = s?['department']?.toString() ?? '';
      } else {
        final f = item['faculty'] as Map?;
        name = f?['user']?['name']?.toString() ?? '';
        code = f?['employee_code']?.toString() ?? '';
        dept = f?['department']?.toString() ?? '';
      }

      final String query = _studentSearchQuery.toLowerCase();
      final bool matchesText = query.isEmpty ||
          name.toLowerCase().contains(query) ||
          code.toLowerCase().contains(query) ||
          dept.toLowerCase().contains(query);

      if (_passengerTypeIndex == 0) {
        final s = item['student'] as Map?;
        final bool matchesGender = _selectedGenderFilter == null ||
            s?['gender']?.toString().toUpperCase() == _selectedGenderFilter;

        final bool matchesBatch = _selectedBatchFilter == null ||
            s?['academic_year']?.toString() == _selectedBatchFilter;

        final bool matchesDept = _selectedDeptFilter == null ||
            s?['department']?.toString() == _selectedDeptFilter;

        return matchesText && matchesGender && matchesBatch && matchesDept;
      } else {
        final f = item['faculty'] as Map?;
        final bool matchesDept = _selectedDeptFilter == null ||
            f?['department']?.toString() == _selectedDeptFilter;

        return matchesText && matchesDept;
      }
    }).toList();

    return Column(
      children: [
        // Slidable Segment Toggle & Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Column(
            children: [
              // Custom Sliding Segment Toggle for Student/Faculty
              LayoutBuilder(
                builder: (context, constraints) {
                  final double toggleWidth = constraints.maxWidth;
                  final double pillWidth = (toggleWidth - 8) / 2;
                  return Container(
                    height: 40,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // Sliding Pill
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          left: _passengerTypeIndex * pillWidth,
                          top: 0,
                          bottom: 0,
                          width: pillWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: primaryBlue,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryBlue.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Interactive labels
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _passengerTypeIndex = 0;
                                  });
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.school_rounded,
                                        size: 14,
                                        color: _passengerTypeIndex == 0 ? Colors.white : subColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Students",
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _passengerTypeIndex == 0 ? Colors.white : subColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _passengerTypeIndex = 1;
                                  });
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.badge_rounded,
                                        size: 14,
                                        color: _passengerTypeIndex == 1 ? Colors.white : subColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Faculties",
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _passengerTypeIndex == 1 ? Colors.white : subColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              
              Row(
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
                          hintText: "Search passengers...",
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
                    onTap: () => _showPassengerFilterBottomSheet(_passengerTypeIndex == 0 ? studentsList : facultiesList),
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
            ],
          ),
        ),
        Expanded(
          child: filteredPassengers.isEmpty
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
                    itemCount: filteredPassengers.length,
                    itemBuilder: (context, index) {
                      final item = filteredPassengers[index];
                      
                      String name = '';
                      String initial = '';
                      String phone = '';
                      String email = '';
                      String boardingStop = item['boardingStop']?['stop_name'] ?? 'N/A';
                      String dropStop = item['dropStop']?['stop_name'] ?? 'N/A';
                      String boardingOtp = item['boarding_otp']?.toString() ?? '';
                      
                      List<Widget> badges = [];

                      if (_passengerTypeIndex == 0) {
                        final s = item['student'] as Map?;
                        final user = s?['user'] as Map?;
                        name = user?['name'] ?? 'Student';
                        phone = user?['phone'] ?? '';
                        email = user?['email'] ?? '';
                        initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

                        final String roll = s?['roll_number'] ?? '';
                        final String registerNumber = s?['register_number'] ?? '';
                        final String dept = s?['department'] ?? '';
                        final String academicYear = s?['academic_year'] ?? '';
                        final String gender = s?['gender'] ?? '';

                        if (roll.isNotEmpty && roll != 'N/A') {
                          badges.add(_buildStudentBadge(Icons.assignment_ind_rounded, "Roll: $roll", primaryBlue));
                        }
                        if (registerNumber.isNotEmpty && registerNumber != 'N/A') {
                          badges.add(_buildStudentBadge(Icons.app_registration_rounded, "Reg: $registerNumber", Colors.teal));
                        }
                        if (dept.isNotEmpty && dept != 'N/A') {
                          badges.add(_buildStudentBadge(Icons.school_rounded, dept, Colors.orange));
                        }
                        if (academicYear.isNotEmpty && academicYear != 'N/A') {
                          badges.add(_buildStudentBadge(Icons.calendar_month_rounded, "Batch: $academicYear", Colors.purple));
                        }
                        if (gender.isNotEmpty && gender != 'N/A') {
                          badges.add(_buildStudentBadge(
                            gender.toUpperCase() == 'FEMALE' ? Icons.female_rounded : Icons.male_rounded,
                            gender,
                            gender.toUpperCase() == 'FEMALE' ? Colors.pink : Colors.blue,
                          ));
                        }
                      } else {
                        final f = item['faculty'] as Map?;
                        final user = f?['user'] as Map?;
                        name = user?['name'] ?? 'Faculty';
                        phone = user?['phone'] ?? '';
                        email = user?['email'] ?? '';
                        initial = name.isNotEmpty ? name[0].toUpperCase() : 'F';

                        final String employeeCode = f?['employee_code'] ?? '';
                        final String dept = f?['department'] ?? '';
                        final String designation = f?['designation'] ?? '';

                        if (employeeCode.isNotEmpty && employeeCode != 'N/A') {
                          badges.add(_buildStudentBadge(Icons.badge_rounded, "Emp Code: $employeeCode", Colors.purple));
                        }
                        if (designation.isNotEmpty && designation != 'N/A') {
                          badges.add(_buildStudentBadge(Icons.work_rounded, designation, primaryBlue));
                        }
                        if (dept.isNotEmpty && dept != 'N/A') {
                          badges.add(_buildStudentBadge(Icons.school_rounded, dept, Colors.orange));
                        }
                      }

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
                            if (badges.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: badges,
                              ),
                            ],
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
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "Boarding: $boardingStop",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11, color: titleColor.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (boardingOtp.isNotEmpty && boardingOtp != 'null') ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.green.withValues(alpha: 0.15)),
                                          ),
                                          child: Text(
                                            "OTP: $boardingOtp",
                                            style: GoogleFonts.outfit(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
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
      ],
    );
  }

  Widget _buildAttendanceTab(bool isDark, Color titleColor, Color subColor, Color primaryBlue, Color cardColor) {
    final bool isMorningConfirmed = _run['is_morning_attendance_confirmed'] == true ||
        _run['is_morning_attendance_confirmed']?.toString() == 'true' ||
        _run['morning_attendance_confirmed'] == true ||
        _run['morning_attendance_confirmed']?.toString() == 'true';

    final bool isEveningConfirmed = _run['is_evening_attendance_confirmed'] == true ||
        _run['is_evening_attendance_confirmed']?.toString() == 'true' ||
        _run['evening_attendance_confirmed'] == true ||
        _run['evening_attendance_confirmed']?.toString() == 'true';

    final attendanceList = _run['attendanceRecords'] as List? ?? [];
    if (attendanceList.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.5,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.rule_rounded, size: 48, color: subColor.withValues(alpha: 0.2)),
              const SizedBox(height: 12),
              Text("No attendance records found", style: TextStyle(color: subColor, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    // Filter by search query, type, status, and department
    final filteredRecords = attendanceList.where((rec) {
      final type = (rec['type'] ?? '').toString().toUpperCase();
      String name = '';
      String roll = '';
      String reg = '';
      String code = '';
      String dept = '';
      if (type == 'STUDENT') {
        final s = rec['student'] as Map?;
        name = s?['user']?['name']?.toString() ?? '';
        roll = s?['roll_number']?.toString() ?? '';
        reg = s?['register_number']?.toString() ?? '';
        dept = s?['department']?.toString() ?? '';
      } else if (type == 'FACULTY') {
        final f = rec['faculty'] as Map?;
        name = f?['user']?['name']?.toString() ?? '';
        code = f?['employee_code']?.toString() ?? '';
        dept = f?['department']?.toString() ?? '';
      }

      final String query = _attendanceSearchQuery.toLowerCase();
      final bool matchesSearch = query.isEmpty ||
          name.toLowerCase().contains(query) ||
          roll.toLowerCase().contains(query) ||
          reg.toLowerCase().contains(query) ||
          code.toLowerCase().contains(query) ||
          dept.toLowerCase().contains(query);

      // Type Filter
      final bool matchesType = _selectedAttendanceTypeFilter == null ||
          type == _selectedAttendanceTypeFilter;

      // Status Filter
      final String sessionStatus = (_attendanceSessionIndex == 0 
          ? rec['morning_attendance_status'] 
          : rec['evening_attendance_status'])?.toString().toUpperCase() ?? 'ABSENT';
      final bool matchesStatus = _selectedAttendanceStatusFilter == null ||
          sessionStatus == _selectedAttendanceStatusFilter;

      // Department Filter
      final bool matchesDept = _selectedAttendanceDeptFilter == null ||
          dept == _selectedAttendanceDeptFilter;

      return matchesSearch && matchesType && matchesStatus && matchesDept;
    }).toList();

    // Counts for selected session
    int presentCount = 0;
    int absentCount = 0;
    for (var rec in filteredRecords) {
      final String status = (_attendanceSessionIndex == 0 
          ? rec['morning_attendance_status'] 
          : rec['evening_attendance_status'])?.toString().toUpperCase() ?? 'ABSENT';
      if (status == 'PRESENT') {
        presentCount++;
      } else {
        absentCount++;
      }
    }

    return Column(
      children: [
        // Horizontal Session Selector Toggle & Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            children: [
              // Custom Sliding Segmented Toggle
              LayoutBuilder(
                builder: (context, constraints) {
                  final double toggleWidth = constraints.maxWidth;
                  final double pillWidth = (toggleWidth - 8) / 2;
                  return Container(
                    height: 40,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // Sliding Pill
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          left: _attendanceSessionIndex * pillWidth,
                          top: 0,
                          bottom: 0,
                          width: pillWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: primaryBlue,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryBlue.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Interactive labels
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _attendanceSessionIndex = 0;
                                  });
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.wb_sunny_rounded,
                                        size: 14,
                                        color: _attendanceSessionIndex == 0 ? Colors.white : subColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Morning",
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _attendanceSessionIndex == 0 ? Colors.white : subColor,
                                        ),
                                      ),
                                      if (isMorningConfirmed) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 12,
                                          color: _attendanceSessionIndex == 0 ? Colors.white : Colors.green,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _attendanceSessionIndex = 1;
                                  });
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.nights_stay_rounded,
                                        size: 14,
                                        color: _attendanceSessionIndex == 1 ? Colors.white : subColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Evening",
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: _attendanceSessionIndex == 1 ? Colors.white : subColor,
                                        ),
                                      ),
                                      if (isEveningConfirmed) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.check_circle_rounded,
                                          size: 12,
                                          color: _attendanceSessionIndex == 1 ? Colors.white : Colors.green,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              
              // Search Bar & Filter Button
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: primaryBlue.withValues(alpha: 0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (val) {
                          setState(() {
                            _attendanceSearchQuery = val;
                          });
                        },
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "Search by name, roll, dept...",
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
                    onTap: () => _showAttendanceFilterBottomSheet(attendanceList),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_selectedAttendanceTypeFilter != null || _selectedAttendanceStatusFilter != null)
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
                        color: (_selectedAttendanceTypeFilter != null || _selectedAttendanceStatusFilter != null)
                            ? Colors.white
                            : primaryBlue,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Summary Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total: ${filteredRecords.length}",
                    style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Present: $presentCount",
                          style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Absent: $absentCount",
                          style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Scrollable List of Records
        Expanded(
          child: filteredRecords.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.35,
                      alignment: Alignment.center,
                      child: Text(
                        "No matching records found",
                        style: TextStyle(color: subColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: filteredRecords.length,
                    itemBuilder: (context, index) {
                      final rec = filteredRecords[index];
                      final type = (rec['type'] ?? '').toString().toUpperCase();
                      
                      String name = 'N/A';
                      String typeLabel = '';
                      Color typeColor = Colors.blue;
                      IconData typeIcon = Icons.school_rounded;

                      String roll = '';
                      String reg = '';
                      String dept = '';
                      String empCode = '';
                      String designation = '';

                      if (type == 'STUDENT') {
                        final s = rec['student'] as Map?;
                        name = s?['user']?['name'] ?? 'Student';
                        roll = s?['roll_number'] ?? '';
                        reg = s?['register_number'] ?? '';
                        dept = s?['department'] ?? '';
                        
                        typeLabel = "Student";
                        typeColor = primaryBlue;
                        typeIcon = Icons.person_rounded;
                      } else {
                        final f = rec['faculty'] as Map?;
                        name = f?['user']?['name'] ?? 'Faculty';
                        empCode = f?['employee_code'] ?? '';
                        dept = f?['department'] ?? '';
                        designation = f?['designation'] ?? '';

                        typeLabel = "Faculty";
                        typeColor = Colors.purple;
                        typeIcon = Icons.badge_rounded;
                      }

                      final String sessionStatus = (_attendanceSessionIndex == 0 
                          ? rec['morning_attendance_status'] 
                          : rec['evening_attendance_status'])?.toString().toUpperCase() ?? 'ABSENT';

                      final isPresent = sessionStatus == 'PRESENT';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isPresent 
                                ? Colors.green.withValues(alpha: 0.1) 
                                : Colors.red.withValues(alpha: 0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.01),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Left indicator icon
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(typeIcon, color: typeColor, size: 18),
                            ),
                            const SizedBox(width: 12),
                            
                            // Center Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: titleColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: typeColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          typeLabel,
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: typeColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (type == 'STUDENT') ...[
                                    Text(
                                      "Roll: $roll  •  Reg: $reg",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subColor.withValues(alpha: 0.8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Dept: $dept",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subColor.withValues(alpha: 0.8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ] else ...[
                                    Text(
                                      "Emp Code: $empCode  •  $designation",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subColor.withValues(alpha: 0.8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Dept: $dept",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subColor.withValues(alpha: 0.8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Right Attendance Status Pill
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isPresent 
                                        ? Colors.green.withValues(alpha: 0.1) 
                                        : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isPresent ? "PRESENT" : "ABSENT",
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: isPresent ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ),
                                if (!isPresent) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      final s = rec['student'] as Map?;
                                      final f = rec['faculty'] as Map?;
                                      final int? targetUserId = type == 'STUDENT'
                                          ? (s?['user_id'] ?? s?['user']?['id'] as int?)
                                          : (f?['user_id'] ?? f?['user']?['id'] as int?);
                                      if (targetUserId != null) {
                                        _markPassengerPresent(type, targetUserId);
                                      } else {
                                        _showSnackBar("User ID not found", Colors.red);
                                      }
                                    },
                                    child: Builder(
                                      builder: (context) {
                                        final s = rec['student'] as Map?;
                                        final f = rec['faculty'] as Map?;
                                        final int? targetUserId = type == 'STUDENT'
                                            ? (s?['user_id'] ?? s?['user']?['id'] as int?)
                                            : (f?['user_id'] ?? f?['user']?['id'] as int?);
                                        final String key = "${type.toUpperCase()}_$targetUserId";
                                        final isLoading = _loadingPresentKeys.contains(key);

                                        return Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.green.withValues(alpha: 0.3),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: isLoading
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                        );
                                      }
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    },
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

  void _showAttendanceFilterBottomSheet(List<dynamic> attendanceList) {
    final Set<String> depts = {};
    for (var rec in attendanceList) {
      final type = (rec['type'] ?? '').toString().toUpperCase();
      if (type == 'STUDENT') {
        final s = rec['student'] as Map?;
        final d = s?['department']?.toString();
        if (d != null && d.isNotEmpty) {
          depts.add(d);
        }
      } else if (type == 'FACULTY') {
        final f = rec['faculty'] as Map?;
        final d = f?['department']?.toString();
        if (d != null && d.isNotEmpty) {
          depts.add(d);
        }
      }
    }
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
                        "Filter Attendance",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: t,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedAttendanceTypeFilter = null;
                            _selectedAttendanceStatusFilter = null;
                            _selectedAttendanceDeptFilter = null;
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
                  
                  // Passenger Type Filter (Student / Faculty)
                  Text(
                    "PASSENGER TYPE",
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
                    children: [
                      ChoiceChip(
                        label: const Text("Student"),
                        selected: _selectedAttendanceTypeFilter == 'STUDENT',
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedAttendanceTypeFilter = selected ? 'STUDENT' : null;
                          });
                          setState(() {});
                        },
                        selectedColor: primaryBlue.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: _selectedAttendanceTypeFilter == 'STUDENT' ? primaryBlue : t,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text("Faculty"),
                        selected: _selectedAttendanceTypeFilter == 'FACULTY',
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedAttendanceTypeFilter = selected ? 'FACULTY' : null;
                          });
                          setState(() {});
                        },
                        selectedColor: primaryBlue.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: _selectedAttendanceTypeFilter == 'FACULTY' ? primaryBlue : t,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Attendance Status Filter (Present / Absent)
                  Text(
                    "STATUS",
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
                    children: [
                      ChoiceChip(
                        label: const Text("Present"),
                        selected: _selectedAttendanceStatusFilter == 'PRESENT',
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedAttendanceStatusFilter = selected ? 'PRESENT' : null;
                          });
                          setState(() {});
                        },
                        selectedColor: primaryBlue.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: _selectedAttendanceStatusFilter == 'PRESENT' ? primaryBlue : t,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text("Absent"),
                        selected: _selectedAttendanceStatusFilter == 'ABSENT',
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedAttendanceStatusFilter = selected ? 'ABSENT' : null;
                          });
                          setState(() {});
                        },
                        selectedColor: primaryBlue.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: _selectedAttendanceStatusFilter == 'ABSENT' ? primaryBlue : t,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  
                  // Department Filter Section
                  if (deptList.isNotEmpty) ...[
                    const SizedBox(height: 20),
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
                          final isSelected = _selectedAttendanceDeptFilter == d;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(d),
                              selected: isSelected,
                              onSelected: (selected) {
                                setModalState(() {
                                  _selectedAttendanceDeptFilter = selected ? d : null;
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
                  ],
                  const SizedBox(height: 24),

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
                          if (oStr.isEmpty) {
                            _showSnackBar("Please fill in odometer details", Colors.orange);
                            return;
                          }
                          final int? odometerVal = int.tryParse(oStr);
                          if (odometerVal == null) {
                            _showSnackBar("Invalid numeric values", Colors.orange);
                            return;
                          }
                          Navigator.pop(context);
                          _submitMorningOdometer(odometerVal, null, allowanceNeeded);
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

  Widget _buildSkeletonLoading(bool isDark, Color cardColor, Color bgColor, Color titleColor, Color subColor) {
    final shimmerBase = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200;
    final shimmerHighlight = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Bus Run Details",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: titleColor,
          ),
        ),
      ),
      body: Shimmer.fromColors(
        baseColor: shimmerBase,
        highlightColor: shimmerHighlight,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card Skeleton
              Container(
                width: double.infinity,
                height: 140,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              const SizedBox(height: 28),

              // Tab Bar Skeleton
              Row(
                children: [
                  Container(
                    width: 100,
                    height: 38,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 120,
                    height: 38,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Section 1: Shift Attendance Skeleton
              Container(
                width: 140,
                height: 20,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              const SizedBox(height: 28),

              // Section 2: Driver / Faculty Skeleton
              Container(
                width: 120,
                height: 20,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              const SizedBox(height: 28),

              // Section 3: Stops Details Header Skeleton
              Container(
                width: 150,
                height: 20,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 16),
              // Stop card 1
              Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ],
          ),
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

    if (_userRole == null) {
      return _buildSkeletonLoading(isDark, cardColor, bgColor, titleColor, subColor);
    }

    final String runName = _run['run_name'] ?? 'Bus Run';
    final String runCode = _run['run_code'] ?? '';
    final String status = _run['status'] ?? 'PENDING';
    final String routeName = _run['dailyBusRoute']?['route_name'] ?? _run['daily_bus_route']?['route_name'] ?? 'Route';
    final String routeCode = _run['dailyBusRoute']?['route_code'] ?? _run['daily_bus_route']?['route_code'] ?? 'Route';

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

    final bool isSuperOrTransportAdmin = _userRole != null &&
        (_userRole!.toLowerCase() == 'super admin' ||
            _userRole!.toLowerCase() == 'transport admin');

    final int? assignedFacultyUserId = _run['assigned_faculty_user_id'] != null
        ? int.tryParse(_run['assigned_faculty_user_id'].toString())
        : null;
    final bool isAssignedFaculty = _userRole != null &&
        _userRole!.toLowerCase() == 'faculty' &&
        assignedFacultyUserId != null &&
        assignedFacultyUserId == _loggedInUserId;

    Map<String, dynamic>? myFacultyRecord;
    if (_userRole != null && (_userRole!.toLowerCase() == 'faculty' || _userRole!.toLowerCase() == 'student')) {
      final String typeToSearch = _userRole!.toLowerCase() == 'faculty' ? 'FACULTY' : 'STUDENT';
      final String entityKey = _userRole!.toLowerCase() == 'faculty' ? 'faculty' : 'student';
      final List attendanceList = _run['attendanceRecords'] as List? ?? [];
      for (var rec in attendanceList) {
        if (rec['type']?.toString().toUpperCase() == typeToSearch) {
          final pMap = rec[entityKey] as Map?;
          final int? pUserId = pMap?['user']?['id'] != null ? int.tryParse(pMap!['user']['id'].toString()) : null;
          if (pUserId != null && pUserId == _loggedInUserId) {
            myFacultyRecord = Map<String, dynamic>.from(rec);
            break;
          }
        }
      }
    }

    final myDetails = _run['my_details'] as Map<String, dynamic>?;
    final String morningStatus = (myFacultyRecord != null
        ? (myFacultyRecord['morning_attendance_status'] ?? 'ABSENT')
        : (myDetails?['morning_attendance_status'] ?? 'ABSENT')).toString().toUpperCase();
    final String eveningStatus = (myFacultyRecord != null
        ? (myFacultyRecord['evening_attendance_status'] ?? 'ABSENT')
        : (myDetails?['evening_attendance_status'] ?? 'ABSENT')).toString().toUpperCase();

    // Morning condition: started or ARRIVED_CAMPUS, and not already marked PRESENT.
    final bool isMorningScanEligible = (s == 'STARTED' || s == 'ARRIVED_CAMPUS') && morningStatus != 'PRESENT';

    // Evening condition: show when FN_COMPLETED, close when AN_STARTED or marked PRESENT.
    final bool isEveningScanEligible = s == 'FN_COMPLETED' && eveningStatus != 'PRESENT';

    final bool showScanOtpButton = isAssignedFaculty && (isMorningScanEligible || isEveningScanEligible);

    // Active status based on shift
    final bool isAn = s.contains('AN') || s == 'FN_COMPLETED';
    final String activeStatus = isAn ? eveningStatus : morningStatus;
    final bool isPresent = activeStatus == 'PRESENT';

    final bool isMorningConfirmed = _run['is_morning_attendance_confirmed'] == true ||
        _run['is_morning_attendance_confirmed']?.toString() == 'true' ||
        _run['morning_attendance_confirmed'] == true ||
        _run['morning_attendance_confirmed']?.toString() == 'true';

    final bool isEveningConfirmed = _run['is_evening_attendance_confirmed'] == true ||
        _run['is_evening_attendance_confirmed']?.toString() == 'true' ||
        _run['evening_attendance_confirmed'] == true ||
        _run['evening_attendance_confirmed']?.toString() == 'true';

    final bool isAttendanceConfirmed = isAn ? isEveningConfirmed : isMorningConfirmed;

    final bool showConfirmAttendance = isAssignedFaculty && 
        (assignedFacultyUserId == 421 || true) &&
        isPresent && 
        !isAttendanceConfirmed && 
        !_localAttendanceConfirmed;

    final bool showOnlyHeaderAndAttendance = _userRole != null &&
        ((_userRole!.toLowerCase() == 'faculty' && !isAssignedFaculty) ||
         _userRole!.toLowerCase() == 'student');

    final bool showScanQrCodeButtonForNormal = showOnlyHeaderAndAttendance && (
        ((s == 'STARTED' || s == 'ARRIVED_CAMPUS' || s == 'CAMPUS_IN') && morningStatus != 'PRESENT') ||
        (s == 'FN_COMPLETED' && eveningStatus != 'PRESENT')
    );

    Widget? bottomBar;
    if (isSuperOrTransportAdmin) {
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
    } else if (showScanQrCodeButtonForNormal) {
      final String otpType = s == 'FN_COMPLETED' ? 'AN' : 'FN';
      bottomBar = _buildBottomButton(
        "Scan QR Code",
        Icons.qr_code_scanner_rounded,
        primaryBlue,
        isDark,
        () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FacultyScanOtpScreen(
                runId: _run['id'] ?? 131,
                otpType: otpType,
              ),
            ),
          );
          if (result == true) {
            _refreshDetails();
          }
        },
      );
    } else if (showScanOtpButton) {
      final String otpType = s == 'FN_COMPLETED' || s.contains('AN') ? 'AN' : 'FN';
      bottomBar = _buildBottomButton(
        "Scan OTP",
        Icons.qr_code_scanner_rounded,
        primaryBlue,
        isDark,
        () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FacultyScanOtpScreen(
                runId: _run['id'] ?? 128,
                otpType: otpType,
              ),
            ),
          );
          if (result == true) {
            _refreshDetails();
          }
        },
      );
    } else if (showConfirmAttendance) {
      bottomBar = _buildBottomButton(
        "I Confirm the Attendance",
        Icons.check_circle_outline_rounded,
        Colors.green,
        isDark,
        _isLoadingAction ? null : _confirmAttendance,
      );
    }

    final String morningBoardingOtp = myFacultyRecord != null
        ? (myFacultyRecord['morning_boarding_otp'] ?? 
           myFacultyRecord['morning_otp'] ?? 
           myFacultyRecord['boarding_otp'] ?? 
           '').toString()
        : '';
    final String eveningBoardingOtp = myFacultyRecord != null
        ? (myFacultyRecord['evening_boarding_otp'] ?? 
           myFacultyRecord['evening_otp'] ?? 
           '').toString()
        : '';

    Widget? facultyAttendanceWidget;
    if (isAssignedFaculty && myFacultyRecord != null) {
      final bool isAn = s.contains('AN') || s == 'FN_COMPLETED';
      final String activeStatus = isAn ? eveningStatus : morningStatus;
      final String activeLabel = isAn ? "Evening Attendance" : "Morning Attendance";
      
      final bool isPresent = activeStatus == 'PRESENT';
      final Color statusColor = isPresent ? Colors.green : Colors.red;
      
      // Build OTP display widgets
      Widget morningOtpBadge = Container();
      Widget eveningOtpBadge = Container();
      
      if (morningBoardingOtp.isNotEmpty && morningBoardingOtp != 'null') {
        morningOtpBadge = _buildFacultyOtpPill(
          label: "Morning Boarding OTP",
          otp: morningBoardingOtp,
          isActive: !isAn,
          primaryBlue: primaryBlue,
          textColor: titleColor,
          subColor: subColor,
          isDark: isDark,
        );
      }
      
      if (eveningBoardingOtp.isNotEmpty && eveningBoardingOtp != 'null') {
        eveningOtpBadge = _buildFacultyOtpPill(
          label: "Evening Boarding OTP",
          otp: eveningBoardingOtp,
          isActive: isAn,
          primaryBlue: primaryBlue,
          textColor: titleColor,
          subColor: subColor,
          isDark: isDark,
        );
      }
      
      facultyAttendanceWidget = Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Attendance Status Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(
                    isPresent ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeLabel,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: subColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeStatus,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    isAn ? "Morning: $morningStatus" : "Evening: $eveningStatus",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: subColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            // OTPs Row
            if ((morningBoardingOtp.isNotEmpty && morningBoardingOtp != 'null') || 
                (eveningBoardingOtp.isNotEmpty && eveningBoardingOtp != 'null')) ...[
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "BOARDING PASSCODES",
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: subColor.withValues(alpha: 0.6),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (morningBoardingOtp.isNotEmpty && morningBoardingOtp != 'null')
                          Expanded(child: morningOtpBadge),
                        if (morningBoardingOtp.isNotEmpty && morningBoardingOtp != 'null' &&
                            eveningBoardingOtp.isNotEmpty && eveningBoardingOtp != 'null')
                          const SizedBox(width: 12),
                        if (eveningBoardingOtp.isNotEmpty && eveningBoardingOtp != 'null')
                          Expanded(child: eveningOtpBadge),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return DefaultTabController(
      key: ValueKey('tab_controller_${showOnlyHeaderAndAttendance}_$_userRole'),
      length: showOnlyHeaderAndAttendance ? 2 : 5,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshDetails,
            notificationPredicate: (ScrollNotification notification) {
              return notification.depth == 1 || notification.depth == 0;
            },
            child: NestedScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                  else ...[
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSuperOrTransportAdmin) ...[
                                          GestureDetector(
                                            onTap: _refreshDetails,
                                            child: Icon(Icons.refresh_rounded, color: primaryBlue, size: 24),
                                          ),
                                          if (isEditable && widget.showEditIcon)
                                            const SizedBox(width: 16),
                                        ],
                                        if (isEditable && widget.showEditIcon && isSuperOrTransportAdmin)
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
                                          ),
                                        if (!isSuperOrTransportAdmin && (!isEditable || !widget.showEditIcon))
                                          const SizedBox(width: 24),
                                      ],
                                    ),
                                  ],
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
                        if (facultyAttendanceWidget != null) facultyAttendanceWidget,
                        // Custom sliding segments TabBar Layout and View
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
                            dividerColor: Colors.transparent,
                            isScrollable: !showOnlyHeaderAndAttendance,
                            tabAlignment: showOnlyHeaderAndAttendance ? TabAlignment.fill : TabAlignment.center,
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
                            tabs: showOnlyHeaderAndAttendance
                                ? const [
                                    Tab(text: "My Details"),
                                    Tab(text: "Assignment"),
                                  ]
                                : const [
                                    Tab(text: "Assignments"),
                                    Tab(text: "Vehicle"),
                                    Tab(text: "Timeline"),
                                    Tab(text: "Passengers"),
                                    Tab(text: "Attendance"),
                                  ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                children: showOnlyHeaderAndAttendance
                    ? [
                        _buildMyDetailsTab(isDark, titleColor, subColor, primaryBlue, cardColor, morningStatus, eveningStatus),
                        _buildAssignmentsTabForNormalFaculty(isDark, titleColor, subColor, primaryBlue, cardColor),
                      ]
                    : [
                        _buildAssignmentsTab(isDark, titleColor, subColor, primaryBlue, cardColor),
                        _buildVehicleTab(isDark, titleColor, subColor, primaryBlue, cardColor),
                        _buildTimelineTab(isDark, titleColor, subColor, primaryBlue),
                        _buildPassengersTab(isDark, titleColor, subColor, primaryBlue, cardColor),
                        _buildAttendanceTab(isDark, titleColor, subColor, primaryBlue, cardColor),
                      ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: bottomBar,
      ),
    );
  }

  Widget _buildGridItem(IconData icon, String label, String value, Color accentColor, Color titleColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: accentColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subColor),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: titleColor),
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

  Widget _buildOtpRow(IconData icon, String label, String value, Color accentColor, Color titleColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subColor),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value,
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyOtpPill({
    required String label,
    required String otp,
    required bool isActive,
    required Color primaryBlue,
    required Color textColor,
    required Color subColor,
    required bool isDark,
  }) {
    final Color activeColor = isActive ? primaryBlue : subColor.withValues(alpha: 0.4);
    final Color bgValues = isActive
        ? primaryBlue.withValues(alpha: 0.05)
        : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01));
    final Color borderValues = isActive
        ? primaryBlue.withValues(alpha: 0.2)
        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgValues,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderValues),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key_rounded, size: 10, color: activeColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: isActive ? primaryBlue : subColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                otp,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isActive ? textColor : subColor.withValues(alpha: 0.6),
                  letterSpacing: 1.0,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: otp));
                  _showSnackBar("Copied OTP to clipboard", Colors.green);
                },
                child: Icon(
                  Icons.copy_all_rounded,
                  size: 14,
                  color: isActive ? primaryBlue : subColor.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
