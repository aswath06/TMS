import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// --- DATA MODEL ---
class LocationStopData {
  final int id;
  final TextEditingController controller;
  double? lat;
  double? lon;

  LocationStopData({
    required this.id,
    required this.controller,
    this.lat,
    this.lon,
  });
}

class LocationSelector extends StatefulWidget {
  final Color cardColor;
  final Color titleColor;
  final Color accentColor;
  final Function(
    List<String> addresses,
    double totalDistance,
    double totalDuration,
  )
  onChanged;

  const LocationSelector({
    super.key,
    required this.cardColor,
    required this.titleColor,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  State<LocationSelector> createState() => _LocationSelectorState();
}

class _LocationSelectorState extends State<LocationSelector> {
  final MapController _mapController = MapController();
  final List<LocationStopData> _stops = [
    LocationStopData(id: 0, controller: TextEditingController()),
    LocationStopData(id: 1, controller: TextEditingController()),
  ];

  List<LatLng> _routePoints = [];
  String _totalDistanceText = "0.0 km";
  String _totalDurationText = "0 min";
  bool _isCalculating = false;

  // IDENTIFICATION: Crucial for not getting blocked
  final String _userAgent =
      "TMS_Fleet_Manager_App/1.0 (contact@yourdomain.com)";

  Future<List<Map<String, dynamic>>> _getSuggestions(String query) async {
    if (query.length < 3) return [];

    // Nominatim requires a valid User-Agent and prefers a limit on query rate
    final String url =
        "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=in";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent, 'Accept-Language': 'en'},
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data
            .map(
              (e) => {
                'display_name': e['display_name'].toString(),
                'lat': double.parse(e['lat']),
                'lon': double.parse(e['lon']),
              },
            )
            .toList();
      }
    } catch (e) {
      debugPrint("Search Error: $e");
    }
    return [];
  }

  Future<void> _calculateRoute() async {
    final validStops = _stops
        .where((s) => s.lat != null && s.lon != null)
        .toList();
    if (validStops.length < 2) {
      setState(() => _routePoints = []);
      return;
    }

    setState(() => _isCalculating = true);

    final String coords = validStops.map((s) => "${s.lon},${s.lat}").join(";");
    final String url =
        "https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final double distance = (route['distance'] ?? 0) / 1000.0;
          final double duration = (route['duration'] ?? 0) / 60.0;

          final List geometry = route['geometry']['coordinates'];
          final List<LatLng> points = geometry
              .map((c) => LatLng(c[1], c[0]))
              .toList();

          setState(() {
            _routePoints = points;
            _totalDistanceText = "${distance.toStringAsFixed(1)} km";
            _totalDurationText = duration > 60
                ? "${(duration / 60).toStringAsFixed(1)} hrs"
                : "${duration.toStringAsFixed(0)} mins";
          });

          _fitBounds(validStops);
          widget.onChanged(
            _stops.map((s) => s.controller.text).toList(),
            distance,
            duration,
          );
        }
      }
    } catch (e) {
      debugPrint("Routing Error: $e");
    } finally {
      setState(() => _isCalculating = false);
    }
  }

  void _fitBounds(List<LocationStopData> validStops) {
    if (validStops.isEmpty) return;
    final points = validStops.map((s) => LatLng(s.lat!, s.lon!)).toList();
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _stops.removeAt(oldIndex);
      _stops.insert(newIndex, item);
    });
    _calculateRoute();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- MAP SECTION ---
        Container(
          height: 220,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(20.5937, 78.9629),
                initialZoom: 4,
              ),
              children: [
                TileLayer(
                  // Switch to CartoDB (much more reliable for apps)
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.yourdomain.tmsapp',
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: widget.accentColor,
                        strokeWidth: 5,
                        borderColor: Colors.white,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: _stops
                      .asMap()
                      .entries
                      .where((e) => e.value.lat != null)
                      .map((entry) {
                        int i = entry.key;
                        var stop = entry.value;
                        bool isFirst = i == 0;
                        bool isLast = i == _stops.length - 1;
                        return Marker(
                          point: LatLng(stop.lat!, stop.lon!),
                          width: 40,
                          height: 40,
                          child: Icon(
                            isFirst
                                ? Icons.stars_rounded
                                : (isLast
                                      ? Icons.location_on_rounded
                                      : Icons.circle),
                            color: isFirst
                                ? Colors.green
                                : (isLast ? Colors.red : Colors.grey),
                            size: 30,
                          ),
                        );
                      })
                      .toList(),
                ),
              ],
            ),
          ),
        ),

        // --- STOP LIST ---
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _stops.length,
          onReorder: _onReorder,
          itemBuilder: (context, i) {
            final bool isFirst = i == 0;
            final bool isLast = i == _stops.length - 1;
            return Container(
              key: ValueKey(_stops[i].id),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: widget.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: ListTile(
                leading: ReorderableDragStartListener(
                  index: i,
                  child: Icon(
                    isFirst
                        ? Icons.trip_origin
                        : (isLast ? Icons.location_on : Icons.circle),
                    size: 18,
                    color: isFirst
                        ? Colors.green
                        : (isLast ? Colors.red : Colors.grey),
                  ),
                ),
                title: TypeAheadField<Map<String, dynamic>>(
                  controller: _stops[i].controller,
                  // DEBOUNCE: Prevents blocking by slowing down requests
                  debounceDuration: const Duration(milliseconds: 600),
                  builder: (context, controller, focusNode) => TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: TextStyle(
                      color: widget.titleColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: isFirst
                          ? "Start Location"
                          : (isLast ? "Destination" : "Stop ${i}"),
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  suggestionsCallback: _getSuggestions,
                  itemBuilder: (context, suggestion) => ListTile(
                    dense: true,
                    title: Text(
                      suggestion['display_name'],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  onSelected: (suggestion) {
                    setState(() {
                      _stops[i].controller.text = suggestion['display_name'];
                      _stops[i].lat = suggestion['lat'];
                      _stops[i].lon = suggestion['lon'];
                    });
                    _calculateRoute();
                  },
                ),
                trailing: _stops.length > 2
                    ? IconButton(
                        icon: const Icon(
                          Icons.do_disturb_on_outlined,
                          size: 20,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => setState(() {
                          _stops.removeAt(i);
                          _calculateRoute();
                        }),
                      )
                    : null,
              ),
            );
          },
        ),

        // --- ADD STOP BUTTON ---
        TextButton.icon(
          onPressed: () => setState(
            () => _stops.insert(
              _stops.length - 1,
              LocationStopData(
                id: DateTime.now().millisecondsSinceEpoch,
                controller: TextEditingController(),
              ),
            ),
          ),
          icon: const Icon(Icons.add_location_alt_rounded, size: 20),
          label: const Text("Add intermediate stop"),
          style: TextButton.styleFrom(foregroundColor: widget.accentColor),
        ),

        // --- SUMMARY ---
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              _infoCell(
                Icons.directions_car_filled_rounded,
                "DISTANCE",
                _totalDistanceText,
              ),
              _infoCell(
                Icons.access_time_filled_rounded,
                "EST. TIME",
                _totalDurationText,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoCell(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: widget.accentColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: widget.titleColor,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
