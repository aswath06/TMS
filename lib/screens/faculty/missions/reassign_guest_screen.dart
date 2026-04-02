import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';

class ReassignGuestScreen extends StatefulWidget {
  final List<dynamic> initialSchedules;
  final String routeId;
  final String defaultRemark;

  const ReassignGuestScreen({
    super.key,
    required this.initialSchedules,
    required this.routeId,
    required this.defaultRemark,
  });

  @override
  State<ReassignGuestScreen> createState() => _ReassignGuestScreenState();
}

class _ReassignGuestScreenState extends State<ReassignGuestScreen> {
  late List<Map<String, dynamic>> _vehicles;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    _vehicles = widget.initialSchedules.map((assignment) {
      final vehicle = assignment['vehicle'];
      final passengers = List<Map<String, dynamic>>.from(assignment['passengers'] ?? []);
      return {
        "vehicle_id": vehicle != null ? vehicle['id'] : null,
        "vehicle_info": vehicle != null ? "${vehicle['vehicle_type_name'] ?? 'Vehicle'} (${vehicle['vehicle_number']})" : "Unknown Vehicle",
        "guests": passengers,
      };
    }).where((v) => v['vehicle_id'] != null).toList();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final token = await UserStore.getToken();
      List<Map<String, dynamic>> allocations = _vehicles.map((v) {
        return {
          "vehicle_id": v['vehicle_id'],
          "guest_ids": (v['guests'] as List).map((p) => p['passenger_id'] ?? p['id']).toList(),
        };
      }).toList();

      final body = {
        "route_id": int.tryParse(widget.routeId) ?? 0,
        "faculty_remarks": widget.defaultRemark.isEmpty ? "Reassigned via Mobile App" : widget.defaultRemark,
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
          const SnackBar(content: Text("Guests Reassigned Successfully"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(respData['message'] ?? "Failed to reassign"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Reassign Guests", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                "Drag and drop guests between vehicles to reassign them.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: _vehicles.isEmpty 
                  ? const Center(child: Text("No valid vehicles to manage."))
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _vehicles.length,
                      itemBuilder: (context, vIndex) {
                        final vehicle = _vehicles[vIndex];
                        return _buildDragTargetZone(vehicle, vIndex, isDark, primaryBlue);
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("CONFIRM REASSIGNMENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragTargetZone(Map<String, dynamic> vehicle, int vIndex, bool isDark, Color primaryBlue) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final guests = vehicle['guests'] as List<Map<String, dynamic>>;

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) {
        final draggedGuest = details.data;
        // Accept if they are not already in this vehicle
        return !guests.any((g) => g['id'] == draggedGuest['id']);
      },
      onAcceptWithDetails: (details) {
        final draggedGuest = details.data;
        setState(() {
          // Add to new vehicle
          guests.add(draggedGuest);
          // Remove from old vehicle
          for (int i = 0; i < _vehicles.length; i++) {
            if (i != vIndex) {
              _vehicles[i]['guests'].removeWhere((g) => g['id'] == draggedGuest['id']);
            }
          }
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: isHovering ? primaryBlue.withOpacity(0.05) : cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isHovering ? primaryBlue : Colors.transparent, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions_car_rounded, color: primaryBlue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vehicle['vehicle_info'],
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        "${guests.length} Guests",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.white),
                      ),
                    )
                  ],
                ),
              ),
              if (guests.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text("Drop guests here", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: guests.map((guest) {
                      return Draggable<Map<String, dynamic>>(
                        data: guest,
                        feedback: Material(
                          color: Colors.transparent,
                          child: _buildGuestPill(guest, primaryBlue, true),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _buildGuestPill(guest, Colors.grey, false),
                        ),
                        child: _buildGuestPill(guest, primaryBlue, false),
                      );
                    }).toList(),
                  ),
                )
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuestPill(Map<String, dynamic> guest, Color color, bool isDragging) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDragging ? color.withOpacity(0.8) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: isDragging ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)] : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.drag_indicator_rounded, size: 14, color: isDragging ? Colors.white : color),
          const SizedBox(width: 6),
          Text(
            guest['passenger_name'] ?? guest['name'] ?? "Unknown",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDragging ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}
