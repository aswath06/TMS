import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tripzo/screens/faculty/missions/reassign_guest_screen.dart';
import 'package:tripzo/screens/faculty/missions/change_driver_vehicle_sheet.dart';
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
import 'package:tripzo/screens/admin/request/admin_finalize_request_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tripzo/services/location_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/providers/notification_provider.dart';
import 'package:tripzo/models/notification_model.dart';


class MissionDetailsScreen extends ConsumerStatefulWidget {
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
  ConsumerState<MissionDetailsScreen> createState() => _MissionDetailsScreenState();
}

class _MissionDetailsScreenState extends ConsumerState<MissionDetailsScreen>
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
  bool _isMarkingReceived = false;
  int? _driverId;
  bool _isQrCodeOpen = false;
  Timer? _qrPollTimer;
  NotificationProvider? _notificationProvider;

  bool get _isTransportOrSuperAdmin =>
      _userRole?.toLowerCase() == 'transport admin' ||
      _userRole?.toLowerCase() == 'super admin';


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
      _setupNotificationListener();
    });
  }

  void _setupNotificationListener() {
    try {
      _notificationProvider = ref.read(notificationProviderFamily);
      _notificationProvider?.addListener(_handleNotificationUpdate);
      debugPrint("[NOTIFICATION LISTENER] Successfully registered notification listener in MissionDetailsScreen.");
    } catch (e) {
      debugPrint("[NOTIFICATION LISTENER] Error registering notification listener: $e");
    }
  }

  void _handleNotificationUpdate() {
    if (!mounted) return;
    
    final provider = _notificationProvider;
    if (provider != null && provider.notifications.isNotEmpty) {
      final NotificationModel latestNotification = provider.notifications.first;
      debugPrint("[SOCKET REFRESH] Driver details screen detected notification: '${latestNotification.title}' | '${latestNotification.message}'");
      
      // Let's inspect the notification message and reference ID
      final currentRequestIdInt = int.tryParse(widget.requestId);
      final isMatchingRequest = latestNotification.referenceId == currentRequestIdInt || 
          latestNotification.message.contains(widget.requestId) || 
          latestNotification.title.contains(widget.requestId);
          
      bool isMatchingTrip = false;
      final tripInstances = _missionData?['trip_instances'] as List?;
      if (tripInstances != null && tripInstances.isNotEmpty) {
        final firstTrip = tripInstances[0];
        final tripId = firstTrip['id'];
        if (tripId != null) {
          isMatchingTrip = latestNotification.referenceId == tripId ||
              latestNotification.message.contains(tripId.toString());
        }
      }
      
      // If we got a real-time notification matching this request or trip instance, auto-refresh and close QR!
      if (isMatchingRequest || isMatchingTrip) {
        debugPrint("[SOCKET REFRESH] Match verified! Closing QR popup and auto-reloading mission details...");
        
        if (_isQrCodeOpen && mounted) {
          _isQrCodeOpen = false;
          Navigator.of(context).pop();
        }
        
        _fetchMissionDetails();
      }
    }
  }

  Future<void> _fetchUserRole() async {
    final role = await UserStore.getRole();
    final driverId = await UserStore.getDriverId();
    if (mounted) {
      setState(() {
        _userRole = role;
        _driverId = driverId;
      });
    }
  }

  void _showTopToast(String message, Color color) {
    if (!mounted) return;
    
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: _TopToastWidget(
          message: message,
          color: color,
          onDismiss: () {
            if (overlayEntry.mounted) {
              overlayEntry.remove();
            }
          },
        ),
      ),
    );

    overlay.insert(overlayEntry);
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
      debugPrint("DEBUG: Mission Details Fetch: ID=${widget.requestId}");
      // debugPrint("curl -X GET '$url' -H 'Authorization: TMS $token' -H 'Content-Type: application/json'");
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
      final bool isAdmin = role?.toLowerCase().contains('admin') == true;

      final body = {
        "route_id": int.tryParse(widget.requestId) ?? 0,
        isAdmin ? "admin_remarks" : "faculty_remarks": remark.trim().isEmpty ? "Approved via Mobile App" : remark.trim(),
        "allocations": allocations,
      };

      final url = ApiConstants.updateAssignedVehicles;
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
    final bool isAdmin = role?.toLowerCase().contains('admin') == true;
    
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

  void _showStartInformationPopup() {
    final TextEditingController odometerController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Start Mission Information",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please enter the starting details before continuing.",
                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: odometerController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      labelText: "Start Odometer",
                      labelStyle: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      floatingLabelStyle: const TextStyle(
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w700,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      prefixIcon: const Icon(Icons.speed, color: Color(0xFF6366F1)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Close", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          final odo = odometerController.text;
                          Navigator.pop(context);
                          _submitStartInformation(odo, "0");
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text("SUBMIT", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEndInformationPopup() {
    final TextEditingController odometerController = TextEditingController();
    bool? allowanceNeeded;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "End Mission Information",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please enter the final details before completing the mission.",
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: odometerController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          labelText: "End Odometer",
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          floatingLabelStyle: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w700,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          prefixIcon: const Icon(Icons.speed, color: Color(0xFF6366F1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "DA/TA is required for driver*",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    allowanceNeeded = true;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: allowanceNeeded == true ? const Color(0xFF6366F1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: allowanceNeeded == true ? const Color(0xFF6366F1) : (isDark ? Colors.white24 : Colors.black12)),
                                  ),
                                  child: Text("YES", style: TextStyle(color: allowanceNeeded == true ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)), fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    allowanceNeeded = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: allowanceNeeded == false ? Colors.redAccent : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: allowanceNeeded == false ? Colors.redAccent : (isDark ? Colors.white24 : Colors.black12)),
                                  ),
                                  child: Text("NO", style: TextStyle(color: allowanceNeeded == false ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)), fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text("Close", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              final odo = odometerController.text;
                              if (odo.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Please enter the end odometer reading"), backgroundColor: Colors.orange),
                                );
                                return;
                              }
                              if (allowanceNeeded == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Please select whether DA/TA is required"), backgroundColor: Colors.orange),
                                );
                                return;
                              }
                              Navigator.pop(context);
                              _submitEndInformation(odo, "0", allowanceNeeded: allowanceNeeded ?? false);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981), // Green for end
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: const Text("SUBMIT", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _fetchAndShowStartQR() async {
    setState(() => _isApproving = true);
    try {
      final token = await UserStore.getToken();
      final tripInstances = _missionData?['trip_instances'] as List?;
      final tripId = tripInstances != null && tripInstances.isNotEmpty ? tripInstances[0]['id'] : null;

      if (tripId == null) throw "Trip ID not found";

      final url = ApiConstants.getStartOtp(tripId);
      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: "", 
      );

      debugPrint("DEBUG: Generate QR Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final encryptedOtp = data['data']?['encrypted_otp']?.toString() ?? "";
        
        if (!mounted) return;
        
        if (encryptedOtp.isEmpty || encryptedOtp == "N/A") {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No QR code data received"), backgroundColor: Colors.red),
          );
          return;
        }

        final qrPayload = jsonEncode({
          "trip_instance_id": data['data']['trip_instance_id'],
          "otp_type": data['data']['otp_type'],
          "otp": encryptedOtp
        });

        _showOtpModal(encryptedOtp, "START OTP", qrPayload: qrPayload);
      } else {
        final error = jsonDecode(response.body);
        throw error['message'] ?? "Failed to generate Start QR (${response.statusCode})";
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

  Future<void> _fetchAndShowEndQR() async {
    setState(() => _isApproving = true);
    try {
      final token = await UserStore.getToken();
      final tripInstances = _missionData?['trip_instances'] as List?;
      final tripId = tripInstances != null && tripInstances.isNotEmpty ? tripInstances[0]['id'] : null;

      if (tripId == null) throw "Trip ID not found";

      final url = ApiConstants.getEndOtp(tripId);
      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: "", 
      );

      debugPrint("DEBUG: Generate End QR Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final encryptedOtp = data['data']?['encrypted_otp']?.toString() ?? "";
        
        if (!mounted) return;
        
        if (encryptedOtp.isEmpty || encryptedOtp == "N/A") {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No QR code data received"), backgroundColor: Colors.red),
          );
          return;
        }

        final qrPayload = jsonEncode({
          "trip_instance_id": data['data']['trip_instance_id'],
          "otp_type": data['data']['otp_type'],
          "otp": encryptedOtp
        });

        _showOtpModal(encryptedOtp, "END OTP", qrPayload: qrPayload);
      } else {
        final error = jsonDecode(response.body);
        throw error['message'] ?? "Failed to generate End QR (${response.statusCode})";
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

  Future<void> _submitStartInformation(String odometer, String capacity) async {
    setState(() => _isApproving = true);
    try {
      final token = await UserStore.getToken();
      final tripInstances = _missionData?['trip_instances'] as List?;
      final tripId = tripInstances != null && tripInstances.isNotEmpty ? tripInstances[0]['id'] : null;

      if (tripId == null) throw "Trip ID not found";

      final url = ApiConstants.startRegister(tripId);
      final body = {
        "start_odometer": int.tryParse(odometer) ?? 0,
        "start_capacity": int.tryParse(capacity) ?? 0,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode(body),
      );

      debugPrint("DEBUG: Start Register Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Trip start reading registered successfully"), backgroundColor: Colors.green),
        );
        _fetchMissionDetails();
      } else {
        final error = jsonDecode(response.body);
        throw error['message'] ?? "Failed to register start reading";
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

  Future<void> _submitEndInformation(String odometer, String capacity, {bool allowanceNeeded = false}) async {
    setState(() => _isApproving = true);
    try {
      final token = await UserStore.getToken();
      final tripInstances = _missionData?['trip_instances'] as List?;
      final tripId = tripInstances != null && tripInstances.isNotEmpty ? tripInstances[0]['id'] : null;

      if (tripId == null) throw "Trip ID not found";

      final url = ApiConstants.endRegister(tripId);
      final body = {
        "end_odometer": double.tryParse(odometer) ?? 0.0,
        "allowance_needed": allowanceNeeded,
      };

      final curl = "curl --location '$url' \\\n"
                   "--header 'Authorization: TMS $token' \\\n"
                   "--header 'Content-Type: application/json' \\\n"
                   "--data '${jsonEncode(body)}'";
      debugPrint("DEBUG: End Register CURL:\n$curl");

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode(body),
      );

      debugPrint("DEBUG: End Register Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Trip end reading registered successfully"), backgroundColor: Colors.green),
        );
        _fetchMissionDetails();
      } else {
        final error = jsonDecode(response.body);
        throw error['message'] ?? "Failed to register end reading";
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

  @override
  void dispose() {
    _stopQrPolling();
    _notificationProvider?.removeListener(_handleNotificationUpdate);
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
    final url = "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=in";
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
    final String url = "https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson";

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

    final String statusString = (_missionData?['status'] ?? _missionData?['travel_info']?['status'] ?? widget.status ?? "").toString().toUpperCase();
    final bool isStart = statusString == 'APPROVED' || statusString == 'PLANNED' || 
                        currentStatus == 4 || currentStatus == 5 || currentStatus == 6 || currentStatus == 12;

    debugPrint("DEBUG: isStart=$isStart, statusString=$statusString, currentStatus=$currentStatus");

    if (isDriver) {
        final tripInstances = _missionData?['trip_instances'] as List?;
        String targetId = widget.requestId; // Fallback
        
        if (tripInstances != null && tripInstances.isNotEmpty) {
          final firstTrip = tripInstances[0];
          // Use Trip Instance ID (e.g., 70) instead of Leg ID (e.g., 84)
          // as per backend requirements for /request/trips/{id}/end
          targetId = firstTrip['id'].toString();
        }

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyMissionScreen(
              requestId: targetId,
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
        endpoint = ApiConstants.getStartOtp(tripId);
      } else {
        endpoint = ApiConstants.getEndOtp(tripId);
      }

      final headers = ApiConstants.getHeaders(token);
      
      // Log CURL for debug
      debugPrint("--- [DEBUG] GENERATING OTP ---");
      debugPrint("Endpoint: ${endpoint.replaceFirst(ApiConstants.baseUrl, '')}");
      // debugPrint("CURL COMMAND:\n$curl");
      debugPrint("-------------------------------");

      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: "", // Dynamic endpoints use empty body as per standard
      );

      debugPrint("--- [DEBUG] OTP GENERATION RESPONSE ---");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Body: ${response.body}");
      debugPrint("---------------------------------------");

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
      if (mounted) setState(() => _isLoadingOtp = false);
    }
  }

  Future<void> _handleAutoEnd(int? legId) async {
    if (legId == null) {
      _showTopToast("Unable to identify leg ID to end.", Colors.red);
      return;
    }

    setState(() => _isApproving = true);
    try {
      final token = await UserStore.getToken();
      final url = ApiConstants.endTripLeg(legId);
      final body = {"mode": "DIRECT"};

      final curl = "curl --location '$url' \\\n"
                   "--header 'Authorization: TMS $token' \\\n"
                   "--header 'Content-Type: application/json' \\\n"
                   "--data '${jsonEncode(body)}'";
      debugPrint("DEBUG: Auto End Leg CURL:\n$curl");

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode(body),
      );

      debugPrint("DEBUG: Auto End Leg Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showTopToast("Trip leg ended successfully!", Colors.green);
        _fetchMissionDetails();
      } else {
        final error = jsonDecode(response.body);
        _showTopToast(error['message'] ?? "End Trip Leg failed", Colors.red);
      }
    } catch (e) {
      _showTopToast("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  Future<void> _handleDirectStart() async {

    setState(() => _isApproving = true); // Using _isApproving state for loading
    try {
      final String? token = await UserStore.getToken();
      final tripInstances = _missionData?['trip_instances'] as List?;
      final tripId = tripInstances != null && tripInstances.isNotEmpty ? tripInstances[0]['id'] : null;

      if (tripId == null) throw "Trip ID not found";

      final url = ApiConstants.startTrip(tripId);
      final body = {"mode": "DIRECT"};

      final curl = "curl --location '$url' \\\n"
                   "--header 'Authorization: TMS $token' \\\n"
                   "--header 'Content-Type: application/json' \\\n"
                   "--data '${jsonEncode(body)}'";
      debugPrint("DEBUG: Direct Start CURL:\n$curl");

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode(body),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint("Direct Start API Error!");
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
      if (mounted) setState(() => _isApproving = false);
    }
  }

  Future<void> _deleteRoute() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Delete Route", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("Are you sure you want to delete this route? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isApproving = true);
    try {
      final String? token = await UserStore.getToken();
      final String requestId = widget.requestId;

      final response = await http.delete(
        Uri.parse(ApiConstants.deleteRoute(requestId)),
        headers: ApiConstants.getHeaders(token),
      );

      debugPrint("DEBUG: Delete Route Response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Route deleted successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Go back to the list and signal refresh
      } else {
        final error = jsonDecode(response.body);
        throw error['message'] ?? "Failed to delete route";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  Future<void> _handleAutoStart() async {
    setState(() => _isApproving = true); 
    try {
      final String? token = await UserStore.getToken();
      final tripInstances = _missionData?['trip_instances'] as List?;
      final tripId = tripInstances != null && tripInstances.isNotEmpty ? tripInstances[0]['id'] : null;

      if (tripId == null) throw "Trip ID not found";

      // 1. Call API with mode AUTO
      final url = ApiConstants.startTrip(tripId);
      final headers = ApiConstants.getHeaders(token);
      final body = {"mode": "DIRECT"};

      // Console the CURL
      debugPrint("--- [DEBUG] AUTO START TRIP CURL ---");
      String curl = "curl --location --request POST '$url' \\\n";
      headers.forEach((k, v) => curl += "--header '$k: $v' \\\n");
      curl += "--data '${jsonEncode(body)}'";
      debugPrint(curl);
      debugPrint("------------------------------------");

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      debugPrint("--- [DEBUG] AUTO START TRIP RESPONSE ---");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Body: ${response.body}");
      debugPrint("---------------------------------------");

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 2. Start Location Tracking
        final role = await UserStore.getRole();
        if (role == 'driver') {
          LocationService().startTracking(tripId);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Trip auto-started successfully! Tracking active."), backgroundColor: Colors.green),
        );
        _fetchMissionDetails();
      } else {
        final error = jsonDecode(response.body);
        throw error['message'] ?? "Auto start failed";
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  Future<void> _markAllowanceReceived(int allowanceId, String mode, String remarks) async {
    setState(() => _isMarkingReceived = true);
    try {
      final token = await UserStore.getToken();
      final url = ApiConstants.markAllowanceReceived(allowanceId);
      final body = {
        "payment_mode": mode,
        "remarks": remarks.isEmpty ? "Received by driver" : remarks,
      };

      final response = await http.patch(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode(body),
      );

      final respData = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        _showTopToast("Allowance marked as received!", Colors.green);
        _fetchMissionDetails();
      } else {
        throw respData['message'] ?? "Failed to mark as received";
      }
    } catch (e) {
      if (!mounted) return;
      _showTopToast("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isMarkingReceived = false);
    }
  }

  void _showMarkReceivedModal(int allowanceId) {
    String selectedMode = "UPI";
    final TextEditingController remarksController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bool isDark = Theme.of(context).brightness == Brightness.dark;
            final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
            final Color primaryIndigo = const Color(0xFF6366F1);

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Mark as Received",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please confirm the payment mode and add remarks.",
                      style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "PAYMENT MODE",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      children: ["UPI", "BANK", "CASH"].map((mode) {
                        final isSelected = selectedMode == mode;
                        return ChoiceChip(
                          label: Text(mode),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setModalState(() => selectedMode = mode);
                          },
                          selectedColor: primaryIndigo.withValues(alpha: 0.2),
                          backgroundColor: Colors.grey.withValues(alpha: 0.1),
                          labelStyle: TextStyle(
                            color: isSelected ? primaryIndigo : Colors.grey.shade600,
                            fontWeight: FontWeight.w800,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? primaryIndigo : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "REMARKS",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarksController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Enter remarks (e.g., Paid and received by driver)",
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryIndigo, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isMarkingReceived ? null : () {
                          Navigator.pop(context);
                          _markAllowanceReceived(allowanceId, selectedMode, remarksController.text);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryIndigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isMarkingReceived 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("CONFIRM RECEIPT", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
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


  void _startQrPolling(String title) {
    _stopQrPolling();
    debugPrint("[QR POLL] Starting periodic status polling for: $title");
    _qrPollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _pollMissionStatus(title);
    });
  }

  void _stopQrPolling() {
    if (_qrPollTimer != null) {
      debugPrint("[QR POLL] Stopping periodic status polling.");
      _qrPollTimer?.cancel();
      _qrPollTimer = null;
    }
  }

  Future<void> _pollMissionStatus(String title) async {
    try {
      final token = await UserStore.getToken();
      final url = "${ApiConstants.getRouteById}${widget.requestId}";
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final freshData = data['data'];
          final String statusString = (freshData?['status'] ?? freshData?['travel_info']?['status'] ?? "").toString().toUpperCase();
          final currentStatus = freshData?['route_status'];

          debugPrint("[QR POLL] Current Poll status: $statusString, currentStatus: $currentStatus, modal: $title");

          bool shouldDismiss = false;
          if (title.toUpperCase().contains("START")) {
            // Looking for STARTED/ONGOING
            if (statusString == 'STARTED' || statusString == 'ONGOING' || currentStatus == 7 || currentStatus == 4) {
              shouldDismiss = true;
            }
          } else if (title.toUpperCase().contains("END")) {
            // Looking for COMPLETED
            if (statusString == 'COMPLETED' || currentStatus == 8) {
              shouldDismiss = true;
            }
          }

          if (shouldDismiss) {
            debugPrint("[QR POLL] Target status matched! Automatically dismissing QR modal...");
            _stopQrPolling();
            if (_isQrCodeOpen && mounted) {
              _isQrCodeOpen = false;
              Navigator.of(context).pop();
            }
            _fetchMissionDetails();
          }
        }
      }
    } catch (e) {
      debugPrint("[QR POLL] Error polling mission status: $e");
    }
  }


  void _showOtpModal(String otp, String title, {String? qrPayload}) {
    _isQrCodeOpen = true;
    _startQrPolling(title);
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) => OtpFlashScreen(
          otp: otp,
          title: title,
          qrDataPayload: qrPayload,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    ).then((_) {
      _isQrCodeOpen = false;
      _stopQrPolling();
    });
  }

  void _showStopStatusModal(int tripId, int stopId) {
    String selectedAction = "ARRIVED";
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bool isDark = Theme.of(context).brightness == Brightness.dark;
            final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
            final Color primaryBlue = const Color(0xFF6366F1);

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Update Stop Status", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("Select the action for this checkpoint.", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildActionChip("ARRIVED", selectedAction == "ARRIVED", primaryBlue, (val) {
                        if (val) setModalState(() => selectedAction = "ARRIVED");
                      }),
                      const SizedBox(width: 12),
                      _buildActionChip("SKIPPED", selectedAction == "SKIPPED", Colors.orange, (val) {
                        if (val) setModalState(() => selectedAction = "SKIPPED");
                      }),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        setModalState(() => isSubmitting = true);
                        try {
                          await _updateStopStatus(tripId, stopId, selectedAction);
                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          if (mounted) {
                             String errorMsg = e.toString();
                             if (errorMsg.contains("MissingPluginException")) {
                               errorMsg = "Please RESTART the application. A new plugin was added.";
                             }
                             _showTopToast(errorMsg, Colors.red);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: isSubmitting 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("SUBMIT UPDATE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionChip(String label, bool isSelected, Color activeColor, Function(bool) onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: activeColor.withValues(alpha: 0.2),
      backgroundColor: Colors.grey.withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: isSelected ? activeColor : Colors.grey.shade600,
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? activeColor : Colors.transparent, width: 1.5),
      ),
      showCheckmark: false,
    );
  }

  Future<void> _updateStopStatus(int tripId, int stopId, String action) async {
    // 1. Get Location (Fallback silently to 0.0, 0.0 if any error occurs or disabled)
    Position? position;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        }
      }
    } catch (e) {
       debugPrint("Silently caught location error: $e");
    }

    // 2. PATCH Request
    final token = await UserStore.getToken();
    final url = ApiConstants.updateStopStatus(tripId, stopId);
    final body = {
      "action": action,
      "latitude": position?.latitude ?? 0.0,
      "longitude": position?.longitude ?? 0.0,
      "recorded_at": DateTime.now().toUtc().toIso8601String(),
    };

    final response = await http.patch(
      Uri.parse(url),
      headers: ApiConstants.getHeaders(token),
      body: jsonEncode(body),
    );

    debugPrint("DEBUG: PATCH Stop Status Response: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (mounted) {
        _showTopToast("Stop status updated successfully!", Colors.green);
        _fetchMissionDetails();
      }
    } else {
      final error = jsonDecode(response.body);
      throw error['message'] ?? "Failed to update status";
    }
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
    final String statusString = (_missionData?['status'] ?? _missionData?['travel_info']?['status'] ?? widget.status ?? "").toString().toUpperCase();
    
    final bool isDriver = _userRole?.toLowerCase() == 'driver';
    
    // Draft check
    final bool isDraft = currentStatus == 1 || currentStatus == 10 || statusString == 'DRAFT';

    // Check if any trip instance has allowances
    final bool hasAllowance = (_missionData?['trip_instances'] as List?)?.any((t) => (t['allowances'] as List?)?.isNotEmpty ?? false) ?? false;

    final bool isApprovedState = statusString == 'APPROVED' || statusString == 'PLANNED' || statusString == 'ASSIGNED' || 
                                currentStatus == 4 || currentStatus == 5 || currentStatus == 6 || currentStatus == 12;
    
    final travelInfo = _missionData?['travel_info'];
    final tripInstancesForEnd = _missionData?['trip_instances'] as List?;
    final activeTripForEnd = (tripInstancesForEnd != null && tripInstancesForEnd.isNotEmpty) ? tripInstancesForEnd[0] : null;
    var endedAt = activeTripForEnd?['ended_at'] ?? _missionData?['ended_at'] ?? travelInfo?['ended_at'];
    bool showAutoStart = false;
    bool showAutoEnd = false;
    int? tripIdToEnd;
    int? legIdToEnd;

    if ((isDriver || _isTransportOrSuperAdmin) && (statusString == 'STARTED' || statusString == 'ONGOING')) {
      final tripInstances = _missionData?['trip_instances'] as List?;
      if (tripInstances != null && tripInstances.isNotEmpty) {
        final latestTrip = tripInstances[0];
        tripIdToEnd = latestTrip['id'];
        final legs = latestTrip['legs'] as List?;
        if (legs != null && legs.isNotEmpty) {
          final firstLeg = legs[0];
          legIdToEnd = firstLeg['id'];
          final stops = firstLeg['stops'] as List?;
          if (stops != null && stops.isNotEmpty) {
            // Check if all stops are either ARRIVED or COMPLETED or SKIPPED
            // (i.e., none are PENDING)
            final allHandled = stops.every((s) => s['stop_status'] != 'PENDING');
            if (allHandled) {
              showAutoEnd = true;
            }
          }
        }
      }
    }

    if (isDriver && isApprovedState) {
      try {
        final startStr = travelInfo?['start_datetime'];
        if (startStr != null) {
          final startTime = DateTime.parse(startStr).toUtc();
          final now = DateTime.now().toUtc();
          final diff = now.difference(startTime).inMinutes;
          
          debugPrint("[AutoStartDebug] Now (UTC): $now");
          debugPrint("[AutoStartDebug] Start (UTC): $startTime");
          debugPrint("[AutoStartDebug] Diff (mins): $diff");
          debugPrint("[AutoStartDebug] Status: $statusString, Raw: $currentStatus, isDriver: $isDriver");

          if (diff >= -30 && diff <= 30) {
            showAutoStart = true;
          }
        }
      } catch (e) {
        debugPrint("Error parsing start_datetime: $e");
      }
    }

    bool hasStartOdometer = false;
    var startOdoCheck = _missionData?['travel_info']?['start_odometer'];
    if (startOdoCheck == null) {
      final tripInstances = _missionData?['trip_instances'] as List?;
      if (tripInstances != null && tripInstances.isNotEmpty) {
        startOdoCheck = tripInstances[0]['start_odometer'];
      }
    }
    hasStartOdometer = startOdoCheck != null;

    bool hasEndOdometer = false;
    var endOdoCheck = _missionData?['travel_info']?['end_odometer'];
    if (endOdoCheck == null) {
      final tripInstances = _missionData?['trip_instances'] as List?;
      if (tripInstances != null && tripInstances.isNotEmpty) {
        endOdoCheck = tripInstances[0]['end_odometer'];
      }
    }
    hasEndOdometer = endOdoCheck != null;

    bool isEligibleForEndInfo = false;
    if ((isDriver || _isTransportOrSuperAdmin) && (statusString == 'STARTED' || statusString == 'ONGOING' || statusString == 'COMPLETED' || currentStatus == 7 || currentStatus == 8)) {
      final tripInstances = _missionData?['trip_instances'] as List?;
      if (tripInstances != null && tripInstances.isNotEmpty) {
        final latestTrip = tripInstances[0];
        final legs = latestTrip['legs'] as List?;
        if (legs != null && legs.isNotEmpty) {
          final stops = legs[0]['stops'] as List?;
          if (stops != null && stops.isNotEmpty) {
             if (stops.length > 1) {
                isEligibleForEndInfo = stops.sublist(0, stops.length - 1).every((s) => s['stop_status'] != 'PENDING');
             } else {
                isEligibleForEndInfo = true;
             }
          }
        }
      }
    }

    if (isDriver) {
      showAutoStart = false;
      showAutoEnd = false;
    }

    bool showAction = isApprovedState || currentStatus == 7 || statusString == 'STARTED' || statusString == 'ONGOING' || (statusString == 'COMPLETED' && !hasEndOdometer);
    final bool isFaculty = _userRole?.toLowerCase() == 'faculty';
    if (isFaculty) showAction = false;
    
    String actionLabel = (currentStatus == 7 || statusString == 'STARTED' || statusString == 'ONGOING') 
        ? "GENERATE END OTP" 
        : "GENERATE START OTP";
        
    if (isDriver) {
      actionLabel = (currentStatus == 7 || statusString == 'STARTED' || statusString == 'ONGOING') ? "GENERATE END OTP" : "SWIPE TO START";
    }

    // if status is approved and allowance exists, show START OTP
    if (isApprovedState && hasAllowance && !isDriver) {
       actionLabel = "SWIPE TO START (GET OTP/QR)";
    }

    bool showApproveDecline = currentStatus == 2 || currentStatus == 3 || statusString == 'PENDING' || statusString == 'SUBMITTED';
    if (isFaculty) showApproveDecline = false;

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
                          _buildOdometerMetrics(cardColor, primaryBlue, subColor, isDark),
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
                          if (isDraft && _userRole?.toLowerCase() != 'faculty') ...[
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
                            if (isApprovedState && _isTransportOrSuperAdmin) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showChangeDriverVehicleModal(cardColor, primaryBlue, titleColor, subColor, isDark),
                                  icon: const Icon(Icons.swap_horiz_rounded),
                                  label: const Text(
                                    "CHANGE DRIVER OR VEHICLE",
                                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primaryBlue,
                                    side: BorderSide(color: primaryBlue.withValues(alpha: 0.5), width: 1.5),
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ),
                            ],
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
                            if (!isFaculty) _buildAllowances(cardColor, primaryBlue, subColor, statusString),
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
                  if (isApprovedState && _isTransportOrSuperAdmin && hasStartOdometer)
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
                  if ((statusString == 'STARTED' || statusString == 'ONGOING') && _isTransportOrSuperAdmin)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isApproving || _isLoadingOtp 
                            ? null 
                            : () {
                                if (!hasEndOdometer) {
                                  _showEndInformationPopup();
                                } else if (tripIdToEnd != null) {
                                  _handleAutoEnd(tripIdToEnd);
                                }
                              },
                          icon: _isApproving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.stop_circle_rounded, size: 20),
                          label: const Text(
                            "DIRECT END",
                            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            shadowColor: Colors.redAccent.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  if (showAutoEnd)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isApproving || _isLoadingOtp ? null : () => _handleAutoEnd(tripIdToEnd),
                          icon: _isApproving 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                            : const Icon(Icons.stop_circle_rounded, size: 20),
                          label: const Text(
                            "Auto end button",
                            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            shadowColor: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  if (showAutoStart)

                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isApproving || _isLoadingOtp ? null : _handleAutoStart,
                          icon: _isApproving 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                            : const Icon(Icons.flash_auto_rounded, size: 20),
                          label: const Text(
                            "AUTO START TRIP",
                            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            shadowColor: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  if ((isDriver || _isTransportOrSuperAdmin) && statusString == 'APPROVED' && !hasStartOdometer)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showStartInformationPopup,
                          icon: const Icon(Icons.info_outline_rounded, size: 20),
                          label: const Text(
                            "START",
                            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 4,
                            shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  if ((isDriver || _isTransportOrSuperAdmin) && (statusString == 'STARTED' || statusString == 'ONGOING' || statusString == 'COMPLETED' || currentStatus == 7 || currentStatus == 8) && isEligibleForEndInfo && !hasEndOdometer && endedAt != null)
                    _EndButtonWithTimer(
                      endedAtStr: endedAt.toString(),
                      onPressed: _showEndInformationPopup,
                      isAdmin: _isTransportOrSuperAdmin,
                    ),
                  if (!_isTransportOrSuperAdmin &&
                      (!isDriver || 
                      (isDriver && statusString == 'APPROVED' && hasStartOdometer) || 
                      (isDriver && (statusString == 'STARTED' || statusString == 'ONGOING') && (!isEligibleForEndInfo || endedAt == null))))
                    _SwipeToConfirm(
                      label: actionLabel.toUpperCase(),
                      onConfirm: () {
                        if (isDriver && statusString == 'APPROVED') {
                           _fetchAndShowStartQR();
                        } else if (isDriver && (statusString == 'STARTED' || statusString == 'ONGOING') && isEligibleForEndInfo && endedAt == null) {
                           _fetchAndShowEndQR();
                        } else {
                           _handleAction();
                        }
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOdometerMetrics(Color cardColor, Color primaryColor, Color subColor, bool isDark) {
    Map<String, dynamic>? travelInfo = _missionData?['travel_info'];
    
    final tripInstances = _missionData?['trip_instances'] as List?;
    final activeTrip = (tripInstances != null && tripInstances.isNotEmpty) ? tripInstances[0] : null;
    
    var startedAt = activeTrip?['started_at'] ?? _missionData?['started_at'] ?? travelInfo?['started_at'];
    var endedAt = activeTrip?['ended_at'] ?? _missionData?['ended_at'] ?? travelInfo?['ended_at'];

    final String? startedBy = (activeTrip?['started_by'] is Map ? activeTrip?['started_by']?['name']?.toString() : activeTrip?['started_by']?.toString()) ??
                              (_missionData?['started_by'] is Map ? _missionData?['started_by']?['name']?.toString() : _missionData?['started_by']?.toString());

    final String? endedBy = (activeTrip?['ended_by'] is Map ? activeTrip?['ended_by']?['name']?.toString() : activeTrip?['ended_by']?.toString()) ??
                            (_missionData?['ended_by'] is Map ? _missionData?['ended_by']?['name']?.toString() : _missionData?['ended_by']?.toString());

    var startOdometer = travelInfo?['start_odometer'];
    var endOdometer = travelInfo?['end_odometer'];
    var startCapacity = travelInfo?['start_capacity'];
    var endCapacity = travelInfo?['end_capacity'];

    // Fallback if nested or in trip_instances
    if (startOdometer == null) {
      if (activeTrip != null) {
        startOdometer = activeTrip['start_odometer'];
        endOdometer = activeTrip['end_odometer'];
        startCapacity = activeTrip['start_capacity'];
        endCapacity = activeTrip['end_capacity'];
      }
    }

    startCapacity ??= 0;
    endCapacity ??= 0;

    double? startVal = startOdometer != null ? double.tryParse(startOdometer.toString()) : null;
    double? endVal = endOdometer != null ? double.tryParse(endOdometer.toString()) : null;

    double? difference;
    if (startVal != null && endVal != null && endVal >= startVal) {
      difference = endVal - startVal;
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, color: primaryColor, size: 24),
              const SizedBox(width: 10),
              Text(
                "Travel Metrics",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTimeDurationSection(startedAt, endedAt, startedBy, endedBy, primaryColor, isDark),
          const SizedBox(height: 24),
          Divider(height: 1, thickness: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildMetricTile("START ODOMETER", startOdometer?.toString() ?? "N/A", Icons.flag_circle_rounded, Colors.blue, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricTile("END ODOMETER", endOdometer?.toString() ?? "N/A", Icons.check_circle_rounded, Colors.green, isDark)),
            ],
          ),
          if (startedAt != null || difference != null) ...[
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final startDt = _parseTimestamp(startedAt);
                final endDt = _parseTimestamp(endedAt);
                Duration? dur;
                if (startDt != null && endDt != null) dur = endDt.difference(startDt);
                else if (startDt != null && endedAt == null) dur = DateTime.now().difference(startDt);
                
                final bool isOngoing = startedAt != null && endedAt == null;
                final String label = dur != null ? _formatDuration(dur) : (isOngoing ? "Calculating..." : "N/A");
                
                return Row(
                  children: [
                    if (startedAt != null) Expanded(child: _buildMetricTile("TOTAL DURATION", label, Icons.timer_outlined, primaryColor, isDark)),
                    if (startedAt != null && difference != null) const SizedBox(width: 12),
                    if (difference != null) Expanded(child: _buildMetricTile("TOTAL DISTANCE", "${difference.toStringAsFixed(1)} KM", Icons.route_outlined, primaryColor, isDark)),
                  ],
                );
              }
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, Color iconColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
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
    final String statusString = (_missionData?['status'] ?? _missionData?['travel_info']?['status'] ?? widget.status ?? "").toString().toUpperCase();
    final bool isApproved = statusString == 'APPROVED';
    final bool isDraft = statusString == 'DRAFT' || statusString == 'PENDING' || statusString == 'SUBMITTED';
    final bool isAdmin = _isTransportOrSuperAdmin;
    final bool isFaculty = _userRole?.toLowerCase() == 'faculty';
    
    final bool showDeleteIcon = (isApproved && isAdmin) || (isFaculty && (isApproved || isDraft));

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
        showDeleteIcon
            ? IconButton(
                onPressed: _isApproving ? null : _deleteRoute,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 24,
                ),
              )
            : const SizedBox(width: 48),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
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

    final tripInstances = _missionData?['trip_instances'] as List?;
    final activeTrip = (tripInstances != null && tripInstances.isNotEmpty) ? tripInstances[0] : null;
    final bool? allowanceNeeded = activeTrip?['allowance_needed'];

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
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
                    if (sUpper == 'COMPLETED' && (allowanceNeeded ?? false)) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payments_outlined, color: Colors.green, size: 12),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                "ALLOWANCE REQUIRED",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tType.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Redesigned Schedule Section
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: subColor.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                _buildScheduleItem(
                  icon: Icons.departure_board_rounded,
                  label: "DEPARTURE",
                  dateTimeStr: travelInfo?['start_datetime'],
                  fallback: widget.time,
                  color: Colors.blueAccent,
                  subColor: subColor,
                  titleColor: titleColor,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    height: 40,
                    width: 1,
                    color: subColor.withValues(alpha: 0.1),
                  ),
                ),
                _buildScheduleItem(
                  icon: Icons.auto_awesome_motion_rounded,
                  label: "ARRIVAL",
                  dateTimeStr: travelInfo?['end_datetime'],
                  fallback: "TBD",
                  color: Colors.greenAccent,
                  subColor: subColor,
                  titleColor: titleColor,
                ),
              ],
            ),
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

          if (travelInfo?['department'] != null &&
              travelInfo?['department']['department_name'] != null &&
              travelInfo?['department']['department_name'].toString().isNotEmpty == true &&
              travelInfo?['department']['department_name'].toString() != 'null') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business_rounded, size: 14, color: Colors.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "DEPARTMENT: ${travelInfo?['department']?['department_name']}",
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.purple, letterSpacing: 0.3),
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

  Widget _buildScheduleItem({
    required IconData icon,
    required String label,
    String? dateTimeStr,
    required String fallback,
    required Color color,
    required Color subColor,
    required Color titleColor,
  }) {
    DateTime? dt = dateTimeStr != null ? DateTime.tryParse(dateTimeStr) : null;
    String datePart = dt != null ? DateFormat('MMM dd, yyyy').format(dt.toLocal()) : "---";
    String timePart = dt != null ? DateFormat('hh:mm a').format(dt.toLocal()) : fallback;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: subColor.withValues(alpha: 0.6),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            timePart,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: titleColor,
              letterSpacing: -0.2,
            ),
          ),
          Text(
            datePart,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: subColor.withValues(alpha: 0.5),
            ),
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
    final tripInstances = _missionData?['trip_instances'] as List?;
    
    // Attempt to get stops from the active trip instance first
    if (tripInstances != null && tripInstances.isNotEmpty) {
      final activeTrip = tripInstances[0];
      final tripId = activeTrip['id'];
      final legs = activeTrip['legs'] as List?;
      
      if (legs != null && legs.isNotEmpty) {
        List<dynamic> allStops = [];
        for (var leg in legs) {
          final stops = leg['stops'] as List?;
          if (stops != null) {
            allStops.addAll(stops.map((s) => { ...s, 'tripId': tripId }));
          }
        }
        
        if (allStops.isNotEmpty) {
          // Find the last stop that has arrived to show the "current location" car icon
          int lastArrivedIndex = -1;
          for (int i = 0; i < allStops.length; i++) {
            if (allStops[i]['stop_status'] == 'ARRIVED') {
              lastArrivedIndex = i;
            }
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allStops.length,
            itemBuilder: (context, index) {
              final stop = allStops[index];
              return _buildTimelineItem(
                location: stop['stop_name'] ?? "Unknown Stop",
                eta: stop['planned_arrival_at'] ?? "",
                actualTime: stop['actual_arrival_at'],
                status: stop['stop_status'] ?? "PENDING",
                isFirst: index == 0,
                isLast: index == allStops.length - 1,
                isCurrentLocation: index == lastArrivedIndex,
                color: blue,
                titleColor: title,
                tripId: stop['tripId'],
                stopId: stop['id'],
              );
            },
          );
        }
      }
    }

    // Fallback to route_details if trip_instances are not available or empty
    final legs = _missionData?['route_details']?['legs'] as List?;
    if (legs == null || legs.isEmpty) return const SizedBox.shrink();
    
    List<dynamic> allStops = [];
    for (var leg in legs) {
      final stops = leg['stops'] as List?;
      if (stops != null) {
        allStops.addAll(stops);
      }
    }

    if (allStops.isEmpty) return const SizedBox.shrink();

    // Find last arrived for fallback route as well (though less common)
    int lastArrivedIndex = -1;
    for (int i = 0; i < allStops.length; i++) {
      if (allStops[i]['stop_status'] == 'ARRIVED') {
        lastArrivedIndex = i;
      }
    }

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
          isCurrentLocation: index == lastArrivedIndex,
          color: blue,
          titleColor: title,
        );
      },
    );
  }

  Widget _buildTimelineItem({
    required String location,
    required String eta,
    String? actualTime,
    String status = "PENDING",
    required bool isFirst,
    required bool isLast,
    bool isCurrentLocation = false,
    required Color color,
    required Color titleColor,
    int? tripId,
    int? stopId,
  }) {
    final bool isDark = titleColor == Colors.white;
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color blueIcon = const Color(0xFF6366F1);
    
    // Handle isDriver role locally
    final bool isDriver = _userRole?.toLowerCase() == 'driver' || _isTransportOrSuperAdmin;

    Color statusColor = Colors.grey;
    if (status == 'ARRIVED' || status == 'COMPLETED') statusColor = Colors.green;
    if (status == 'SKIPPED') statusColor = Colors.orange;

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
                  color: isFirst ? Colors.green : (isLast ? Colors.red : blueIcon),
                  border: Border.all(color: (isFirst ? Colors.green : (isLast ? Colors.red : blueIcon)).withValues(alpha: 0.2), width: 4),
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
              child: Column(
                children: [
                  Row(
                    children: [
                      // Location Pin Icon instead of Blue Car Icon container
                      Icon(Icons.location_on_rounded, color: isFirst ? Colors.green : (isLast ? Colors.red : blueIcon), size: 20),
                      const SizedBox(width: 12),
                      // Location Details alone
                      Expanded(
                        child: Text(
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
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatActualTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${dt.day} ${months[dt.month - 1]}, ${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
    } catch (_) {
      return timeStr;
    }
  }

  String _formatDateTimeString(String timeStr, {bool showDate = false}) {
     if (timeStr.contains('T') || timeStr.contains('-')) {
        try {
          final dt = DateTime.parse(timeStr).toLocal();
          final timePart = "${dt.hour % 12 == 0 ? 12 : dt.hour % 12}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
          if (showDate) {
            final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
            return "${dt.day} ${months[dt.month - 1]}, $timePart";
          }
          return timePart;
        } catch (_) {}
     }
     return timeStr;
  }

  DateTime? _parseTimestamp(dynamic val) {
    if (val == null) return null;
    try {
      final str = val.toString().replaceAll(' ', 'T');
      return DateTime.parse(str);
    } catch (_) {
      return null;
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    
    List<String> parts = [];
    if (hours > 0) {
      parts.add("$hours hr${hours > 1 ? 's' : ''}");
    }
    if (minutes > 0) {
      parts.add("$minutes min${minutes > 1 ? 's' : ''}");
    }
    if (hours == 0 && minutes == 0) {
      parts.add("$seconds sec${seconds > 1 ? 's' : ''}");
    }
    return parts.join(" ");
  }

  Widget _buildTimeDurationSection(dynamic startedAt, dynamic endedAt, String? startedBy, String? endedBy, Color primaryColor, bool isDark) {
    final startDt = _parseTimestamp(startedAt);
    final endDt = _parseTimestamp(endedAt);
    Duration? duration;
    if (startDt != null && endDt != null) {
      duration = endDt.difference(startDt);
    } else if (startDt != null && endedAt == null) {
      duration = DateTime.now().difference(startDt);
    }

    final bool isOngoing = startedAt != null && endedAt == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Start Node
            Expanded(
              child: _buildTimeNodeCard(
                "STARTED",
                startedAt,
                startedBy,
                Icons.play_circle_fill_rounded,
                Colors.green,
                isDark,
              ),
            ),
            
            // Bridge Animation
            _buildConnectingBridge(primaryColor, isOngoing),
            
            // End Node
            Expanded(
              child: _buildTimeNodeCard(
                endedAt != null ? "ENDED" : (startedAt != null ? "ONGOING" : "PENDING"),
                endedAt ?? (startedAt != null ? "In Progress" : null),
                endedBy,
                Icons.stop_circle_rounded,
                endedAt != null ? Colors.redAccent : (startedAt != null ? Colors.orange : Colors.grey),
                isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectingBridge(Color activeColor, bool isOngoing) {
    return SizedBox(
      width: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 2,
            width: 32,
            color: activeColor.withValues(alpha: 0.2),
          ),
          ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.2).animate(
              CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOngoing ? Colors.orange : activeColor,
                boxShadow: [
                  BoxShadow(
                    color: (isOngoing ? Colors.orange : activeColor).withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationBadge(Duration? duration, Color primaryColor, bool isOngoing) {
    final String label = duration != null ? _formatDuration(duration) : (isOngoing ? "Calculating..." : "N/A");
    
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.timer_outlined, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "TOTAL DURATION",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeNodeCard(String title, dynamic rawTime, String? byName, IconData icon, Color accentColor, bool isDark) {
    final String timeStr = (rawTime != null && rawTime != "In Progress") ? _formatActualTime(rawTime.toString()) : (rawTime == "In Progress" ? "In Progress" : "N/A");
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final Color cardBg = isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: subTextColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          if (rawTime != null && rawTime != "In Progress") ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 12, color: subTextColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "By: ${byName != null && byName.trim().isNotEmpty ? byName : 'Not Recorded'}",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: subTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }


  void _showAllGuestsBottomSheet(List<dynamic> guests, Color cardColor, Color blue, Color subColor, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.people_alt_rounded, color: blue, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        "Assigned Guests",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${guests.length} Total",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // List of guests
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: guests.length,
                  itemBuilder: (context, index) {
                    final g = guests[index];
                    final phone = g['phone'];
                    final isPrimary = g['is_primary_contact'] == true;
                    final dept = g['department'];
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
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
                                "${index + 1}",
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
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800, 
                                            fontSize: 16, 
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
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
                  },
                ),
              ),
            ],
          ),
        );
      },
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

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<dynamic> displayedGuests = guests.take(2).toList();

    return Column(
      children: [
        ...displayedGuests.asMap().entries.map((entry) {
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
        }),
        if (guests.length > 2)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _showAllGuestsBottomSheet(guests, cardColor, blue, subColor, isDark),
                icon: Icon(Icons.people_outline_rounded, color: blue, size: 20),
                label: Text(
                  "View All Guests (+${guests.length - 2} more)",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: blue,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: blue.withValues(alpha: 0.4), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: blue.withValues(alpha: 0.02),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDriverCard(Color cardColor, Color blue, Color sub, String dName, String dPhone) {
    final bool isNotAssigned = dName == "no driver assigned" || dName == "Driver Not Assigned";
    final Color nameColor = isNotAssigned ? Colors.redAccent : (cardColor == Colors.white ? Colors.black87 : Colors.white);
    final Color phoneColor = isNotAssigned ? Colors.redAccent.withValues(alpha: 0.7) : sub;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
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
          if (vNumber.isNotEmpty) ...[
            Expanded(
              child: _buildEnhancedSmallInfo(
                  Icons.tag_rounded,
                  vNumber,
                  "PLATE NO",
                  blue,
                  sub,
                ),
            ),
          ] else ...[
            Expanded(
              child: _buildEnhancedSmallInfo(
                  Icons.directions_car_filled_rounded,
                  vType,
                  "VEHICLE",
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
    final travelInfo = _missionData?['travel_info'];
    final tripInstances = _missionData?['trip_instances'] as List?;
    
    // Extract effective driver/vehicle info from _missionData for fallbacks
    final rootDriver = _missionData?['driver'] ?? travelInfo?['driver'];
    final rootVehicle = _missionData?['vehicle'] ?? travelInfo?['vehicle'];
    
    final effectiveDriverName = rootDriver?['name'] ?? widget.driverName;
    final effectiveDriverPhone = rootDriver?['phone'] ?? widget.driverPhone;
    
    final effectiveVehicleInfo = rootVehicle != null 
        ? "${rootVehicle['vehicle_type_name'] ?? 'Vehicle'} (${rootVehicle['vehicle_number']})" 
        : widget.vehicleInfo;
    final effectiveCapacity = rootVehicle != null 
        ? "${rootVehicle['capacity']} Seats" 
        : widget.capacity;

    if (tripInstances == null || tripInstances.isEmpty) {
      return Column(
        children: [
          _buildDriverCard(cardColor, blue, subColor, effectiveDriverName, effectiveDriverPhone),
          const SizedBox(height: 12),
          _buildVehicleDetails(cardColor, blue, subColor, effectiveVehicleInfo, effectiveCapacity),
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
                        ...passengers.take(2).toList().asMap().entries.map((entry) {
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
                        if (passengers.length > 2)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 12),
                            child: SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final bool isDark = Theme.of(context).brightness == Brightness.dark;
                                  _showAllGuestsBottomSheet(passengers, cardColor, blue, subColor, isDark);
                                },
                                icon: Icon(Icons.people_outline_rounded, color: blue, size: 18),
                                label: Text(
                                  "View All Assigned Guests (+${passengers.length - 2} more)",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: blue,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: blue.withValues(alpha: 0.3), width: 1.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  backgroundColor: blue.withValues(alpha: 0.02),
                                ),
                              ),
                            ),
                          ),
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
                           _buildDriverCard(cardColor, blue, subColor, effectiveDriverName, effectiveDriverPhone),
                           const SizedBox(height: 12),
                           _buildVehicleDetails(cardColor, blue, subColor, effectiveVehicleInfo, effectiveCapacity),
                        ],
                      ),
                    );
                 }),
               if (assignmentWidgets.isEmpty && (_missionData?['trip_instances'] == null || (_missionData?['trip_instances'] as List).isEmpty)) ...[
                 _buildDriverCard(cardColor, blue, subColor, effectiveDriverName, effectiveDriverPhone),
                 const SizedBox(height: 12),
                 _buildVehicleDetails(cardColor, blue, subColor, effectiveVehicleInfo, effectiveCapacity),
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
         color: cardColor,
         borderRadius: BorderRadius.circular(24),
         boxShadow: [
           BoxShadow(
             color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05),
             blurRadius: 15,
             offset: const Offset(0, 5),
           ),
         ],
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
             padding: const EdgeInsets.all(20),
             decoration: BoxDecoration(
               color: cardColor,
               borderRadius: BorderRadius.circular(24),
               border: Border.all(color: subColor.withValues(alpha: 0.1)),
               boxShadow: [
                 BoxShadow(
                   color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05),
                   blurRadius: 15,
                   offset: const Offset(0, 5),
                 ),
               ],
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
             padding: const EdgeInsets.all(20),
             decoration: BoxDecoration(
               color: cardColor,
               borderRadius: BorderRadius.circular(24),
               border: Border.all(color: subColor.withValues(alpha: 0.1)),
               boxShadow: [
                 BoxShadow(
                   color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05),
                   blurRadius: 15,
                   offset: const Offset(0, 5),
                 ),
               ],
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: subColor.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
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
          allAllowances.addAll(List<Map<String, dynamic>>.from(allowances));
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

    // Filter allowances for drivers
    if (_userRole?.toLowerCase() == 'driver' && _driverId != null) {
      allAllowances = allAllowances.where((a) => a['driver_id'] == _driverId).toList();
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
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: blue.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
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
                  if (pStatus.toString().toUpperCase() == 'ASSIGNED') ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showMarkReceivedModal(allowance['id']),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                        label: const Text(
                          "MARK AS RECEIVED",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
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

  void _showChangeDriverVehicleModal(Color cardColor, Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    if (_missionData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mission data is still loading...")));
      return;
    }
    
    // Attempt to extract dynamic current driver/vehicle from missionData first, fallback to widget
    String currentDriverName = widget.driverName;
    String currentVehicleName = widget.vehicleInfo;
    
    final tripInstances = _missionData!['trip_instances'] as List?;
    if (tripInstances != null && tripInstances.isNotEmpty) {
      final legs = tripInstances[0]['legs'] as List?;
      if (legs != null && legs.isNotEmpty) {
        final assignments = legs[0]['assignments'] as List?;
        if (assignments != null && assignments.isNotEmpty) {
          final assignment = assignments[0];
          if (assignment['driver'] != null) {
            currentDriverName = assignment['driver']['name'] ?? currentDriverName;
          }
          if (assignment['vehicle'] != null) {
            currentVehicleName = assignment['vehicle']['vehicle_number'] ?? currentVehicleName;
          }
        }
      }
    }

    ChangeDriverVehicleSheet.show(
      context,
      _missionData!,
      currentDriverName,
      currentVehicleName,
      () {
        _fetchMissionDetails();
      }
    );
  }
}

class _OtpFullScreenOverlay extends ConsumerStatefulWidget {
  final String otp;
  final String title;
  final VoidCallback onClose;

  const _OtpFullScreenOverlay({
    required this.otp,
    required this.title,
    required this.onClose,
  });

  @override
  ConsumerState<_OtpFullScreenOverlay> createState() => _OtpFullScreenOverlayState();
}

class _OtpFullScreenOverlayState extends ConsumerState<_OtpFullScreenOverlay> {
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

class _SwipeToConfirm extends ConsumerStatefulWidget {
  final String label;
  final VoidCallback onConfirm;

  const _SwipeToConfirm({required this.label, required this.onConfirm});

  @override
  ConsumerState<_SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends ConsumerState<_SwipeToConfirm> with SingleTickerProviderStateMixin {
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

class _OtpBottomSheet extends ConsumerStatefulWidget {
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
  ConsumerState<_OtpBottomSheet> createState() => _OtpBottomSheetState();
}

class _OtpBottomSheetState extends ConsumerState<_OtpBottomSheet> {
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

class _TopToastWidget extends ConsumerStatefulWidget {
  final String message;
  final Color color;
  final VoidCallback onDismiss;

  const _TopToastWidget({
    required this.message,
    required this.color,
    required this.onDismiss,
  });

  @override
  ConsumerState<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends ConsumerState<_TopToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.color == Colors.green ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
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
}

class _EndButtonWithTimer extends ConsumerStatefulWidget {
  final String endedAtStr;
  final VoidCallback onPressed;
  final bool isAdmin;

  const _EndButtonWithTimer({
    required this.endedAtStr,
    required this.onPressed,
    this.isAdmin = false,
  });

  @override
  ConsumerState<_EndButtonWithTimer> createState() => _EndButtonWithTimerState();
}

class _EndButtonWithTimerState extends ConsumerState<_EndButtonWithTimer> {
  late Timer _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateRemaining();
    });
  }

  void _calculateRemaining() {
    try {
      final endedTime = DateTime.parse(widget.endedAtStr).toUtc();
      final now = DateTime.now().toUtc();
      final diff = now.difference(endedTime);
      final elapsedSeconds = diff.inSeconds;
      final rem = (15 * 60) - elapsedSeconds;
      if (mounted) {
        setState(() {
          _remainingSeconds = rem > 0 ? rem : 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _remainingSeconds = 0;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAdmin && _remainingSeconds <= 0) {
      return const SizedBox.shrink();
    }

    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeFormatted = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    final bool showTimer = _remainingSeconds > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTimer)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Submit End Info in: ",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                    child: Text(
                      timeFormatted,
                      key: ValueKey<String>(timeFormatted),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onPressed,
              icon: const Icon(Icons.info_outline_rounded, size: 20),
              label: const Text(
                "END",
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: const Color(0xFF10B981).withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
