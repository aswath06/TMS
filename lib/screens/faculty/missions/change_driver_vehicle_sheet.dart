import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';

class ChangeDriverVehicleSheet extends StatefulWidget {
  final Map<String, dynamic> missionData;
  final String currentDriverName;
  final String currentVehicleName;
  final VoidCallback onSuccess;

  const ChangeDriverVehicleSheet({
    super.key,
    required this.missionData,
    required this.currentDriverName,
    required this.currentVehicleName,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> missionData,
    String currentDriverName,
    String currentVehicleName,
    VoidCallback onSuccess,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ChangeDriverVehicleSheet(
          missionData: missionData,
          currentDriverName: currentDriverName,
          currentVehicleName: currentVehicleName,
          onSuccess: onSuccess,
        ),
      ),
    );
  }

  @override
  State<ChangeDriverVehicleSheet> createState() => _ChangeDriverVehicleSheetState();
}

class _ChangeDriverVehicleSheetState extends State<ChangeDriverVehicleSheet> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<dynamic> _vehicles = [];
  List<dynamic> _drivers = [];
  
  int? _selectedVehicleId;
  int? _selectedDriverId;
  String _changeMode = 'BOTH';
  final TextEditingController _remarkController = TextEditingController();
  int _guestCount = 0;

  @override
  void initState() {
    super.initState();
    _calculateGuestCount();
    _fetchAvailableResources();
  }

  void _calculateGuestCount() {
    final tripInstances = widget.missionData['trip_instances'] as List?;
    if (tripInstances != null && tripInstances.isNotEmpty) {
      final trip = tripInstances[0];
      final legs = trip['legs'] as List?;
      if (legs != null && legs.isNotEmpty) {
        final assignments = legs[0]['assignments'] as List?;
        if (assignments != null && assignments.isNotEmpty) {
          final passengers = assignments[0]['passengers'] as List? ?? [];
          _guestCount = passengers.length;
          return;
        }
      }
    }
    final passengers = widget.missionData['passengers'] as List? ?? [];
    _guestCount = passengers.length;
  }

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _fetchAvailableResources() async {
    setState(() => _isLoading = true);
    try {
      final token = await UserStore.getToken();
      final startDate = widget.missionData['start_date'];
      final endDate = widget.missionData['end_date'];
      
      final String startStr = startDate != null 
          ? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(startDate).toLocal()) 
          : DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final String endStr = endDate != null 
          ? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(endDate).toLocal()) 
          : DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now().add(const Duration(hours: 4)));
      
      final String startEncoded = Uri.encodeComponent(startStr);
      final String endEncoded = Uri.encodeComponent(endStr);
      final queryParams = "?start_datetime=$startEncoded&end_datetime=$endEncoded&include_route_suggestions=true&time_flex_hours=5";

      final headers = ApiConstants.getHeaders(token);

      final vehicleRes = await http.get(Uri.parse(ApiConstants.getAvailableVehicles + queryParams), headers: headers);
      final driverRes = await http.get(Uri.parse(ApiConstants.getAvailableDrivers + queryParams), headers: headers);

      if (vehicleRes.statusCode == 200 && driverRes.statusCode == 200) {
        final vData = jsonDecode(vehicleRes.body);
        final dData = jsonDecode(driverRes.body);
        
        final allVehicles = vData['data']?['vehicles'] as List? ?? [];
        final allDrivers = dData['data']?['drivers'] as List? ?? [];

        allVehicles.sort((a, b) {
          final aCap = int.tryParse(a['capacity']?.toString() ?? '0') ?? 0;
          final bCap = int.tryParse(b['capacity']?.toString() ?? '0') ?? 0;

          final aIdeal = aCap >= _guestCount;
          final bIdeal = bCap >= _guestCount;

          if (aIdeal && !bIdeal) return -1;
          if (!aIdeal && bIdeal) return 1;

          final aDiff = (aCap - _guestCount).abs();
          final bDiff = (bCap - _guestCount).abs();

          return aDiff.compareTo(bDiff);
        });

        setState(() {
          _vehicles = allVehicles;
          _drivers = allDrivers.where((d) => d['available'] == true).toList();
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to fetch available resources")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSubmit() async {
    if ((_changeMode != 'DRIVER_ONLY' && _selectedVehicleId == null) || 
        (_changeMode != 'VEHICLE_ONLY' && _selectedDriverId == null) || 
        _remarkController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please make necessary selections and enter a remark")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final token = await UserStore.getToken();
      
      // Extract trip assignment ID
      int? assignmentId;
      final tripInstances = widget.missionData['trip_instances'] as List?;
      if (tripInstances != null && tripInstances.isNotEmpty) {
        final trip = tripInstances[0];
        final legs = trip['legs'] as List?;
        if (legs != null && legs.isNotEmpty) {
          final assignments = legs[0]['assignments'] as List?;
          if (assignments != null && assignments.isNotEmpty) {
            assignmentId = assignments[0]['id'];
          }
        }
      }

      if (assignmentId == null) {
        throw Exception("Could not find trip assignment ID.");
      }

      final url = ApiConstants.updateVehicleDriver(assignmentId);
      final Map<String, dynamic> body = {
        "reason": _remarkController.text.trim(),
      };
      if (_changeMode != 'DRIVER_ONLY') {
        body["vehicle_id"] = _selectedVehicleId;
      }
      if (_changeMode != 'VEHICLE_ONLY') {
        body["driver_id"] = _selectedDriverId;
      }

      final response = await http.patch(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Successfully changed driver and vehicle"), backgroundColor: Colors.green),
          );
        }
      } else {
        final respData = jsonDecode(response.body);
        throw Exception(respData['message'] ?? "Failed to update");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
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
            "Change Driver or Vehicle",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          // Current Assignment
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("CURRENT ASSIGNMENT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue, letterSpacing: 1)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.currentDriverName, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.directions_car_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.currentVehicleName, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            // Change Mode Toggle
            const Text("What would you like to change?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Vehicle Only'),
                  selected: _changeMode == 'VEHICLE_ONLY',
                  onSelected: (val) { if (val) setState(() => _changeMode = 'VEHICLE_ONLY'); },
                  selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  labelStyle: TextStyle(color: _changeMode == 'VEHICLE_ONLY' ? const Color(0xFF6366F1) : null, fontWeight: FontWeight.bold),
                ),
                ChoiceChip(
                  label: const Text('Driver Only'),
                  selected: _changeMode == 'DRIVER_ONLY',
                  onSelected: (val) { if (val) setState(() => _changeMode = 'DRIVER_ONLY'); },
                  selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  labelStyle: TextStyle(color: _changeMode == 'DRIVER_ONLY' ? const Color(0xFF6366F1) : null, fontWeight: FontWeight.bold),
                ),
                ChoiceChip(
                  label: const Text('Both'),
                  selected: _changeMode == 'BOTH',
                  onSelected: (val) { if (val) setState(() => _changeMode = 'BOTH'); },
                  selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  labelStyle: TextStyle(color: _changeMode == 'BOTH' ? const Color(0xFF6366F1) : null, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            if (_changeMode != 'DRIVER_ONLY') ...[
              // Vehicle Dropdown
              const Text("Select New Vehicle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showSelectionSheet(
                title: "Select Vehicle",
                items: _vehicles,
                isDriver: false,
                onSelected: (id) {
                  setState(() {
                    _selectedVehicleId = id;
                    if (_changeMode == 'BOTH') {
                      final selected = _vehicles.firstWhere((v) => v['id'] == id, orElse: () => {});
                      if (selected != null && selected['default_driver'] != null && selected['default_driver']['driver_id'] != null) {
                        _selectedDriverId = selected['default_driver']['driver_id'];
                      } else {
                        _selectedDriverId = null;
                      }
                    }
                  });
                },
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.1), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                      child: const Icon(Icons.directions_car_rounded, color: Colors.green, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedVehicleId != null
                            ? (_vehicles.firstWhere((v) => v['id'] == _selectedVehicleId, orElse: () => {})['vehicle_number'] ?? 'Unknown Vehicle')
                            : "Choose an available vehicle",
                        style: TextStyle(
                          color: _selectedVehicleId != null ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                          fontWeight: _selectedVehicleId != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
            ],
            const SizedBox(height: 16),
            if (_changeMode != 'VEHICLE_ONLY') ...[
              // Driver Dropdown
              const Text("Select New Driver", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showSelectionSheet(
                title: "Select Driver",
                items: _drivers,
                isDriver: true,
                onSelected: (id) => setState(() => _selectedDriverId = id),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.1), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      child: const Icon(Icons.person_rounded, color: Colors.blue, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDriverId != null
                            ? (_drivers.firstWhere((d) => d['id'] == _selectedDriverId, orElse: () => {})['user']?['name'] ?? 'Unknown Driver')
                            : "Choose an available driver",
                        style: TextStyle(
                          color: _selectedDriverId != null ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                          fontWeight: _selectedDriverId != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
            ],
            const SizedBox(height: 16),
            // Remark
            const Text("Remark", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _remarkController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Enter reason for change...",
                filled: true,
                fillColor: Colors.grey.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.grey, width: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: const Color(0xFF6366F1).withValues(alpha: 0.4),
                ),
                child: _isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            "CONFIRM CHANGES",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSelectionSheet({
    required String title,
    required List<dynamic> items,
    required bool isDriver,
    required Function(int) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SelectionListSheet(
          title: title,
          items: items,
          isDriver: isDriver,
          guestCount: _guestCount,
          onSelected: (id) {
            onSelected(id);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}

class _SelectionListSheet extends StatefulWidget {
  final String title;
  final List<dynamic> items;
  final bool isDriver;
  final int guestCount;
  final Function(int) onSelected;

  const _SelectionListSheet({
    required this.title,
    required this.items,
    required this.isDriver,
    required this.guestCount,
    required this.onSelected,
  });

  @override
  State<_SelectionListSheet> createState() => _SelectionListSheetState();
}

class _SelectionListSheetState extends State<_SelectionListSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    final filteredItems = widget.items.where((item) {
      if (widget.isDriver) {
        final name = (item['user']?['name'] ?? 'Unknown Driver').toString().toLowerCase();
        return name.contains(_searchQuery.toLowerCase());
      } else {
        final name = (item['vehicle_number'] ?? 'Unknown Vehicle').toString().toLowerCase();
        return name.contains(_searchQuery.toLowerCase());
      }
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
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
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: "Search...",
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: filteredItems.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    if (widget.isDriver) {
                      final name = item['user']?['name'] ?? 'Unknown Driver';
                      final phone = item['user']?['phone'] ?? 'N/A';
                      final status = item['status']?.toString() ?? 'UNKNOWN';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(phone, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        trailing: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           decoration: BoxDecoration(
                               color: status == 'AVAILABLE' ? Colors.green.withValues(alpha: 0.1) : (status == 'ON_TRIP' ? Colors.orange.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)),
                               borderRadius: BorderRadius.circular(12),
                           ),
                           child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: status == 'AVAILABLE' ? Colors.green : (status == 'ON_TRIP' ? Colors.orange : Colors.grey))),
                        ),
                        onTap: () => widget.onSelected(item['id']),
                      );
                    } else {
                      final name = item['vehicle_number'] ?? 'Unknown Vehicle';
                      final type = item['vehicle_type_name'] ?? 'Unknown Type';
                      final capacity = item['capacity']?.toString() ?? '0';
                      final capacityNum = int.tryParse(capacity) ?? 0;
                      final isCapacityInvalid = capacityNum < widget.guestCount;

                      return ListTile(
                        enabled: !isCapacityInvalid,
                        leading: CircleAvatar(
                          backgroundColor: isCapacityInvalid ? Colors.grey.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                          child: Icon(Icons.directions_car_rounded, color: isCapacityInvalid ? Colors.grey : Colors.green),
                        ),
                        title: Row(
                          children: [
                            Text(name, style: TextStyle(fontWeight: FontWeight.w700, color: isCapacityInvalid ? Colors.grey : (isDark ? Colors.white : Colors.black))),
                            if (item['default_driver'] != null && item['default_driver']['name'] != null) ...[
                               const SizedBox(width: 8),
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                 decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                 child: Text(item['default_driver']['name'].toString().toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
                               )
                            ]
                          ],
                        ),
                        subtitle: Text("$type • $capacity Seats", style: TextStyle(color: isCapacityInvalid ? Colors.red : Colors.grey.shade600, fontSize: 12)),
                        onTap: isCapacityInvalid ? null : () => widget.onSelected(item['id']),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
