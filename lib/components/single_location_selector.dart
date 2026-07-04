import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:tripzo/components/location_picker_sheet.dart';

class SingleLocationSelector extends StatefulWidget {
  final String label;
  final String? initialAddress;
  final double? initialLat;
  final double? initialLon;
  final Color cardColor;
  final Color titleColor;
  final Color accentColor;
  final Function(Map<String, dynamic> location) onChanged;

  const SingleLocationSelector({
    super.key,
    required this.label,
    this.initialAddress,
    this.initialLat,
    this.initialLon,
    required this.cardColor,
    required this.titleColor,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  State<SingleLocationSelector> createState() => _SingleLocationSelectorState();
}

class _SingleLocationSelectorState extends State<SingleLocationSelector> {
  final MapController _mapController = MapController();
  String? _address;
  double? _lat;
  double? _lon;

  @override
  void initState() {
    super.initState();
    _address = widget.initialAddress;
    _lat = widget.initialLat;
    _lon = widget.initialLon;
  }

  final String _userAgent = 'TMS_Fleet_Manager_App/1.0 (contact@yourdomain.com)';

  Future<void> _openLocationPicker() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPickerSheet(
        label: widget.label,
        accentColor: widget.accentColor,
        cardColor: widget.cardColor,
        titleColor: widget.titleColor,
        userAgent: _userAgent,
      ),
    );

    if (result != null) {
      setState(() {
        _address = result['display_name'];
        _lat = result['lat'];
        _lon = result['lon'];
      });
      _mapController.move(LatLng(_lat!, _lon!), 15);
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasValue = _address != null && _address!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── MAP PREVIEW ─────────────────────────────────────
        Container(
          height: 180,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _lat != null && _lon != null 
                        ? LatLng(_lat!, _lon!) 
                        : const LatLng(20.5937, 78.9629),
                    initialZoom: _lat != null ? 15 : 4,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.yourdomain.tmsapp',
                    ),
                    if (_lat != null && _lon != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(_lat!, _lon!),
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.location_on_rounded,
                              color: widget.accentColor,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // Overlay for tap-to-picker
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openLocationPicker,
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.bottomRight,
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                        ),
                        child: Icon(Icons.fullscreen_rounded, color: widget.accentColor, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── ADDRESS CARD ─────────────────────────────────────
        InkWell(
          onTap: _openLocationPicker,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasValue ? widget.accentColor.withValues(alpha: 0.3) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.location_on_rounded, color: widget.accentColor, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasValue ? _address! : 'Select Location',
                        style: TextStyle(
                          color: hasValue ? widget.titleColor : (isDark ? Colors.white38 : Colors.black38),
                          fontSize: 14,
                          fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
