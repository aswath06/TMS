import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/utils/api_constants.dart';

class ScheduleDetailsPage extends StatefulWidget {
  final int scheduleId;

  const ScheduleDetailsPage({super.key, required this.scheduleId});

  @override
  State<ScheduleDetailsPage> createState() => _ScheduleDetailsPageState();
}

class _ScheduleDetailsPageState extends State<ScheduleDetailsPage> {
  bool _isLoading = true;
  bool _isSubmittingShift = false;
  String? _errorMessage;
  Map<String, dynamic>? _scheduleDetails;
  int? _currentDriverId;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails({bool showLoading = true}) async {
    setState(() {
      if (showLoading) {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      final token = await UserStore.getToken();
      final driverId = await UserStore.getDriverId();
      if (token == null) {
        setState(() {
          _errorMessage = "Authentication token not found.";
          _isLoading = false;
        });
        return;
      }
      
      if (mounted) {
        setState(() {
          _currentDriverId = driverId;
        });
      }

      final url = ApiConstants.getDriverScheduleDetails(widget.scheduleId);
      debugPrint("🔗 Fetching Schedule Details URL: $url");
      
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      debugPrint("📦 Response Status: ${response.statusCode}");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _scheduleDetails = data['data'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? "Failed to parse schedule details.";
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = "Failed to load schedule details (Status: ${response.statusCode}).";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error occurred: $e";
        _isLoading = false;
      });
      debugPrint("ScheduleDetailsPage Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isTamil = LanguageStore.isTamil;
    
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isTamil ? "அட்டவணை விவரங்கள்" : "Schedule Details",
          style: GoogleFonts.outfit(
            color: titleColor,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? _buildSkeletonLoading(isDark, cardColor, bgColor)
          : _errorMessage != null
              ? _buildErrorWidget(titleColor, subColor, primaryBlue)
              : _buildContent(isDark, isTamil, bgColor, cardColor, titleColor, subColor, primaryBlue),
    );
  }

  Widget _buildErrorWidget(Color titleColor, Color subColor, Color primaryBlue) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: subColor, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchDetails,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading(bool isDark, Color cardColor, Color bgColor) {
    final shimmerBase = isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200;
    final shimmerHighlight = isDark ? Colors.white.withOpacity(0.15) : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: shimmerBase,
      highlightColor: shimmerHighlight,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 190,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 80,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      Container(
                        width: 70,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 180,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 1,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(width: 18, height: 18, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Container(width: 80, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Container(width: 18, height: 18, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Container(width: 80, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: 100,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 140,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  width: 30,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(3, (index) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: double.infinity,
              height: 76,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    bool isDark,
    bool isTamil,
    Color bgColor,
    Color cardColor,
    Color titleColor,
    Color subColor,
    Color primaryBlue,
  ) {
    final dutyShift = _scheduleDetails?['dutyShift'] as Map<String, dynamic>? ?? {};
    final String shiftName = dutyShift['shift_name'] ?? 'FN';
    final String shiftCode = dutyShift['shift_code'] ?? 'FN';
    final String shiftStart = dutyShift['shift_start'] ?? '06:00:00';
    final String shiftEnd = dutyShift['shift_end'] ?? '14:00:00';
    final String shiftTime = "${_formatTimeOfDay(shiftStart)} - ${_formatTimeOfDay(shiftEnd)}";
    String dutyStatus = dutyShift['status'] ?? 'PLANNED';
    final String? actualStartTime = dutyShift['actual_start_time'];
    final String? actualEndTime = dutyShift['actual_end_time'];

    final masterDuty = dutyShift['masterDuty'] as Map<String, dynamic>? ?? {};
    final String dutyDate = masterDuty['duty_date'] ?? '';
    final category = masterDuty['category'] as Map<String, dynamic>? ?? {};
    final String categoryName = category['category_name'] ?? (isTamil ? 'கடமை அட்டவணை' : 'Duty Schedule');

    final int driversRequired = dutyShift['drivers_required'] ?? 0;
    final int spareRequired = dutyShift['spare_required'] ?? 0;

    final vehicles = dutyShift['vehicles'] as List? ?? [];
    final int assignedVehicles = vehicles.length;
    final int vehiclesWithOdometer = vehicles.where((v) {
      final odo = v['odometer'] as Map<String, dynamic>?;
      return odo != null && odo['start_odometer'] != null && odo['start_odometer'].toString().isNotEmpty;
    }).length;
    final drivers = dutyShift['drivers'] as List? ?? [];
    final bool anyDriverStarted = drivers.any((d) => d['assignment_status'] == 'STARTED' || d['assignment_status'] == 'COMPLETED');
    final bool allDriversStarted = drivers.isNotEmpty && drivers.every((d) => d['assignment_status'] == 'STARTED' || d['assignment_status'] == 'COMPLETED');

    if (dutyStatus == 'STARTED') {
      if (!allDriversStarted) {
        dutyStatus = 'ONGOING';
      }
    } else if (dutyStatus == 'PLANNED') {
      if (anyDriverStarted) {
        dutyStatus = 'ONGOING';
      } else {
        dutyStatus = 'PENDING';
      }
    }

    final bool hasAssignedVehicle = vehicles.isNotEmpty && vehicles.any((v) => v['is_my_responsibility'] == true);

    final bool hasCurrentDriverStarted = _currentDriverId != null && drivers.any((d) => 
      d['driver_id']?.toString() == _currentDriverId?.toString() && 
      d['assignment_status'] == 'STARTED'
    );
    
    final bool hasCurrentDriverCompleted = _currentDriverId != null && drivers.any((d) => 
      d['driver_id']?.toString() == _currentDriverId?.toString() && 
      d['assignment_status'] == 'COMPLETED'
    );

    final bool anyStartOdoEntered = vehicles.isNotEmpty && vehicles.any((v) {
      final odo = v['odometer'] as Map<String, dynamic>?;
      return odo != null && odo['start_odometer'] != null && odo['start_odometer'].toString().isNotEmpty;
    });

    final bool anyEndOdoEntered = vehicles.isNotEmpty && vehicles.any((v) {
      final odo = v['odometer'] as Map<String, dynamic>?;
      return odo != null && odo['end_odometer'] != null && odo['end_odometer'].toString().isNotEmpty;
    });

    final bool canStartDuty = hasAssignedVehicle && anyStartOdoEntered && !hasCurrentDriverStarted && !hasCurrentDriverCompleted && dutyStatus != 'COMPLETED';
    final bool canEndDuty = hasCurrentDriverStarted && anyEndOdoEntered && dutyStatus != 'COMPLETED';
    final bool showActionBtn = canStartDuty || canEndDuty;
    final bool isEndAction = canEndDuty;

    Color accentColor = primaryBlue;
    if (shiftCode == 'FN') {
      accentColor = const Color(0xFF6366F1);
    } else if (shiftCode == 'AN') {
      accentColor = const Color(0xFFF59E0B);
    } else {
      accentColor = const Color(0xFF10B981);
    }

    return Stack(
      children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1E1B4B), const Color(0xFF311042)]
                    : [const Color(0xFFEEF2FF), const Color(0xFFFDF2F8)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            shiftName,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadgeWidget(dutyStatus),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  categoryName,
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 1,
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 18, color: subColor),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isTamil ? "தேதி" : "DATE",
                                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: subColor),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDate(dutyDate.isNotEmpty ? dutyDate : null),
                                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: titleColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 18, color: subColor),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isTamil ? "நேரம்" : "TIME",
                                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: subColor),
                              ),
                               const SizedBox(height: 2),
                              Text(
                                shiftTime,
                                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: titleColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (actualStartTime != null && actualStartTime.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    height: 1,
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.play_circle_fill_rounded, size: 18, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isTamil ? "உண்மையான தொடக்கம்" : "ACTUAL START",
                                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: subColor),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDateTimeString(actualStartTime),
                                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: titleColor),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.stop_circle_rounded, size: 18, color: actualEndTime != null ? Colors.red : Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isTamil ? "உண்மையான முடிவு" : "ACTUAL END",
                                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: subColor),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    actualEndTime != null && actualEndTime.isNotEmpty
                                        ? _formatDateTimeString(actualEndTime)
                                        : (isTamil ? "செயலில் உள்ளது" : "In Progress"),
                                    style: GoogleFonts.outfit(
                                      fontSize: 12, 
                                      fontWeight: FontWeight.w800, 
                                      color: actualEndTime != null && actualEndTime.isNotEmpty ? titleColor : Colors.orange
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 1,
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 18, color: primaryBlue),
                      const SizedBox(width: 8),
                      Text(
                        isTamil ? "கால அளவு: " : "DURATION: ",
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: subColor, letterSpacing: 0.5),
                      ),
                      Expanded(
                        child: Text(
                          _calculateDurationString(actualStartTime, actualEndTime, isTamil),
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: titleColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          // Requirements Section
          Text(
            isTamil ? "தேவைகள்" : "REQUIREMENTS",
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: subColor.withOpacity(0.7),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.people_rounded, color: primaryBlue, size: 20),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTamil ? "தேவைப்படும் ஓட்டுநர்கள்" : "Drivers Required",
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: subColor),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$driversRequired",
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: titleColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.person_add_alt_rounded, color: Colors.orange, size: 20),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTamil ? "கூடுதல் ஓட்டுநர்கள்" : "Spare Required",
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: subColor),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$spareRequired",
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: titleColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Assigned Vehicles Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isTamil ? "ஒதுக்கப்பட்ட வாகனங்கள்" : "ASSIGNED VEHICLES",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: subColor.withOpacity(0.7),
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                "(${vehicles.length})",
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          if (vehicles.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              "Progress: $vehiclesWithOdometer / $assignedVehicles vehicles ready",
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: vehiclesWithOdometer == assignedVehicles ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "Duty Status: $dutyStatus",
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (vehicles.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  isTamil ? "வாகனங்கள் எதுவும் ஒதுக்கப்படவில்லை" : "No vehicles assigned.",
                  style: GoogleFonts.outfit(color: subColor, fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            ...vehicles.map((v) => _buildVehicleItem(v, dutyShift['id'] ?? 0, isDark, isTamil, cardColor, titleColor, subColor, primaryBlue)),
        ],
      ),
    ),
    if (showActionBtn)
      Positioned(
        bottom: 20,
        left: 20,
        right: 20,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isEndAction ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: (isEndAction ? Colors.red : Colors.green).withOpacity(0.3),
            ),
            onPressed: _isSubmittingShift
                ? null
                : () {
                    if (isEndAction) {
                      _endShift(dutyShift['id'] ?? 0);
                    } else {
                      _startShift(dutyShift['id'] ?? 0);
                    }
                  },
            icon: _isSubmittingShift
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isEndAction ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 28,
                  ),
            label: Text(
              _isSubmittingShift
                  ? (isEndAction
                      ? (isTamil ? "முடிக்கப்படுகிறது..." : "Ending...")
                      : (isTamil ? "தொடங்குகிறது..." : "Starting..."))
                  : (isEndAction
                      ? (isTamil ? "கடமையை முடிக்கவும்" : "End Duty")
                      : (isTamil ? "கடமையைத் தொடங்கு" : "Start Duty")),
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    ],
  );
}

  Widget _buildVehicleItem(
    Map<String, dynamic> v,
    int shiftId,
    bool isDark,
    bool isTamil,
    Color cardColor,
    Color titleColor,
    Color subColor,
    Color primaryBlue,
  ) {
    final vehicleNum = v['vehicle_number'] ?? 'N/A';
    final details = v['vehicle'] as Map<String, dynamic>? ?? {};
    final busNum = details['bus_number'] ?? '';
    final make = details['make'] ?? '';
    final model = details['model'] ?? '';
    final capacity = details['capacity'] ?? 0;

    final bool isCar = capacity <= 7 ||
        busNum.toString().toLowerCase().contains('car') ||
        model.toString().toLowerCase().contains('crysta') ||
        make.toString().toLowerCase().contains('marazzo');

    final odometer = v['odometer'] as Map<String, dynamic>?;
    final String? startOdo = odometer?['start_odometer']?.toString();
    final String? endOdo = odometer?['end_odometer']?.toString();
    final String? startTime = odometer?['start_time'];
    final String? endTime = odometer?['end_time'];

    final bool isMyResp = v['is_my_responsibility'] == true && startOdo != null && startOdo.isNotEmpty;
    final bool isTaken = v['is_taken'] == true;

    final double? startVal = double.tryParse(startOdo ?? '');
    final double? endVal = double.tryParse(endOdo ?? '');
    final double? distance = (startVal != null && endVal != null) ? (endVal - startVal) : null;

    // Professional Plate Number Design
    Widget buildLicensePlate(String number) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Blue state stripe
              Container(
                width: 6,
                height: 32,
                color: Colors.blue.shade700,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  number,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isMyResp
              ? Colors.green.withOpacity(0.35)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
          width: isMyResp ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            _showOdometerDialog(
              context: context,
              vehicleNum: vehicleNum,
              busNumber: busNum,
              shiftId: shiftId,
              vehicleId: v['vehicle_id'] ?? 0,
              currentStartOdo: startOdo,
              currentEndOdo: endOdo,
              isTamil: isTamil,
              isDark: isDark,
              cardColor: cardColor,
              titleColor: titleColor,
              subColor: subColor,
              primaryBlue: primaryBlue,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Icon, Details, and License Plate
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Modern Rounded Square Icon Container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isMyResp
                              ? [Colors.green.shade500.withOpacity(0.15), Colors.green.shade600.withOpacity(0.05)]
                              : [primaryBlue.withOpacity(0.12), primaryBlue.withOpacity(0.03)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isCar ? Icons.directions_car_filled_rounded : Icons.directions_bus_rounded,
                        size: 26,
                        color: isMyResp ? Colors.green.shade400 : primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Title and Seat Capacity
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            busNum.isNotEmpty
                                ? busNum
                                : (make.isNotEmpty ? "$make $model" : (isTamil ? "வாகனம்" : "Vehicle")),
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Premium Pill badge for capacity
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.airline_seat_recline_normal_rounded, size: 12, color: subColor),
                                const SizedBox(width: 4),
                                Text(
                                  isTamil ? "$capacity இருக்கைகள்" : "$capacity Seats",
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: subColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    buildLicensePlate(vehicleNum),
                  ],
                ),

                // Odometer Section (Timeline/Track Style)
                if (odometer != null && startOdo != null && startOdo.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A).withOpacity(0.6) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Start Odometer Line
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isTamil ? "ஆரம்ப வாசிப்பு: " : "Start Reading: ",
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subColor),
                            ),
                            Text(
                              "$startOdo km",
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: titleColor),
                            ),
                          ],
                        ),
                        // Connector line
                        Container(
                          margin: const EdgeInsets.only(left: 3.5),
                          width: 1,
                          height: 12,
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                        // End Odometer Line
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: endOdo != null && endOdo.isNotEmpty ? Colors.red : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isTamil ? "முடிவு வாசிப்பு: " : "End Reading: ",
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subColor),
                            ),
                            Text(
                              endOdo != null && endOdo.isNotEmpty ? "$endOdo km" : (isTamil ? "செயலில் உள்ளது" : "In Progress"),
                              style: GoogleFonts.outfit(
                                fontSize: 12, 
                                fontWeight: FontWeight.w900, 
                                color: endOdo != null && endOdo.isNotEmpty ? titleColor : Colors.orange
                              ),
                            ),
                          ],
                        ),
                        if (startTime != null && startTime.isNotEmpty) ...[
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.timer_outlined, size: 14, color: primaryBlue),
                                  const SizedBox(width: 6),
                                  Text(
                                    isTamil ? "பயண நேரம்: " : "Trip Duration: ",
                                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subColor),
                                  ),
                                  Text(
                                    _calculateDurationString(startTime, endTime, isTamil),
                                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: primaryBlue),
                                  ),
                                ],
                              ),
                              if (distance != null)
                                Row(
                                  children: [
                                    Icon(Icons.route_outlined, size: 14, color: Colors.green),
                                    const SizedBox(width: 6),
                                    Text(
                                      isTamil ? "தூரம்: " : "Distance: ",
                                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subColor),
                                    ),
                                    Text(
                                      "${distance.toStringAsFixed(1)} km",
                                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // Responsibility Badges below (if applicable)
                if (isMyResp) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              isTamil ? "எனது பொறுப்பு" : "My Responsibility",
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                ] else if (isTaken) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline_rounded, color: subColor, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              isTamil ? "எடுக்கப்பட்டது" : "Taken",
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: subColor,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadgeWidget(String status) {
    final String s = status.toUpperCase();
    final Map<String, Map<String, Color>> statusStyles = {
      'PLANNED': {
        'bg': const Color(0xFFFEF3C7),
        'text': const Color(0xFFD97706),
      },
      'ONGOING': {
        'bg': const Color(0xFFDBEAFE),
        'text': const Color(0xFF2563EB),
      },
      'COMPLETED': {
        'bg': const Color(0xFFD1FAE5),
        'text': const Color(0xFF047857),
      },
      'CANCELLED': {
        'bg': const Color(0xFFFFE4E6),
        'text': const Color(0xFFBE123C),
      },
    };

    final style = statusStyles[s] ??
        {
          'bg': const Color(0xFFF1F5F9),
          'text': const Color(0xFF475569),
        };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style['bg'],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        s,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: style['text'],
        ),
      ),
    );
  }

  String _formatTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "TBD";
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final minStr = minute.toString().padLeft(2, '0');
        return "$displayHour:$minStr $period";
      }
      return timeStr;
    } catch (_) {
      return timeStr;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "";
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${date.day} ${months[date.month - 1]} ${date.year}";
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _startShift(int shiftId) async {
    setState(() {
      _isSubmittingShift = true;
    });

    try {
      final token = await UserStore.getToken();
      if (token == null) {
        throw "Authentication token not found.";
      }

      final url = Uri.parse("${ApiConstants.baseUrl}/schedule-duty/master/shift/$shiftId/start");
      final headers = ApiConstants.getHeaders(token);
      final curlHeaders = headers.entries.map((e) => "--header '${e.key}: ${e.value}'").join(" \\\n  ");
      debugPrint("🚀 START SHIFT CURL: 🚀\ncurl --location --request POST '$url' \\\n  $curlHeaders");

      final response = await http.post(
        url,
        headers: headers,
      );
      debugPrint("📦 START SHIFT RESPONSE: 📦\nStatus: ${response.statusCode}\nBody: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchDetails(showLoading: false);
        final bool isTamil = LanguageStore.isTamil;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTamil ? "கடமை வெற்றிகரமாக தொடங்கப்பட்டது." : "Duty started successfully."),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Failed to start shift."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmittingShift = false;
      });
    }
  }

  Future<void> _endShift(int shiftId) async {
    setState(() {
      _isSubmittingShift = true;
    });

    try {
      final token = await UserStore.getToken();
      if (token == null) {
        throw "Authentication token not found.";
      }

      final url = Uri.parse("${ApiConstants.baseUrl}/schedule-duty/master/shift/$shiftId/end");
      final headers = ApiConstants.getHeaders(token);
      final curlHeaders = headers.entries.map((e) => "--header '${e.key}: ${e.value}'").join(" \\\n  ");
      debugPrint("🔴 END SHIFT CURL: 🔴\ncurl --location --request POST '$url' \\\n  $curlHeaders");

      final response = await http.post(
        url,
        headers: headers,
      );
      debugPrint("📦 END SHIFT RESPONSE: 📦\nStatus: ${response.statusCode}\nBody: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchDetails(showLoading: false);
        final bool isTamil = LanguageStore.isTamil;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTamil ? "கடமை வெற்றிகரமாக முடிக்கப்பட்டது." : "Duty ended successfully."),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Failed to end shift."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmittingShift = false;
      });
    }
  }

  Future<void> _submitOdometer({
    required int shiftId,
    required int vehicleId,
    required double reading,
    required bool isStart,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await UserStore.getToken();
      if (token == null) {
        throw "Authentication token not found.";
      }

      Uri url;
      String bodyData;
      
      if (isStart) {
        final driverId = await UserStore.getDriverId();
        url = Uri.parse("${ApiConstants.baseUrl}/api/duties/$shiftId/vehicles/$vehicleId/start");
        bodyData = jsonEncode({
          "driverId": driverId,
          "odometerStart": reading,
        });
      } else {
        url = Uri.parse("${ApiConstants.baseUrl}/schedule-duty/master/shift/$shiftId/vehicle/$vehicleId/end-odometer");
        bodyData = jsonEncode({
          "end_odometer": reading,
        });
      }

      final headers = ApiConstants.getHeaders(token);
      final curlHeaders = headers.entries.map((e) => "--header '${e.key}: ${e.value}'").join(" \\\n  ");
      debugPrint("⚙️ ODOMETER SUBMIT CURL: ⚙️\ncurl --location --request POST '$url' \\\n  $curlHeaders \\\n  --header 'Content-Type: application/json' \\\n  --data '$bodyData'");

      final response = await http.post(
        url,
        headers: headers,
        body: bodyData,
      );
      debugPrint("📦 ODOMETER SUBMIT RESPONSE: 📦\nStatus: ${response.statusCode}\nBody: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        _fetchDetails();
        final bool isTamil = LanguageStore.isTamil;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTamil ? "ஓடோமீட்டர் வெற்றிகரமாக சமர்ப்பிக்கப்பட்டது." : "Odometer submitted successfully."),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Failed to submit odometer."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOdometerDialog({
    required BuildContext context,
    required String vehicleNum,
    required String busNumber,
    required int shiftId,
    required int vehicleId,
    required String? currentStartOdo,
    required String? currentEndOdo,
    required bool isTamil,
    required bool isDark,
    required Color cardColor,
    required Color titleColor,
    required Color subColor,
    required Color primaryBlue,
  }) {
    if (currentStartOdo != null && currentStartOdo.isNotEmpty && currentEndOdo != null && currentEndOdo.isNotEmpty) {
      return;
    }

    final bool isStart = currentStartOdo == null || currentStartOdo.isEmpty;
    final TextEditingController mainOdoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String activeTab = "End Odometer"; // "End Odometer" or "Transfer"
        List<dynamic> drivers = [];
        List<dynamic> filteredDrivers = [];
        bool isLoadingDrivers = false;
        bool hasFetchedDrivers = false;
        Map<String, dynamic>? selectedDriver;
        String driverSearchQuery = "";

        final TextEditingController endOdoController = TextEditingController();
        final TextEditingController reasonController = TextEditingController();
        final TextEditingController searchController = TextEditingController();

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> fetchTransferDrivers() async {
              setModalState(() {
                isLoadingDrivers = true;
                hasFetchedDrivers = true;
              });
              try {
                final token = await UserStore.getToken();
                if (token == null) return;
                final url = Uri.parse("${ApiConstants.baseUrl}/schedule-duty/master/shift/$shiftId/drivers?duty_shift_id=$shiftId");
                final headers = ApiConstants.getHeaders(token);
                final curlHeaders = headers.entries.map((e) => "--header '${e.key}: ${e.value}'").join(" \\\n  ");
                debugPrint("🔍 GET TRANSFER DRIVERS CURL: 🔍\ncurl --location '$url' \\\n  $curlHeaders");
                final response = await http.get(url, headers: headers);
                if (response.statusCode == 200) {
                  final data = jsonDecode(response.body);
                  if (data['success'] == true && data['data'] != null) {
                    final rawList = data['data'] as List;
                    final cleanList = rawList.where((item) => item != null && item is Map && item.isNotEmpty).toList();
                    setModalState(() {
                      drivers = cleanList;
                      filteredDrivers = cleanList;
                    });
                  }
                }
              } catch (e) {
                debugPrint("Error fetching transfer drivers: $e");
              } finally {
                setModalState(() {
                  isLoadingDrivers = false;
                });
              }
            }

            if (!isStart && activeTab == "Transfer" && !hasFetchedDrivers && !isLoadingDrivers) {
              fetchTransferDrivers();
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isStart 
                              ? (isTamil ? "ஆரம்ப ஓடோமீட்டர்" : "Start Odometer")
                              : (activeTab == "Transfer"
                                  ? (isTamil ? "வாகன பரிமாற்றம்" : "Vehicle Transfer")
                                  : (isTamil ? "முடிவு ஓடோமீட்டர்" : "End Odometer")),
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: titleColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Toggle segment control for End Odo / Transfer Option
                    if (!isStart) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        height: 46,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    activeTab = "End Odometer";
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: activeTab == "End Odometer" ? primaryBlue : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    isTamil ? "முடிவு ஓடோமீட்டர்" : "End Odometer",
                                    style: GoogleFonts.outfit(
                                      color: activeTab == "End Odometer" ? Colors.white : subColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    activeTab = "Transfer";
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: activeTab == "Transfer" ? primaryBlue : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    isTamil ? "மாற்று" : "Transfer Option",
                                    style: GoogleFonts.outfit(
                                      color: activeTab == "Transfer" ? Colors.white : subColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Tab View content
                    if (isStart || activeTab == "End Odometer") ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.directions_car_filled_rounded, color: primaryBlue, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    busNumber,
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: titleColor,
                                    ),
                                  ),
                                  Text(
                                    vehicleNum,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: subColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        isStart 
                            ? (isTamil ? "ஆரம்ப ஓடோமீட்டர் மதிப்பு" : "Enter Start Odometer Reading")
                            : (isTamil ? "முடிவு ஓடோமீட்டர் மதிப்பு" : "Enter End Odometer Reading"),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: subColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: mainOdoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.outfit(color: titleColor, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: "e.g. 15050",
                          hintStyle: GoogleFonts.outfit(color: subColor.withOpacity(0.5)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: primaryBlue, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            final text = mainOdoController.text.trim();
                            if (text.isEmpty) return;
                            final double? val = double.tryParse(text);
                            if (val == null) return;
                            Navigator.pop(context);
                            _submitOdometer(
                              shiftId: shiftId,
                              vehicleId: vehicleId,
                              reading: val,
                              isStart: isStart,
                            );
                          },
                          child: Text(
                            isTamil ? "சமர்ப்பி" : "Submit",
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Transfer option view
                      if (selectedDriver == null) ...[
                        Text(
                          isTamil ? "மாற்ற வேண்டிய ஓட்டுநரைத் தேர்ந்தெடுக்கவும்" : "Select Driver for Transfer",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: searchController,
                          style: GoogleFonts.outfit(color: titleColor, fontWeight: FontWeight.bold),
                          onChanged: (val) {
                            setModalState(() {
                              driverSearchQuery = val.toLowerCase().trim();
                              filteredDrivers = drivers.where((d) {
                                final driverData = d['driver'] as Map<String, dynamic>? ?? {};
                                final userData = driverData['user'] as Map<String, dynamic>? ?? {};
                                final name = (userData['name'] ?? "").toString().toLowerCase();
                                final username = (userData['username'] ?? "").toString().toLowerCase();
                                final phone = (userData['phone'] ?? "").toString().toLowerCase();
                                return name.contains(driverSearchQuery) || 
                                       username.contains(driverSearchQuery) || 
                                       phone.contains(driverSearchQuery);
                              }).toList();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: isTamil ? "ஓட்டுநரைத் தேடுக..." : "Search driver name, username...",
                            hintStyle: GoogleFonts.outfit(color: subColor.withOpacity(0.5)),
                            prefixIcon: Icon(Icons.search_rounded, color: subColor),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        isLoadingDrivers
                            ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                            : filteredDrivers.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Text(
                                        isTamil ? "ஓட்டுநர்கள் எவரும் கிடைக்கவில்லை" : "No drivers available",
                                        style: TextStyle(color: subColor),
                                      ),
                                    ),
                                  )
                                : SizedBox(
                                    height: 200,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: filteredDrivers.length,
                                      itemBuilder: (context, index) {
                                        final d = filteredDrivers[index];
                                        final driverData = d['driver'] as Map<String, dynamic>? ?? {};
                                        final userData = driverData['user'] as Map<String, dynamic>? ?? {};
                                        final name = userData['name'] ?? 'N/A';
                                        
                                        final halfDayType = d['half_day_type'] ?? '';
                                        final leaveType = d['leave_type'] ?? '';
                                        final isHalfDay = leaveType == 'HALF_DAY';
                                        
                                        return Card(
                                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                                          ),
                                          margin: const EdgeInsets.only(bottom: 12),
                                          elevation: 2,
                                          shadowColor: Colors.black.withOpacity(0.05),
                                          child: ListTile(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            leading: CircleAvatar(
                                              backgroundColor: primaryBlue.withOpacity(0.1),
                                              child: Icon(Icons.person_rounded, color: primaryBlue),
                                            ),
                                            title: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    name,
                                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: titleColor, fontSize: 15),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isHalfDay)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.orange.withOpacity(0.5)),
                                                    ),
                                                    child: Text(
                                                      "0.5 Day Leave ${halfDayType.toString().isNotEmpty ? '($halfDayType)' : ''}",
                                                      style: GoogleFonts.outfit(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            trailing: Icon(Icons.chevron_right_rounded, color: primaryBlue),
                                            onTap: () {
                                              setModalState(() {
                                                selectedDriver = d;
                                              });
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                      ] else ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.orange.withOpacity(0.4), width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.orange.withOpacity(0.1),
                                    child: const Icon(Icons.person_rounded, color: Colors.orange),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Builder(
                                      builder: (context) {
                                        final driverData = selectedDriver!['driver'] as Map<String, dynamic>? ?? {};
                                        final userData = driverData['user'] as Map<String, dynamic>? ?? {};
                                        final name = userData['name'] ?? 'N/A';
                                        
                                        final halfDayType = selectedDriver!['half_day_type'] ?? '';
                                        final leaveType = selectedDriver!['leave_type'] ?? '';
                                        final isHalfDay = leaveType == 'HALF_DAY';
                                        
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: titleColor, fontSize: 16),
                                            ),
                                            if (isHalfDay) ...[
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.orange.withOpacity(0.5)),
                                                ),
                                                child: Text(
                                                  "0.5 Day Leave ${halfDayType.toString().isNotEmpty ? '($halfDayType)' : ''}",
                                                  style: GoogleFonts.outfit(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ],
                                        );
                                      }
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setModalState(() {
                                        selectedDriver = null;
                                      });
                                    },
                                    child: Text(
                                      isTamil ? "மாற்று" : "Change",
                                      style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isTamil ? "தேர்ந்தெடுக்கப்பட்ட வாகனம்" : "Selected Vehicle",
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: subColor),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.directions_car_filled_rounded, color: primaryBlue, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    "$busNumber ($vehicleNum)",
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: titleColor, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isTamil ? "முடிவு ஓடோமீட்டர் மதிப்பு" : "Enter End Odometer Reading",
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: subColor),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: endOdoController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.outfit(color: titleColor, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: "e.g. 15050",
                                hintStyle: GoogleFonts.outfit(color: subColor.withOpacity(0.5)),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryBlue, width: 2)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isTamil ? "பரிமாற்றத்திற்கான காரணம்" : "Reason for Transfer",
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: subColor),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: reasonController,
                              style: GoogleFonts.outfit(color: titleColor, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: isTamil ? "காரணத்தை உள்ளிடவும் (எ.கா. ஓட்டுநர் உடல்நிலை சரியில்லை)" : "Enter reason (e.g. Driver feeling unwell)",
                                hintStyle: GoogleFonts.outfit(color: subColor.withOpacity(0.5)),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryBlue, width: 2)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  final odoText = endOdoController.text.trim();
                                  final reasonText = reasonController.text.trim();
                                  if (odoText.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isTamil ? "ஓடோமீட்டர் உள்ளிடவும்." : "Please enter odometer."),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }
                                  final double? odoVal = double.tryParse(odoText);
                                  if (odoVal == null) return;
                                  
                                  Navigator.pop(context);
                                  
                                  final currentDriverId = _scheduleDetails?['driver_id'] ?? 0;
                                  
                                  _submitTransfer(
                                    shiftId: shiftId,
                                    fromDriverId: currentDriverId,
                                    toDriverId: selectedDriver!['driver_id'] ?? selectedDriver!['driver']?['id'] ?? 0,
                                    toDriverShiftId: selectedDriver!['id'],
                                    vehicleId: vehicleId,
                                    endOdometer: odoVal,
                                    reason: reasonText,
                                    dutyShiftType: selectedDriver!['half_day_type']?.toString(),
                                  );
                                },
                                child: Text(
                                  isTamil ? "பரிமாற்றம் செய்" : "Submit Transfer",
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitTransfer({
    required int shiftId,
    required int fromDriverId,
    required int toDriverId,
    int? toDriverShiftId,
    required int vehicleId,
    required double endOdometer,
    required String reason,
    String? dutyShiftType,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await UserStore.getToken();
      if (token == null) {
        throw "Authentication token not found.";
      }

      final url = Uri.parse("${ApiConstants.baseUrl}/schedule-duty/master/shift/$shiftId/transfer");

      final bodyData = jsonEncode({
        "from_driver_id": fromDriverId,
        "to_driver_id": toDriverId,
        if (toDriverShiftId != null) "to_driver_shift_id": toDriverShiftId,
        "vehicle_id": vehicleId,
        "end_odometer_for_from_driver": endOdometer,
        "reason": reason,
        if (dutyShiftType != null && dutyShiftType.isNotEmpty) "duty_shift_type": dutyShiftType,
      });

      final headers = ApiConstants.getHeaders(token);
      final curlHeaders = headers.entries.map((e) => "--header '${e.key}: ${e.value}'").join(" \\\n  ");
      debugPrint("🔄 VEHICLE TRANSFER CURL: 🔄\ncurl --location --request POST '$url' \\\n  $curlHeaders \\\n  --header 'Content-Type: application/json' \\\n  --data '$bodyData'");

      final response = await http.post(
        url,
        headers: headers,
        body: bodyData,
      );
      debugPrint("📦 VEHICLE TRANSFER RESPONSE: 📦\nStatus: ${response.statusCode}\nBody: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        _fetchDetails();
        final bool isTamil = LanguageStore.isTamil;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTamil ? "வாகனம் வெற்றிகரமாக மாற்றப்பட்டது." : "Vehicle transferred successfully."),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Failed to transfer vehicle."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDateTimeString(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      return DateFormat("d MMM yyyy, hh:mm a").format(dateTime);
    } catch (_) {
      return isoString;
    }
  }

  String _calculateDurationString(String startIso, String? endIso, bool isTamil) {
    try {
      final startTime = DateTime.parse(startIso).toLocal();
      final endTime = (endIso != null && endIso.isNotEmpty) ? DateTime.parse(endIso).toLocal() : DateTime.now();
      
      final difference = endTime.difference(startTime);
      final int hours = difference.inHours;
      final int minutes = difference.inMinutes % 60;
      
      if (hours > 0) {
        if (isTamil) {
          return "$hours மணிநேரம் $minutes நிமிடங்கள்";
        }
        return "${hours}h ${minutes}m";
      } else {
        if (isTamil) {
          return "$minutes நிமிடங்கள்";
        }
        return "${minutes}m";
      }
    } catch (_) {
      return "N/A";
    }
  }
}
