import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tripzo/screens/faculty/missions/reassign_guest_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/crypto_utils.dart';

class MissionDetailsScreen extends StatefulWidget {
  final String missionTitle,
      time,
      driverName,
      driverPhone,
      vehicleInfo,
      capacity,
      pathType,
      status,
      requestId;
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
    required this.pathType,
    required this.stops,
    required this.status,
    required this.statusColor,
    required this.requestId,
    required this.rawStatus,
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
    });
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

      final body = {
        "route_id": int.tryParse(widget.requestId) ?? 0,
        "faculty_remarks": remark.trim().isEmpty ? "Approved via Mobile App" : remark.trim(),
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
          const SnackBar(content: Text("Mission Approved Successfully"), backgroundColor: Colors.green),
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

  void _showRemarkModal(bool isApprove) {
    final TextEditingController remarkController = TextEditingController();
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
                  isApprove ? "Approve Mission" : "Decline Mission",
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
    final showAction =
        currentStatus == 5 || currentStatus == 6 || currentStatus == 7;
    final actionLabel = currentStatus == 7 ? "End Activity" : "Start Activity";
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
                          _buildHeroCard(cardColor, titleColor, subColor),
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
                                  
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => ReassignGuestScreen(
                                      initialSchedules: schedules,
                                      routeId: widget.requestId,
                                      defaultRemark: _missionData?['faculty_remark'] ?? '',
                                    )),
                                  );

                                  if (result == true) {
                                    _fetchMissionDetails();
                                  }
                                },
                                icon: const Icon(Icons.manage_accounts_rounded),
                                label: const Text(
                                  "MANAGE & REASSIGN GUESTS",
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
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoadingOtp ? null : _handleAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoadingOtp
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          actionLabel.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                ),
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

  Widget _buildHeroCard(Color cardColor, Color titleColor, Color subColor) {
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
          Text(
            widget.pathType.toUpperCase(),
            style: TextStyle(
              color: subColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
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
          _buildEnhancedSmallInfo(
            Icons.directions_car_filled_rounded,
            vInfo.split('(')[0],
            "VEHICLE",
            blue,
            sub,
          ),
          const SizedBox(width: 40),
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

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
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
                              Text(
                                g['name'] ?? "Unknown", 
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: cardColor == Colors.white ? Colors.black87 : Colors.white),
                              ),
                              Text(
                                phone ?? 'No Phone',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: subColor),
                              ),
                            ],
                          ),
                        ),
                        if (phone != null && phone.toString().isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.green, size: 20),
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
