import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:tripzo/store/istamil.dart'; // Ensure this path is correct

class DriverRoutesScreen extends StatefulWidget {
  const DriverRoutesScreen({super.key});

  @override
  State<DriverRoutesScreen> createState() => _DriverRoutesScreenState();
}

class _DriverRoutesScreenState extends State<DriverRoutesScreen> {
  final MapController _mapController = MapController();

  // Route: Erode -> Tiruppur -> Coimbatore
  final List<LatLng> _points = [
    const LatLng(11.3410, 77.7172), // Erode
    const LatLng(11.1085, 77.3411), // Tiruppur
    const LatLng(11.0168, 76.9558), // Coimbatore
  ];

  void _showFullScreenMap(
    BuildContext context,
    Color primary,
    bool isDark,
    bool isTamil,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            title: Text(
              isTamil ? "பயண வரைபடம்" : "Route Map",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: _buildMapStack(primary, isDark, isTamil, isFullScreen: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTamil = LanguageStore.isTamil;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background Decoration
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryBlue.withOpacity(isDark ? 0.1 : 0.05),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildHeader(
                      isTamil ? "பயண விவரங்கள்" : "Trip Details",
                      titleColor,
                      screenWidth,
                      isTamil,
                    ),
                    const SizedBox(height: 24),
                    _buildVehicleInfo(
                      surfaceColor,
                      isDark,
                      primaryBlue,
                      isTamil,
                    ),
                    const SizedBox(height: 32),

                    _buildSectionTitle(
                      isTamil ? "பயண பாதை" : "Journey Roadmap",
                      titleColor,
                    ),
                    const SizedBox(height: 18),
                    _buildTimelineCard(
                      surfaceColor,
                      isDark,
                      primaryBlue,
                      isTamil,
                    ),

                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      isTamil ? "நேரடி வரைபடம்" : "Live Route Map",
                      titleColor,
                    ),
                    const SizedBox(height: 18),
                    _buildMapContainer(primaryBlue, isDark, isTamil),

                    const SizedBox(height: 32),
                    // --- PASSENGER SECTION ---
                    _buildSectionTitle(
                      isTamil ? "பயணிகள் பட்டியல்" : "Passenger List",
                      titleColor,
                    ),
                    const SizedBox(height: 18),
                    _buildPassengerCard(
                      isTamil ? "செந்தில் குமார்" : "Senthil Kumar",
                      "+91 98765 43210",
                      surfaceColor,
                      isDark,
                      primaryBlue,
                    ),
                    const SizedBox(height: 12),
                    _buildPassengerCard(
                      isTamil ? "அனிதா ராஜ்" : "Anitha Raj",
                      "+91 88776 65544",
                      surfaceColor,
                      isDark,
                      primaryBlue,
                    ),

                    const SizedBox(height: 32),
                    _buildAdminContact(
                      surfaceColor,
                      isDark,
                      primaryBlue,
                      isTamil,
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerCard(
    String name,
    String phone,
    Color surface,
    bool isDark,
    Color primary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primary.withOpacity(0.1),
            child: Icon(Icons.person_outline_rounded, color: primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                Text(
                  phone,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.call_outlined, color: primary),
            style: IconButton.styleFrom(
              backgroundColor: primary.withOpacity(0.05),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapContainer(Color primary, bool isDark, bool isTamil) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: _buildMapStack(primary, isDark, isTamil),
      ),
    );
  }

  Widget _buildMapStack(
    Color primary,
    bool isDark,
    bool isTamil, {
    bool isFullScreen = false,
  }) {
    return Stack(
      children: [
        FlutterMap(
          mapController: isFullScreen ? MapController() : _mapController,
          options: MapOptions(
            initialCenter: _points[1],
            initialZoom: isFullScreen ? 9 : 10,
          ),
          children: [
            TileLayer(
              urlTemplate: isDark
                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                  : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _points,
                  color: primary,
                  strokeWidth: 5,
                  borderColor: Colors.white,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                _buildMapMarker(
                  _points[0],
                  Colors.green,
                  isTamil ? "ஈரோடு" : "Erode",
                ),
                _buildMapMarker(
                  _points[1],
                  Colors.orange,
                  isTamil ? "திருப்பூர்" : "Tiruppur",
                ),
                _buildMapMarker(
                  _points[2],
                  Colors.red,
                  isTamil ? "கோயம்புத்தூர்" : "Coimbatore",
                ),
              ],
            ),
          ],
        ),
        if (!isFullScreen)
          Positioned(
            bottom: 16,
            right: 16,
            child: GestureDetector(
              onTap: () =>
                  _showFullScreenMap(context, primary, isDark, isTamil),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fullscreen_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Marker _buildMapMarker(LatLng point, Color color, String label) {
    return Marker(
      point: point,
      width: 100,
      height: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Icon(Icons.location_on_rounded, color: color, size: 30),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(
    Color surfaceColor,
    bool isDark,
    Color primaryBlue,
    bool isTamil,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
        ),
      ),
      child: Column(
        children: [
          _buildTimelineItem(
            isTamil ? "ஈரோடு மையம்" : "Erode Central",
            isTamil ? "தொடக்க இடம் • 08:00 AM" : "Start Location • 08:00 AM",
            Icons.trip_origin_rounded,
            Colors.green,
            false,
          ),
          _buildTimelineItem(
            isTamil ? "திருப்பூர் மையம்" : "Tiruppur Hub",
            isTamil
                ? "இடைநிறுத்தம் • 09:15 AM"
                : "Intermediate Stop • 09:15 AM",
            Icons.location_on_rounded,
            Colors.orangeAccent,
            false,
          ),
          _buildTimelineItem(
            isTamil ? "கோவை முனையம்" : "Coimbatore Terminal",
            isTamil ? "சேருமிடம் • 10:30 AM" : "Destination • 10:30 AM",
            Icons.flag_circle_rounded,
            Colors.redAccent,
            true,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    String title,
    Color titleColor,
    double width,
    bool isTamil,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: width * 0.075,
            fontWeight: FontWeight.w900,
            color: titleColor,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isTamil ? "பயண எண்: MSN-8821" : "Mission ID: MSN-8821",
          style: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleInfo(
    Color surface,
    bool isDark,
    Color primary,
    bool isTamil,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_bus_filled_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isTamil ? "ஒதுக்கப்பட்ட வாகனம்" : "Assigned Vehicle",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Text(
                isTamil
                    ? "மெர்சிடிஸ் ஸ்பிரிண்டர் (Tn3-04)"
                    : "Mercedes Sprinter (Tn3-04)",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool isLast,
  ) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
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
                        colors: [color, color.withOpacity(0.1)],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminContact(
    Color surface,
    bool isDark,
    Color primary,
    bool isTamil,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isTamil ? "நிர்வாக ஆதரவு" : "Dispatch Support",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              Text(
                isTamil ? "நிர்வாக அலுவலகம்" : "Admin Office",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          IconButton.filled(
            onPressed: () {},
            style: IconButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.phone_in_talk_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: -0.8,
      ),
    );
  }
}
