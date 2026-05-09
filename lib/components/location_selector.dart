import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:tripzo/components/location_picker_sheet.dart';
import 'package:tripzo/utils/api_constants.dart';

// ─────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
// LOCATION SELECTOR (parent widget)
// ─────────────────────────────────────────────
class LocationSelector extends StatefulWidget {
  final Color cardColor;
  final Color titleColor;
  final Color accentColor;
  final Function(List<Map<String, dynamic>> stops, double totalDistance, double totalDuration) onChanged;

  final List<String>? initialAddresses;

  const LocationSelector({
    super.key,
    required this.cardColor,
    required this.titleColor,
    required this.accentColor,
    required this.onChanged,
    this.initialAddresses,
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
  String _totalDistanceText = '0.0 km';
  String _totalDurationText = '0 min';
  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddresses != null && widget.initialAddresses!.isNotEmpty) {
      _stops.clear();
      for (int i = 0; i < widget.initialAddresses!.length; i++) {
        _stops.add(LocationStopData(
          id: i,
          controller: TextEditingController(text: widget.initialAddresses![i]),
        ));
      }
    }
  }

  final String _userAgent = 'TMS_Fleet_Manager_App/1.0 (contact@yourdomain.com)';

  // ── Route Calculation ──────────────────────────────────────
  Future<void> _calculateRoute() async {
    final valid = _stops.where((s) => s.lat != null && s.lon != null).toList();
    if (valid.length < 2) {
      setState(() => _routePoints = []);
      return;
    }
    setState(() => _isCalculating = true);

    final coords = valid.map((s) => '${s.lon},${s.lat}').join(';');
    final url =
        'https://router.project-osrm.org/route/v1/driving/$coords?overview=full&geometries=geojson';

    try {
      final res = await http.get(Uri.parse(url), headers: {'User-Agent': _userAgent});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final double dist = (route['distance'] ?? 0) / 1000.0;
          // Calculate duration based on average speed of 40 km/h (requested by user)
          final double dur = (dist / 40.0) * 60.0; 
          
          final List geo = route['geometry']['coordinates'];
          final pts = geo.map((c) => LatLng(c[1], c[0])).toList();

          if (!mounted) return;
          setState(() {
            _routePoints = pts;
            _totalDistanceText = '${dist.toStringAsFixed(1)} km';
            // Formatting the duration text
            if (dur >= 60) {
              int hrs = dur ~/ 60;
              int mins = (dur % 60).toInt();
              _totalDurationText = mins > 0 ? '${hrs}h ${mins}m' : '${hrs}h';
            } else {
              _totalDurationText = '${dur.toStringAsFixed(0)} mins';
            }
          });
          _fitBounds(valid);
          final stopData = _stops.map((s) => {
            'address': s.controller.text,
            'lat': s.lat,
            'lon': s.lon,
          }).toList();
          widget.onChanged(stopData, dist, dur);
        }
      }
    } catch (e) {
      debugPrint('Routing Error: $e');
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  void _fitBounds(List<LocationStopData> valid) {
    if (valid.isEmpty) return;
    final pts = valid.map((s) => LatLng(s.lat!, s.lon!)).toList();
    final bounds = LatLngBounds.fromPoints(pts);
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _stops.removeAt(oldIndex);
      _stops.insert(newIndex, item);
    });
    _calculateRoute();
  }

  // ── Open Bottom Sheet Picker ───────────────────────────────
  Future<void> _openLocationPicker(int stopIndex) async {
    final bool isFirst = stopIndex == 0;
    final bool isLast = stopIndex == _stops.length - 1;
    String label = isFirst ? 'Start Location' : (isLast ? 'Destination' : 'Stop $stopIndex');

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPickerSheet(
        label: label,
        accentColor: widget.accentColor,
        cardColor: widget.cardColor,
        titleColor: widget.titleColor,
        userAgent: _userAgent,
      ),
    );

    if (result != null) {
      setState(() {
        _stops[stopIndex].controller.text = result['display_name'];
        _stops[stopIndex].lat = result['lat'];
        _stops[stopIndex].lon = result['lon'];
      });
      _calculateRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // ── MAP ─────────────────────────────────────────────
        Container(
          height: 220,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(initialCenter: LatLng(20.5937, 78.9629), initialZoom: 4),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.yourdomain.tmsapp',
                    ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: _routePoints,
                          color: widget.accentColor,
                          strokeWidth: 5,
                          borderColor: Colors.white,
                          borderStrokeWidth: 2,
                        )
                      ]),
                    MarkerLayer(
                      markers: _stops.asMap().entries.where((e) => e.value.lat != null).map((entry) {
                        int i = entry.key;
                        var stop = entry.value;
                        bool isFirst = i == 0;
                        bool isLast = i == _stops.length - 1;
                        return Marker(
                          point: LatLng(stop.lat!, stop.lon!),
                          width: 40,
                          height: 40,
                          child: Icon(
                            isFirst ? Icons.stars_rounded : (isLast ? Icons.location_on_rounded : Icons.circle),
                            color: isFirst ? Colors.green : (isLast ? Colors.red : Colors.grey),
                            size: 30,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                if (_isCalculating)
                  Container(
                    color: Colors.black26,
                    child: Center(
                      child: CircularProgressIndicator(color: widget.accentColor, strokeWidth: 2.5),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── STOP LIST ────────────────────────────────────────
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _stops.length,
          onReorder: _onReorder,
          itemBuilder: (context, i) {
            final bool isFirst = i == 0;
            final bool isLast = i == _stops.length - 1;
            final String hint = isFirst ? 'Start Location' : (isLast ? 'Destination' : 'Stop $i');
            final bool hasValue = _stops[i].controller.text.isNotEmpty;

            return Container(
              key: ValueKey(_stops[i].id),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: widget.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasValue ? widget.accentColor.withOpacity(0.35) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: ReorderableDragStartListener(
                  index: i,
                  child: Icon(
                    isFirst ? Icons.trip_origin : (isLast ? Icons.location_on : Icons.circle),
                    size: 18,
                    color: isFirst ? Colors.green : (isLast ? Colors.red : Colors.grey),
                  ),
                ),
                title: GestureDetector(
                  onTap: () => _openLocationPicker(i),
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: hasValue
                        ? Text(
                            _stops[i].controller.text,
                            style: TextStyle(
                              color: widget.titleColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : Text(
                            hint,
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasValue)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _stops[i].controller.clear();
                            _stops[i].lat = null;
                            _stops[i].lon = null;
                          });
                          _calculateRoute();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, size: 16, color: Colors.grey.shade400),
                        ),
                      ),
                    if (_stops.length > 2)
                      IconButton(
                        icon: const Icon(Icons.do_disturb_on_outlined, size: 20, color: Colors.redAccent),
                        onPressed: () => setState(() {
                          _stops.removeAt(i);
                          _calculateRoute();
                        }),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        // ── ADD STOP ─────────────────────────────────────────
        TextButton.icon(
          onPressed: () => setState(() => _stops.insert(
                _stops.length - 1,
                LocationStopData(id: DateTime.now().millisecondsSinceEpoch, controller: TextEditingController()),
              )),
          icon: const Icon(Icons.add_location_alt_rounded, size: 20),
          label: const Text('Add intermediate stop'),
          style: TextButton.styleFrom(foregroundColor: widget.accentColor),
        ),

        // ── SUMMARY ──────────────────────────────────────────
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              _infoCell(Icons.directions_car_filled_rounded, 'APPROX DISTANCE', _totalDistanceText),
              _infoCell(Icons.access_time_filled_rounded, 'EST. TIME', _totalDurationText),
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
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: widget.titleColor, fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }
}
