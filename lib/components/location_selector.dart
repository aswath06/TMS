import 'package:flutter/material.dart';

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

  void _notify() =>
      widget.onChanged(_stops.map((s) => s.controller.text).toList());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _stops.length,
          onReorder: (oldIdx, newIdx) {
            setState(() {
              if (newIdx > oldIdx) newIdx -= 1;
              _stops.insert(newIdx, _stops.removeAt(oldIdx));
            });
            _notify();
          },
          itemBuilder: (context, i) {
            bool isFirst = i == 0;
            bool isLast = i == _stops.length - 1;
            return Container(
              key: ValueKey(_stops[i].id),
              margin: const EdgeInsets.only(bottom: 8),
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
                title: TextField(
                  controller: _stops[i].controller,
                  onChanged: (_) => _notify(),
                  style: TextStyle(
                    color: widget.titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: isFirst
                        ? "Pickup"
                        : (isLast ? "Drop" : "Stop $i"),
                    border: InputBorder.none,
                  ),
                ),
                trailing: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_indicator, color: Colors.grey),
                ),
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
