import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tripzo/screens/faculty/missions/reassign_guest_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/utils/crypto_utils.dart';
import 'package:tripzo/screens/driver/verify_mission_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';


class MissionDetailsScreen extends StatefulWidget {
  final String missionTitle,
      time,
      driverName,
      driverPhone,
      vehicleInfo,
      capacity,
      passengerCount,
      pathType,
      status,
      requestId,
      creatorName;
  final int rawStatus;
  final List<Map<String, String>> stops;
  final Color statusColor;

  const MissionDetailsScreen({
    super.key,
    required this.missionTitle,
    required this.time,
    required this.driverName,
    required this.driverPhone,
    required this.vehicleInfo,
    required this.capacity,
    this.passengerCount = "0",
    required this.pathType,
    required this.stops,
    required this.status,
    required this.statusColor,
    required this.requestId,
    required this.rawStatus,
    this.creatorName = "Faculty Member",
  });


  @override
  State<MissionDetailsScreen> createState() => _MissionDetailsScreenState();
}

class _MissionDetailsScreenState extends State<MissionDetailsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final MapController _mapController = MapController();
  bool _isLoadingOtp = false;

  // --- Map & Route State ---
  List<LatLng> _routePoints = [];
  List<Marker> _markers = [];
  bool _isMapLoading = false;
  final String _userAgent = "TMS_Fleet_Manager_App/1.0";

  // --- Dynamic Mission Data ---
  Map<String, dynamic>? _missionData;
  bool _isFetchingDetails = true;
  bool _isApproving = false;
  String? _userRole;


  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Start loading data and route after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMissionDetails();
      _loadMapData();
      _fetchUserRole();
    });
  }

  Future<void> _fetchUserRole() async {
    final role = await UserStore.getRole();
    if (mounted) setState(() => _userRole = role);
  }


  Future<void> _fetchMissionDetails() async {
    setState(() => _isFetchingDetails = true);
    try {
      final token = await UserStore.getToken();
      final url = "${ApiConstants.baseUrl}/request/get-by-id/${widget.requestId}";
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _missionData = data['data'];
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch details error: $e");
    } finally {
      if (mounted) setState(() => _isFetchingDetails = false);
    }
  }

  Future<void> _handleApprove(String remark) async {
    setState(() => _isApproving = true);
    try {
      final token = await UserStore.getToken();
      List<Map<String, dynamic>> allocations = [];
      final schedules = _missionData?['schedules'] as List?;
      if (schedules != null) {
        for (var schedule in schedules) {
          final vehicleId = schedule['vehicle']?['id'];
          final guests = schedule['guests'] as List?;
          if (vehicleId != null && guests != null) {
            allocations.add({
              "vehicle_id": vehicleId,
              "guest_ids": guests.map((g) => g['id']).toList(),
            });
          }
        }
      }

      final String? role = await UserStore.getRole();
      final bool isAdmin = role?.toLowerCase() == 'admin';

      final body = {
        "route_id": int.tryParse(widget.requestId) ?? 0,
        isAdmin ? "admin_remarks" : "faculty_remarks": remark.trim().isEmpty ? "Approved via Mobile App" : remark.trim(),
        "allocations": allocations,
      };

      final url = "${ApiConstants.baseUrl}/request/update-assigned-vehicles";
      final response = await http.put(
        Uri.parse(url),
        headers: {
          ...ApiConstants.getHeaders(token),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final respData = jsonDecode(response.body);
      if (response.statusCode == 200 && respData['success'] != false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${isAdmin ? 'Admin' : 'Mission'} Approved Successfully"), backgroundColor: Colors.green),
        );
        await _fetchMissionDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(respData['message'] ?? "Failed to approve"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  void _handleDecline(String remark) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Declined with remark: $remark"), backgroundColor: Colors.orange),
    );
  }

  void _showRemarkModal(bool isApprove) async {
    final String? role = await UserStore.getRole();
    final bool isAdmin = role?.toLowerCase() == 'admin';
    
    final TextEditingController remarkController = TextEditingController();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isApprove ? (isAdmin ? "Admin Approval" : "Approve Mission") : (isAdmin ? "Admin Decline" : "Decline Mission"),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please add a remark before proceeding.",
                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: remarkController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Enter your remarks here...",
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.grey, width: 0.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isApprove ? Colors.green : Colors.red, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                       Navigator.pop(context);
                       if (isApprove) {
                         _handleApprove(remarkController.text);
                       } else {
                         _handleDecline(remarkController.text);
                       }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isApprove ? Colors.green : Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      "CONFIRM ${isApprove ? 'APPROVAL' : 'DECLINE'}",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadMapData() async {
    if (widget.stops.isEmpty) return;
    setState(() => _isMapLoading = true);

    try {
      List<LatLng> stopCoords = [];
      for (var stop in widget.stops) {
        final loc = stop['location'];
        if (loc != null && loc.isNotEmpty) {
          final coords = await _geocode(loc);
          if (coords != null) stopCoords.add(coords);
        }
      }

      if (stopCoords.length >= 2) {
        await _calculateRoute(stopCoords);
      } else if (stopCoords.isNotEmpty) {
        // Just show a single marker if path not possible
        setState(() {
          _markers = [
            Marker(
              point: stopCoords.first,
              width: 40,
              height: 40,
              child: const Icon(Icons.location_on, color: Colors.blue, size: 30),
            ),
          ];
        });
        _mapController.move(stopCoords.first, 12);
      }
    } catch (e) {
      debugPrint("Map Load Error: $e");
    } finally {
      if (mounted) setState(() => _isMapLoading = false);
    }
  }

  Future<LatLng?> _geocode(String query) async {
    final url =
        "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=in";
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          return LatLng(double.parse(data[0]['lat']), double.parse(data[0]['lon']));
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _calculateRoute(List<LatLng> points) async {
    final String coords = points.map((p) => "${p.longitude},${p.latitude}").join(";");
    final String url =
        "https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final List geometry = data['routes'][0]['geometry']['coordinates'];
          final List<LatLng> route = geometry.map((c) => LatLng(c[1], c[0])).toList();

          setState(() {
            _routePoints = route;
            _markers = points.asMap().entries.map((entry) {
              final isFirst = entry.key == 0;
              final isLast = entry.key == points.length - 1;
              return Marker(
                point: entry.value,
                width: 40,
                height: 40,
                child: Icon(
                  isFirst ? Icons.stars_rounded : (isLast ? Icons.location_on : Icons.circle),
                  color: isFirst ? Colors.green : (isLast ? Colors.red : Colors.blue),
                  size: isFirst || isLast ? 30 : 15,
                ),
              );
            }).toList();
          });

          _fitBounds(points);
        }
      }
    } catch (_) {}
  }

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  Future<void> _handleAction() async {
    setState(() => _isLoadingOtp = true);
    try {
      final String? role = await UserStore.getRole();
      final bool isDriver = role?.toLowerCase() == 'driver';

      if (isDriver) {
        final currentStatus = _missionData?['route_status'] ?? widget.rawStatus;
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyMissionScreen(
              requestId: widget.requestId,
              isStart: currentStatus == 5 || currentStatus == 6,
            ),
          ),
        );
        if (result == true) {
          _fetchMissionDetails();
        }
        return;
      }

      final String? token = await UserStore.getToken();
      final currentStatus = _missionData?['route_status'] ?? widget.rawStatus;
      final isStart = currentStatus == 5 || currentStatus == 6;

      final endpoint = isStart
          ? "${ApiConstants.baseUrl}/request/generate-start-otp"
          : "${ApiConstants.baseUrl}/request/generate-end-otp";

      final response = await http.post(
        Uri.parse(endpoint),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode({"route_id": int.tryParse(widget.requestId) ?? 0}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String displayOtp = data['otp']?.toString() ?? "";

        // Attempt JWT Decode just in case
        try {
          final parts = displayOtp.split('.');
          if (parts.length == 3) {
            String payloadStr = parts[1];
            String normalized = payloadStr.replaceAll('-', '+').replaceAll('_', '/');
            switch (normalized.length % 4) {
              case 2: normalized += '=='; break;
              case 3: normalized += '='; break;
            }
            final decodedBytes = base64Url.decode(normalized);
            final payloadMap = jsonDecode(utf8.decode(decodedBytes));
            if (payloadMap['otp'] != null) {
              displayOtp = payloadMap['otp'].toString();
            }
          }
        } catch (e) {
          debugPrint("Failed to parse JWT: $e");
        }

        _showOtpModal(displayOtp, isStart ? "Start OTP" : "End OTP");
      } else {
        throw "Failed to generate OTP";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoadingOtp = false);
    }
  }

  void _showOtpInputModal() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final currentStatus = _missionData?['route_status'] ?? widget.rawStatus;
    final isStart = currentStatus == 5 || currentStatus == 6;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OtpBottomSheet(
        requestId: widget.requestId,
        isStart: isStart,
        bgColor: bgColor,
        titleColor: titleColor,
        onSuccess: () {
          _fetchMissionDetails();
        },
      ),
    );
  }

  void _showOtpModal(String otp, String title) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _OtpFullScreenOverlay(
          otp: otp,
          title: title,
          onClose: () => Navigator.pop(context),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);

    final currentStatus = _missionData?['route_status'] ?? widget.rawStatus;
    
    final bool isDriver = _userRole?.toLowerCase() == 'driver';

    final showAction =

        currentStatus == 5 || currentStatus == 6 || currentStatus == 7;
    
    String actionLabel = currentStatus == 7 ? "End Activity" : "Start Activity";
    if (isDriver) {
      actionLabel = currentStatus == 7 ? "ARRIVED OTP" : "START OTP";
    }

    final showApproveDecline = currentStatus == 2 || currentStatus == 3;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isFetchingDetails 
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          _buildBackgroundDecor(isDark),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: _buildHeader(context, titleColor),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100), // Extra bottom padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroCard(cardColor, titleColor, subColor, primaryBlue),
                          const SizedBox(height: 32),
                          _buildTripMetrics(cardColor, primaryBlue, subColor),
                          const SizedBox(height: 32),
                          _buildSectionTitle(
                            "Live tracking path",
                            primaryBlue,
                            titleColor,
                          ),
                          const SizedBox(height: 16),
                          _buildMap(primaryBlue),
                          const SizedBox(height: 32),
                          _buildSectionTitle(
                            "Detailed Checkpoints",
                            primaryBlue,
                            titleColor,
                          ),
                          const SizedBox(height: 20),
                          _buildCheckpointList(primaryBlue, titleColor),
                          const SizedBox(height: 32),
                          _buildSectionTitle(
                            "Resource & Vehicle",
                            primaryBlue,
                            titleColor,
                          ),
                          const SizedBox(height: 16),
                          _buildDynamicResources(cardColor, primaryBlue, subColor),
                          const SizedBox(height: 8),
                          _buildAdditionalInfo(cardColor, primaryBlue, subColor),
                          const SizedBox(height: 24),
                          _buildRemarks(cardColor, titleColor, subColor, primaryBlue),
                          if (showApproveDecline) ...[
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isLoadingOtp || _isApproving ? null : () async {
                                  final schedules = _missionData?['schedules'] as List?;
                                  if (schedules == null || schedules.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No schedules to manage.")));
                                    return;
                                  }
                                  
                                  final String? role = await UserStore.getRole();
                                  final bool isAdmin = role?.toLowerCase() == 'admin';

                                  if (!mounted) return;
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => ReassignGuestScreen(
                                      initialSchedules: schedules,
                                      routeId: widget.requestId,
                                      defaultRemark: isAdmin 
                                          ? (_missionData?['admin_remark'] ?? '') 
                                          : (_missionData?['faculty_remark'] ?? ''),
                                    )),
                                  );

                                  if (result == true) {
                                    _fetchMissionDetails();
                                  }
                                },
                                icon: const Icon(Icons.manage_accounts_rounded),
                                label: const Text(
                                  "MANAGE & ALLOCATIONS",
                                  style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: BorderSide(color: primaryBlue, width: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  foregroundColor: primaryBlue,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isLoadingOtp || _isApproving ? null : () => _showRemarkModal(false),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: const BorderSide(color: Colors.red, width: 2),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      "DECLINE",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.red,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _isLoadingOtp || _isApproving ? null : () => _showRemarkModal(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isApproving
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            "APPROVE",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showAction)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: _SwipeToConfirm(
                label: actionLabel.toUpperCase(),
                onConfirm: () {
                  _showOtpInputModal();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color titleColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: titleColor,
            size: 22,
          ),
        ),
        Text(
          "Mission Details",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildHeroCard(Color cardColor, Color titleColor, Color subColor, Color primaryBlue) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: widget.statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.status.toUpperCase(),
                  style: TextStyle(
                    color: widget.statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: subColor.withOpacity(0.6)),
                  const SizedBox(width: 6),
                  Text(
                    widget.time,
                    style: TextStyle(color: subColor, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            widget.missionTitle,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: titleColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                widget.pathType.toUpperCase(),
                style: TextStyle(
                  color: subColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Icon(Icons.person_pin_rounded, size: 14, color: subColor.withOpacity(0.6)),
              const SizedBox(width: 4),
              Text(
                widget.creatorName.toUpperCase(),
                style: TextStyle(
                  color: subColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetric(Icons.groups_rounded, widget.passengerCount, "GUESTS", primaryBlue, subColor),
              const SizedBox(width: 48),
              _buildMetric(Icons.alt_route_rounded, widget.stops.length.toString(), "STOPS", primaryBlue, subColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(IconData icon, String value, String label, Color blue, Color sub) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: blue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: blue, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: sub.withOpacity(0.6),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color accent, Color titleColor) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 18,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: titleColor,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckpointList(Color blue, Color title) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.stops.length,
      itemBuilder: (context, index) {
        final stop = widget.stops[index];
        return _buildTimelineItem(
          location: stop['location']!,
          eta: stop['eta']!,
          isFirst: index == 0,
          isLast: index == widget.stops.length - 1,
          color: blue,
          titleColor: title,
        );
      },
    );
  }

  Widget _buildTimelineItem({
    required String location,
    required String eta,
    required bool isFirst,
    required bool isLast,
    required Color color,
    required Color titleColor,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFirst ? color : (isLast ? Colors.red : Colors.transparent),
                  border: Border.all(color: isLast ? Colors.red : color, width: 3),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2.5, color: color.withOpacity(0.15)),
                ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          eta,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: color,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isFirst)
                     Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text("Origin point", style: TextStyle(color: color.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(Color cardColor, Color blue, Color sub, String dName, String dPhone) {
    final bool isNotAssigned = dName == "no driver assigned" || dName == "Driver Not Assigned";
    final Color nameColor = isNotAssigned ? Colors.redAccent : (cardColor == Colors.white ? Colors.black87 : Colors.white);
    final Color phoneColor = isNotAssigned ? Colors.redAccent.withOpacity(0.7) : sub;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isNotAssigned ? Colors.red.withOpacity(0.1) : blue.withOpacity(0.1),
            child: Icon(isNotAssigned ? Icons.person_off_rounded : Icons.person_rounded, color: isNotAssigned ? Colors.red : blue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dName,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: nameColor),
                ),
                const SizedBox(height: 2),
                Text(
                  dPhone,
                  style: TextStyle(color: phoneColor, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (!isNotAssigned)
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_rounded, size: 20, color: Colors.green),
            ),
        ],
      ),
    );
  }

  Widget _buildVehicleDetails(Color cardColor, Color blue, Color sub, String vInfo, String cap) {
    String vType = vInfo;
    String vNumber = "";
    if (vInfo.contains('(')) {
      vType = vInfo.split('(')[0].trim();
      vNumber = vInfo.split('(')[1].replaceAll(')', '').trim();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildEnhancedSmallInfo(
            Icons.directions_car_filled_rounded,
            vType,
            "VEHICLE",
            blue,
            sub,
          ),
          if (vNumber.isNotEmpty)
            _buildEnhancedSmallInfo(
              Icons.tag_rounded,
              vNumber,
              "PLATE NO",
              blue,
              sub,
            ),
           _buildEnhancedSmallInfo(
            Icons.groups_rounded,
            cap,
            "SEATS",
            blue,
            sub,
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicResources(Color cardColor, Color blue, Color subColor) {
    // ... (rest of _buildDynamicResources remains the same, inserting beneath it)
    final schedules = _missionData?['schedules'] as List?;
    if (schedules == null || schedules.isEmpty) {
      return Column(
        children: [
          _buildDriverCard(cardColor, blue, subColor, widget.driverName, widget.driverPhone),
          const SizedBox(height: 12),
          _buildVehicleDetails(cardColor, blue, subColor, widget.vehicleInfo, widget.capacity),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: schedules.map((schedule) {
        final driver = schedule['driver'];
        final vehicle = schedule['vehicle'];
        final guests = schedule['guests'] as List?;
        
        final dName = driver?['name'] ?? "no driver assigned";
        final dPhone = driver?['phone'] ?? "n/a";
        final vInfo = vehicle != null ? "${vehicle['vehicle_type']} (${vehicle['vehicle_number']})" : "no driver assigned";
        final vCap = vehicle != null ? "${vehicle['vehicle_capacity']} Seats" : "n/a";

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDriverCard(cardColor, blue, subColor, dName, dPhone),
              const SizedBox(height: 12),
              _buildVehicleDetails(cardColor, blue, subColor, vInfo, vCap),
              if (guests != null && guests.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  "Assigned Guests (${guests.length})",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: subColor.withOpacity(0.8), letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                ...guests.asMap().entries.map((entry) {
                  final i = entry.key;
                  final g = entry.value;
                  final phone = g['phone'];
                  final status = g['status']?.toString().toUpperCase() ?? "UNKNOWN";
                  final Color statusColor = status == "ACTIVE" ? Colors.green : Colors.orange;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: blue.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: blue.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: blue.withOpacity(0.1), shape: BoxShape.circle),
                            child: Text(
                              "${i + 1}",
                              style: TextStyle(fontWeight: FontWeight.w900, color: blue, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        g['name'] ?? "Unknown", 
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: cardColor == Colors.white ? Colors.black87 : Colors.white),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.phone_rounded, size: 12, color: subColor.withOpacity(0.7)),
                                    const SizedBox(width: 4),
                                    Text(
                                      phone ?? 'No Phone',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subColor),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (phone != null && phone.toString().isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.green, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                final Uri url = Uri.parse("tel:$phone");
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url);
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch dialer')));
                                  }
                                }
                              },
                            )
                        ],
                      ),
                    ),
                  );
                }),
              ]
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTripMetrics(Color cardColor, Color blue, Color sub) {
    if (_missionData == null || _missionData!['route_details'] == null) return const SizedBox.shrink();
    
    final details = _missionData!['route_details'];
    final dist = details['distance_km'] != null ? "${details['distance_km']} km" : "N/A";
    
    // Formatting duration correctly from minutes (e.g., 360 -> 6h 0m)
    String dur = "N/A";
    if (details['duration_mins'] != null) {
       int durationInMins = (details['duration_mins'] as num).toInt();
       int hours = durationInMins ~/ 60;
       int mins = durationInMins % 60;
       dur = hours > 0 ? "${hours}h ${mins}m" : "${mins}m";
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildEnhancedSmallInfo(Icons.map_rounded, dist, "DISTANCE", blue, sub),
          Container(height: 40, width: 1, color: sub.withOpacity(0.2)),
          _buildEnhancedSmallInfo(Icons.timer_rounded, dur, "EST. DURATION", blue, sub),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo(Color cardColor, Color blue, Color sub) {
     if (_missionData == null || _missionData!['additional_info'] == null) return const SizedBox.shrink();
     final addInfo = _missionData!['additional_info'];
     final reqs = addInfo['special_requirements'];
     final lug = addInfo['luggage_details'];

     if ((reqs == null || reqs == 'Nil' || reqs == 'null' || reqs.toString().isEmpty) && 
         (lug == null || lug == 'Nil' || lug == 'null' || lug.toString().isEmpty)) return const SizedBox.shrink();

     return Container(
       width: double.infinity,
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(
         color: blue.withOpacity(0.05),
         borderRadius: BorderRadius.circular(24),
         border: Border.all(color: blue.withOpacity(0.1)),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           if (reqs != null && reqs != 'Nil' && reqs != 'null' && reqs.toString().isNotEmpty) ...[
             Row(
               children: [
                 Icon(Icons.assignment_late_rounded, size: 16, color: blue),
                 const SizedBox(width: 8),
                 Text("Special Requirements", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: blue, letterSpacing: 0.5)),
               ],
             ),
             const SizedBox(height: 6),
             Text(reqs, style: TextStyle(fontSize: 14, color: sub, fontWeight: FontWeight.w600, height: 1.4)),
             const SizedBox(height: 16),
           ],
           
           if (lug != null && lug != 'Nil' && lug != 'null' && lug.toString().isNotEmpty) ...[
             Row(
               children: [
                 Icon(Icons.luggage_rounded, size: 16, color: blue),
                 const SizedBox(width: 8),
                 Text("Luggage Details", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: blue, letterSpacing: 0.5)),
               ],
             ),
             const SizedBox(height: 6),
             Text(lug, style: TextStyle(fontSize: 14, color: sub, fontWeight: FontWeight.w600, height: 1.4)),
           ]
         ],
       ),
     );
  }

  Widget _buildRemarks(Color cardColor, Color titleColor, Color subColor, Color blue) {
    if (_missionData == null) return const SizedBox.shrink();
    
    final facultyRemark = _missionData!['faculty_remark'];
    final adminRemark = _missionData!['admin_remark'];
    final creator = _missionData!['creator'];
    
    if (facultyRemark == null && adminRemark == null && creator == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (creator != null) ...[
           _buildSectionTitle("Assigned By", blue, titleColor),
           const SizedBox(height: 12),
           Container(
             width: double.infinity,
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: cardColor,
               borderRadius: BorderRadius.circular(16),
               border: Border.all(color: subColor.withOpacity(0.1)),
             ),
             child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Text(creator['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.w800, color: titleColor, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(creator['Role']?['name'] ?? 'Staff', style: TextStyle(fontWeight: FontWeight.w600, color: subColor, fontSize: 12)),
                     ],
                   ),
                   Icon(Icons.assignment_turned_in_rounded, color: Colors.green.withOpacity(0.8), size: 28),
                 ],
             ),
           ),
           const SizedBox(height: 24),
        ],

        if (facultyRemark != null || adminRemark != null) ...[
          _buildSectionTitle("Remarks", blue, titleColor),
          const SizedBox(height: 12),
          if (facultyRemark != null && facultyRemark.toString().isNotEmpty && facultyRemark != 'null')
            _buildRemarkTile(Icons.person_outline, "Faculty Remark", facultyRemark, cardColor, subColor, titleColor),
          if (adminRemark != null && adminRemark.toString().isNotEmpty && adminRemark != 'null')
            _buildRemarkTile(Icons.admin_panel_settings_outlined, "Admin Remark", adminRemark, cardColor, subColor, titleColor),
        ]
      ],
    );
  }

  Widget _buildRemarkTile(IconData icon, String title, String body, Color cardColor, Color subColor, Color titleColor) {
     return Container(
        margin: const EdgeInsets.only(bottom: 12),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: subColor.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
               children: [
                  Icon(icon, size: 16, color: subColor),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: subColor)),
               ]
            ),
            const SizedBox(height: 8),
            Text(body, style: TextStyle(fontSize: 14, color: titleColor, fontWeight: FontWeight.w600, height: 1.4)),
          ],
        ),
     );
  }


  Widget _buildEnhancedSmallInfo(IconData icon, String val, String label, Color blue, Color sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: sub.withOpacity(0.6), letterSpacing: 1)),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(icon, size: 18, color: blue),
            const SizedBox(width: 8),
            Text(
              val,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMap(Color primaryColor) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(20.5937, 78.9629),
                initialZoom: 5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4.5,
                        color: primaryColor,
                      ),
                    ],
                  ),
                MarkerLayer(markers: _markers),
              ],
            ),
          ),
          if (_isMapLoading)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
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
              backgroundColor: const Color(0xFF6366F1).withOpacity(isDark ? 0.06 : 0.04),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: const Color(0xFFA855F7).withOpacity(isDark ? 0.04 : 0.02),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpFullScreenOverlay extends StatefulWidget {
  final String otp;
  final String title;
  final VoidCallback onClose;

  const _OtpFullScreenOverlay({
    required this.otp,
    required this.title,
    required this.onClose,
  });

  @override
  State<_OtpFullScreenOverlay> createState() => _OtpFullScreenOverlayState();
}

class _OtpFullScreenOverlayState extends State<_OtpFullScreenOverlay> {
  int _secondsLeft = 30;
  late final Stream<int> _timerStream;
  bool _isClosed = false;

  @override
  void initState() {
    super.initState();
    _timerStream = Stream.periodic(const Duration(seconds: 1), (i) => 29 - i).take(30);
    _startTimer();
  }

  void _startTimer() async {
    await for (final second in _timerStream) {
      if (_isClosed) return;
      if (mounted) {
        setState(() => _secondsLeft = second);
      }
    }
    if (mounted && !_isClosed) {
      _close();
    }
  }

  void _close() {
    _isClosed = true;
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final String decryptedOtp = CryptoUtils.decryptOTP(widget.otp);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code_2_rounded,
                        color: Color(0xFF6366F1), size: 24),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.grey, size: 28),
                    onPressed: _close,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Driver scans this code to verify",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: QrImageView(
                  data: widget.otp, // Encrypted value for scanning
                  version: QrVersions.auto,
                  size: MediaQuery.of(context).size.width * 0.5,
                  gapless: false,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "OTP CODE",
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                decryptedOtp, // Decrypted value for visual confirmation
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6366F1),
                  letterSpacing: 6,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: Color(0xFF6366F1), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "$_secondsLeft seconds remaining",
                      style: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        decoration: TextDecoration.none,
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
}

class _SwipeToConfirm extends StatefulWidget {
  final String label;
  final VoidCallback onConfirm;

  const _SwipeToConfirm({required this.label, required this.onConfirm});

  @override
  State<_SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<_SwipeToConfirm> with SingleTickerProviderStateMixin {
  double _dragValue = 0;
  bool _isConfirmed = false;
  late AnimationController _vibeController;
  final List<_SmokeParticle> _smoke = [];

  @override
  void initState() {
    super.initState();
    _vibeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _vibeController.dispose();
    super.dispose();
  }

  void _addSmoke(double position) {
    if (_smoke.length < 15) {
      setState(() {
        _smoke.add(_SmokeParticle(position));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width - 40;
    const double knobSize = 64;
    final double maxDrag = width - knobSize - 8;

    // Pulse smoke logic
    if (_dragValue > 10 && _dragValue < maxDrag) {
      _addSmoke(_dragValue + knobSize / 2);
    }

    // Update smoke particles
    _smoke.removeWhere((p) => p.isDead);
    for (var p in _smoke) p.update();

    return Container(
      height: 72,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Road markings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              12,
              (index) => Container(
                width: 12,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.yellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),

          // Smoke particles
          ..._smoke.map((p) => Positioned(
            left: 4 + p.position - (p.size * p.progress / 2),
            top: 25 + p.offsetY,
            child: Opacity(
              opacity: p.opacity,
              child: Container(
                width: p.size * p.progress,
                height: p.size * p.progress,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          )),
          
          Text(
            widget.label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 10,
            ),
          ),
          
          Positioned(
            left: 4 + _dragValue,
            top: 4,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (_isConfirmed) return;
                setState(() {
                  _dragValue += details.delta.dx;
                  if (_dragValue < 0) _dragValue = 0;
                  if (_dragValue > maxDrag) _dragValue = maxDrag;
                  
                  if (_dragValue > 10 && !_vibeController.isAnimating) {
                    _vibeController.repeat(reverse: true);
                  } else if (_dragValue <= 10) {
                    _vibeController.stop();
                  }
                });
              },
              onHorizontalDragEnd: (details) {
                if (_isConfirmed) return;
                _vibeController.stop();
                
                if (_dragValue >= maxDrag * 0.85) {
                  setState(() {
                    _dragValue = maxDrag;
                    _isConfirmed = true;
                  });
                  widget.onConfirm();
                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted) {
                      setState(() {
                        _dragValue = 0;
                        _isConfirmed = false;
                        _smoke.clear();
                      });
                    }
                  });
                } else {
                  setState(() {
                    _dragValue = 0;
                  });
                }
              },
              child: AnimatedBuilder(
                animation: _vibeController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _vibeController.value * 2),
                    child: child,
                  );
                },
                child: Container(
                  width: knobSize,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmokeParticle {
  double position;
  double progress = 0.1;
  double opacity = 0.5;
  double offsetY = 0;
  double size = 20;
  bool isDead = false;

  _SmokeParticle(this.position);

  void update() {
    progress += 0.05;
    opacity = (opacity - 0.02).clamp(0.0, 1.0);
    offsetY -= 1.5;
    if (opacity <= 0) isDead = true;
  }
}

class _OtpBottomSheet extends StatefulWidget {
  final String requestId;
  final bool isStart;
  final Color bgColor;
  final Color titleColor;
  final VoidCallback onSuccess;

  const _OtpBottomSheet({
    required this.requestId,
    required this.isStart,
    required this.bgColor,
    required this.titleColor,
    required this.onSuccess,
  });

  @override
  State<_OtpBottomSheet> createState() => _OtpBottomSheetState();
}

class _OtpBottomSheetState extends State<_OtpBottomSheet> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isVerifying = false;
  bool _isScanning = false;

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp(String otp) async {
    if (otp.length != 6) return;
    setState(() => _isVerifying = true);
    try {
      final result = await useDriverStore.verifyRouteOtp(
        routeId: int.tryParse(widget.requestId) ?? 0,
        otp: otp,
        isStart: widget.isStart,
      );

      if (result['success'] == true) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          widget.onSuccess();
        }
      } else {
        throw result['message'];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            dismissDirection: DismissDirection.up,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 120,
              left: 20,
              right: 20,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isVerifying) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code != null) {
        final decrypted = CryptoUtils.decryptOTP(code);
        if (decrypted.length == 6 && int.tryParse(decrypted) != null) {
          setState(() {
            _isScanning = false;
            for (int i = 0; i < 6; i++) {
              _controllers[i].text = decrypted[i];
            }
          });
          _verifyOtp(decrypted);
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: widget.bgColor,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "OTP Verification",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: widget.titleColor,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isStart ? "Verify start of mission" : "Verify end of mission",
              style: TextStyle(
                color: widget.titleColor.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),
            if (_isScanning)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.black,
                  border: Border.all(color: const Color(0xFF6366F1), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: MobileScanner(onDetect: _onDetect),
                ),
              )
            else
              FittedBox(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) => _buildOtpField(i)),
                ),
              ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _isScanning = !_isScanning),
                    icon: Icon(_isScanning ? Icons.keyboard_rounded : Icons.qr_code_scanner_rounded),
                    label: Text(_isScanning ? "MANUAL" : "SCAN QR"),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isVerifying || _isScanning ? null : () {
                      final otp = _controllers.map((c) => c.text).join();
                      _verifyOtp(otp);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            "VERIFY",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
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
  }

  Widget _buildOtpField(int index) {
    return Container(
      width: 48,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focusNodes[index].hasFocus ? const Color(0xFF6366F1) : Colors.transparent,
          width: 2,
        ),
      ),
      child: KeyboardListener(
        focusNode: FocusNode(), // Captures key events
        onKeyEvent: (event) {
          if (event is KeyDownEvent && 
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[index].text.isEmpty && 
              index > 0) {
            _focusNodes[index - 1].requestFocus();
            _controllers[index - 1].clear();
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
          decoration: const InputDecoration(counterText: "", border: InputBorder.none),
          onChanged: (value) {
            if (value.isNotEmpty) {
              if (index < 5) {
                _focusNodes[index + 1].requestFocus();
              } else {
                _focusNodes[index].unfocus();
              }
            } else if (value.isEmpty && index > 0) {
              // Standard delete handling if field just became empty
              _focusNodes[index - 1].requestFocus();
            }
          },
        ),
      ),
    );
  }
}
