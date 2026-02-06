import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_typeahead/flutter_typeahead.dart';

class LocationStopData {
  final int id;
  final TextEditingController controller;
  LocationStopData({required this.id, required this.controller});
}

class LocationSelector extends StatefulWidget {
  final Color cardColor;
  final Color titleColor;
  final Color accentColor;
  final Function(List<String>) onChanged;

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
  final List<LocationStopData> _stops = [
    LocationStopData(id: 0, controller: TextEditingController()),
    LocationStopData(id: 1, controller: TextEditingController()),
  ];

  @override
  void dispose() {
    for (var stop in _stops) stop.controller.dispose();
    super.dispose();
  }

  // Free OpenStreetMap Search Logic
  Future<List<String>> _getSuggestions(String query) async {
    if (query.length < 3) return [];

    // Filtered for Tamil Nadu, India
    final String url =
        "https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&countrycodes=in&viewbox=76.2,13.5,80.3,8.1&bounded=1";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'TMS_Flutter_App', // Required for OSM usage
        },
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((e) => e['display_name'].toString()).toList();
      }
    } catch (e) {
      debugPrint("OSM Error: $e");
    }
    return [];
  }

  void _notify() =>
      widget.onChanged(_stops.map((s) => s.controller.text).toList());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _stops.length,
          itemBuilder: (context, i) {
            bool isFirst = i == 0;
            bool isLast = i == _stops.length - 1;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: widget.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Icon(
                  isFirst
                      ? Icons.trip_origin
                      : (isLast ? Icons.location_on : Icons.circle),
                  size: 18,
                  color: isFirst
                      ? Colors.green
                      : (isLast ? Colors.red : Colors.grey),
                ),
                title: TypeAheadField<String>(
                  // v5.0+ requires this controller setup
                  controller: _stops[i].controller,
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (_) => _notify(),
                      style: TextStyle(
                        color: widget.titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: isFirst
                            ? "Pickup Location"
                            : (isLast ? "Drop Location" : "Stop $i"),
                        border: InputBorder.none,
                        hintStyle: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                  suggestionsCallback: (search) => _getSuggestions(search),
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined, size: 16),
                      title: Text(
                        suggestion,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                  onSelected: (suggestion) {
                    _stops[i].controller.text = suggestion;
                    _notify();
                  },
                ),
                trailing: _stops.length > 2
                    ? IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() => _stops.removeAt(i));
                          _notify();
                        },
                      )
                    : null,
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(
                () => _stops.insert(
                  _stops.length - 1,
                  LocationStopData(
                    id: DateTime.now().millisecondsSinceEpoch,
                    controller: TextEditingController(),
                  ),
                ),
              );
              _notify();
            },
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text("Add Stop"),
            style: TextButton.styleFrom(foregroundColor: widget.accentColor),
          ),
        ),
      ],
    );
  }
}
