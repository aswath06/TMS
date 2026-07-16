import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tripzo/utils/api_error_parser.dart';

import 'package:tripzo/components/assigned_faculty_cards.dart';



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

import 'package:lottie/lottie.dart';

import 'package:tripzo/store/faculty_store.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';





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

        color: accentColor.withOpacity( 0.06),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: accentColor.withOpacity( 0.12)),

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

            style: TextStyle(fontSize: 9, color: subColor.withOpacity( 0.7), fontWeight: FontWeight.w500),

            textAlign: TextAlign.center,

          ),

        ],

      ),

    );

  }



  Widget _buildOdoTile(String label, double? odoVal, bool isDark, Color titleColor, Color subColor, {bool isHighlight = false, Color? highlightColor}) {

    final displayVal = odoVal != null && odoVal > 0 ? "${odoVal.toStringAsFixed(1)} km" : "N/A";

    final Color bgColor = isHighlight 

        ? (highlightColor?.withOpacity( 0.08) ?? Colors.transparent)

        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC));

    final Color borderColor = isHighlight

        ? (highlightColor?.withOpacity( 0.2) ?? Colors.transparent)

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

            Icon(Icons.verified_user_rounded, color: subColor.withOpacity( 0.3), size: 20),

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

        color: Colors.green.withOpacity( 0.06),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: Colors.green.withOpacity( 0.12)),

      ),

      child: Row(

        children: [

          Container(

            padding: const EdgeInsets.all(6),

            decoration: BoxDecoration(

              color: Colors.green.withOpacity( 0.15),

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

              color: Colors.green.withOpacity( 0.15),

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



  bool _getIsAssignedFaculty() {

    if (_loggedInUserId == null) {

      return false;

    }



    final int? morningFacultyUserId = _run['morning_assigned_faculty_id'] != null

        ? int.tryParse(_run['morning_assigned_faculty_id'].toString())

        : (_run['morningAssignedFaculty']?['id'] != null

            ? int.tryParse(_run['morningAssignedFaculty']['id'].toString())

            : null);



    final int? eveningFacultyUserId = _run['evening_assigned_faculty_id'] != null

        ? int.tryParse(_run['evening_assigned_faculty_id'].toString())

        : (_run['eveningAssignedFaculty']?['id'] != null

            ? int.tryParse(_run['eveningAssignedFaculty']['id'].toString())

            : null);



    final int? assignedFacultyUserId = _run['assigned_faculty_user_id'] != null

        ? int.tryParse(_run['assigned_faculty_user_id'].toString())

        : null;



    return morningFacultyUserId == _loggedInUserId ||

        eveningFacultyUserId == _loggedInUserId ||

        assignedFacultyUserId == _loggedInUserId;

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



      int? userId = _loggedInUserId;

      userId ??= await UserStore.getUserId();



      String url = "${ApiConstants.baseUrl}/daily-bus/bus-run-id/$runId";
      if (userId != null) {
        url += "?user_id=$userId";
      }

      final String curlCmd = "curl --request GET \\\n"
          "  --url '$url' \\\n"
          "  --header 'Authorization: TMS $token' \\\n"
          "  --header 'Content-Type: application/json'";
          
      debugPrint("\n🌟🌟🌟 [GET BY ID: FETCHING ROUTE DETAILS] 🌟🌟🌟\n"
          "====================================================\n"
          "$curlCmd\n"
          "====================================================\n");

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );



      if (_userRole?.toLowerCase() == 'student') {

        debugPrint("🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟");

        debugPrint("🚀 [STUDENT] FETCHING ROUTINE DETAILS 🚀");

        debugPrint("🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟");

        debugPrint("🔗 CURL COMMAND:");

        debugPrint("curl --location --request GET '$url' \\");

        debugPrint("--header 'authorization: TMS $token' \\");

        debugPrint("--header 'Content-Type: application/json'");

        debugPrint("--------------------------------------------");

        debugPrint("📦 RESPONSE DATA:");

        debugPrint("🚥 Status Code: ${response.statusCode} ${response.statusCode == 200 ? '✅' : '❌'}");

        debugPrint("📄 Body: ${response.body}");

        debugPrint("🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟🌟");

      }



      if (response.statusCode == 200) {

        final Map<String, dynamic> data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {

          final Map<String, dynamic> freshRun = Map<String, dynamic>.from(data['data']);

          if (mounted) {

            setState(() {

              _run = freshRun;

            });

          }

        }

      }

    } catch (e) {

      debugPrint("Error refreshing details: $e");

    } finally {

      if (mounted) {

        setState(() => _isLoading = false);

      }

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



  void _showConfirmAttendancePopup() {

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final Color primaryBlue = const Color(0xFF6366F1);



    showDialog(

      context: context,

      builder: (ctx) => Dialog(

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

        backgroundColor: Colors.transparent,

        insetPadding: const EdgeInsets.symmetric(horizontal: 24),

        child: Container(

          decoration: BoxDecoration(

            color: bgColor,

            borderRadius: BorderRadius.circular(24),

            boxShadow: [

              BoxShadow(

                color: Colors.black.withOpacity( 0.1),

                blurRadius: 20,

                offset: const Offset(0, 10),

              ),

            ],

          ),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              // Header

              Container(

                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),

                decoration: BoxDecoration(

                  color: primaryBlue.withOpacity( 0.1),

                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),

                ),

                child: Row(

                  children: [

                    Container(

                      padding: const EdgeInsets.all(10),

                      decoration: BoxDecoration(

                        color: primaryBlue.withOpacity( 0.2),

                        shape: BoxShape.circle,

                      ),

                      child: Icon(Icons.warning_rounded, color: primaryBlue, size: 24),

                    ),

                    const SizedBox(width: 16),

                    Expanded(

                      child: Text(

                        "Confirm Attendance",

                        style: GoogleFonts.outfit(

                          fontSize: 20,

                          fontWeight: FontWeight.w800,

                          color: primaryBlue,

                        ),

                      ),

                    ),

                  ],

                ),

              ),

              

              // Body

              Padding(

                padding: const EdgeInsets.all(24),

                child: Column(

                  children: [

                    Text(

                      "Are you sure you want to confirm the attendance?",

                      style: GoogleFonts.outfit(

                        fontSize: 18,

                        fontWeight: FontWeight.w700,

                        color: textColor,

                      ),

                      textAlign: TextAlign.center,

                    ),

                    const SizedBox(height: 20),

                    Container(

                      padding: const EdgeInsets.all(16),

                      decoration: BoxDecoration(

                        color: Colors.amber.withOpacity( 0.1),

                        borderRadius: BorderRadius.circular(12),

                        border: Border.all(

                          color: Colors.amber.withOpacity( 0.3),

                        ),

                      ),

                      child: Row(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          Icon(Icons.info_outline_rounded, color: Colors.amber.shade700, size: 20),

                          const SizedBox(width: 12),

                          Expanded(

                            child: Text(

                              "When you confirm the attendance, students can't enter their attendance anymore.",

                              style: TextStyle(

                                fontSize: 13,

                                color: Colors.amber.shade700,

                                fontWeight: FontWeight.w600,

                                height: 1.4,

                              ),

                            ),

                          ),

                        ],

                      ),

                    ),

                  ],

                ),

              ),

              

              // Footer

              Padding(

                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),

                child: Row(

                  children: [

                    Expanded(

                      child: OutlinedButton(

                        onPressed: () => Navigator.pop(ctx),

                        style: OutlinedButton.styleFrom(

                          padding: const EdgeInsets.symmetric(vertical: 14),

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                          side: BorderSide(color: subTextColor.withOpacity( 0.3)),

                        ),

                        child: Text(

                          "Cancel",

                          style: TextStyle(

                            fontSize: 16,

                            fontWeight: FontWeight.bold,

                            color: subTextColor,

                          ),

                        ),

                      ),

                    ),

                    const SizedBox(width: 16),

                    Expanded(

                      child: ElevatedButton(

                        onPressed: () {

                          Navigator.pop(ctx);

                          _confirmAttendance();

                        },

                        style: ElevatedButton.styleFrom(

                          backgroundColor: primaryBlue,

                          foregroundColor: Colors.white,

                          padding: const EdgeInsets.symmetric(vertical: 14),

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                          elevation: 0,

                        ),

                        child: const Text(

                          "Confirm",

                          style: TextStyle(

                            fontSize: 16,

                            fontWeight: FontWeight.bold,

                          ),

                        ),

                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

        ),

      ),

    );

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



  Future<void> _markPassengerAbsent(String type, int targetUserId) async {

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



      final url = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/$runId/mark-absent";

      final bodyData = {

        "type": type,

        "targetId": targetUserId,

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

          _showSnackBar("Passenger marked absent successfully.", Colors.green);

          await _refreshDetails();

        } else {

          _showSnackBar(data['message'] ?? "Failed to mark absent", Colors.red);

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



  void _showAttendancePopup({

    required String name,

    required String typeLabel,

    required String type,

    required String rollOrCode,

    required String dept,

    required String sessionStatus,

    required int targetUserId,

  }) {

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final Color primaryBlue = const Color(0xFF6366F1);

    

    final bool isStudent = typeLabel == 'Student';

    final IconData typeIcon = isStudent ? Icons.person_rounded : Icons.badge_rounded;

    final Color typeColor = isStudent ? primaryBlue : Colors.purple;



    showDialog(

      context: context,

      builder: (ctx) => Dialog(

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

        backgroundColor: Colors.transparent,

        insetPadding: const EdgeInsets.symmetric(horizontal: 24),

        child: Container(

          decoration: BoxDecoration(

            color: bgColor,

            borderRadius: BorderRadius.circular(24),

            boxShadow: [

              BoxShadow(

                color: Colors.black.withOpacity( 0.1),

                blurRadius: 20,

                offset: const Offset(0, 10),

              ),

            ],

          ),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              // Header

              Container(

                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),

                decoration: BoxDecoration(

                  color: typeColor.withOpacity( 0.1),

                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),

                ),

                child: Row(

                  children: [

                    Container(

                      padding: const EdgeInsets.all(8),

                      decoration: BoxDecoration(

                        color: typeColor.withOpacity( 0.2),

                        shape: BoxShape.circle,

                      ),

                      child: Icon(typeIcon, color: typeColor, size: 20),

                    ),

                    const SizedBox(width: 12),

                    Expanded(

                      child: Text(

                        isStudent ? "Student Details" : "Faculty Details",

                        style: GoogleFonts.outfit(

                          fontSize: 18,

                          fontWeight: FontWeight.w800,

                          color: typeColor,

                        ),

                      ),

                    ),

                    GestureDetector(

                      onTap: () => Navigator.pop(ctx),

                      child: Container(

                        padding: const EdgeInsets.all(6),

                        decoration: BoxDecoration(

                          color: Colors.black.withOpacity( 0.05),

                          shape: BoxShape.circle,

                        ),

                        child: Icon(Icons.close_rounded, size: 18, color: textColor),

                      ),

                    ),

                  ],

                ),

              ),

              

              // Body

              Padding(

                padding: const EdgeInsets.all(24),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    // Name

                    Text(

                      name,

                      style: GoogleFonts.outfit(

                        fontSize: 22,

                        fontWeight: FontWeight.w900,

                        color: textColor,

                      ),

                    ),

                    const SizedBox(height: 16),

                    

                    // Info Row

                    Row(

                      children: [

                        Expanded(

                          child: _buildInfoCard(

                            isStudent ? Icons.pin_rounded : Icons.tag_rounded, 

                            isStudent ? "Roll/Reg No" : "Emp Code", 

                            rollOrCode,

                            bgColor,

                            subTextColor,

                            textColor,

                            isDark,

                          ),

                        ),

                        const SizedBox(width: 12),

                        Expanded(

                          child: _buildInfoCard(

                            Icons.business_rounded, 

                            "Department", 

                            dept.isNotEmpty ? dept : "N/A",

                            bgColor,

                            subTextColor,

                            textColor,

                            isDark,

                          ),

                        ),

                      ],

                    ),

                    const SizedBox(height: 24),

                    

                    // Status

                    Container(

                      width: double.infinity,

                      padding: const EdgeInsets.symmetric(vertical: 12),

                      decoration: BoxDecoration(

                        color: sessionStatus == 'PRESENT' 

                            ? Colors.green.withOpacity( 0.1) 

                            : sessionStatus == 'LEAVE'

                                ? Colors.orange.withOpacity( 0.1)

                                : Colors.red.withOpacity( 0.1),

                        borderRadius: BorderRadius.circular(16),

                        border: Border.all(

                          color: sessionStatus == 'PRESENT' 

                              ? Colors.green.withOpacity( 0.3) 

                              : sessionStatus == 'LEAVE'

                                  ? Colors.orange.withOpacity( 0.3)

                                  : Colors.red.withOpacity( 0.3),

                          width: 1,

                        ),

                      ),

                      child: Column(

                        children: [

                          Text(

                            "Current Status",

                            style: TextStyle(

                              fontSize: 12,

                              fontWeight: FontWeight.w600,

                              color: sessionStatus == 'PRESENT' 

                                  ? Colors.green.shade700 

                                  : sessionStatus == 'LEAVE'

                                      ? Colors.orange.shade700

                                      : Colors.red.shade700,

                            ),

                          ),

                          const SizedBox(height: 4),

                          Text(

                            sessionStatus == 'PRESENT' ? "PRESENT" : sessionStatus == 'LEAVE' ? "LEAVE" : "ABSENT",

                            style: GoogleFonts.outfit(

                              fontSize: 18,

                              fontWeight: FontWeight.w900,

                              color: sessionStatus == 'PRESENT' 

                                  ? Colors.green 

                                  : sessionStatus == 'LEAVE'

                                      ? Colors.orange

                                      : Colors.red,

                              letterSpacing: 1,

                            ),

                          ),

                        ],

                      ),

                    ),

                  ],

                ),

              ),

              

              // Footer

              Padding(

                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),

                child: SizedBox(

                  width: double.infinity,

                  child: ElevatedButton.icon(

                    onPressed: () {

                      Navigator.pop(ctx);

                      if (sessionStatus == 'PRESENT') {

                        _markPassengerAbsent(type, targetUserId);

                      } else {

                        _markPassengerPresent(type, targetUserId);

                      }

                    },

                    icon: Icon(

                      sessionStatus == 'PRESENT' ? Icons.person_off_rounded : Icons.how_to_reg_rounded,

                      size: 20,

                    ),

                    label: Text(

                      sessionStatus == 'PRESENT' ? "MARK AS ABSENT" : "MARK AS PRESENT",

                      style: GoogleFonts.outfit(

                        fontSize: 16,

                        fontWeight: FontWeight.bold,

                        letterSpacing: 1,

                      ),

                    ),

                    style: ElevatedButton.styleFrom(

                      backgroundColor: sessionStatus == 'PRESENT' ? Colors.red : Colors.green,

                      foregroundColor: Colors.white,

                      padding: const EdgeInsets.symmetric(vertical: 16),

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

                      elevation: 0,

                    ),

                  ),

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }



  Widget _buildInfoCard(IconData icon, String title, String value, Color bgColor, Color subTextColor, Color textColor, bool isDark) {

    return Container(

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(

        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(

          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),

        ),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Icon(icon, size: 14, color: subTextColor),

              const SizedBox(width: 6),

              Expanded(

                child: Text(

                  title,

                  style: TextStyle(

                    fontSize: 11,

                    fontWeight: FontWeight.w600,

                    color: subTextColor,

                  ),

                  overflow: TextOverflow.ellipsis,

                ),

              ),

            ],

          ),

          const SizedBox(height: 6),

          Text(

            value,

            style: TextStyle(

              fontSize: 14,

              fontWeight: FontWeight.w800,

              color: textColor,

            ),

            overflow: TextOverflow.ellipsis,

          ),

        ],

      ),

    );

  }



  Future<void> _sendAttendanceReminders(String note) async {

    setState(() => _isLoadingAction = true);

    try {

      final String? token = await UserStore.getToken();

      if (token == null) {

        _showSnackBar("Session expired. Please log in again.", Colors.red);

        return;

      }



      final String runId = _run['id']?.toString() ?? '';

      if (runId.isEmpty) return;



      final url = "${ApiConstants.baseUrl}/daily-bus/bus-runs/$runId/send-attendance-reminders";



      final body = {

        if (note.isNotEmpty) "note": note,

        "is_alert": true,

      };



      final response = await http.post(

        Uri.parse(url),

        headers: ApiConstants.getHeaders(token),

        body: json.encode(body),

      );



      if (response.statusCode == 200 || response.statusCode == 201) {

        _showSnackBar("Reminders sent successfully.", Colors.green);

      } else {

        String errorMsg = "Failed to send reminders.";

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



  void _showFindPopup() {

    showDialog(

      context: context,

      builder: (BuildContext context) {

        final bool isDark = Theme.of(context).brightness == Brightness.dark;

        return Dialog(

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

          backgroundColor: Colors.transparent,

          elevation: 0,

          child: Container(

            padding: const EdgeInsets.all(24),

            decoration: BoxDecoration(

              color: isDark ? const Color(0xFF1E293B) : Colors.white,

              borderRadius: BorderRadius.circular(24),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withOpacity( 0.2),

                  blurRadius: 20,

                  offset: const Offset(0, 10),

                ),

              ],

            ),

            child: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                Container(

                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(

                    color: const Color(0xFF6366F1).withOpacity( 0.1),

                    shape: BoxShape.circle,

                  ),

                  child: const Icon(

                    Icons.notifications_active_rounded,

                    color: Color(0xFF6366F1),

                    size: 32,

                  ),

                ),

                const SizedBox(height: 20),

                Text(

                  "Send Reminders",

                  style: TextStyle(

                    fontSize: 22,

                    fontWeight: FontWeight.w800,

                    color: isDark ? Colors.white : const Color(0xFF0F172A),

                  ),

                  textAlign: TextAlign.center,

                ),

                const SizedBox(height: 16),

                Container(

                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(

                    color: isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB),

                    borderRadius: BorderRadius.circular(12),

                    border: Border.all(

                      color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),

                    ),

                  ),

                  child: Row(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Icon(

                        Icons.warning_amber_rounded,

                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),

                        size: 20,

                      ),

                      const SizedBox(width: 12),

                      Expanded(

                        child: Text(

                          "This will make the absent student and faculty phone to ring as a reminder continuously until they turn it off.",

                          style: TextStyle(

                            fontSize: 14,

                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),

                            fontWeight: FontWeight.w500,

                            height: 1.4,

                          ),

                        ),

                      ),

                    ],

                  ),

                ),

                const SizedBox(height: 28),

                Row(

                  children: [

                    Expanded(

                      child: TextButton(

                        onPressed: () => Navigator.of(context).pop(),

                        style: TextButton.styleFrom(

                          padding: const EdgeInsets.symmetric(vertical: 14),

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                        ),

                        child: Text(

                          "Cancel",

                          style: TextStyle(

                            fontSize: 16,

                            fontWeight: FontWeight.bold,

                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),

                          ),

                        ),

                      ),

                    ),

                    const SizedBox(width: 16),

                    Expanded(

                      child: ElevatedButton(

                        onPressed: () {

                          Navigator.of(context).pop();

                          _sendAttendanceReminders("");

                        },

                        style: ElevatedButton.styleFrom(

                          backgroundColor: const Color(0xFF6366F1),

                          padding: const EdgeInsets.symmetric(vertical: 14),

                          elevation: 0,

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                        ),

                        child: const Text(

                          "Send",

                          style: TextStyle(

                            fontSize: 16,

                            fontWeight: FontWeight.bold,

                            color: Colors.white,

                          ),

                        ),

                      ),

                    ),

                  ],

                ),

              ],

            ),

          ),

        );

      },

    );

  }



  Future<void> _updateAnimationForRun(int animationId) async {

    setState(() => _isLoadingAction = true);

    try {

      final String? token = await UserStore.getToken();

      if (token == null) {

        _showSnackBar("Session expired. Please log in again.", Colors.red);

        return;

      }



      final String runId = _run['id']?.toString() ?? '';

      if (runId.isEmpty) return;



      final url = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/$runId/animation";



      final response = await http.patch(

        Uri.parse(url),

        headers: ApiConstants.getHeaders(token),

        body: json.encode({"animation_id": animationId}),

      );



      if (response.statusCode == 200 || response.statusCode == 201) {

        final Map<String, dynamic> data = json.decode(response.body);

        final String msg = data['message'] ?? "Animation updated successfully.";

        _showSnackBar(msg, Colors.green);

      } else {

        String errorMsg = "Failed to update animation.";

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

              Icon(Icons.assignment_ind_rounded, size: 48, color: subColor.withOpacity( 0.2)),

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

            border: Border.all(color: primaryBlue.withOpacity( 0.1)),

            boxShadow: [

              BoxShadow(

                color: Colors.black.withOpacity( 0.03),

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

                  color: primaryBlue.withOpacity( 0.06),

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

                        color: primaryBlue.withOpacity( 0.1),

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

                        color: titleColor.withOpacity( 0.8),

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

                      color: isDark ? Colors.white.withOpacity( 0.08) : Colors.black.withOpacity( 0.06),

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

                          color: Colors.orange.withOpacity( 0.04),

                          borderRadius: BorderRadius.circular(16),

                          border: Border.all(color: Colors.orange.withOpacity( 0.08)),

                        ),

                        child: Column(

                          children: [

                            Row(

                              children: [

                                CircleAvatar(

                                  radius: 20,

                                  backgroundColor: Colors.orange.withOpacity( 0.1),

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

                                      backgroundColor: Colors.green.withOpacity( 0.08),

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

                                    color: Colors.orange.withOpacity( 0.1),

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



                    // Assigned Faculty for this shift

                    if (_run['morningAssignedFaculty'] != null || _run['eveningAssignedFaculty'] != null) ...[

                      const SizedBox(height: 20),

                      Container(

                        height: 1,

                        color: isDark ? Colors.white.withOpacity( 0.08) : Colors.black.withOpacity( 0.06),

                      ),

                      const SizedBox(height: 20),

                      Row(

                        children: [

                          const Icon(Icons.supervisor_account_rounded, color: Colors.purple, size: 18),

                          const SizedBox(width: 8),

                          Text(

                            "Assigned Faculty",

                            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor),

                          ),

                        ],

                      ),

                      const SizedBox(height: 12),

                      if (shiftCode.contains('MORNING') && _run['morningAssignedFaculty'] != null)

                        AssignmentFacultyMiniCard(

                          faculty: _run['morningAssignedFaculty'],

                          accentColor: Colors.orange,

                          titleColor: titleColor,

                          subColor: subColor,

                          onCall: () => _makePhoneCall(_run['morningAssignedFaculty']['phone']?.toString() ?? ''),

                        )

                      else if (shiftCode.contains('EVENING') && _run['eveningAssignedFaculty'] != null)

                        AssignmentFacultyMiniCard(

                          faculty: _run['eveningAssignedFaculty'],

                          accentColor: Colors.deepPurpleAccent,

                          titleColor: titleColor,

                          subColor: subColor,

                          onCall: () => _makePhoneCall(_run['eveningAssignedFaculty']['phone']?.toString() ?? ''),

                        )

                      else

                        Padding(

                          padding: const EdgeInsets.symmetric(vertical: 8),

                          child: Text("No faculty assigned for this shift", style: TextStyle(color: subColor, fontSize: 13)),

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

          color: isDark ? Colors.white.withOpacity( 0.08) : Colors.black.withOpacity( 0.06),

          width: 1,

        ),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withOpacity( 0.02),

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

                  color: iconColor.withOpacity( 0.08),

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

                  color: titleColor.withOpacity( 0.9),

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

                child: Icon(Icons.location_on_rounded, color: titleColor.withOpacity( 0.6), size: 22),

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

                    color: isDark ? Colors.white.withOpacity( 0.02) : Colors.grey.shade50,

                    borderRadius: BorderRadius.circular(16),

                    border: Border.all(

                      color: (isDark ? Colors.white : Colors.black).withOpacity( 0.04),

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

                    color: isDark ? Colors.white.withOpacity( 0.02) : Colors.grey.shade50,

                    borderRadius: BorderRadius.circular(16),

                    border: Border.all(

                      color: (isDark ? Colors.white : Colors.black).withOpacity( 0.04),

                    ),

                  ),

                  child: Row(

                    children: [

                      Icon(Icons.tag_rounded, size: 16, color: titleColor.withOpacity( 0.5)),

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



    final morningFaculty = _run['morningAssignedFaculty'] ?? myDetails?['morningAssignedFaculty'];

    final eveningFaculty = _run['eveningAssignedFaculty'] ?? myDetails?['eveningAssignedFaculty'];



    final int? assignedFacultyUserId = _run['assigned_faculty_user_id'] != null

        ? int.tryParse(_run['assigned_faculty_user_id'].toString())

        : null;



    final assignments = List.from(_run['assignment'] ?? []);

    Map<String, dynamic>? driver;

    Map<String, dynamic>? driverUser;

    if (assignments.isNotEmpty) {

      final assign = assignments.first;

      driver = assign['driver'] as Map<String, dynamic>?;

      driverUser = _run['driver_assigned']?['user'] as Map<String, dynamic>?;

    }

    final String? driverName = driverUser?['name']?.toString();

    final String? driverUsername = driverUser?['username']?.toString();



    final bool isAssignedFaculty = _getIsAssignedFaculty();



    final bool isNormalUser = _userRole != null &&

        ((_userRole!.toLowerCase() == 'faculty' && !isAssignedFaculty) ||

         _userRole!.toLowerCase() == 'student');



    final bool showMorningQrIcon = isNormalUser && morningStatus.toUpperCase() == 'PRESENT';

    final bool showEveningQrIcon = isNormalUser && eveningStatus.toUpperCase() == 'PRESENT';





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

                color: isDark ? Colors.white.withOpacity( 0.08) : Colors.black.withOpacity( 0.06),

                width: 1,

              ),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withOpacity( 0.02),

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

                    showQrIcon: showMorningQrIcon,

                    onTapQr: () => _fetchAndShowOperationAnimation(shift: 'MORNING'),

                  ),

                ),

                Container(

                  width: 1,

                  height: 50,

                  color: isDark ? Colors.white10 : Colors.black.withOpacity( 0.06),

                  margin: const EdgeInsets.symmetric(horizontal: 16),

                ),

                Expanded(

                  child: _buildAttendanceStatusColumn(

                    "Evening Shift",

                    eveningStatus,

                    isDark,

                    showQrIcon: showEveningQrIcon,

                    onTapQr: () => _fetchAndShowOperationAnimation(shift: 'EVENING'),

                  ),

                ),

              ],

            ),

          ),



          if (morningFaculty != null || eveningFaculty != null) ...[

              const SizedBox(height: 28),

              Text(

                "Assigned Faculties",

                style: GoogleFonts.outfit(

                  fontSize: 18,

                  fontWeight: FontWeight.w900,

                  color: titleColor,

                ),

              ),

              const SizedBox(height: 16),

              if (morningFaculty != null)

                AssignedFacultyCard(

                  faculty: morningFaculty,

                  shiftName: "Morning Shift",

                  icon: Icons.wb_sunny_rounded,

                  iconColor: Colors.orange,

                  isDark: isDark,

                  cardColor: cardColor,

                  titleColor: titleColor,

                  subColor: subColor,

                  onCall: () => _makePhoneCall(morningFaculty['phone']?.toString() ?? ''),

                ),

              if (morningFaculty != null && eveningFaculty != null)

                const SizedBox(height: 12),

              if (eveningFaculty != null)

                AssignedFacultyCard(

                  faculty: eveningFaculty,

                  shiftName: "Evening Shift",

                  icon: Icons.nights_stay_rounded,

                  iconColor: Colors.deepPurpleAccent,

                  isDark: isDark,

                  cardColor: cardColor,

                  titleColor: titleColor,

                  subColor: subColor,

                  onCall: () => _makePhoneCall(eveningFaculty['phone']?.toString() ?? ''),

                ),

            ],

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

                    color: isDark ? Colors.white.withOpacity( 0.08) : Colors.black.withOpacity( 0.06),

                    width: 1,

                  ),

                  boxShadow: [

                    BoxShadow(

                      color: Colors.black.withOpacity( 0.02),

                      blurRadius: 16,

                      offset: const Offset(0, 8),

                    ),

                  ],

                ),

                child: Row(

                  children: [

                    CircleAvatar(

                      radius: 22,

                      backgroundColor: isDark ? Colors.white.withOpacity( 0.05) : Colors.grey.shade100,

                      child: Icon(Icons.person_rounded, color: titleColor.withOpacity( 0.7), size: 22),

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



  Widget _buildAttendanceStatusColumn(

    String title,

    String status,

    bool isDark, {

    bool showQrIcon = false,

    VoidCallback? onTapQr,

  }) {

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

            GestureDetector(

              onTap: showQrIcon ? onTapQr : null,

              behavior: HitTestBehavior.opaque,

              child: Container(

                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                decoration: BoxDecoration(

                  color: statusColor.withOpacity( 0.1),

                  borderRadius: BorderRadius.circular(8),

                ),

                child: Row(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    Text(

                      statusLabel,

                      style: GoogleFonts.outfit(

                        color: statusColor,

                        fontSize: 11,

                        fontWeight: FontWeight.w900,

                        letterSpacing: 0.5,

                      ),

                    ),

                    if (showQrIcon) ...[

                      const SizedBox(width: 6),

                      Icon(

                        Icons.qr_code_rounded,

                        color: statusColor,

                        size: 14,

                      ),

                    ],

                  ],

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

                    color: isDark ? Colors.white.withOpacity( 0.08) : Colors.black.withOpacity( 0.06),

                    width: 1,

                  ),

                  boxShadow: [

                    BoxShadow(

                      color: Colors.black.withOpacity( 0.02),

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

                        color: isDark ? Colors.white.withOpacity( 0.02) : Colors.grey.shade50,

                        borderRadius: const BorderRadius.only(

                          topLeft: Radius.circular(24),

                          topRight: Radius.circular(24),

                        ),

                        border: Border(

                          bottom: BorderSide(

                            color: isDark ? Colors.white.withOpacity( 0.08) : Colors.black.withOpacity( 0.06),

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

                              color: primaryBlue.withOpacity( 0.08),

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

                              color: titleColor.withOpacity( 0.8),

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

                            color: isDark ? Colors.white.withOpacity( 0.08) : Colors.black.withOpacity( 0.06),

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

                                color: isDark ? Colors.white.withOpacity( 0.02) : Colors.grey.shade50,

                                borderRadius: BorderRadius.circular(16),

                                border: Border.all(color: isDark ? Colors.white.withOpacity( 0.08) : Colors.black.withOpacity( 0.06)),

                              ),

                              child: Row(

                                children: [

                                  CircleAvatar(

                                    radius: 20,

                                    backgroundColor: Colors.orange.withOpacity( 0.1),

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

                border: Border.all(color: primaryBlue.withOpacity( 0.1)),

                boxShadow: [

                  BoxShadow(

                    color: Colors.black.withOpacity( 0.02),

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

                                color: primaryBlue.withOpacity( 0.1),

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

                              color: primaryBlue.withOpacity( 0.08),

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

                border: Border.all(color: Colors.orange.withOpacity( 0.1)),

                boxShadow: [

                  BoxShadow(

                    color: Colors.black.withOpacity( 0.02),

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

                                color: Colors.orange.withOpacity( 0.1),

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

                              color: Colors.orange.withOpacity( 0.08),

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

              Icon(Icons.map_rounded, size: 48, color: subColor.withOpacity( 0.2)),

              const SizedBox(height: 12),

              Text("No stops mapped for this routine", style: TextStyle(color: subColor, fontWeight: FontWeight.bold)),

            ],

          ),

        ),

      );

    }



    final sortedStops = List<Map<String, dynamic>>.from(stops.map((s) => Map<String, dynamic>.from(s)));
    sortedStops.sort((a, b) => (a['stop_order'] ?? 0).compareTo(b['stop_order'] ?? 0));

    final bool isSuperOrTransportAdmin = _userRole != null &&
        (_userRole!.toLowerCase() == 'super_admin' ||
         _userRole!.toLowerCase() == 'super admin' ||
         _userRole!.toLowerCase() == 'transport admin' ||
         _userRole!.toLowerCase() == 'transport_admin');

    final bool isAssignedFaculty = _getIsAssignedFaculty();

    final List students = _run['students'] as List? ?? [];
    final List faculties = _run['faculties'] as List? ?? [];
    final List nonTeaching = _run['nonTeachingStaffs'] as List? ?? [];
    final List interns = _run['interns'] as List? ?? [];
    final List allPassengers = [...students, ...faculties, ...nonTeaching, ...interns];

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

        int studentCount = 0;
        int facultyCount = 0;
        int nonTeachingCount = 0;
        int internCount = 0;

        if (isSuperOrTransportAdmin || isAssignedFaculty) {
          final stopIdStr = (stop['stop_id'] ?? stop['id'])?.toString();
          if (stopIdStr != null) {
            void checkStop(List list, void Function() increment) {
              for (var p in list) {
                final bStop = p['boardingStop'];
                final dStop = p['dropStop'];
                final bStopIdStr = (bStop?['stop_id'] ?? bStop?['id'] ?? p['boarding_stop_id'])?.toString();
                final dStopIdStr = (dStop?['stop_id'] ?? dStop?['id'] ?? p['drop_stop_id'])?.toString();
                if (bStopIdStr == stopIdStr || dStopIdStr == stopIdStr) {
                  increment();
                }
              }
            }
            checkStop(students, () => studentCount++);
            checkStop(faculties, () => facultyCount++);
            checkStop(nonTeaching, () => nonTeachingCount++);
            checkStop(interns, () => internCount++);
          }
        }

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
                          color: (isFirst ? const Color(0xFF10B981) : (isLast ? const Color(0xFFEF4444) : primaryBlue)).withOpacity( 0.3),
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
                        color: primaryBlue.withOpacity( 0.3),
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
                    border: Border.all(color: primaryBlue.withOpacity( 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity( 0.02),
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
                              color: (isFirst ? const Color(0xFF10B981) : (isLast ? const Color(0xFFEF4444) : primaryBlue)).withOpacity( 0.1),
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
                      if ((isSuperOrTransportAdmin || isAssignedFaculty) && (studentCount > 0 || facultyCount > 0 || nonTeachingCount > 0 || internCount > 0)) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (studentCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.school_rounded, size: 12, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Student: $studentCount",
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                  ],
                                ),
                              ),
                            if (facultyCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.person_rounded, size: 12, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Faculty: $facultyCount",
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                                    ),
                                  ],
                                ),
                              ),
                            if (nonTeachingCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.teal.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.engineering_rounded, size: 12, color: Colors.teal),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Non-Teaching: $nonTeachingCount",
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal),
                                    ),
                                  ],
                                ),
                              ),
                            if (internCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.purple.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.assignment_ind_rounded, size: 12, color: Colors.purple),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Intern: $internCount",
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
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

              Icon(Icons.people_rounded, size: 48, color: subColor.withOpacity( 0.2)),

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

                                  color: primaryBlue.withOpacity( 0.25),

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

                            color: Colors.black.withOpacity( 0.02),

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

                          hintStyle: TextStyle(color: subColor.withOpacity( 0.5), fontSize: 13, fontWeight: FontWeight.w500),

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

                            color: Colors.black.withOpacity(0.05),

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

                          border: Border.all(color: primaryBlue.withOpacity( 0.04)),

                          boxShadow: [

                            BoxShadow(

                              color: Colors.black.withOpacity( 0.02),

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

                                  backgroundColor: primaryBlue.withOpacity( 0.1),

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

                                      backgroundColor: Colors.green.withOpacity( 0.08),

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

                                  color: primaryBlue.withOpacity( 0.05),

                                  borderRadius: BorderRadius.circular(10),

                                  border: Border.all(color: primaryBlue.withOpacity( 0.1), width: 1),

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

                                          style: TextStyle(fontSize: 11, color: titleColor.withOpacity( 0.8), fontWeight: FontWeight.bold),

                                        ),

                                      ),

                                      if (boardingOtp.isNotEmpty && boardingOtp != 'null') ...[

                                        const SizedBox(width: 8),

                                        Container(

                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),

                                          decoration: BoxDecoration(

                                            color: Colors.green.withOpacity( 0.08),

                                            borderRadius: BorderRadius.circular(6),

                                            border: Border.all(color: Colors.green.withOpacity( 0.15)),

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

                                    style: TextStyle(fontSize: 11, color: titleColor.withOpacity( 0.8), fontWeight: FontWeight.bold),

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

              Icon(Icons.rule_rounded, size: 48, color: subColor.withOpacity( 0.2)),

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
          sessionStatus == _selectedAttendanceStatusFilter ||
          (_selectedAttendanceStatusFilter == 'LEAVE' && sessionStatus == 'ON_LEAVE');



      // Department Filter

      final bool matchesDept = _selectedAttendanceDeptFilter == null ||

          dept == _selectedAttendanceDeptFilter;



      return matchesSearch && matchesType && matchesStatus && matchesDept;

    }).toList();



    int presentCount = 0;
    int absentCount = 0;
    int leaveCount = 0;

    for (var rec in filteredRecords) {
      final String sessionStatus = (_attendanceSessionIndex == 0 
          ? rec['morning_attendance_status'] 
          : rec['evening_attendance_status'])?.toString().toUpperCase() ?? 'ABSENT';
      final isPresent = sessionStatus == 'PRESENT';

      if (sessionStatus == 'PRESENT') {
        presentCount++;
      } else if (sessionStatus == 'LEAVE' || sessionStatus == 'ON_LEAVE') {
        leaveCount++;
      } else {
        absentCount++;
      }
    }



    final bool isSuperOrTransportAdmin = _userRole != null &&

        (_userRole!.toLowerCase() == 'super_admin' ||

         _userRole!.toLowerCase() == 'super admin' ||

         _userRole!.toLowerCase() == 'transport admin' ||

            _userRole!.toLowerCase() == 'transport_admin');

    final int? morningFacultyUserId = _run['morning_assigned_faculty_id'] != null

        ? int.tryParse(_run['morning_assigned_faculty_id'].toString())

        : null;

    final int? eveningFacultyUserId = _run['evening_assigned_faculty_id'] != null

        ? int.tryParse(_run['evening_assigned_faculty_id'].toString())

        : null;

    final bool isAssignedFaculty = _getIsAssignedFaculty();

    final bool showFindButton = isSuperOrTransportAdmin || isAssignedFaculty;



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

                                  color: primaryBlue.withOpacity( 0.25),

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

                        border: Border.all(color: primaryBlue.withOpacity( 0.05)),

                        boxShadow: [

                          BoxShadow(

                            color: Colors.black.withOpacity( 0.02),

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

                          hintStyle: TextStyle(color: subColor.withOpacity( 0.5), fontSize: 13, fontWeight: FontWeight.w500),

                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: subColor),

                          border: InputBorder.none,

                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

                        ),

                      ),

                    ),

                  ),

                  if (showFindButton) ...[

                    const SizedBox(width: 8),

                    GestureDetector(

                      onTap: _showFindPopup,

                      child: Container(

                        padding: const EdgeInsets.all(12),

                        decoration: BoxDecoration(

                          color: isDark ? const Color(0xFF1E293B) : Colors.white,

                          borderRadius: BorderRadius.circular(16),

                          boxShadow: [

                            BoxShadow(

                              color: Colors.black.withOpacity( 0.02),

                              blurRadius: 8,

                              offset: const Offset(0, 4),

                            ),

                          ],

                        ),

                        child: Icon(

                          Icons.ring_volume_rounded,

                          color: primaryBlue,

                          size: 20,

                        ),

                      ),

                    ),

                  ],

                  const SizedBox(width: 8),

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

                            color: Colors.black.withOpacity( 0.02),

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
                      if (isSuperOrTransportAdmin || isAssignedFaculty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity( 0.08),
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
                            color: Colors.red.withOpacity( 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "Absent: $absentCount",
                            style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity( 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "Leave: $leaveCount",
                            style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
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



                      return GestureDetector(

                        onTap: () {

                          if (isSuperOrTransportAdmin || isAssignedFaculty) {

                            final s = rec['student'] as Map?;

                            final f = rec['faculty'] as Map?;

                            final int? targetUserId = type == 'STUDENT'

                                ? (s?['user_id'] ?? s?['user']?['id'] as int?)

                                : (f?['user_id'] ?? f?['user']?['id'] as int?);

                                

                            if (targetUserId != null) {

                              _showAttendancePopup(

                                name: name,

                                typeLabel: typeLabel,

                                type: type,

                                rollOrCode: type == 'STUDENT' ? roll : empCode,

                                dept: dept,

                                sessionStatus: sessionStatus,

                                targetUserId: targetUserId,

                              );

                            } else {

                              _showSnackBar("User ID not found", Colors.red);

                            }

                          }

                        },

                        child: Container(

                          margin: const EdgeInsets.only(bottom: 12),

                          padding: const EdgeInsets.all(14),

                          decoration: BoxDecoration(

                            color: cardColor,

                            borderRadius: BorderRadius.circular(20),

                            border: Border.all(

                              color: sessionStatus == 'PRESENT' 

                                  ? Colors.green.withOpacity( 0.1) 

                                  : sessionStatus == 'LEAVE'

                                      ? Colors.orange.withOpacity( 0.1)

                                      : Colors.red.withOpacity( 0.1),

                            ),

                            boxShadow: [

                              BoxShadow(

                                color: Colors.black.withOpacity( 0.01),

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

                                  color: typeColor.withOpacity( 0.08),

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

                                            color: typeColor.withOpacity( 0.1),

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

                                          color: subColor.withOpacity( 0.8),

                                          fontWeight: FontWeight.w600,

                                        ),

                                      ),

                                      const SizedBox(height: 2),

                                      Text(

                                        "Dept: $dept",

                                        style: TextStyle(

                                          fontSize: 11,

                                          color: subColor.withOpacity( 0.8),

                                          fontWeight: FontWeight.w600,

                                        ),

                                      ),

                                    ] else ...[

                                      Text(

                                        "Emp Code: $empCode  •  $designation",

                                        style: TextStyle(

                                          fontSize: 11,

                                          color: subColor.withOpacity( 0.8),

                                          fontWeight: FontWeight.w600,

                                        ),

                                      ),

                                      const SizedBox(height: 2),

                                      Text(

                                        "Dept: $dept",

                                        style: TextStyle(

                                          fontSize: 11,

                                          color: subColor.withOpacity( 0.8),

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

                                      color: sessionStatus == 'PRESENT' 

                                          ? Colors.green.withOpacity( 0.1) 

                                          : sessionStatus == 'LEAVE'

                                              ? Colors.orange.withOpacity( 0.1)

                                              : Colors.red.withOpacity( 0.1),

                                      borderRadius: BorderRadius.circular(10),

                                    ),

                                    child: Text(

                                      sessionStatus == 'PRESENT' ? "PRESENT" : sessionStatus == 'LEAVE' ? "LEAVE" : "ABSENT",

                                      style: GoogleFonts.outfit(

                                        fontSize: 10,

                                        fontWeight: FontWeight.w900,

                                        color: sessionStatus == 'PRESENT' 

                                            ? Colors.green 

                                            : sessionStatus == 'LEAVE'

                                                ? Colors.orange

                                                : Colors.red,

                                      ),

                                    ),

                                  ),

                                ],

                              ),

                            ],

                          ),

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

        color: color.withOpacity( 0.08),

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: color.withOpacity( 0.15), width: 1),

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

                        color: Colors.grey.withOpacity( 0.3),

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

                          selectedColor: primaryBlue.withOpacity( 0.15),

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

                          selectedColor: primaryBlue.withOpacity( 0.15),

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

                              selectedColor: primaryBlue.withOpacity( 0.15),

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

                        color: Colors.grey.withOpacity( 0.3),

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

                        selectedColor: primaryBlue.withOpacity( 0.15),

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

                        selectedColor: primaryBlue.withOpacity( 0.15),

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

                        selectedColor: primaryBlue.withOpacity( 0.15),

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
                        selectedColor: primaryBlue.withOpacity( 0.15),
                        labelStyle: TextStyle(
                          color: _selectedAttendanceStatusFilter == 'ABSENT' ? primaryBlue : t,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text("Leave"),
                        selected: _selectedAttendanceStatusFilter == 'LEAVE',
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedAttendanceStatusFilter = selected ? 'LEAVE' : null;
                          });
                          setState(() {});
                        },
                        selectedColor: primaryBlue.withOpacity( 0.15),
                        labelStyle: TextStyle(
                          color: _selectedAttendanceStatusFilter == 'LEAVE' ? primaryBlue : t,
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

                              selectedColor: primaryBlue.withOpacity( 0.15),

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









  void _showDirectGatePassPopup(Color primaryBlue, Color titleColor, Color subColor, bool isDark, {String defaultType = 'FN'}) {

    String autoOtp = '';

    final assignments = _run['assignment'] as List? ?? [];

    if (assignments.isNotEmpty) {

      final String targetShift = defaultType == 'AN' ? 'EVENING' : 'MORNING';

      final firstV = assignments.firstWhere((a) => a['shift_code'] == targetShift && a['vehicle']?['vehicle_otp'] != null, orElse: () => null);

      if (firstV != null) {

        autoOtp = firstV['vehicle']['vehicle_otp']?.toString() ?? '';

      }

    }



    final String title = defaultType == 'AN' ? "Direct Gate Out Pass" : "Direct Gate In Pass";



    showDialog(

      context: context,

      builder: (BuildContext context) {

        return Dialog(

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

          backgroundColor: Colors.transparent,

          elevation: 0,

          child: Container(

            padding: const EdgeInsets.all(24),

            decoration: BoxDecoration(

              color: isDark ? const Color(0xFF1E293B) : Colors.white,

              borderRadius: BorderRadius.circular(24),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withOpacity( 0.2),

                  blurRadius: 20,

                  offset: const Offset(0, 10),

                ),

              ],

            ),

            child: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                Container(

                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(

                    color: primaryBlue.withOpacity( 0.1),

                    shape: BoxShape.circle,

                  ),

                  child: Icon(

                    Icons.security_rounded,

                    color: primaryBlue,

                    size: 32,

                  ),

                ),

                const SizedBox(height: 20),

                Text(

                  title,

                  style: GoogleFonts.outfit(

                    fontSize: 22,

                    fontWeight: FontWeight.w800,

                    color: titleColor,

                  ),

                  textAlign: TextAlign.center,

                ),

                const SizedBox(height: 12),

                Text(

                  "Are you sure you want to give the direct gate pass?",

                  style: TextStyle(

                    fontSize: 15,

                    color: subColor,

                    height: 1.4,

                  ),

                  textAlign: TextAlign.center,

                ),

                const SizedBox(height: 28),

                Row(

                  children: [

                    Expanded(

                      child: TextButton(

                        onPressed: () => Navigator.of(context).pop(),

                        style: TextButton.styleFrom(

                          padding: const EdgeInsets.symmetric(vertical: 14),

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                        ),

                        child: Text(

                          "Cancel",

                          style: TextStyle(

                            fontSize: 16,

                            fontWeight: FontWeight.bold,

                            color: subColor,

                          ),

                        ),

                      ),

                    ),

                    const SizedBox(width: 16),

                    Expanded(

                      child: ElevatedButton(

                        onPressed: () {

                          Navigator.of(context).pop();

                          _verifyCampusInOtp(autoOtp, defaultType);

                        },

                        style: ElevatedButton.styleFrom(

                          backgroundColor: primaryBlue,

                          padding: const EdgeInsets.symmetric(vertical: 14),

                          elevation: 0,

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                        ),

                        child: const Text(

                          "Confirm",

                          style: TextStyle(

                            fontSize: 16,

                            fontWeight: FontWeight.bold,

                            color: Colors.white,

                          ),

                        ),

                      ),

                    ),

                  ],

                ),

              ],

            ),

          ),

        );

      },

    );

  }





  Future<void> _startMorningRun(int startOdometer, String datetime, String remarks) async {
    setState(() => _isLoadingAction = true);
    try {
      final String? token = await UserStore.getToken();
      if (token == null) return;
      final String runId = _run['id']?.toString() ?? '';
      if (runId.isEmpty) return;

      final url = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/$runId/start";
      final body = json.encode({
        "start_odometer": startOdometer,
        "datetime": datetime,
        "direct_start_remarks": remarks,
      });

      print('--- API CALL: START MORNING RUN ---');
      print('URL: $url');
      print('HEADERS: ${ApiConstants.getHeaders(token)..addAll({'Content-Type': 'application/json'})}');
      print('BODY: $body');

      final response = await http.patch(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token)..addAll({'Content-Type': 'application/json'}),
        body: body,
      );

      print('RESPONSE STATUS: ${response.statusCode}');
      print('RESPONSE BODY: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar("Morning run started successfully", Colors.green);
        await _refreshDetails();
      } else {
        try {
          final decoded = json.decode(response.body);
          final msg = decoded['detail'] ?? decoded['message'] ?? decoded['error'] ?? response.body;
          _showSnackBar(msg.toString(), Colors.red);
        } catch (_) {
          _showSnackBar("Error: ${response.body}", Colors.red);
        }
      }
    } catch (e) {
      print('EXCEPTION: $e');
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      setState(() => _isLoadingAction = false);
    }
  }



  Future<void> _submitEveningStart(int startOdometer, int passengerCount) async {

    setState(() => _isLoadingAction = true);

    try {

      final String? token = await UserStore.getToken();

      if (token == null) return;

      final String runId = _run['id']?.toString() ?? '';

      if (runId.isEmpty) return;



      final url = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/$runId/campus-out-details";

      final response = await http.patch(

        Uri.parse(url),

        headers: ApiConstants.getHeaders(token)..addAll({'Content-Type': 'application/json'}),

        body: json.encode({

          "start_odometer": startOdometer,

          "passenger_count": passengerCount,

          "latitude": null,

          "longitude": null,

          "image_url": null,

        }),

      );

      if (response.statusCode == 200 || response.statusCode == 201) {

        _showSnackBar("Evening run started successfully", Colors.green);

        await _refreshDetails();

      } else {

        try {

          final decoded = json.decode(response.body);

          final msg = decoded['detail'] ?? decoded['message'] ?? decoded['error'] ?? response.body;

          _showSnackBar(msg.toString(), Colors.red);

        } catch (_) {

          _showSnackBar(response.body, Colors.red);

        }

      }

    } catch (e) {

      _showSnackBar("Error: $e", Colors.red);

    } finally {

      setState(() => _isLoadingAction = false);

    }

  }



  Future<void> _submitEveningOdometer(int endOdometer, bool allowanceNeeded) async {

    setState(() => _isLoadingAction = true);

    try {

      final String? token = await UserStore.getToken();

      if (token == null) return;

      final String runId = _run['id']?.toString() ?? '';

      if (runId.isEmpty) return;



      final url = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/$runId/evening-odometer";

      final response = await http.patch(

        Uri.parse(url),

        headers: ApiConstants.getHeaders(token)..addAll({'Content-Type': 'application/json'}),

        body: json.encode({

          "end_odometer": endOdometer,

          "allowance_needed": allowanceNeeded,

          "latitude": null,

          "longitude": null,

          "image_url": null,

        }),

      );

      if (response.statusCode == 200 || response.statusCode == 201) {

        _showSnackBar("Evening odometer updated", Colors.green);

        await _refreshDetails();

      } else {

        try {

          final decoded = json.decode(response.body);

          final msg = decoded['detail'] ?? decoded['message'] ?? decoded['error'] ?? response.body;

          _showSnackBar(msg.toString(), Colors.red);

        } catch (_) {

          _showSnackBar(response.body, Colors.red);

        }

      }

    } catch (e) {

      _showSnackBar("Error: $e", Colors.red);

    } finally {

      setState(() => _isLoadingAction = false);

    }

  }



  Future<void> _haltEveningBusRun(String datetime, String remarks) async {
    setState(() => _isLoadingAction = true);
    try {
      final String? token = await UserStore.getToken();
      if (token == null) return;
      final String runId = _run['id']?.toString() ?? '';
      if (runId.isEmpty) return;

      final url = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/$runId/halt";
      final response = await http.patch(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token)..addAll({'Content-Type': 'application/json'}),
        body: json.encode({
          "datetime": datetime,
          "direct_halt_remarks": remarks,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {

        _showSnackBar("Bus run halted successfully", Colors.green);

        await _refreshDetails();

      } else {

        try {

          final decoded = json.decode(response.body);

          final msg = decoded['detail'] ?? decoded['message'] ?? decoded['error'] ?? response.body;

          _showSnackBar(msg.toString(), Colors.red);

        } catch (_) {

          _showSnackBar(response.body, Colors.red);

        }

      }

    } catch (e) {

      _showSnackBar("Error: $e", Colors.red);

    } finally {

      setState(() => _isLoadingAction = false);

    }

  }



  Future<void> _pickDateTime(BuildContext context, TextEditingController controller) async {
    final DateTime? date = await CustomDateTimePicker.show(
      context,
      initialDate: DateTime.now(),
      showTime: true,
    );
    if (date != null) {
      controller.text = date.toIso8601String().substring(0, 16);
    }
  }

  void _showStartMorningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    final assignments = _run['assignment'] as List? ?? [];
    final activeAssignment = assignments.firstWhere((a) => a['shift_code'] == 'MORNING', orElse: () => null);
    final correctVehicle = activeAssignment?['vehicle'];
    final correctOdometer = correctVehicle?['current_odometer'] ?? 0;
    
    final TextEditingController odometerController = TextEditingController(text: correctOdometer.toString());
    final TextEditingController datetimeController = TextEditingController();
    final TextEditingController remarksController = TextEditingController();
    final String campusInCount = _run['campus_in_count']?.toString() ?? '0';

    // Pre-fill datetime
    datetimeController.text = DateTime.now().toIso8601String().substring(0, 16);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Direct start (FN)", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: titleColor)),
              const SizedBox(height: 6),
              Text(
                "Submit details to start the morning run.",
                style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: odometerController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: "Start Odometer Reading",
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
              const SizedBox(height: 16),
              TextField(
                controller: datetimeController,
                readOnly: true,
                onTap: () => _pickDateTime(ctx, datetimeController),
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: "Date & Time",
                  labelStyle: TextStyle(color: subColor),
                  hintText: "Select date and time",
                  prefixIcon: Icon(Icons.calendar_month_rounded, color: primaryBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: primaryBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: remarksController,
                maxLines: 2,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: "Remarks",
                  labelStyle: TextStyle(color: subColor),
                  hintText: "Enter remarks for direct start",
                  prefixIcon: Icon(Icons.notes_rounded, color: primaryBlue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: primaryBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people_alt_rounded, color: primaryBlue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Passenger Count",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      campusInCount,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final int? odo = int.tryParse(odometerController.text);
                    final String dt = datetimeController.text.trim();
                    final String rm = remarksController.text.trim();
                    if (odo != null && dt.isNotEmpty) {
                      Navigator.pop(ctx);
                      _startMorningRun(odo, dt, rm);
                    } else {
                      _showSnackBar("Please fill all required fields", Colors.orange);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text("Start Morning Run", style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHaltBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    final TextEditingController datetimeController = TextEditingController();
    final TextEditingController remarksController = TextEditingController();

    datetimeController.text = DateTime.now().toIso8601String().substring(0, 16);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Halt Run", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.orange)),
              const SizedBox(height: 6),
              Text(
                "Provide details to manually halt the run.",
                style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: datetimeController,
                readOnly: true,
                onTap: () => _pickDateTime(ctx, datetimeController),
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: "Date & Time",
                  labelStyle: TextStyle(color: subColor),
                  hintText: "Select date and time",
                  prefixIcon: const Icon(Icons.calendar_month_rounded, color: Colors.orange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.orange, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: remarksController,
                maxLines: 2,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: "Remarks",
                  labelStyle: TextStyle(color: subColor),
                  hintText: "Enter reason for halting",
                  prefixIcon: const Icon(Icons.notes_rounded, color: Colors.orange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.orange, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final String dt = datetimeController.text.trim();
                    final String rm = remarksController.text.trim();
                    if (dt.isNotEmpty && rm.isNotEmpty) {
                      Navigator.pop(ctx);
                      _haltEveningBusRun(dt, rm);
                    } else {
                      _showSnackBar("Remarks and DateTime are required", Colors.orange);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text("Halt Run", style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  void _showStartEveningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {

    final assignments = _run['assignment'] as List? ?? [];
    final activeAssignment = assignments.firstWhere((a) => a['shift_code'] == 'EVENING', orElse: () => null);
    final correctVehicle = activeAssignment?['vehicle'];
    final correctOdometer = correctVehicle?['current_odometer'] ?? 0;

    final TextEditingController odometerController = TextEditingController(text: correctOdometer.toString());

    final String campusOutCount = _run['campus_out_count']?.toString() ?? '0';



    showModalBottomSheet(

      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (ctx) => Padding(

        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 24),

        child: Container(

          padding: const EdgeInsets.all(24),

          decoration: BoxDecoration(

            color: isDark ? const Color(0xFF1E293B) : Colors.white,

            borderRadius: BorderRadius.circular(28),

            boxShadow: [

              BoxShadow(

                color: Colors.black.withOpacity( 0.15),

                blurRadius: 30,

                offset: const Offset(0, 10),

              ),

            ],

          ),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text("Direct start AN", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: titleColor)),

              const SizedBox(height: 6),

              Text(

                "Submit details to start the evening run.",

                style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w500),

              ),

              const SizedBox(height: 20),

              TextField(

                controller: odometerController,

                keyboardType: TextInputType.number,

                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),

                decoration: InputDecoration(

                  labelText: "Start Odometer Reading",

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

              const SizedBox(height: 16),

              Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [

                  Row(

                    children: [

                      Icon(Icons.people_alt_rounded, color: primaryBlue, size: 20),

                      const SizedBox(width: 8),

                      Text(

                        "Passenger Count",

                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor),

                      ),

                    ],

                  ),

                  Container(

                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

                    decoration: BoxDecoration(

                      color: primaryBlue.withOpacity( 0.1),

                      borderRadius: BorderRadius.circular(12),

                    ),

                    child: Text(

                      campusOutCount,

                      style: GoogleFonts.outfit(

                        fontSize: 16,

                        fontWeight: FontWeight.w800,

                        color: primaryBlue,

                      ),

                    ),

                  ),

                ],

              ),

              const SizedBox(height: 24),

              SizedBox(

                width: double.infinity,

                child: ElevatedButton(

                  onPressed: () {

                    final int? odo = int.tryParse(odometerController.text);

                    if (odo != null) {

                      Navigator.pop(ctx);

                      _submitEveningStart(odo, 0); // Passenger count is not required for evening start

                    } else {

                      _showSnackBar("Invalid odometer reading", Colors.orange);

                    }

                  },

                  style: ElevatedButton.styleFrom(

                    backgroundColor: primaryBlue,

                    foregroundColor: Colors.white,

                    padding: const EdgeInsets.symmetric(vertical: 16),

                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

                    elevation: 0,

                  ),

                  child: Text("Start Evening Run", style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900)),

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }



  void _showEndEveningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {

    final TextEditingController odometerController = TextEditingController();

    bool allowanceNeeded = false;

    showModalBottomSheet(

      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (ctx) => StatefulBuilder(

        builder: (context, setModalState) => Padding(

          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 24),

          child: Container(

            padding: const EdgeInsets.all(24),

            decoration: BoxDecoration(

              color: isDark ? const Color(0xFF1E293B) : Colors.white,

              borderRadius: BorderRadius.circular(28),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withOpacity( 0.15),

                  blurRadius: 30,

                  offset: const Offset(0, 10),

                ),

              ],

            ),

            child: Column(

              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text("Direct end AN", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: titleColor)),

                const SizedBox(height: 6),

                Text(

                  "Submit final shift details for evening routine.",

                  style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w500),

                ),

                const SizedBox(height: 20),

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

                SizedBox(

                  width: double.infinity,

                  child: ElevatedButton(

                    onPressed: () {

                      final int? odo = int.tryParse(odometerController.text);

                      if (odo != null) {

                        Navigator.pop(ctx);

                        _submitEveningOdometer(odo, allowanceNeeded);

                      } else {

                        _showSnackBar("Invalid numeric values", Colors.orange);

                      }

                    },

                    style: ElevatedButton.styleFrom(

                      backgroundColor: primaryBlue,

                      foregroundColor: Colors.white,

                      padding: const EdgeInsets.symmetric(vertical: 16),

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),

                      elevation: 0,

                    ),

                    child: Text("Submit End Details", style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900)),

                  ),

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }



  void _showEndMorningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {

    final TextEditingController odometerController = TextEditingController();

    final String campusInCount = _run['campus_in_count']?.toString() ?? '0';

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

                  color: Colors.black.withOpacity( 0.15),

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

                    const SizedBox(height: 16),

                    Row(

                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [

                        Row(

                          children: [

                            Icon(Icons.people_alt_rounded, color: primaryBlue, size: 20),

                            const SizedBox(width: 8),

                            Text(

                              "Passenger Count",

                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor),

                            ),

                          ],

                        ),

                        Container(

                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

                          decoration: BoxDecoration(

                            color: primaryBlue.withOpacity( 0.1),

                            borderRadius: BorderRadius.circular(12),

                          ),

                          child: Text(

                            campusInCount,

                            style: GoogleFonts.outfit(

                              fontSize: 16,

                              fontWeight: FontWeight.w800,

                              color: primaryBlue,

                            ),

                          ),

                        ),

                      ],

                    ),

                    const SizedBox(height: 24),



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

                          final int? paxVal = int.tryParse(campusInCount);

                          if (odometerVal == null) {

                            _showSnackBar("Invalid numeric values", Colors.orange);

                            return;

                          }

                          Navigator.pop(context);

                          _submitMorningOdometer(odometerVal, paxVal, allowanceNeeded);

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



  Widget _buildDualBottomButtonColumn(

    String text1, IconData icon1, Color color1, VoidCallback? onPressed1,

    String text2, IconData icon2, Color color2, VoidCallback? onPressed2,

    bool isDark

  ) {

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(

      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomPadding),

      decoration: BoxDecoration(

        color: isDark ? const Color(0xFF1E293B) : Colors.white,

        boxShadow: [

          BoxShadow(

            color: Colors.black.withOpacity( 0.05),

            blurRadius: 10,

            offset: const Offset(0, -4),

          ),

        ],

      ),

      child: Column(

        mainAxisSize: MainAxisSize.min,

        children: [

          _buildInnerButton(text1, icon1, color1, onPressed1),

          const SizedBox(height: 12),

          _buildInnerButton(text2, icon2, color2, onPressed2),

        ],

      ),

    );

  }



  Widget _buildInnerButton(String text, IconData icon, Color primaryBlue, VoidCallback? onPressed) {

    return Container(

      width: double.infinity,

      decoration: BoxDecoration(

        borderRadius: BorderRadius.circular(16),

        boxShadow: [

          if (onPressed != null)

            BoxShadow(

              color: primaryBlue.withOpacity( 0.3),

              blurRadius: 12,

              offset: const Offset(0, 4),

            ),

        ],

      ),

      child: ElevatedButton(

        onPressed: onPressed,

        style: ElevatedButton.styleFrom(

          backgroundColor: primaryBlue,

          foregroundColor: Colors.white,

          padding: const EdgeInsets.symmetric(vertical: 18),

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

                  Icon(icon, size: 24),

                  const SizedBox(width: 10),

                  Text(

                    text,

                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),

                  ),

                ],

              ),

      ),

    );

  }



  Widget _buildBottomButton(String text, IconData icon, Color primaryBlue, bool isDark, VoidCallback? onPressed) {

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(

      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomPadding),

      decoration: BoxDecoration(

        color: isDark ? const Color(0xFF1E293B) : Colors.white,

        boxShadow: [

          BoxShadow(

            color: Colors.black.withOpacity( 0.05),

            blurRadius: 10,

            offset: const Offset(0, -4),

          ),

        ],

      ),

      child: Container(

        decoration: BoxDecoration(

          borderRadius: BorderRadius.circular(16),

          boxShadow: [

            if (onPressed != null)

              BoxShadow(

                color: primaryBlue.withOpacity( 0.3),

                blurRadius: 12,

                offset: const Offset(0, 4),

              ),

          ],

        ),

        child: ElevatedButton(

          onPressed: onPressed,

          style: ElevatedButton.styleFrom(

            backgroundColor: primaryBlue,

            foregroundColor: Colors.white,

            padding: const EdgeInsets.symmetric(vertical: 18),

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

                    Icon(icon, size: 24),

                    const SizedBox(width: 10),

                    Text(

                      text,

                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),

                    ),

                  ],

                ),

        ),

      ),

    );

  }



  Future<void> _deleteTrip(BuildContext context) async {

    try {

      final token = await UserStore.getToken();

      final url = Uri.parse('${ApiConstants.baseUrl}/daily-bus/delete-runs/${_run['id']}');

      

      final response = await http.delete(

        url,

        headers: {

          'accept': '*/*',

          'authorization': 'TMS $token',

        },

      );

      

      if (response.statusCode == 200 || response.statusCode == 204) {

        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(

            const SnackBar(content: Text('Trip deleted successfully', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),

          );

          Navigator.pop(context, true); 

        }

      } else {

        if (mounted) {

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ApiErrorParser.parse(response, fallback: 'Failed to delete trip'), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
          );
        }
      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Error deleting trip: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),

        );

      }

    }

  }



  void _confirmDeleteTrip(BuildContext context) {

    showDialog(

      context: context,

      builder: (dialogContext) {

        final bool isDark = Theme.of(dialogContext).brightness == Brightness.dark;

        return Dialog(

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

          backgroundColor: Colors.transparent,

          elevation: 0,

          child: Container(

            padding: const EdgeInsets.all(24),

            decoration: BoxDecoration(

              color: isDark ? const Color(0xFF1E293B) : Colors.white,

              borderRadius: BorderRadius.circular(24),

              boxShadow: [

                BoxShadow(

                  color: Colors.black.withOpacity( 0.2),

                  blurRadius: 20,

                  offset: const Offset(0, 10),

                ),

              ],

            ),

            child: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                Container(

                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(

                    color: Colors.red.withOpacity( 0.1),

                    shape: BoxShape.circle,

                  ),

                  child: const Icon(

                    Icons.delete_forever_rounded,

                    color: Colors.red,

                    size: 32,

                  ),

                ),

                const SizedBox(height: 20),

                Text(

                  "Delete Trip",

                  style: TextStyle(

                    fontSize: 22,

                    fontWeight: FontWeight.w800,

                    color: isDark ? Colors.white : const Color(0xFF0F172A),

                  ),

                  textAlign: TextAlign.center,

                ),

                const SizedBox(height: 12),

                Text(

                  "Are you sure you want to delete this trip? This action cannot be undone.",

                  style: TextStyle(

                    fontSize: 15,

                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),

                    height: 1.4,

                  ),

                  textAlign: TextAlign.center,

                ),

                const SizedBox(height: 28),

                Row(

                  children: [

                    Expanded(

                      child: TextButton(

                        onPressed: () => Navigator.pop(dialogContext),

                        style: TextButton.styleFrom(

                          padding: const EdgeInsets.symmetric(vertical: 14),

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                        ),

                        child: Text(

                          "Cancel",

                          style: TextStyle(

                            fontSize: 16,

                            fontWeight: FontWeight.bold,

                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),

                          ),

                        ),

                      ),

                    ),

                    const SizedBox(width: 16),

                    Expanded(

                      child: ElevatedButton(

                        onPressed: () {

                          Navigator.pop(dialogContext);

                          _deleteTrip(context);

                        },

                        style: ElevatedButton.styleFrom(

                          backgroundColor: Colors.red,

                          padding: const EdgeInsets.symmetric(vertical: 14),

                          elevation: 0,

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

                        ),

                        child: const Text(

                          "Delete",

                          style: TextStyle(

                            fontSize: 16,

                            fontWeight: FontWeight.bold,

                            color: Colors.white,

                          ),

                        ),

                      ),

                    ),

                  ],

                ),

              ],

            ),

          ),

        );

      },

    );

  }



  Widget _buildSkeletonLoading(bool isDark, Color cardColor, Color bgColor, Color titleColor, Color subColor) {

    final shimmerBase = isDark ? Colors.white.withOpacity( 0.05) : Colors.grey.shade200;

    final shimmerHighlight = isDark ? Colors.white.withOpacity( 0.15) : Colors.grey.shade100;



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

    final String status = _run['status'] ?? 'PENDING';



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

        (_userRole!.toLowerCase() == 'super_admin' ||

         _userRole!.toLowerCase() == 'super admin' ||

         _userRole!.toLowerCase() == 'transport admin' ||

            _userRole!.toLowerCase() == 'transport_admin');



    final int? morningFacultyUserId = _run['morning_assigned_faculty_id'] != null

        ? int.tryParse(_run['morning_assigned_faculty_id'].toString())

        : null;

    final int? eveningFacultyUserId = _run['evening_assigned_faculty_id'] != null

        ? int.tryParse(_run['evening_assigned_faculty_id'].toString())

        : null;

    final bool isAssignedFaculty = _getIsAssignedFaculty();

    final int studentCount = (_run['students'] as List?)?.length ?? 0;
    final int facultyCount = (_run['faculties'] as List?)?.length ?? 0;
    final int internCount = (_run['interns'] as List?)?.length ?? 0;
    final int nonTeachingCount = (_run['nonTeachingStaffs'] as List?)?.length ?? 0;

    final List<String> passengerParts = [];
    if (studentCount > 0) passengerParts.add("$studentCount ${studentCount == 1 ? 'Student' : 'Students'}");
    if (facultyCount > 0) passengerParts.add("$facultyCount Faculty");
    if (nonTeachingCount > 0) passengerParts.add("$nonTeachingCount Non-Teaching");
    if (internCount > 0) passengerParts.add("$internCount ${internCount == 1 ? 'Intern' : 'Interns'}");
    final String passengerSummary = passengerParts.isNotEmpty ? passengerParts.join(" • ") : "No passengers assigned";

    final bool showQrCodeButton = (isSuperOrTransportAdmin || isAssignedFaculty) &&

        (s == 'STARTED' ||

         s == 'ARRIVED_CAMPUS' ||

         s == 'FN_COMPLETED' ||

         s == 'AN_STARTED' ||

         s == 'DEPARTED_CAMPUS');



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

    final bool isAn = s.contains('AN') || s == 'FN_COMPLETED' || s == 'DEPARTED_CAMPUS' || s == 'HALTED';

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



    final bool canConfirm = isSuperOrTransportAdmin || (isAssignedFaculty && isPresent);

    

    final bool checkMorningConfirm = (s == 'ARRIVED_CAMPUS') && !isMorningConfirmed;

    final bool checkEveningConfirm = (s == 'FN_COMPLETED' || s == 'AN_STARTED' || s == 'DEPARTED_CAMPUS' || s == 'HALTED') && !isEveningConfirmed;

    

    final bool showConfirmAttendance = canConfirm && (checkMorningConfirm || checkEveningConfirm) && !_localAttendanceConfirmed;



    final String roleLower = _userRole?.toLowerCase() ?? '';

    final bool showOnlyHeaderAndAttendance = _userRole != null &&

        ((roleLower == 'faculty' ||

          roleLower == 'student' ||

          roleLower == 'intern' ||

          roleLower == 'non teaching' ||

          roleLower == 'non teaching faculty' ||

          roleLower.contains('teaching')) &&

         !isAssignedFaculty);



    final bool showScanQrCodeButtonForNormal = showOnlyHeaderAndAttendance && (

        ((s == 'STARTED' || s == 'ARRIVED_CAMPUS' || s == 'CAMPUS_IN') && morningStatus != 'PRESENT') ||

        (s == 'FN_COMPLETED' && eveningStatus != 'PRESENT')

    );



    Widget? bottomBar;

    if (isSuperOrTransportAdmin) {

      if (isPlanned) {

        bottomBar = _buildBottomButton("Mark Run Ready", Icons.check_circle_rounded, primaryBlue, isDark, _isLoadingAction ? null : _markRunReady);

      } else if (s == 'READY') {

        bottomBar = _buildBottomButton("Direct start (FN)", Icons.play_circle_fill_rounded, primaryBlue, isDark, _isLoadingAction ? null : () => _showStartMorningBottomSheet(primaryBlue, titleColor, subColor, isDark));

      } else if (s == 'ARRIVED_CAMPUS') {

        if (showConfirmAttendance) {

          bottomBar = _buildDualBottomButtonColumn(

            "Confirm Attendance", Icons.check_circle_rounded, Colors.green, _isLoadingAction ? null : _showConfirmAttendancePopup,

            "Direct end (FN)", Icons.stop_circle_rounded, primaryBlue, _isLoadingAction ? null : () => _showEndMorningBottomSheet(primaryBlue, titleColor, subColor, isDark),

            isDark

          );

        } else {

          bottomBar = _buildBottomButton("Direct end button (FN)", Icons.stop_circle_rounded, primaryBlue, isDark, _isLoadingAction ? null : () => _showEndMorningBottomSheet(primaryBlue, titleColor, subColor, isDark));

        }

      } else if (s == 'FN_COMPLETED') {

        if (showConfirmAttendance) {

          bottomBar = _buildDualBottomButtonColumn(

            "Confirm Attendance", Icons.check_circle_rounded, Colors.green, _isLoadingAction ? null : _showConfirmAttendancePopup,

            "Direct start AN", Icons.play_circle_fill_rounded, primaryBlue, _isLoadingAction ? null : () => _showStartEveningBottomSheet(primaryBlue, titleColor, subColor, isDark),

            isDark

          );

        } else {

          bottomBar = _buildBottomButton("Direct start AN", Icons.play_circle_fill_rounded, primaryBlue, isDark, _isLoadingAction ? null : () => _showStartEveningBottomSheet(primaryBlue, titleColor, subColor, isDark));

        }

      } else if (s == 'DEPARTED_CAMPUS') {

        bottomBar = _buildBottomButton("Halt", Icons.pan_tool_rounded, Colors.orange, isDark, _isLoadingAction ? null : () => _showHaltBottomSheet(primaryBlue, titleColor, subColor, isDark));

      } else if (s == 'HALTED') {

        bottomBar = _buildBottomButton("Direct end AN", Icons.stop_circle_rounded, primaryBlue, isDark, _isLoadingAction ? null : () => _showEndEveningBottomSheet(primaryBlue, titleColor, subColor, isDark));

      } else if (isStarted) {

        bottomBar = _buildBottomButton(

          s == 'AN_STARTED' ? "Direct Gate Out Verification" : "Direct Gate In Verification",

          Icons.vpn_key_rounded,

          primaryBlue,

          isDark,

          _isLoadingAction

              ? null

              : () => _showDirectGatePassPopup(

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

        _isLoadingAction ? null : _showConfirmAttendancePopup,

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

            color: statusColor.withOpacity( 0.15),

          ),

          boxShadow: [

            BoxShadow(

              color: statusColor.withOpacity( 0.03),

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

                color: statusColor.withOpacity( 0.05),

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

                      color: subColor.withOpacity( 0.8),

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

                        color: subColor.withOpacity( 0.6),

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



    final bool isDriver = _userRole != null && _userRole!.toLowerCase() == 'driver';



    final List<Tab> tabsList;

    final List<Widget> tabViews;



    if (showOnlyHeaderAndAttendance) {

      tabsList = const [

        Tab(text: "My Details"),

        Tab(text: "Assignment"),

      ];

      tabViews = [

        _buildMyDetailsTab(isDark, titleColor, subColor, primaryBlue, cardColor, morningStatus, eveningStatus),

        _buildAssignmentsTabForNormalFaculty(isDark, titleColor, subColor, primaryBlue, cardColor),

      ];

    } else if (isDriver) {

      tabsList = const [

        Tab(text: "Assignments"),

        Tab(text: "Vehicle"),

        Tab(text: "Timeline"),

      ];

      tabViews = [

        _buildAssignmentsTab(isDark, titleColor, subColor, primaryBlue, cardColor),

        _buildVehicleTab(isDark, titleColor, subColor, primaryBlue, cardColor),

        _buildTimelineTab(isDark, titleColor, subColor, primaryBlue),

      ];

    } else if (isSuperOrTransportAdmin) {

      tabsList = const [

        Tab(text: "Assignments"),

        Tab(text: "Vehicle"),

        Tab(text: "Timeline"),

        Tab(text: "Passengers"),

        Tab(text: "Attendance"),

      ];

      tabViews = [

        _buildAssignmentsTab(isDark, titleColor, subColor, primaryBlue, cardColor),

        _buildVehicleTab(isDark, titleColor, subColor, primaryBlue, cardColor),

        _buildTimelineTab(isDark, titleColor, subColor, primaryBlue),

        _buildPassengersTab(isDark, titleColor, subColor, primaryBlue, cardColor),

        _buildAttendanceTab(isDark, titleColor, subColor, primaryBlue, cardColor),

      ];

    } else {

      tabsList = const [

        Tab(text: "Assignments"),

        Tab(text: "Timeline"),

        Tab(text: "Passengers"),

        Tab(text: "Attendance"),

      ];

      tabViews = [

        _buildAssignmentsTab(isDark, titleColor, subColor, primaryBlue, cardColor),

        _buildTimelineTab(isDark, titleColor, subColor, primaryBlue),

        _buildPassengersTab(isDark, titleColor, subColor, primaryBlue, cardColor),

        _buildAttendanceTab(isDark, titleColor, subColor, primaryBlue, cardColor),

      ];

    }



    return DefaultTabController(

      key: ValueKey('tab_controller_${showOnlyHeaderAndAttendance}_$isDriver'),

      length: tabsList.length,

      child: Scaffold(

        backgroundColor: bgColor,

        body: SafeArea(

          child: RefreshIndicator(

            onRefresh: _refreshDetails,

            notificationPredicate: (ScrollNotification notification) {

              // Ensure refresh triggers properly regardless of scroll view depth inside tabs

              return notification.metrics.axis == Axis.vertical;

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

                                        if (showQrCodeButton) ...[

                                          GestureDetector(

                                            onTap: _showQrCodeBottomSheet,

                                            child: Icon(Icons.qr_code_rounded, color: primaryBlue, size: 24),

                                          ),

                                          const SizedBox(width: 16),

                                        ],

                                        if (isSuperOrTransportAdmin) ...[



                                          GestureDetector(

                                            onTap: _refreshDetails,

                                            child: Icon(Icons.refresh_rounded, color: primaryBlue, size: 24),

                                          ),

                                          if (isEditable && (widget.showEditIcon || isAssignedFaculty))

                                            const SizedBox(width: 16),

                                        ],

                                        if (isEditable && ((isSuperOrTransportAdmin && widget.showEditIcon) || isAssignedFaculty))

                                          GestureDetector(

                                            onTap: () async {

                                              final result = await Navigator.push(

                                                context,

                                                MaterialPageRoute(

                                                  builder: (context) => EditVehicleDriverPage(

                                                    run: _run,

                                                    editFacultyOnly: isAssignedFaculty && !isSuperOrTransportAdmin,

                                                  ),

                                                ),

                                              );

                                              if (result == true) {

                                                _refreshDetails();

                                              }

                                            },

                                            child: (isAssignedFaculty && !isSuperOrTransportAdmin)

                                                ? Padding(
                                                    padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.swap_horiz_rounded, color: primaryBlue, size: 18),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          "Transfer",
                                                          style: TextStyle(
                                                            color: primaryBlue,
                                                            fontWeight: FontWeight.w900,
                                                            fontSize: 14,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )

                                                : Icon(Icons.edit_rounded, color: primaryBlue, size: 24),

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

                                          style: GoogleFonts.outfit(

                                            fontSize: 22,

                                            fontWeight: FontWeight.w900,

                                            color: titleColor,

                                            height: 1.2,

                                          ),

                                        ),

                                        if (isSuperOrTransportAdmin || isAssignedFaculty) ...[

                                          const SizedBox(height: 6),

                                          Text(

                                            passengerSummary,

                                            style: GoogleFonts.outfit(

                                              fontSize: 12,

                                              fontWeight: FontWeight.w700,

                                              color: primaryBlue,

                                            ),

                                          ),

                                        ],

                                      ],

                                    ),

                                  ),

                                  Row(

                                    children: [

                                      if (isSuperOrTransportAdmin && s == 'PLANNED') ...[

                                        GestureDetector(

                                          onTap: () => _confirmDeleteTrip(context),

                                          child: const Icon(Icons.delete_rounded, color: Colors.red, size: 24),

                                        ),

                                        const SizedBox(width: 12),

                                      ],

                                      _buildStatusBadge(status),

                                    ],

                                  ),

                                ],

                              ),

                            ],

                          ),

                        ),

                        ?facultyAttendanceWidget,

                        // Custom sliding segments TabBar Layout and View

                        Container(

                          margin: const EdgeInsets.symmetric(horizontal: 24),

                          padding: const EdgeInsets.all(6),

                          decoration: BoxDecoration(

                            color: isDark ? const Color(0xFF1E293B) : Colors.white,

                            borderRadius: BorderRadius.circular(18),

                            border: Border.all(color: primaryBlue.withOpacity( 0.08)),

                            boxShadow: [

                              BoxShadow(

                                color: Colors.black.withOpacity( 0.02),

                                blurRadius: 10,

                                offset: const Offset(0, 4),

                              ),

                            ],

                          ),

                          child: TabBar(

                            dividerColor: Colors.transparent,

                            isScrollable: tabsList.length > 3,

                            tabAlignment: tabsList.length <= 3 ? TabAlignment.fill : TabAlignment.center,

                            indicator: BoxDecoration(

                              color: primaryBlue,

                              borderRadius: BorderRadius.circular(14),

                              boxShadow: [

                                BoxShadow(

                                  color: primaryBlue.withOpacity( 0.25),

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

                            tabs: tabsList,

                          ),

                        ),

                        const SizedBox(height: 12),

                      ],

                    ),

                  ),

                ];

              },

              body: TabBarView(

                children: tabViews,

              ),

            ),

          ),

        ),

        bottomNavigationBar: bottomBar,
        floatingActionButton: showOnlyHeaderAndAttendance 
            ? FloatingActionButton(
                onPressed: _showBusChangeRequestModal,
                backgroundColor: primaryBlue,
                child: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
              )
            : null,
      ),

    );

  }



  Widget _buildGridItem(IconData icon, String label, String value, Color accentColor, Color titleColor, Color subColor) {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

      decoration: BoxDecoration(

        color: accentColor.withOpacity( 0.04),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: accentColor.withOpacity( 0.08)),

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

        color: accentColor.withOpacity( 0.08),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: accentColor.withOpacity( 0.15)),

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

    final Color activeColor = isActive ? primaryBlue : subColor.withOpacity( 0.4);

    final Color bgValues = isActive

        ? primaryBlue.withOpacity( 0.05)

        : (isDark ? Colors.white.withOpacity( 0.02) : Colors.black.withOpacity( 0.01));

    final Color borderValues = isActive

        ? primaryBlue.withOpacity( 0.2)

        : (isDark ? Colors.white.withOpacity( 0.05) : Colors.black.withOpacity( 0.04));



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

                  color: isActive ? textColor : subColor.withOpacity( 0.6),

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

                  color: isActive ? primaryBlue : subColor.withOpacity( 0.4),

                ),

              ),

            ],

          ),

        ],

      ),

    );

  }



  Future<void> _showQrCodeBottomSheet() async {

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);



    showModalBottomSheet(

      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (context) {

        return FutureBuilder<List<dynamic>?>(

          future: _fetchQrCodeAnimations(),

          builder: (context, snapshot) {

            Widget content;



            if (snapshot.connectionState == ConnectionState.waiting) {

              content = const SizedBox(

                height: 250,

                child: Center(

                  child: CircularProgressIndicator(),

                ),

              );

            } else if (snapshot.hasError || snapshot.data == null) {

              content = SizedBox(

                height: 250,

                child: Center(

                  child: Text(

                    "Failed to load animations",

                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),

                  ),

                ),

              );

            } else {

              final animations = snapshot.data!;

              if (animations.isEmpty) {

                content = SizedBox(

                  height: 200,

                  child: Center(

                    child: Text(

                      "No animations available",

                      style: TextStyle(color: subColor),

                    ),

                  ),

                );

              } else {

                content = Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    Text(

                      "Select Any QR Animation",

                      style: GoogleFonts.outfit(

                        fontSize: 20,

                        fontWeight: FontWeight.w900,

                        color: titleColor,

                      ),

                      textAlign: TextAlign.center,

                    ),

                    const SizedBox(height: 20),

                    ConstrainedBox(

                      constraints: BoxConstraints(

                        maxHeight: MediaQuery.of(context).size.height * 0.6,

                      ),

                      child: ListView.separated(

                        shrinkWrap: true,

                        physics: const BouncingScrollPhysics(),

                        itemCount: animations.length,

                        separatorBuilder: (context, index) => const SizedBox(height: 12),

                        itemBuilder: (context, index) {

                          final item = animations[index];

                          final String name = item['animation_name']?.toString() ?? 'QR Code Animation';

                          final String jsonStr = item['json']?.toString() ?? '';

                          final int animationId = int.tryParse(item['id']?.toString() ?? item['animation_id']?.toString() ?? '') ?? 0;



                          return GestureDetector(

                            onTap: () {

                              Navigator.pop(context);

                              _updateAnimationForRun(animationId);

                            },

                            child: Container(

                              margin: const EdgeInsets.symmetric(horizontal: 16),

                              padding: const EdgeInsets.all(12),

                              decoration: BoxDecoration(

                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),

                                borderRadius: BorderRadius.circular(16),

                                border: Border.all(

                                  color: isDark ? Colors.white10 : Colors.black12,

                                ),

                              ),

                              child: Row(

                                children: [

                                  // Left side: Lottie animation

                                  if (jsonStr.isNotEmpty)

                                    SizedBox(

                                      height: 80,

                                      width: 80,

                                      child: ClipRRect(

                                        borderRadius: BorderRadius.circular(8),

                                        child: Lottie.memory(

                                          utf8.encode(jsonStr),

                                          fit: BoxFit.contain,

                                        ),

                                      ),

                                    )

                                  else

                                    Container(

                                      height: 80,

                                      width: 80,

                                      decoration: BoxDecoration(

                                        color: isDark ? Colors.white10 : Colors.black.withOpacity( 0.05),

                                        borderRadius: BorderRadius.circular(8),

                                      ),

                                      child: Icon(Icons.qr_code_scanner_rounded, color: subColor),

                                    ),

                                  const SizedBox(width: 16),

                                  // Right side: Name

                                  Expanded(

                                    child: Text(

                                      name,

                                      style: GoogleFonts.outfit(

                                        fontSize: 16,

                                        fontWeight: FontWeight.w800,

                                        color: titleColor,

                                      ),

                                    ),

                                  ),

                                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: subColor),

                                ],

                              ),

                            ),

                          );

                        },

                      ),

                    ),

                  ],

                );

              }

            }



            return Container(

              width: double.infinity,

              decoration: BoxDecoration(

                color: isDark ? const Color(0xFF0F172A) : Colors.white,

                borderRadius: const BorderRadius.only(

                  topLeft: Radius.circular(28),

                  topRight: Radius.circular(28),

                ),

              ),

              padding: EdgeInsets.only(

                top: 12,

                bottom: MediaQuery.of(context).padding.bottom + 16,

              ),

              child: Column(

                mainAxisSize: MainAxisSize.min,

                children: [

                  // Handle bar

                  Container(

                    width: 40,

                    height: 5,

                    decoration: BoxDecoration(

                      color: isDark ? Colors.white24 : Colors.black12,

                      borderRadius: BorderRadius.circular(10),

                    ),

                  ),

                  const SizedBox(height: 20),

                  content,

                ],

              ),

            );

          },

        );

      },

    );

  }



  Future<List<dynamic>?> _fetchQrCodeAnimations() async {

    try {

      final String? token = await UserStore.getToken();

      if (token == null) return null;



      final url = "${ApiConstants.baseUrl}/daily-bus/bus-runs/animations";

      final response = await http.get(

        Uri.parse(url),

        headers: ApiConstants.getHeaders(token),

      );



      if (response.statusCode == 200) {

        final Map<String, dynamic> decoded = json.decode(response.body);

        if (decoded['success'] == true && decoded['data'] is List) {

          return decoded['data'];

        }

      }

    } catch (e) {

      debugPrint("Error fetching QR code animations: $e");

    }

    return null;

  }



  Future<void> _fetchAndShowOperationAnimation({String shift = 'MORNING'}) async {

    final String runId = _run['id']?.toString() ?? '';

    if (runId.isEmpty) return;



    // Show loading dialog

    showDialog(

      context: context,

      barrierDismissible: false,

      builder: (context) => const Center(

        child: CircularProgressIndicator(),

      ),

    );



    try {

      final String? token = await UserStore.getToken();

      if (!mounted) return;

      if (token == null) {

        Navigator.pop(context); // Close loading loader

        _showSnackBar("Session expired. Please log in again.", Colors.red);

        return;

      }



      final url = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/$runId/animation";

      final response = await http.get(

        Uri.parse(url),

        headers: ApiConstants.getHeaders(token),

      );



      if (!mounted) return;

      Navigator.pop(context); // Close loading loader



      final Map<String, dynamic> decoded = json.decode(response.body);

      if (decoded['success'] == true && decoded['data'] != null) {

        final animationData = decoded['data'];

        final String name = animationData['animation_name']?.toString() ?? '';

        final String jsonStr = animationData['json']?.toString() ?? '';



        if (jsonStr.isNotEmpty) {

          _showBoardingPassModal(name, jsonStr, shift);

        } else {

          _showSnackBar("No animation data found.", Colors.orange);

        }

      } else {

        // success is false, show the toast/snackbar message

        final String msg = decoded['message'] ?? "Something went wrong";

        _showSnackBar(msg, Colors.red);

      }

    } catch (e) {

      if (mounted) {

        Navigator.pop(context); // Close loading loader

      }

      debugPrint("Error fetching operation animation: $e");

      _showSnackBar("Failed to connect to the server.", Colors.red);

    }

  }



  Future<void> _showBoardingPassModal(String animationName, String jsonStr, String shift) async {

    final bool isDark = Theme.of(context).brightness == Brightness.dark;



    if (useFacultyStore.profileData.value == null) {

      // Show loading indicator

      showDialog(

        context: context,

        barrierDismissible: false,

        builder: (ctx) => const Center(child: CircularProgressIndicator()),

      );

      await useFacultyStore.fetchProfile();

      if (mounted) {

        Navigator.pop(context); // Close loading indicator

      }

    }



    // Gather student info from run data

    final myDetails = _run['my_details'] as Map<String, dynamic>?;

    final List attendanceList = _run['attendanceRecords'] as List? ?? [];

    Map<String, dynamic>? myRecord;

    for (var rec in attendanceList) {

      if (rec['type']?.toString().toUpperCase() == 'STUDENT') {

        final pMap = rec['student'] as Map?;

        final int? pUserId = pMap?['user']?['id'] != null ? int.tryParse(pMap!['user']['id'].toString()) : null;

        if (pUserId != null && pUserId == _loggedInUserId) {

          myRecord = Map<String, dynamic>.from(rec);

          break;

        }

      }

    }



    final profileData = useFacultyStore.profileData.value;

    final studentProfile = profileData?['studentProfile'] as Map?;



    final String studentName = profileData?['name']?.toString()

        ?? myRecord?['student']?['user']?['name']?.toString()

        ?? myDetails?['name']?.toString()

        ?? 'Student';

        

    final String rollNumber = studentProfile?['roll_number']?.toString()

        ?? myRecord?['student']?['roll_number']?.toString()

        ?? myDetails?['roll_number']?.toString()

        ?? '—';

        

    final String registerNumber = studentProfile?['register_number']?.toString()

        ?? myRecord?['student']?['register_number']?.toString()

        ?? myDetails?['register_number']?.toString()

        ?? '—';



    final String academicYear = studentProfile?['academic_year']?.toString()

        ?? myRecord?['student']?['academic_year']?.toString()

        ?? myDetails?['academic_year']?.toString()

        ?? '—';



    // The user doesn't want username in student profile, but we can pass registerNumber instead of username to the dialog

    final String tripDate = _run['service_date']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    final String runName = _run['run_name']?.toString() ?? 'Bus Run';



    if (!mounted) return;

    

    showDialog(

      context: context,

      barrierColor: Colors.black.withOpacity( 0.6),

      builder: (ctx) {

        return _BoardingPassDialog(

          isDark: isDark,

          studentName: studentName,

          rollNumber: rollNumber,

          registerNumber: registerNumber,

          academicYear: academicYear,

          shift: shift,

          tripDate: tripDate,

          runName: runName,

          animationName: animationName,

          jsonStr: jsonStr,

        );

      },

    );

  }

  void _showBusChangeRequestModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _BusChangeRequestModal(
          currentRunId: int.tryParse(_run['id'].toString()) ?? 0,
          serviceDate: _run['service_date']?.toString() ?? '',
          onSuccess: _refreshDetails,
        );
      },
    );
  }
}



// ---------------------------------------------------------------------------

// Boarding Pass Dialog Widget (Stateful for live clock)

// ---------------------------------------------------------------------------

class _BoardingPassDialog extends StatefulWidget {

  final bool isDark;

  final String studentName;

  final String rollNumber;

  final String registerNumber;

  final String academicYear;

  final String shift;

  final String tripDate;

  final String runName;

  final String animationName;

  final String jsonStr;



  const _BoardingPassDialog({

    required this.isDark,

    required this.studentName,

    required this.rollNumber,

    required this.registerNumber,

    required this.academicYear,

    required this.shift,

    required this.tripDate,

    required this.runName,

    required this.animationName,

    required this.jsonStr,

  });



  @override

  State<_BoardingPassDialog> createState() => _BoardingPassDialogState();

}



class _BoardingPassDialogState extends State<_BoardingPassDialog> {

  late Timer _clockTimer;

  late String _currentTime;



  @override

  void initState() {

    super.initState();

    _currentTime = DateFormat('hh:mm:ss a').format(DateTime.now());

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {

      if (mounted) {

        setState(() {

          _currentTime = DateFormat('hh:mm:ss a').format(DateTime.now());

        });

      }

    });

  }



  @override

  void dispose() {

    _clockTimer.cancel();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    final bool isDark = widget.isDark;

    final bool isMorning = widget.shift.toUpperCase() == 'MORNING';



    // ── Professional Elegant Dark/Monochrome Palette ─────────────────

    const Color headerStripLight = Color(0xFF1E1E1E); // Sleek Charcoal

    const Color headerStripDark  = Color(0xFF121212); // Deep Black



    const Color accentLight = Color(0xFFD4AF37);         // Gold Accent

    const Color accentDark  = Color(0xFFFACC15);



    const Color cardLight   = Color(0xFFFAFAF9);         // Warm off-white

    const Color cardDark    = Color(0xFF1E293B);



    const Color bodyBgLight = Color(0xFFEEEEEE);

    const Color bodyBgDark  = Color(0xFF0F172A);



    const Color labelLight  = Color(0xFF6B7280);

    const Color labelDark   = Color(0xFF94A3B8);



    const Color valueLight  = Color(0xFF111827);

    const Color valueDark   = Color(0xFFF1F5F9);



    const Color dividerLight = Color(0xFFD1D5DB);

    const Color dividerDark  = Color(0xFF334155);



    final Color headerStrip = isDark ? headerStripDark  : headerStripLight;

    final Color accent      = isDark ? accentDark       : accentLight;

    final Color cardBg      = isDark ? cardDark         : cardLight;

    final Color pageBg      = isDark ? bodyBgDark       : bodyBgLight;

    final Color labelColor  = isDark ? labelDark        : labelLight;

    final Color valueColor  = isDark ? valueDark        : valueLight;

    final Color divider     = isDark ? dividerDark      : dividerLight;



    // Shift accent strip colour

    final Color shiftAccent = isMorning

        ? const Color(0xFFF59E0B)   // Amber

        : const Color(0xFF3B82F6);  // Blue



    // Format trip date

    String formattedDate = widget.tripDate;

    String formattedDateShort = widget.tripDate;

    try {

      final dt = DateFormat('yyyy-MM-dd').parse(widget.tripDate);

      formattedDate      = DateFormat('dd MMM yyyy').format(dt);

      formattedDateShort = DateFormat('EEE').format(dt).toUpperCase();

    } catch (_) {}



    return Dialog(

      backgroundColor: Colors.transparent,

      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),

      child: Container(

        decoration: BoxDecoration(

          color: pageBg,

          borderRadius: BorderRadius.circular(24),

        ),

        child: SingleChildScrollView(

          physics: const BouncingScrollPhysics(),

          child: Padding(

            padding: const EdgeInsets.only(

              left: 18,

              right: 18,

              top: 18,

              bottom: 24,

            ),

            child: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                // ── CLOSE BUTTON ──

                Align(

                  alignment: Alignment.topRight,

                  child: GestureDetector(

                    onTap: () => Navigator.of(context).pop(),

                    child: Container(

                      padding: const EdgeInsets.all(6),

                      decoration: BoxDecoration(

                        color: Colors.black.withOpacity( 0.05),

                        shape: BoxShape.circle,

                      ),

                      child: const Icon(Icons.close, size: 20, color: Colors.black54),

                    ),

                  ),

                ),

                const SizedBox(height: 12),



                // ══════════════════════════════════════════════

                //  BOARDING PASS CARD

                // ══════════════════════════════════════════════

                Container(

                  width: double.infinity,

                  decoration: BoxDecoration(

                    color: cardBg,

                    borderRadius: BorderRadius.circular(20),

                    boxShadow: [

                      BoxShadow(

                        color: Colors.black.withOpacity( isDark ? 0.4 : 0.12),

                        blurRadius: 24,

                        offset: const Offset(0, 8),

                      ),

                    ],

                  ),

                  child: ClipRRect(

                    borderRadius: BorderRadius.circular(20),

                    child: Column(

                      children: [



                        // ── HEADER STRIP ──────────────────────────

                        Container(

                          width: double.infinity,

                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),

                          color: headerStrip,

                          child: Row(

                            crossAxisAlignment: CrossAxisAlignment.center,

                            children: [

                              // Bus icon circle

                              Container(

                                width: 40,

                                height: 40,

                                decoration: BoxDecoration(

                                  color: Colors.white.withOpacity( 0.12),

                                  shape: BoxShape.circle,

                                ),

                                child: const Icon(

                                  Icons.directions_bus_rounded,

                                  color: Colors.white,

                                  size: 20,

                                ),

                              ),

                              const SizedBox(width: 12),

                              Expanded(

                                child: Column(

                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [

                                    Text(

                                      'TRIPZO TRANSIT',

                                      style: GoogleFonts.outfit(

                                        color: Colors.white.withOpacity( 0.6),

                                        fontSize: 9,

                                        fontWeight: FontWeight.w700,

                                        letterSpacing: 1.8,

                                      ),

                                    ),

                                    const SizedBox(height: 2),

                                    Text(

                                      'BOARDING PASS',

                                      style: GoogleFonts.outfit(

                                        color: Colors.white,

                                        fontSize: 20,

                                        fontWeight: FontWeight.w900,

                                        letterSpacing: 0.5,

                                        height: 1.1,

                                      ),

                                    ),

                                  ],

                                ),

                              ),

                              // Shift pill — right-aligned

                              Container(

                                padding: const EdgeInsets.symmetric(

                                  horizontal: 10, vertical: 5),

                                decoration: BoxDecoration(

                                  color: shiftAccent.withOpacity( 0.85),

                                  borderRadius: BorderRadius.circular(6),

                                ),

                                child: Row(

                                  mainAxisSize: MainAxisSize.min,

                                  children: [

                                    Icon(

                                      isMorning

                                          ? Icons.wb_sunny_outlined

                                          : Icons.nights_stay_outlined,

                                      color: Colors.white,

                                      size: 11,

                                    ),

                                    const SizedBox(width: 4),

                                    Text(

                                      isMorning ? 'MORNING' : 'EVENING',

                                      style: GoogleFonts.outfit(

                                        color: Colors.white,

                                        fontSize: 10,

                                        fontWeight: FontWeight.w800,

                                        letterSpacing: 1.0,

                                      ),

                                    ),

                                  ],

                                ),

                              ),

                            ],

                          ),

                        ),



                        // ── PASSENGER BLOCK ────────────────────────

                        Container(

                          width: double.infinity,

                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),

                          child: Column(

                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [

                              // NAME — big, like airline

                              _fieldLabel('PASSENGER NAME', labelColor),

                              const SizedBox(height: 3),

                              Text(

                                widget.studentName.toUpperCase(),

                                style: GoogleFonts.outfit(

                                  color: valueColor,

                                  fontSize: 22,

                                  fontWeight: FontWeight.w900,

                                  letterSpacing: 0.5,

                                  height: 1.1,

                                ),

                                maxLines: 1,

                                overflow: TextOverflow.ellipsis,

                              ),

                              const SizedBox(height: 14),



                              // Roll + Username + Academic Year side-by-side

                              Row(

                                children: [

                                  Expanded(

                                    child: Column(

                                      crossAxisAlignment: CrossAxisAlignment.start,

                                      children: [

                                        _fieldLabel('ROLL NUMBER', labelColor),

                                        const SizedBox(height: 3),

                                        Text(

                                          widget.rollNumber,

                                          style: GoogleFonts.outfit(

                                            color: Colors.black87,

                                            fontSize: 14,

                                            fontWeight: FontWeight.w800,

                                            letterSpacing: 0.3,

                                          ),

                                        ),

                                      ],

                                    ),

                                  ),

                                  Container(

                                    width: 1,

                                    height: 36,

                                    color: divider,

                                  ),

                                  const SizedBox(width: 12),

                                  Expanded(

                                    child: Column(

                                      crossAxisAlignment: CrossAxisAlignment.start,

                                      children: [

                                        _fieldLabel('REG. NUMBER', labelColor),

                                        const SizedBox(height: 3),

                                        Text(

                                          widget.registerNumber.isNotEmpty && widget.registerNumber != 'null' ? widget.registerNumber : 'N/A',

                                          style: GoogleFonts.outfit(

                                            color: Colors.black87,

                                            fontSize: 14,

                                            fontWeight: FontWeight.w800,

                                            letterSpacing: 0.3,

                                          ),

                                          overflow: TextOverflow.ellipsis,

                                        ),

                                      ],

                                    ),

                                  ),

                                  Container(

                                    width: 1,

                                    height: 36,

                                    color: divider,

                                  ),

                                  const SizedBox(width: 12),

                                  Expanded(

                                    child: Column(

                                      crossAxisAlignment: CrossAxisAlignment.start,

                                      children: [

                                        _fieldLabel('ACADEMIC YR', labelColor),

                                        const SizedBox(height: 3),

                                        Text(

                                          widget.academicYear,

                                          style: GoogleFonts.outfit(

                                            color: Colors.black87,

                                            fontSize: 14,

                                            fontWeight: FontWeight.w800,

                                            letterSpacing: 0.3,

                                          ),

                                          overflow: TextOverflow.ellipsis,

                                        ),

                                      ],

                                    ),

                                  ),

                                ],

                              ),

                              const SizedBox(height: 14),



                              Divider(color: divider, thickness: 1, height: 1),

                              const SizedBox(height: 14),



                              // Run name + shift row

                              Row(

                                children: [

                                  Expanded(

                                    flex: 3,

                                    child: Column(

                                      crossAxisAlignment: CrossAxisAlignment.start,

                                      children: [

                                        _fieldLabel('ROUTE / RUN', labelColor),

                                        const SizedBox(height: 3),

                                        Text(

                                          widget.runName,

                                          style: GoogleFonts.outfit(

                                            color: Colors.black87,

                                            fontSize: 13,

                                            fontWeight: FontWeight.w800,

                                          ),

                                          overflow: TextOverflow.ellipsis,

                                        ),

                                      ],

                                    ),

                                  ),

                                  Container(

                                    width: 1,

                                    height: 36,

                                    color: divider,

                                  ),

                                  const SizedBox(width: 16),

                                  Expanded(

                                    flex: 2,

                                    child: Column(

                                      crossAxisAlignment: CrossAxisAlignment.start,

                                      children: [

                                        _fieldLabel('SHIFT', labelColor),

                                        const SizedBox(height: 3),

                                        Text(

                                          isMorning ? 'MORNING' : 'EVENING',

                                          style: GoogleFonts.outfit(

                                            color: shiftAccent,

                                            fontSize: 13,

                                            fontWeight: FontWeight.w900,

                                            letterSpacing: 0.5,

                                          ),

                                        ),

                                      ],

                                    ),

                                  ),

                                ],

                              ),

                              const SizedBox(height: 16),

                            ],

                          ),

                        ),



                        // ── PERFORATED TEAR LINE ──────────────────

                        _PerforatedCutLine(cardBg: cardBg, lineColor: divider),



                        // ── BOTTOM STUB ────────────────────────────

                        Container(

                          width: double.infinity,

                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),

                          child: Column(

                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [

                              // Date | Time

                              Row(

                                children: [

                                  // DATE block

                                  Expanded(

                                    child: Column(

                                      crossAxisAlignment: CrossAxisAlignment.start,

                                      children: [

                                        _fieldLabel('TRIP DATE', labelColor),

                                        const SizedBox(height: 3),

                                        Row(

                                          crossAxisAlignment: CrossAxisAlignment.baseline,

                                          textBaseline: TextBaseline.alphabetic,

                                          children: [

                                            Text(

                                              formattedDateShort,

                                              style: GoogleFonts.outfit(

                                                color: accent,

                                                fontSize: 12,

                                                fontWeight: FontWeight.w900,

                                                letterSpacing: 0.5,

                                              ),

                                            ),

                                            const SizedBox(width: 5),

                                            Text(

                                              formattedDate,

                                              style: GoogleFonts.outfit(

                                                color: Colors.black87,

                                                fontSize: 15,

                                                fontWeight: FontWeight.w900,

                                              ),

                                            ),

                                          ],

                                        ),

                                      ],

                                    ),

                                  ),

                                  Container(width: 1, height: 36, color: divider),

                                  const SizedBox(width: 16),

                                  // TIME block — live

                                  Expanded(

                                    child: Column(

                                      crossAxisAlignment: CrossAxisAlignment.start,

                                      children: [

                                        Row(

                                          children: [

                                            _fieldLabel('CURRENT TIME', labelColor),

                                            const SizedBox(width: 5),

                                            Container(

                                              width: 6,

                                              height: 6,

                                              decoration: const BoxDecoration(

                                                color: Color(0xFF22C55E),

                                                shape: BoxShape.circle,

                                              ),

                                            ),

                                          ],

                                        ),

                                        const SizedBox(height: 3),

                                        Text(

                                          _currentTime,

                                          style: GoogleFonts.outfit(

                                            color: Colors.black87,

                                            fontSize: 15,

                                            fontWeight: FontWeight.w900,

                                            fontFeatures: [

                                              const FontFeature.tabularFigures(),

                                            ],

                                          ),

                                        ),

                                      ],

                                    ),

                                  ),

                                ],

                              ),

                              const SizedBox(height: 16),



                              Divider(color: divider, thickness: 1, height: 1),

                              const SizedBox(height: 16),



                              // ── ANIMATION SECTION ──────────────

                              if (widget.animationName.isNotEmpty)

                                Row(

                                  children: [

                                    _fieldLabel(

                                      widget.animationName.toUpperCase(),

                                      labelColor,

                                    ),

                                  ],

                                ),

                              const SizedBox(height: 10),



                              // Lottie animation — centred, no heavy border

                              Center(

                                child: Container(

                                  width: 190,

                                  height: 190,

                                  decoration: BoxDecoration(

                                    color: isDark

                                        ? Colors.white.withOpacity( 0.04)

                                        : Colors.black.withOpacity( 0.02),

                                    borderRadius: BorderRadius.circular(16),

                                    border: Border.all(

                                      color: divider,

                                      width: 1,

                                    ),

                                  ),

                                  child: ClipRRect(

                                    borderRadius: BorderRadius.circular(15),

                                    child: Lottie.memory(

                                      utf8.encode(widget.jsonStr),

                                      fit: BoxFit.contain,

                                    ),

                                  ),

                                ),

                              ),

                              const SizedBox(height: 16),



                              // Footer note — like the fine print on real tickets

                              Center(

                                child: Text(

                                  'This pass is valid only for the listed trip date and shift.',

                                  style: GoogleFonts.outfit(

                                    color: labelColor,

                                    fontSize: 10,

                                    fontWeight: FontWeight.w500,

                                    letterSpacing: 0.2,

                                  ),

                                  textAlign: TextAlign.center,

                                ),

                              ),

                              const SizedBox(height: 16),

                            ],

                          ),

                        ),

                      ],

                    ),

                  ),

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }



  Widget _fieldLabel(String text, Color color) {

    return Text(

      text,

      style: GoogleFonts.outfit(

        color: color,

        fontSize: 9,

        fontWeight: FontWeight.w700,

        letterSpacing: 1.2,

      ),

    );
  }

}



// ---------------------------------------------------------------------------

// Perforated cut line widget

// ---------------------------------------------------------------------------

class _PerforatedCutLine extends StatelessWidget {

  final Color cardBg;

  final Color lineColor;

  const _PerforatedCutLine({required this.cardBg, required this.lineColor});



  @override

  Widget build(BuildContext context) {

    return SizedBox(

      height: 28,

      child: Stack(

        alignment: Alignment.center,

        children: [

          // Left semicircle cutout

          Positioned(

            left: -14,

            child: Container(

              width: 28,

              height: 28,

              decoration: BoxDecoration(

                color: Theme.of(context).scaffoldBackgroundColor == Colors.transparent

                    ? const Color(0xFFF1F5F9)

                    : Theme.of(context).scaffoldBackgroundColor,

                shape: BoxShape.circle,

              ),

            ),

          ),

          // Right semicircle cutout

          Positioned(

            right: -14,

            child: Container(

              width: 28,

              height: 28,

              decoration: BoxDecoration(

                color: Theme.of(context).scaffoldBackgroundColor == Colors.transparent

                    ? const Color(0xFFF1F5F9)

                    : Theme.of(context).scaffoldBackgroundColor,

                shape: BoxShape.circle,

              ),

            ),

          ),

          // Dashed line

          Padding(

            padding: const EdgeInsets.symmetric(horizontal: 12),

            child: LayoutBuilder(

              builder: (context, constraints) {

                final dashWidth = 6.0;

                final dashSpace = 5.0;

                final totalWidth = constraints.maxWidth;

                final dashCount = (totalWidth / (dashWidth + dashSpace)).floor();

                return Row(

                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: List.generate(

                    dashCount,

                    (i) => Container(

                      width: dashWidth,

                      height: 1.5,

                      color: lineColor,

                    ),

                  ),

                );

              },

            ),

          ),

          // Scissors icon in the center

          Container(

            padding: const EdgeInsets.symmetric(horizontal: 4),

            child: Icon(

              Icons.content_cut_rounded,

              size: 14,

              color: lineColor,

            ),

          ),

        ],

      ),

    );
  }
}

class _BusChangeRequestModal extends StatefulWidget {
  final int currentRunId;
  final String serviceDate;
  final VoidCallback onSuccess;

  const _BusChangeRequestModal({
    super.key,
    required this.currentRunId,
    required this.serviceDate,
    required this.onSuccess,
  });

  @override
  State<_BusChangeRequestModal> createState() => _BusChangeRequestModalState();
}

class _BusChangeRequestModalState extends State<_BusChangeRequestModal> {
  String _selectedShift = 'MORNING';
  List<dynamic> _availableRoutes = [];
  int? _selectedTargetRunId;
  final TextEditingController _remarksController = TextEditingController();
  bool _isLoading = false;
  bool _isFetchingRoutes = false;

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  Future<void> _fetchRoutes() async {
    setState(() {
      _isFetchingRoutes = true;
      _availableRoutes = [];
      _selectedTargetRunId = null;
    });

    try {
      final token = await UserStore.getToken();
      if (token == null) return;
      
      final String url;
      if (_selectedShift == 'BOTH') {
        url = "${ApiConstants.baseUrl}/daily-bus/transfer-requests/search-runs?service_date=${widget.serviceDate}";
      } else {
        final shiftParam = _selectedShift == 'MORNING' ? 'Morning' : 'Evening';
        url = "${ApiConstants.baseUrl}/daily-bus/transfer-requests/search-runs?shift=$shiftParam&service_date=${widget.serviceDate}";
      }
      
      final String curlCmd = "curl --request GET \\\n"
          "  --url '$url' \\\n"
          "  --header 'Authorization: TMS $token' \\\n"
          "  --header 'Content-Type: application/json'";
          
      debugPrint("\n🌟🌟🌟 [GET ROUTES: FETCHING AVAILABLE ROUTES] 🌟🌟🌟\n"
          "====================================================\n"
          "$curlCmd\n"
          "====================================================\n");

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data is List) {
          setState(() {
            _availableRoutes = data;
          });
        } else if (data['data'] is List) {
          setState(() {
            _availableRoutes = data['data'];
          });
        }
      } else {
        String errMsg = 'Failed to fetch routes';
        try {
          final errData = json.decode(response.body);
          if (errData['message'] != null) errMsg = errData['message'];
        } catch (_) {}
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      }
    } catch (e) {
      print(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching routes: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isFetchingRoutes = false);
    }
  }

  String _getSelectedRouteName() {
    if (_selectedTargetRunId == null) return 'Select a route';
    final route = _availableRoutes.firstWhere(
      (r) => (r['id'] as int?) == _selectedTargetRunId,
      orElse: () => <String, dynamic>{},
    );
    if (route.isEmpty) return 'Select a route';
    return (route['run_name']?.toString() ?? route['name']?.toString() ?? 'Route $_selectedTargetRunId').toUpperCase();
  }

  void _showRouteSelectionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final filteredRoutes = _availableRoutes.where((route) {
              final String routeName = (route['run_name']?.toString() ?? route['name']?.toString() ?? '').toLowerCase();
              return routeName.contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Target Route', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search route...',
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2)),
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.05),
                      ),
                      onChanged: (value) {
                        setModalState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filteredRoutes.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final route = filteredRoutes[index];
                        final int routeId = route['id'] ?? 0;
                        final String routeName = (route['run_name']?.toString() ?? route['name']?.toString() ?? 'Route $routeId').toUpperCase();
                        
                        String busNumber = 'N/A';
                        final assignList = route['assignment'] as List?;
                        if (assignList != null && assignList.isNotEmpty) {
                          final vehicle = assignList[0]['vehicle'];
                          if (vehicle is Map) {
                            busNumber = vehicle['bus_number']?.toString() ?? 'N/A';
                          }
                        }
                        
                        String inchargeName = 'N/A';
                        final facList = route['faculties'] as List?;
                        if (facList != null && facList.isNotEmpty) {
                          inchargeName = facList[0]['name']?.toString() ?? 'N/A';
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          title: Text(routeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Bus: $busNumber • Incharge: $inchargeName', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedTargetRunId = routeId;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
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

  Future<void> _submitRequest() async {
    if (_selectedTargetRunId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a target route', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      return;
    }
    if (_remarksController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remarks are required', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await UserStore.getToken();
      if (token == null) return;

      final url = "${ApiConstants.baseUrl}/daily-bus/transfer-requests";
      final body = {
        "original_run_id": widget.currentRunId,
        "target_run_id": _selectedTargetRunId,
        "shift_requested": _selectedShift,
        "remarks": _remarksController.text.trim()
      };

      final String curlCmd = "curl --request POST \\\n"
          "  --url '$url' \\\n"
          "  --header 'Authorization: TMS $token' \\\n"
          "  --header 'Content-Type: application/json' \\\n"
          "  --data '${json.encode(body)}'";
      debugPrint("---- [HTTP REQUEST CURL] ----\n$curlCmd\n----------------------------");

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(body),
      );
      
      debugPrint("---- [HTTP RESPONSE STATUS: ${response.statusCode}] ----\n${response.body}\n----------------------------");

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer request submitted successfully', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
          widget.onSuccess();
        }
      } else {
        String errMsg = 'Failed to submit request';
        try {
          final errData = json.decode(response.body);
          if (errData['message'] != null) errMsg = errData['message'];
        } catch (_) {}
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      }
    } catch (e) {
      print(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting request: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bus Change Request',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),
          const Text('Select Shift', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_selectedShift != 'MORNING') {
                        setState(() => _selectedShift = 'MORNING');
                        _fetchRoutes();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedShift == 'MORNING' ? const Color(0xFF5352ED) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text('Morning', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _selectedShift == 'MORNING' ? Colors.white : Colors.grey[600])),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_selectedShift != 'EVENING') {
                        setState(() => _selectedShift = 'EVENING');
                        _fetchRoutes();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedShift == 'EVENING' ? const Color(0xFF5352ED) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text('Evening', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _selectedShift == 'EVENING' ? Colors.white : Colors.grey[600])),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_selectedShift != 'BOTH') {
                        setState(() => _selectedShift = 'BOTH');
                        _fetchRoutes();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedShift == 'BOTH' ? const Color(0xFF5352ED) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text('Both', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _selectedShift == 'BOTH' ? Colors.white : Colors.grey[600])),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Select Target Route', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _isFetchingRoutes
              ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()))
              : InkWell(
                  onTap: () => _showRouteSelectionBottomSheet(context),
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: Colors.white,
                      suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                    ),
                    child: Text(
                      _getSelectedRouteName(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _selectedTargetRunId == null ? Colors.grey[500] : const Color(0xFF1B233A),
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 16),
          const Text('Remarks *', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _remarksController,
            decoration: InputDecoration(
              hintText: 'Reason for changing bus...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: Theme.of(context).primaryColor,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Request', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
