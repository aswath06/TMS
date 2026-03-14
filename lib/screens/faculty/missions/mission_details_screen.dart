import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';

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

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Start loading the route after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMapData();
    });
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
      final isStart = widget.rawStatus == 5 || widget.rawStatus == 6;
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
        _showOtpModal(data['otp'].toString(), isStart ? "Start OTP" : "End OTP");
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
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.9),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
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

    final showAction =
        widget.rawStatus == 5 || widget.rawStatus == 6 || widget.rawStatus == 7;
    final actionLabel = widget.rawStatus == 7 ? "End Activity" : "Start Activity";

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
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
                          _buildDriverCard(cardColor, primaryBlue, subColor),
                          const SizedBox(height: 12),
                          _buildVehicleDetails(cardColor, primaryBlue, subColor),
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

  Widget _buildDriverCard(Color cardColor, Color blue, Color sub) {
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
            backgroundColor: blue.withOpacity(0.1),
            child: Icon(Icons.person_rounded, color: blue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.driverName,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.driverPhone,
                  style: TextStyle(color: sub, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
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

  Widget _buildVehicleDetails(Color cardColor, Color blue, Color sub) {
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
            widget.vehicleInfo.split('(')[0],
            "VEHICLE",
            blue,
            sub,
          ),
          const SizedBox(width: 40),
           _buildEnhancedSmallInfo(
            Icons.groups_rounded,
            widget.capacity,
            "SEATS",
            blue,
            sub,
          ),
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom - 40,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 32),
                      onPressed: _close,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code_2_rounded,
                        color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Driver must scan this code within the time limit",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: widget.otp,
                      version: QrVersions.auto,
                      size: MediaQuery.of(context).size.width * 0.6,
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
                  const SizedBox(height: 40),
                  const Text(
                    "OTP CODE",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.otp,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 12,
                    ),
                  ),
                  const SizedBox(height: 60),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          "Expires in $_secondsLeft seconds",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
