import 'dart:convert';
import 'dart:ui';
import 'package:shimmer/shimmer.dart';
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
import 'package:tripzo/screens/faculty/missions/otp_flash_screen.dart';
import 'package:tripzo/screens/faculty/missions/create_allowance_screen.dart';
import 'package:tripzo/screens/admin/request/admin_finalize_request_screen.dart';


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
  bool _isMapReady = false;


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
      _fetchUserRole();
    });
  }

  Future<void> _fetchUserRole() async {
    final role = await UserStore.getRole();
    if (mounted) setState(() => _userRole = role);
  }

  /// Pull-to-refresh handler — re-fetches all data in parallel.
  Future<void> _refreshData() async {
    await Future.wait([
      _fetchMissionDetails(),
      _fetchUserRole(),
    ]);
  }


  Future<void> _fetchMissionDetails() async {
    setState(() => _isFetchingDetails = true);
    try {
      final token = await UserStore.getToken();
      final url = "${ApiConstants.getRouteById}${widget.requestId}";
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      // Console the curl and response as requested
      debugPrint("DEBUG: CURL command for Mission Details:");
      debugPrint("curl -X GET '$url' -H 'Authorization: TMS $token' -H 'Content-Type: application/json'");
      debugPrint("DEBUG: Mission Details Response Status: ${response.statusCode}");
      debugPrint("DEBUG: Mission Details Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _missionData = data['data'];
          });
          _updateMapFromMissionData();
        }
      }
    } catch (e) {
      debugPrint("Fetch details error: $e");
      // Fallback to basic geocoding if details fetch fails
      _loadMapData();
    } finally {
      if (mounted) setState(() => _isFetchingDetails = false);
    }
  }

  Future<void> _handleApprove(String remark) async {
    setState(() => _isApproving = true);
    try {
      final token = await UserStore.getToken();
      List<Map<String, dynamic>> allocations = [];
      final tripInstances = _missionData?['trip_instances'] as List?;
      
      if (tripInstances != null) {
        for (var trip in tripInstances) {
          final legs = trip['legs'] as List?;
          if (legs != null) {
            for (var leg in legs) {
              final assignments = leg['assignments'] as List?;
              if (assignments != null) {
                for (var assignment in assignments) {
                  final vehicleId = assignment['vehicle']?['id'];
                  final passengers = assignment['passengers'] as List?;
                  if (vehicleId != null && passengers != null) {
                    allocations.add({
                      "vehicle_id": vehicleId,
                      "guest_ids": passengers.map((p) => p['passenger_id']).toList(),
                    });
                  }
                }
              }
            }
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${isAdmin ? 'Admin' : 'Mission'} Approved Successfully"), backgroundColor: Colors.green),
        );
        await _fetchMissionDetails();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(respData['message'] ?? "Failed to approve"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  void _handleDecline(String remark) {
    if (!mounted) return;
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
                    fillColor: Colors.grey.withValues(alpha: 0.05),
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
    // If coordinates were already extracted from API, skip geocoding fallback
    if (_routePoints.isNotEmpty || _markers.isNotEmpty) return;
    
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
        
        if (_isMapReady) {
          _mapController.move(stopCoords.first, 12);
        }
      }
    } catch (e) {
      debugPrint("Map Load Error: $e");
    } finally {
      if (mounted) setState(() => _isMapLoading = false);
    }
  }

  /// Extracts coordinates from mission data (API response) and updates map.
  /// Bypasses slow/unreliable address-based geocoding.
  Future<void> _updateMapFromMissionData() async {
    final legs = _missionData?['route_details']?['legs'] as List?;
    if (legs == null || legs.isEmpty) return;

    List<LatLng> stopCoords = [];
    for (var leg in legs) {
      final stops = leg['stops'] as List?;
      if (stops != null) {
        for (var stop in stops) {
          // Check for latitude/longitude in various possible formats
          final latVal = stop['latitude'] ?? stop['lat'];
          final lonVal = stop['longitude'] ?? stop['lng'] ?? stop['lon'];
          
          final lat = latVal != null ? double.tryParse(latVal.toString()) : null;
          final lon = lonVal != null ? double.tryParse(lonVal.toString()) : null;
          
          if (lat != null && lon != null) {
            stopCoords.add(LatLng(lat, lon));
          }
        }
      }
    }

    if (stopCoords.length >= 2) {
      debugPrint("DEBUG: Found ${stopCoords.length} coordinates in mission data. Updating map.");
      await _calculateRoute(stopCoords);
    } else if (stopCoords.isNotEmpty) {
      debugPrint("DEBUG: Found 1 coordinate in mission data. Showing marker.");
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
      if (_isMapReady) {
        _mapController.move(stopCoords.first, 12);
      }
    } else {
       debugPrint("DEBUG: No coordinates found in mission data. Falling back to geocoding.");
       // No coords found in API, fallback to address geocoding if possible
       _loadMapData();
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
    if (points.isEmpty || !_isMapReady) return;
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
      final currentStatus = _missionData?['route_status'] ?? widget.rawStatus;

    final String statusString = (_missionData?['travel_info']?['status'] ?? _missionData?['status'] ?? widget.status ?? "").toString().toUpperCase();
    final bool isStart = statusString == 'APPROVED' || statusString == 'PLANNED' || 
                        currentStatus == 4 || currentStatus == 5 || currentStatus == 6 || currentStatus == 12;

    debugPrint("DEBUG: isStart=$isStart, statusString=$statusString, currentStatus=$currentStatus");

    if (isDriver) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyMissionScreen(
              requestId: widget.requestId,
              isStart: isStart,
            ),
          ),
        );
        if (!mounted) return;
        if (result == true) {
          _fetchMissionDetails();
        }
        return;
      }

      final String? token = await UserStore.getToken();
      final tripInstances = _missionData?['trip_instances'] as List?;
      final tripId = tripInstances != null && tripInstances.isNotEmpty ? tripInstances[0]['id'] : null;

      if (tripId == null) throw "Trip ID not found";

      // Determine dynamic endpoint based on action type
      String endpoint;
      if (isStart) {
        endpoint = "https://18x50gz9-8055.inc1.devtunnels.ms/api/routes/trips/$tripId/start-otp";
      } else {
        endpoint = "https://18x50gz9-8055.inc1.devtunnels.ms/api/routes/trips/$tripId/end-otp";
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: ApiConstants.getHeaders(token),
        body: "", // Dynamic endpoints use empty body as per standard
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint("API Error! Endpoint: $endpoint");
        debugPrint("Curl: curl -X POST '$endpoint' -H 'Authorization: TMS $token' -H 'Content-Type: application/json' --data ''");
        debugPrint("Response Status: ${response.statusCode}");
        debugPrint("Response Body: ${response.body}");
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        String displayOtp = data['data']?['encrypted_otp']?.toString() ?? data['otp']?.toString() ?? "";

        // Attempt JWT Decode just in case if it's potentially a token
        if (displayOtp.length > 20 && displayOtp.contains('.')) {
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
        }

        _showOtpModal(displayOtp, isStart ? "Start OTP" : "End OTP");
      } else {
        final error = jsonDecode(response.body);
        throw error['message'] ?? "Failed to generate OTP (${response.statusCode})";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoadingOtp = false);
    }
  }

  Future<void> _handleDirectStart() async {
    setState(() => _isApproving = true); // Using _isApproving state for loading
    try {
      final String? token = await UserStore.getToken();
      final tripInstances = _missionData?['trip_instances'] as List?;
      final tripId = tripInstances != null && tripInstances.isNotEmpty ? tripInstances[0]['id'] : null;

      if (tripId == null) throw "Trip ID not found";

      final response = await http.post(
        Uri.parse("https://18x50gz9-8055.inc1.devtunnels.ms/api/routes/trips/$tripId/start"),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode({"mode": "DIRECT"}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint("Direct Start API Error!");
        debugPrint("Curl: curl -X POST 'https://18x50gz9-8055.inc1.devtunnels.ms/api/routes/trips/$tripId/start' -H 'Authorization: TMS $token' -H 'Content-Type: application/json' --data '${jsonEncode({"mode": "DIRECT"})}'");
        debugPrint("Response Status: ${response.statusCode}");
        debugPrint("Response Body: ${response.body}");
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Trip started directly!"), backgroundColor: Colors.green),
        );
        _fetchMissionDetails();
      } else {
        final error = jsonDecode(response.body);
        throw error['message'] ?? "Direct start failed";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isApproving = false);
    }
  }


  void _showOtpModal(String otp, String title) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) => OtpFlashScreen(
          otp: otp,
          title: title,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
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
    final String statusString = (_missionData?['travel_info']?['status'] ?? _missionData?['status'] ?? widget.status ?? "").toString().toUpperCase();
    
    final bool isDriver = _userRole?.toLowerCase() == 'driver';
    
    // Draft check
    final bool isDraft = currentStatus == 1 || currentStatus == 10 || statusString == 'DRAFT';

    // Check if any trip instance has allowances
    final bool hasAllowance = (_missionData?['trip_instances'] as List?)?.any((t) => (t['allowances'] as List?)?.isNotEmpty ?? false) ?? false;

    // Status 4 (Approved), 5 (Driver Assigned), 6 (Driver Reassigned), 7 (Started), 12 (Planned)
    // Also checking string status for robustness
    final bool isApprovedState = statusString == 'APPROVED' || statusString == 'PLANNED' || 
                                currentStatus == 4 || currentStatus == 5 || currentStatus == 6 || currentStatus == 12;
    
    final bool showAction = isApprovedState || currentStatus == 7 || statusString == 'STARTED' || statusString == 'ONGOING';
    
    String actionLabel = (currentStatus == 7 || statusString == 'STARTED' || statusString == 'ONGOING') 
        ? "GENERATE END OTP" 
        : "GENERATE START OTP";
        
    if (isDriver) {
      actionLabel = (currentStatus == 7 || statusString == 'STARTED' || statusString == 'ONGOING') ? "ARRIVED OTP" : "START OTP";
    }

    // if status is approved and allowance exists, show START OTP
    if (isApprovedState && hasAllowance) {
       actionLabel = "SWIPE TO START (GET OTP/QR)";
    }

    final showApproveDecline = currentStatus == 2 || currentStatus == 3 || statusString == 'PENDING' || statusString == 'SUBMITTED';

    return Scaffold(
      backgroundColor: bgColor,
      body: _isFetchingDetails
          ? _buildShimmerSkeleton(isDark, bgColor, cardColor)
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
                  child: RefreshIndicator(
                    onRefresh: _refreshData,
                    color: primaryBlue,
                    backgroundColor: cardColor,
                    displacement: 40,
                    strokeWidth: 2.5,
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
                          if (isDraft) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                 onPressed: () async {
                                   final result = await Navigator.push(
                                     context,
                                     MaterialPageRoute(
                                       builder: (context) => AdminFinalizeRequestScreen(requestId: widget.requestId),
                                     ),
                                   );
                                   if (result == true) {
                                      _fetchMissionDetails(); 
                                   }
                                 },
                                icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                                label: const Text(
                                  "ASSIGN DRIVER & VEHICLE",
                                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  elevation: 4,
                                  shadowColor: primaryBlue.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (!isDraft) ...[
                            _buildSectionTitle(
                              "Guest Contacts",
                              primaryBlue,
                              titleColor,
                            ),
                            const SizedBox(height: 16),
                            _buildGuestContacts(cardColor, primaryBlue, subColor),
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
                            _buildAllowances(cardColor, primaryBlue, subColor, statusString),
                          ],
                          const SizedBox(height: 24),
                          _buildRemarks(cardColor, titleColor, subColor, primaryBlue),
                          if (showApproveDecline) ...[
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isLoadingOtp || _isApproving ? null : () async {
                                  final tripInstances = _missionData?['trip_instances'] as List?;
                                  if (tripInstances == null || tripInstances.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No entries to manage.")));
                                    return;
                                  }
                                  
                                  List<Map<String, dynamic>> flattenedAssignments = [];
                                  for (var trip in tripInstances) {
                                    final legs = trip['legs'] as List?;
                                    if (legs != null) {
                                        for (var leg in legs) {
                                          final assignments = leg['assignments'] as List?;
                                          if (assignments != null) {
                                            for (var assignment in assignments) {
                                              flattenedAssignments.add(Map<String, dynamic>.from(assignment));
                                            }
                                          }
                                        }
                                    }
                                  }

                                  if (flattenedAssignments.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No assignments found.")));
                                    return;
                                  }

                                  final String? role = await UserStore.getRole();
                                  final bool isAdmin = role?.toLowerCase() == 'admin';

                                  if (!mounted) return;
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => ReassignGuestScreen(
                                      initialSchedules: flattenedAssignments,
                                      routeId: widget.requestId,
                                      defaultRemark: isAdmin 
                                          ? (_missionData?['route_status']?['admin_remark'] ?? '') 
                                          : (_missionData?['route_status']?['faculty_remark'] ?? ''),
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
                ),
              ],
            ),
          ),
          if (showAction)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isApprovedState && _userRole?.toLowerCase() == 'transport admin')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isApproving || _isLoadingOtp ? null : _handleDirectStart,
                          icon: _isApproving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.flash_on_rounded, size: 20),
                          label: const Text(
                            "DIRECT START",
                            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            shadowColor: Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  _SwipeToConfirm(
                    label: actionLabel.toUpperCase(),
                    onConfirm: () {
                      _handleAction();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  SHIMMER SKELETON – mirrors the actual page structure
  // ══════════════════════════════════════════════════════════
  Widget _buildShimmerSkeleton(bool isDark, Color bgColor, Color cardColor) {
    final Color base = isDark ? const Color(0xFF1E293B) : Colors.grey.shade300;
    final Color highlight = isDark ? const Color(0xFF334155) : Colors.grey.shade100;

    Widget bone({
      double width = double.infinity,
      double height = 14,
      double radius = 8,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Stack(
      children: [
        _buildBackgroundDecor(isDark),
        SafeArea(
          child: Shimmer.fromColors(
            baseColor: base,
            highlightColor: highlight,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header skeleton ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      bone(width: 36, height: 36, radius: 12),
                      bone(width: 140, height: 20, radius: 10),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Hero card skeleton ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            bone(width: 80, height: 26, radius: 12),
                            bone(width: 100, height: 16, radius: 8),
                          ],
                        ),
                        const SizedBox(height: 24),
                        bone(width: 200, height: 24, radius: 10),
                        const SizedBox(height: 10),
                        bone(width: 120, height: 14, radius: 8),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            bone(width: 32, height: 32, radius: 16),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                bone(width: 110, height: 14, radius: 7),
                                const SizedBox(height: 6),
                                bone(width: 80, height: 11, radius: 6),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Trip metrics row skeleton ──
                  Row(
                    children: List.generate(3, (_) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),

                  // ── Section title ──
                  bone(width: 160, height: 16, radius: 8),
                  const SizedBox(height: 16),

                  // ── Map skeleton ──
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Checkpoints section title ──
                  bone(width: 180, height: 16, radius: 8),
                  const SizedBox(height: 20),

                  // ── Checkpoint items skeleton ──
                  ...List.generate(3, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          bone(width: 28, height: 28, radius: 14),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                bone(height: 14, width: 160, radius: 7),
                                const SizedBox(height: 6),
                                bone(height: 10, width: 100, radius: 6),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 32),

                  // ── Resource section title ──
                  bone(width: 150, height: 16, radius: 8),
                  const SizedBox(height: 16),

                  // ── Resource cards skeleton ──
                  ...List.generate(2, (_) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          bone(width: 40, height: 40, radius: 12),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                bone(height: 14, radius: 7),
                                const SizedBox(height: 8),
                                bone(height: 10, width: 120, radius: 6),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
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

  int _getTotalStopsCount() {
    final legs = _missionData?['route_details']?['legs'] as List?;
    if (legs == null) return 0;
    int count = 0;
    for (var leg in legs) {
      final stops = leg['stops'] as List?;
      if (stops != null) count += stops.length;
    }
    return count;
  }

  Widget _buildHeroCard(Color cardColor, Color titleColor, Color subColor, Color primaryBlue) {
    final bool isDriver = _userRole?.toLowerCase() == 'driver';
    final travelInfo = _missionData?['travel_info'];
    final mTitle = travelInfo?['route_name'] ?? widget.missionTitle;
    final reqNo = travelInfo?['request_number'] ?? "REQ-N/A";
    final tType = travelInfo?['trip_type'] ?? widget.pathType;
    final String status = (_missionData?['status'] ?? _missionData?['route_status']?['route_request_status'] ?? travelInfo?['status'] ?? widget.status ?? "UNKNOWN").toString();
    
    // Calculate color based on route_request_status
    Color statusColor = widget.statusColor;
    final String sUpper = status.toUpperCase();
    if (sUpper == 'APPROVED' || sUpper == 'COMPLETED') {
      statusColor = Colors.green;
    } else if (sUpper == 'PENDING' || sUpper == 'SUBMITTED') {
      statusColor = Colors.orange;
    } else if (sUpper == 'REJECTED' || sUpper == 'CANCELLED') {
      statusColor = Colors.red;
    } else if (sUpper == 'PLANNED' || sUpper == 'ASSIGNED') {
      statusColor = Colors.blue;
    }
    final passengerCount = _missionData?['vehicle_config']?['passenger_count']?.toString() ?? widget.passengerCount;
    final dynamic purpose = travelInfo?['purpose'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tag_rounded, size: 14, color: subColor.withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        reqNo,
                        style: TextStyle(color: subColor, fontWeight: FontWeight.w700, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            mTitle,
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
              Expanded(
                child: Text(
                  tType.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    color: subColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.calendar_today_rounded, size: 14, color: subColor.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(
                widget.time.toUpperCase(),
                style: TextStyle(
                  color: subColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (purpose != null && purpose.toString().isNotEmpty && purpose.toString() != 'null') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "PURPOSE: ${travelInfo?['purpose']}",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primaryBlue, letterSpacing: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isDriver) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.assignment_turned_in_rounded, size: 14, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"status": "${status.toUpperCase()}"',
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.w900, 
                        color: statusColor, 
                        letterSpacing: 0.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetric(Icons.groups_rounded, passengerCount, "GUESTS", primaryBlue, subColor)),
              const SizedBox(width: 16),
              Expanded(child: _buildMetric(Icons.alt_route_rounded, _getTotalStopsCount().toString(), "STOPS", primaryBlue, subColor)),
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
            color: blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: blue, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: sub.withValues(alpha: 0.6),
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
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
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: titleColor,
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckpointList(Color blue, Color title) {
    final legs = _missionData?['route_details']?['legs'] as List?;
    if (legs == null || legs.isEmpty) return const SizedBox.shrink();
    
    // Flatten all stops from all legs
    List<dynamic> allStops = [];
    for (var leg in legs) {
      final stops = leg['stops'] as List?;
      if (stops != null) {
        allStops.addAll(stops);
      }
    }

    if (allStops.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: allStops.length,
      itemBuilder: (context, index) {
        final stop = allStops[index];
        return _buildTimelineItem(
          location: stop['stop_name'] ?? stop['address'] ?? "Unknown",
          eta: stop['planned_arrival_time'] ?? "",
          isFirst: index == 0,
          isLast: index == allStops.length - 1,
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
    final bool isDark = titleColor == Colors.white;
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color blueIcon = const Color(0xFF6366F1);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 24),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFirst ? Colors.green : (isLast ? Colors.red : color.withValues(alpha: 0.3)),
                  border: Border.all(color: isFirst ? Colors.green.withValues(alpha: 0.2) : (isLast ? Colors.red.withValues(alpha: 0.2) : color.withValues(alpha: 0.1)), width: 4),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 20),
          // Checkpoint Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 15, offset: const Offset(0, 8)),
                ],
                border: Border.all(color: titleColor.withValues(alpha: 0.05), width: 1),
              ),
              child: Row(
                children: [
                  // Blue Car Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: blueIcon.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.directions_car_rounded, color: blueIcon, size: 22),
                  ),
                  const SizedBox(width: 16),
                  // Location Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 12, color: titleColor.withValues(alpha: 0.4)),
                            const SizedBox(width: 4),
                            Text(
                              eta.isNotEmpty ? "Scheduled: $eta" : "Time not set",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: titleColor.withValues(alpha: 0.4),
                              ),
                            ),
                            if (isFirst || isLast) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isFirst ? Colors.green : Colors.red).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isFirst ? "START" : "END",
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: isFirst ? Colors.green : Colors.red),
                                ),
                              ),
                            ],
                          ],
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
    );
  }

  Widget _buildGuestContacts(Color cardColor, Color blue, Color subColor) {
    final guests = _missionData?['passengers'] as List?;
    if (guests == null || guests.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: subColor.withValues(alpha: 0.1)),
        ),
        child: Text(
          "No guest contact information available.",
          style: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );
    }

    return Column(
      children: guests.asMap().entries.map((entry) {
        final i = entry.key;
        final g = entry.value;
        final phone = g['phone'];
        final isPrimary = g['is_primary_contact'] == true;
        final dept = g['department'];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: blue.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: blue.withValues(alpha: 0.1),
                  child: Text(
                    "${i + 1}",
                    style: TextStyle(fontWeight: FontWeight.w900, color: blue, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              g['passenger_name'] ?? "Guest",
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: cardColor == Colors.white ? Colors.black87 : Colors.white),
                            ),
                          ),
                          if (isPrimary)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                "PRIMARY",
                                style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              phone ?? 'No Phone Provided',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subColor),
                            ),
                          ),
                          if (dept != null && dept.toString().isNotEmpty && dept != 'null')
                             Text(
                               dept,
                               style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: blue.withValues(alpha: 0.6)),
                             ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (phone != null && phone.toString().isNotEmpty)
                  IconButton(
                    onPressed: () async {
                      final Uri url = Uri.parse("tel:$phone");
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                    icon: const Icon(Icons.call_rounded, color: Colors.green, size: 22),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(10),
                    ),
                  )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDriverCard(Color cardColor, Color blue, Color sub, String dName, String dPhone) {
    final bool isNotAssigned = dName == "no driver assigned" || dName == "Driver Not Assigned";
    final Color nameColor = isNotAssigned ? Colors.redAccent : (cardColor == Colors.white ? Colors.black87 : Colors.white);
    final Color phoneColor = isNotAssigned ? Colors.redAccent.withValues(alpha: 0.7) : sub;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isNotAssigned ? Colors.red.withValues(alpha: 0.1) : blue.withValues(alpha: 0.1),
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
                color: Colors.green.withValues(alpha: 0.1),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _buildEnhancedSmallInfo(
                Icons.directions_car_filled_rounded,
                vType,
                "VEHICLE",
                blue,
                sub,
              ),
          ),
          if (vNumber.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _buildEnhancedSmallInfo(
                  Icons.tag_rounded,
                  vNumber,
                  "PLATE NO",
                  blue,
                  sub,
                ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: _buildEnhancedSmallInfo(
              Icons.groups_rounded,
              cap,
              "SEATS",
              blue,
              sub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicResources(Color cardColor, Color blue, Color subColor) {
    final tripInstances = _missionData?['trip_instances'] as List?;
    if (tripInstances == null || tripInstances.isEmpty) {
      return Column(
        children: [
          _buildDriverCard(cardColor, blue, subColor, widget.driverName, widget.driverPhone),
          const SizedBox(height: 12),
          _buildVehicleDetails(cardColor, blue, subColor, widget.vehicleInfo, widget.capacity),
        ],
      );
    }

    List<Widget> assignmentWidgets = [];

    for (var trip in tripInstances) {
      final legs = trip['legs'] as List?;
      if (legs != null) {
        for (var leg in legs) {
          final assignments = leg['assignments'] as List?;
          if (assignments != null) {
            for (var assignment in assignments) {
              final vehicle = assignment['vehicle'];
              final driver = assignment['driver'];
              final passengers = assignment['passengers'] as List?;

              final dName = driver?['name'] ?? "Driver Not Assigned";
              final dPhone = driver?['phone'] ?? "n/a";
              final vInfo = vehicle != null ? "${vehicle['vehicle_type_name'] ?? 'Vehicle'} (${vehicle['vehicle_number']})" : "Vehicle Not Assigned";
              final vCap = vehicle != null ? "${vehicle['capacity']} Seats" : "n/a";

              assignmentWidgets.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trip Header with gradient
                      if (trip['trip_number'] != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [blue.withValues(alpha: 0.2), blue.withValues(alpha: 0.05)]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "TRIP: ${trip['trip_number']}",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: blue, letterSpacing: 1),
                          ),
                        ),
                      _buildDriverCard(cardColor, blue, subColor, dName, dPhone),
                      const SizedBox(height: 12),
                      _buildVehicleDetails(cardColor, blue, subColor, vInfo, vCap),
                      if (passengers != null && passengers.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.people_outline_rounded, size: 14, color: subColor),
                            const SizedBox(width: 8),
                            Text(
                              "Assigned Guests (${passengers.length})",
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: subColor.withValues(alpha: 0.8), letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...passengers.asMap().entries.map((entry) {
                          final i = entry.key;
                          final g = entry.value;
                          final phone = g['phone'];
                          final isPrimary = g['is_primary_contact'] == true;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: blue.withValues(alpha: 0.1)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 4, offset: const Offset(0, 2))
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(color: blue.withValues(alpha: 0.1), shape: BoxShape.circle),
                                    child: Center(
                                      child: Text(
                                        "${i + 1}",
                                        style: TextStyle(fontWeight: FontWeight.w900, color: blue, fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                g['passenger_name'] ?? "Unknown", 
                                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: cardColor == Colors.white ? Colors.black87 : Colors.white),
                                              ),
                                            ),
                                            if (isPrimary)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  "PRIMARY",
                                                  style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          phone ?? 'No Phone Provided',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (phone != null && phone.toString().isNotEmpty)
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () async {
                                          final Uri url = Uri.parse("tel:$phone");
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                          child: const Icon(Icons.phone_in_talk_rounded, color: Colors.green, size: 20),
                                        ),
                                      ),
                                    )
                                ],
                              ),
                            ),
                          );
                        }),
                      ]
                    ],
                  ),
                )
              );
            }
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: assignmentWidgets.isNotEmpty 
          ? assignmentWidgets 
          : [
               if (_missionData?['trip_instances'] != null && (_missionData?['trip_instances'] as List).isNotEmpty)
                 ...(_missionData?['trip_instances'] as List).map((trip) {
                    final notes = trip['notes'];
                    final status = trip['status'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           if (notes != null && notes != 'null' && notes.toString().isNotEmpty)
                             Text("NOTES: $notes", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: subColor.withValues(alpha: 0.7))),
                           _buildDriverCard(cardColor, blue, subColor, widget.driverName, widget.driverPhone),
                           const SizedBox(height: 12),
                           _buildVehicleDetails(cardColor, blue, subColor, widget.vehicleInfo, widget.capacity),
                        ],
                      ),
                    );
                 }),
               if (assignmentWidgets.isEmpty && (_missionData?['trip_instances'] == null || (_missionData?['trip_instances'] as List).isEmpty)) ...[
                 _buildDriverCard(cardColor, blue, subColor, widget.driverName, widget.driverPhone),
                 const SizedBox(height: 12),
                 _buildVehicleDetails(cardColor, blue, subColor, widget.vehicleInfo, widget.capacity),
               ]
            ],
    );
  }

  Widget _buildTripMetrics(Color cardColor, Color blue, Color sub) {
    if (_missionData == null || _missionData!['route_details'] == null) return const SizedBox.shrink();
    
    final details = _missionData!['route_details'];
    final dist = details['approx_distance_km'] != null ? "${details['approx_distance_km']} km" : "N/A";
    
    // Formatting duration correctly
    int approxMin = int.tryParse(details['approx_duration']?.toString() ?? "0") ?? 0;
    String dur = "N/A";
    if (approxMin > 0) {
      if (approxMin < 60) {
        dur = "$approxMin mins";
      } else {
        int h = approxMin ~/ 60;
        int m = approxMin % 60;
        dur = m > 0 ? "${h}h ${m}m" : "${h}h";
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(child: _buildEnhancedSmallInfo(Icons.map_rounded, dist, "DISTANCE", blue, sub)),
          Container(height: 40, width: 1, color: sub.withValues(alpha: 0.2), margin: const EdgeInsets.symmetric(horizontal: 8)),
          Expanded(child: _buildEnhancedSmallInfo(Icons.timer_rounded, dur, "EST. DURATION", blue, sub)),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo(Color cardColor, Color blue, Color sub) {
     if (_missionData == null || _missionData!['additional_info'] == null) return const SizedBox.shrink();
     final addInfo = _missionData!['additional_info'];
     final instr = addInfo['special_instructions'];
     final lug = addInfo['luggage_details'];

     if ((instr == null || instr == 'NIL' || instr == 'null' || instr.toString().isEmpty) && 
         (lug == null || lug == 'NIL' || lug == 'null' || lug.toString().isEmpty)) {
       return const SizedBox.shrink();
     }

     return Container(
       width: double.infinity,
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(
         color: blue.withValues(alpha: 0.05),
         borderRadius: BorderRadius.circular(24),
         border: Border.all(color: blue.withValues(alpha: 0.1)),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           if (instr != null && instr != 'NIL' && instr != 'null' && instr.toString().isNotEmpty) ...[
             Row(
               children: [
                 Icon(Icons.assignment_late_rounded, size: 16, color: blue),
                 const SizedBox(width: 8),
                 Text("Special Instructions", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: blue, letterSpacing: 0.5)),
               ],
             ),
             const SizedBox(height: 6),
             Text(instr, style: TextStyle(fontSize: 14, color: sub, fontWeight: FontWeight.w600, height: 1.4)),
             const SizedBox(height: 16),
           ],
           
           if (lug != null && lug != 'NIL' && lug != 'null' && lug.toString().isNotEmpty) ...[
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
    
    final audit = _missionData!['audit'];
    final createdBy = audit?['created_by'];
    final approvedBy = audit?['approved_by'];
    final statusData = _missionData!['route_status'];
    
    final facultyRemark = statusData?['faculty_remark'];
    final adminRemark = statusData?['admin_remark'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (createdBy != null) ...[
           _buildSectionTitle("Created By", blue, titleColor),
           const SizedBox(height: 12),
           Container(
             width: double.infinity,
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: cardColor,
               borderRadius: BorderRadius.circular(16),
               border: Border.all(color: subColor.withValues(alpha: 0.1)),
             ),
             child: Column(
               children: [
                 Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                              Text(createdBy['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.w800, color: titleColor, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(createdBy['role'] ?? 'Staff', style: TextStyle(fontWeight: FontWeight.w600, color: subColor, fontSize: 12)),
                           ],
                         ),
                       ),
                       Icon(Icons.edit_note_rounded, color: blue.withValues(alpha: 0.8), size: 28),
                     ],
                 ),
                 if (createdBy['email'] != null || createdBy['phone'] != null) ...[
                   const SizedBox(height: 12),
                   const Divider(height: 1),
                   const SizedBox(height: 12),
                   Row(
                     children: [
                       if (createdBy['email'] != null)
                         Expanded(
                           child: Row(
                             children: [
                               Icon(Icons.email_outlined, size: 12, color: subColor),
                               const SizedBox(width: 6),
                               Expanded(child: Text(createdBy['email'], style: TextStyle(fontSize: 11, color: subColor), overflow: TextOverflow.ellipsis)),
                             ],
                           ),
                         ),
                       if (createdBy['phone'] != null)
                         Row(
                           children: [
                             Icon(Icons.phone_outlined, size: 12, color: subColor),
                             const SizedBox(width: 6),
                             Text(createdBy['phone'], style: TextStyle(fontSize: 11, color: subColor)),
                           ],
                         ),
                     ],
                   ),
                 ],
               ],
             ),
           ),
           const SizedBox(height: 24),
        ],

        if (approvedBy != null) ...[
           _buildSectionTitle("Approved By", blue, titleColor),
           const SizedBox(height: 12),
           Container(
             width: double.infinity,
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: cardColor,
               borderRadius: BorderRadius.circular(16),
               border: Border.all(color: subColor.withValues(alpha: 0.1)),
             ),
             child: Column(
               children: [
                 Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                              Text(approvedBy['name'] ?? 'System', style: TextStyle(fontWeight: FontWeight.w800, color: titleColor, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text("AUTHORIZED", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 10, letterSpacing: 1)),
                           ],
                         ),
                       ),
                       const Icon(Icons.verified_user_rounded, color: Colors.green, size: 28),
                     ],
                 ),
                 if (approvedBy['email'] != null || approvedBy['phone'] != null) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (approvedBy['email'] != null)
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.email_outlined, size: 12, color: subColor),
                                const SizedBox(width: 6),
                                Expanded(child: Text(approvedBy['email'], style: TextStyle(fontSize: 11, color: subColor), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                        if (approvedBy['phone'] != null)
                          Row(
                            children: [
                              Icon(Icons.phone_outlined, size: 12, color: subColor),
                              const SizedBox(width: 6),
                              Text(approvedBy['phone'], style: TextStyle(fontSize: 11, color: subColor)),
                            ],
                          ),
                      ],
                    ),
                 ],
               ],
             ),
           ),
           const SizedBox(height: 24),
        ],

        if ((facultyRemark != null && facultyRemark.toString() != 'NIL') || 
            (adminRemark != null && adminRemark.toString() != 'NIL')) ...[
          _buildSectionTitle("Remarks", blue, titleColor),
          const SizedBox(height: 12),
          if (facultyRemark != null && facultyRemark.toString().isNotEmpty && facultyRemark != 'NIL')
            _buildRemarkTile(Icons.person_outline, "Faculty Remark", facultyRemark, cardColor, subColor, titleColor),
          if (adminRemark != null && adminRemark.toString().isNotEmpty && adminRemark != 'NIL')
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
          border: Border.all(color: subColor.withValues(alpha: 0.1)),
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
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: sub.withValues(alpha: 0.6), letterSpacing: 1)),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(icon, size: 18, color: blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  val,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAllowances(Color cardColor, Color blue, Color sub, String statusString) {
    List<dynamic> allAllowances = [];
    final tripInstances = _missionData?['trip_instances'] as List?;
    
    int? firstTripId;
    List<Map<String, dynamic>> allDrivers = [];

    if (tripInstances != null && tripInstances.isNotEmpty) {
      firstTripId = tripInstances[0]['id'];
      for (var trip in tripInstances) {
        final allowances = trip['allowances'] as List?;
        if (allowances != null) {
          allAllowances.addAll(allowances);
        }
        
        // Collect drivers for this trip
        final legs = trip['legs'] as List?;
        if (legs != null) {
          for (var leg in legs) {
            final assignments = leg['assignments'] as List?;
            if (assignments != null) {
              for (var assignment in assignments) {
                final driver = assignment['driver'];
                if (driver != null && !allDrivers.any((d) => d['id'] == driver['id'])) {
                  allDrivers.add(Map<String, dynamic>.from(driver));
                }
              }
            }
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _buildSectionTitle("Allowances & BATA", blue, Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A)),
              ),
            if (firstTripId != null && _userRole?.toLowerCase() == 'transport admin')
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateAllowanceScreen(
                        routeRequestId: int.tryParse(widget.requestId) ?? 0,
                        tripId: firstTripId!,
                        drivers: allDrivers,
                      ),
                    ),
                  ).then((value) {
                    if (value == true) _fetchMissionDetails();
                  });
                },
                icon: Icon(Icons.add_circle_outline_rounded, size: 18, color: blue),
                label: Text("CREATE ALLOWANCE", style: TextStyle(color: blue, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (allAllowances.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: blue.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: blue.withValues(alpha: 0.08), style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Icon(Icons.payments_outlined, size: 32, color: blue.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text("No allowances recorded yet", style: TextStyle(color: sub, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          )
        else
          ...allAllowances.map((allowance) {
            final driver = allowance['driver'];
            final amount = allowance['amount'] ?? "0.00";
            final type = allowance['allowance_type'] ?? "ALLOWANCE";
            final reason = allowance['reason'] ?? "Trip related expense";
            final pStatus = allowance['payment_status'] ?? "PENDING";
            final paidByUser = allowance['paid_by_user'];
            final aRemarks = allowance['remarks'];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: blue.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${driver?['name'] ?? 'Driver'} - $type",
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reason,
                              style: TextStyle(color: sub, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "₹$amount",
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF10B981)),
                          ),
                          Text(
                            pStatus.toString().toUpperCase(),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: pStatus == 'PAID' ? Colors.green : Colors.amber),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (aRemarks != null && aRemarks.toString().isNotEmpty && aRemarks != 'null') ...[
                    const SizedBox(height: 12),
                    Text("REMARKS: $aRemarks", style: TextStyle(fontSize: 11, color: sub.withValues(alpha: 0.7), fontStyle: FontStyle.italic)),
                  ],
                  if (paidByUser != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 10, color: sub.withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Text("Paid by: ${paidByUser['name']}", style: TextStyle(fontSize: 10, color: sub.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
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
            color: Colors.black.withValues(alpha: 0.08),
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
              options: MapOptions(
                initialCenter: const LatLng(20.5937, 78.9629),
                initialZoom: 5,
                onMapReady: () {
                  setState(() => _isMapReady = true);
                  if (_routePoints.isNotEmpty) {
                    _fitBounds(_routePoints);
                  }
                },
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
                color: Colors.white.withValues(alpha: 0.7),
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
              backgroundColor: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.06 : 0.04),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: const Color(0xFFA855F7).withValues(alpha: isDark ? 0.04 : 0.02),
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
                color: Colors.black.withValues(alpha: 0.2),
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
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
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
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
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
                  color: const Color(0xFF6366F1).withValues(alpha: 0.05),
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
    for (var p in _smoke) { p.update(); }

    return Container(
      height: 72,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
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
                  color: Colors.yellow.withValues(alpha: 0.2),
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
                  color: Colors.white.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          )),
          
          Text(
            widget.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
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
                        color: const Color(0xFF6366F1).withValues(alpha: 0.5),
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
    for (var c in _controllers) { c.dispose(); }
    for (var f in _focusNodes) { f.dispose(); }
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accentColor = const Color(0xFF6366F1);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: widget.bgColor.withValues(alpha: isDark ? 0.7 : 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : accentColor.withValues(alpha: 0.1),
              width: 1.5,
            ),
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
                    color: Colors.grey.withValues(alpha: 0.3),
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
                    color: widget.titleColor.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                if (_isScanning)
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      color: Colors.black,
                      border: Border.all(color: accentColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.3),
                          blurRadius: 20,
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
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
                          foregroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: accentColor, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isVerifying || _isScanning ? null : () {
                            final otp = _controllers.map((c) => c.text).join();
                            _verifyOtp(otp);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
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
                    ),
                  ],
                ),
              ],
            ),
          ),
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
        color: const Color(0xFF6366F1).withValues(alpha: 0.05),
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
