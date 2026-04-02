import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
// SHARED PREFS KEY
// ─────────────────────────────────────────────
const _kFrequentKey = 'frequent_locations';
const _kMaxFrequent = 10;

// ─────────────────────────────────────────────
// LOCATION SELECTOR (parent widget)
// ─────────────────────────────────────────────
class LocationSelector extends StatefulWidget {
  final Color cardColor;
  final Color titleColor;
  final Color accentColor;
  final Function(List<String> addresses, double totalDistance, double totalDuration) onChanged;

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
          final double dur = (route['duration'] ?? 0) / 60.0;
          final List geo = route['geometry']['coordinates'];
          final pts = geo.map((c) => LatLng(c[1], c[0])).toList();

          if (!mounted) return;
          setState(() {
            _routePoints = pts;
            _totalDistanceText = '${dist.toStringAsFixed(1)} km';
            _totalDurationText =
                dur > 60 ? '${(dur / 60).toStringAsFixed(1)} hrs' : '${dur.toStringAsFixed(0)} mins';
          });
          _fitBounds(valid);
          widget.onChanged(_stops.map((s) => s.controller.text).toList(), dist, dur);
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
      builder: (_) => _LocationPickerSheet(
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
              _infoCell(Icons.directions_car_filled_rounded, 'DISTANCE', _totalDistanceText),
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
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: widget.titleColor, fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCATION PICKER BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _LocationPickerSheet extends StatefulWidget {
  final String label;
  final Color accentColor;
  final Color cardColor;
  final Color titleColor;
  final String userAgent;

  const _LocationPickerSheet({
    required this.label,
    required this.accentColor,
    required this.cardColor,
    required this.titleColor,
    required this.userAgent,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _frequent = [];
  bool _isLoading = false;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _loadFrequent();
    // Auto-focus after sheet animation
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── SharedPreferences: frequent locations ─────────────────
  Future<void> _loadFrequent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kFrequentKey) ?? [];
    setState(() {
      _frequent = raw.map((e) => json.decode(e) as Map<String, dynamic>).toList();
    });
  }

  Future<void> _saveFrequent(Map<String, dynamic> loc) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kFrequentKey) ?? [];

    // Remove duplicate if it already exists
    final updated = raw.where((e) {
      final decoded = json.decode(e) as Map<String, dynamic>;
      return decoded['display_name'] != loc['display_name'];
    }).toList();

    // Insert at front (most recent first)
    updated.insert(0, json.encode(loc));

    // Keep only top N
    if (updated.length > _kMaxFrequent) updated.removeRange(_kMaxFrequent, updated.length);

    await prefs.setStringList(_kFrequentKey, updated);
  }

  // ── Nominatim search ──────────────────────────────────────
  Future<void> _search(String query) async {
    if (query.trim().length < 3) {
      setState(() { _results = []; _searched = false; });
      return;
    }
    if (!mounted) return;
    setState(() { _isLoading = true; _searched = true; });

    final url =
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=8&countrycodes=in';

    try {
      final res = await http.get(Uri.parse(url), headers: {'User-Agent': widget.userAgent, 'Accept-Language': 'en'});
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (!mounted) return;
        setState(() {
          _results = data
              .map((e) => {
                    'display_name': e['display_name'].toString(),
                    'lat': double.parse(e['lat'].toString()),
                    'lon': double.parse(e['lon'].toString()),
                  })
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Location search error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _pick(Map<String, dynamic> location) {
    _saveFrequent(location);
    Navigator.pop(context, location);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final divColor = isDark ? Colors.white10 : Colors.black.withOpacity(0.06);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 30, offset: const Offset(0, -4))],
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),

              // ── Header row ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.label == 'Start Location' ? Icons.trip_origin : Icons.location_on_rounded,
                        color: widget.accentColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: widget.accentColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Search bar ───────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.07) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: widget.accentColor.withOpacity(0.25), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Icon(Icons.search_rounded, color: widget.accentColor.withOpacity(0.7), size: 22),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _focusNode,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search location…',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontWeight: FontWeight.normal,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          onChanged: (v) => _search(v),
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() { _results = []; _searched = false; });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade400),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              Divider(height: 24, indent: 16, endIndent: 16, color: divColor),

              // ── Results / Frequent list ───────────────────
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: widget.accentColor, strokeWidth: 2.5))
                    : _buildResultList(isDark, scrollCtrl),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultList(bool isDark, ScrollController ctrl) {
    // Show search results
    if (_searched && _results.isNotEmpty) {
      return ListView.separated(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _results.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        itemBuilder: (_, i) => _resultTile(_results[i], isDark, isFrequent: false),
      );
    }

    // No results from search
    if (_searched && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No locations found', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Try a different search term', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      );
    }

    // Frequent locations (default view)
    if (_frequent.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No recent locations', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Search above to find a location', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(Icons.history_rounded, size: 15, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(
                'Frequent Locations',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        ...List.generate(
          _frequent.length,
          (i) => Column(
            children: [
              _resultTile(_frequent[i], isDark, isFrequent: true),
              if (i < _frequent.length - 1)
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _resultTile(Map<String, dynamic> loc, bool isDark, {required bool isFrequent}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pick(loc),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isFrequent
                    ? Colors.orange.withOpacity(0.1)
                    : widget.accentColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isFrequent ? Icons.history_rounded : Icons.location_on_rounded,
                color: isFrequent ? Colors.orange : widget.accentColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                loc['display_name'] ?? '',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
