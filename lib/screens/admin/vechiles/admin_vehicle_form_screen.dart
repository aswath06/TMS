import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';
import 'package:tripzo/utils/api_error_parser.dart';

class AdminVehicleFormScreen extends StatefulWidget {
  final Map<String, dynamic>? vehicleData; // If null, it's Add mode. If provided, Edit mode.

  const AdminVehicleFormScreen({super.key, this.vehicleData});

  @override
  State<AdminVehicleFormScreen> createState() => _AdminVehicleFormScreenState();
}

class _AdminVehicleFormScreenState extends State<AdminVehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  bool get isEditMode => widget.vehicleData != null;

  // Controllers
  final _vehicleNumberCtrl = TextEditingController();
  final _busNumberCtrl = TextEditingController();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _fuelTypeCtrl = TextEditingController();
  final _ownershipTypeCtrl = TextEditingController();
  final _engineNumberCtrl = TextEditingController();
  final _chassisNumberCtrl = TextEditingController();
  final _fuelTankCapacityCtrl = TextEditingController();
  final _vehicleAgeCtrl = TextEditingController();

  DateTime? _insuranceExpiry;
  DateTime? _pollutionExpiry;
  DateTime? _fcExpiry;
  DateTime? _taxValidUpto;
  DateTime? _permitValidUpto;
  DateTime? _registrationDate;

  String? _defaultDriverId;
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoadingDrivers = false;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
    if (isEditMode) {
      final v = widget.vehicleData!;
      _vehicleNumberCtrl.text = v['vehicle_number']?.toString() ?? '';
      _busNumberCtrl.text = v['bus_number']?.toString() ?? '';
      _makeCtrl.text = v['make']?.toString() ?? '';
      _modelCtrl.text = v['model']?.toString() ?? '';
      _capacityCtrl.text = v['capacity']?.toString() ?? '';
      _fuelTypeCtrl.text = v['fuel_type']?.toString() ?? '';
      _ownershipTypeCtrl.text = v['ownership_type']?.toString() ?? '';
      _engineNumberCtrl.text = v['engine_number']?.toString() ?? '';
      _chassisNumberCtrl.text = v['chassis_number']?.toString() ?? '';
      _fuelTankCapacityCtrl.text = v['fuel_tank_capacity']?.toString() ?? '';
      _vehicleAgeCtrl.text = v['vehicle_age']?.toString() ?? '';

      _insuranceExpiry = _parseDate(v['insurance_expiry_date']);
      _pollutionExpiry = _parseDate(v['pollution_expiry_date']);
      _fcExpiry = _parseDate(v['fc_expiry_date']);
      _taxValidUpto = _parseDate(v['tax_valid_upto']);
      _permitValidUpto = _parseDate(v['permit_valid_upto']);
      _registrationDate = _parseDate(v['registration_date']);
      _defaultDriverId = v['default_driver_id']?.toString();
    }
  }

  Future<void> _fetchDrivers() async {
    setState(() => _isLoadingDrivers = true);
    try {
      final token = await UserStore.getToken();
      final response = await http.get(Uri.parse(ApiConstants.getAllDriversWithoutPagination), headers: ApiConstants.getHeaders(token));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _drivers = (data['data'] as List).map((e) {
                Map<String, dynamic> item = Map<String, dynamic>.from(e);
                String empCode = e['employee_code']?.toString() ?? '';
                String phone = e['phone']?.toString() ?? '';
                String fallback = [empCode, phone].where((x) => x.isNotEmpty).join(' • ');
                item['name'] = e['user']?['name'] ?? e['name'] ?? (fallback.isNotEmpty ? fallback : "Unknown Driver");
                return item;
              }).toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching drivers: $e");
    } finally {
      if (mounted) setState(() => _isLoadingDrivers = false);
    }
  }

  DateTime? _parseDate(dynamic dateStr) {
    if (dateStr == null || dateStr.toString().isEmpty) return null;
    try {
      return DateTime.parse(dateStr.toString());
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _vehicleNumberCtrl.dispose();
    _busNumberCtrl.dispose();
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _capacityCtrl.dispose();
    _fuelTypeCtrl.dispose();
    _ownershipTypeCtrl.dispose();
    _engineNumberCtrl.dispose();
    _chassisNumberCtrl.dispose();
    _fuelTankCapacityCtrl.dispose();
    _vehicleAgeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final token = await UserStore.getToken();
      final Map<String, dynamic> body = {
        "vehicle_number": _vehicleNumberCtrl.text,
        "bus_number": _busNumberCtrl.text,
        "make": _makeCtrl.text,
        "model": _modelCtrl.text,
        "capacity": int.tryParse(_capacityCtrl.text) ?? 0,
        "fuel_type": _fuelTypeCtrl.text,
        "ownership_type": _ownershipTypeCtrl.text,
        "engine_number": _engineNumberCtrl.text,
        "chassis_number": _chassisNumberCtrl.text,
        "fuel_tank_capacity": double.tryParse(_fuelTankCapacityCtrl.text) ?? 0.0,
        "vehicle_age": _vehicleAgeCtrl.text,
        "insurance_expiry_date": _insuranceExpiry?.toIso8601String(),
        "pollution_expiry_date": _pollutionExpiry?.toIso8601String(),
        "fc_expiry_date": _fcExpiry?.toIso8601String(),
        "tax_valid_upto": _taxValidUpto?.toIso8601String(),
        "permit_valid_upto": _permitValidUpto?.toIso8601String(),
        "registration_date": _registrationDate?.toIso8601String(),
        "default_driver_id": _defaultDriverId,
      };

      String url = ApiConstants.createVehicle;
      String method = 'POST';
      
      if (isEditMode) {
        url = "${ApiConstants.baseUrl}/api/vehicles/update/${widget.vehicleData!['id']}";
        method = 'PUT'; // Using PUT for updates generically
      }

      final response = await (method == 'POST' ? http.post : http.put)(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vehicle saved successfully!"), backgroundColor: Colors.green));
          Navigator.pop(context, true); // true indicates success
        }
      } else {
        String errorMsg = ApiErrorParser.parse(response, fallback: "Failed to save");
        try {
          final errData = json.decode(response.body);
          if (errData['message'] != null) {
            errorMsg = errData['message'];
          } else if (errData['error'] != null) {
            errorMsg = errData['error'];
          }
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _selectDate(BuildContext context, DateTime? currentDate, Function(DateTime) onSelected) async {
    final selectedDate = await CustomDateTimePicker.show(
      context,
      initialDate: currentDate ?? DateTime.now(),
      showTime: false,
    );
    if (selectedDate != null) {
      setState(() => onSelected(selectedDate));
    }
  }

  void _showResetOdometerDialog() {
    final readingCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final Color bg = isDark ? const Color(0xFF1E293B) : Colors.white;
            final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final Color primaryBlue = const Color(0xFF6366F1);

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: bg,
              elevation: 10,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Reset Odometer",
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Are you sure you want to force reset the base odometer? This action requires a password.",
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: readingCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: "New Odometer Reading",
                        labelStyle: TextStyle(color: primaryBlue),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryBlue),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryBlue.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryBlue, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordCtrl,
                      obscureText: true,
                      style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: "Password",
                        labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryBlue, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isResetting ? null : () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: isResetting ? null : () async {
                            final reading = readingCtrl.text.trim();
                            final pass = passwordCtrl.text.trim();
                            if (reading.isEmpty || pass.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields"), backgroundColor: Colors.orange));
                              return;
                            }
                            
                            setStateModal(() => isResetting = true);
                            try {
                              final token = await UserStore.getToken();
                              final response = await http.patch(
                                Uri.parse(ApiConstants.resetOdometer(widget.vehicleData!['id'])),
                                headers: ApiConstants.getHeaders(token),
                                body: json.encode({
                                  "reading": num.tryParse(reading) ?? 0,
                                  "password": pass,
                                }),
                              );
                              
                              if (response.statusCode == 200 || response.statusCode == 201) {
                                if (mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Odometer reset successfully!"), backgroundColor: Colors.green));
                                }
                              } else {
                                final data = json.decode(response.body);
                                final err = data['message'] ?? "Failed to reset odometer";
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                              }
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                            } finally {
                              if (mounted) setStateModal(() => isResetting = false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444), // Tailwind Red 500
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: isResetting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Force Reset", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(isEditMode ? "Edit Vehicle" : "Add Vehicle", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSectionTitle("Basic Information", isDark),
                    const SizedBox(height: 16),
                    _buildTextField("Vehicle Number", _vehicleNumberCtrl, isRequired: true),
                    const SizedBox(height: 16),
                    _buildTextField("Bus Number / Identifier", _busNumberCtrl),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField("Make", _makeCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField("Model", _modelCtrl)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField("Capacity", _capacityCtrl, isNumber: true)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField("Vehicle Age", _vehicleAgeCtrl)),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    _buildSectionTitle("Technical Details", isDark),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField("Fuel Type", _fuelTypeCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField("Tank Capacity (L)", _fuelTankCapacityCtrl, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField("Ownership Type", _ownershipTypeCtrl),
                    const SizedBox(height: 16),
                    _buildTextField("Engine Number", _engineNumberCtrl),
                    const SizedBox(height: 16),
                    _buildTextField("Chassis Number", _chassisNumberCtrl),

                    const SizedBox(height: 32),
                    _buildSectionTitle("Compliance Dates", isDark),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildDateField("Registration Date", _registrationDate, (d) => _registrationDate = d)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildDateField("Fitness Certificate Expiry", _fcExpiry, (d) => _fcExpiry = d)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildDateField("Tax Valid Upto", _taxValidUpto, (d) => _taxValidUpto = d)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildDateField("Insurance Expiry Date", _insuranceExpiry, (d) => _insuranceExpiry = d)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildDateField("Pollution Certificate Expiry", _pollutionExpiry, (d) => _pollutionExpiry = d)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildDateField("Permit Valid Upto", _permitValidUpto, (d) => _permitValidUpto = d)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildSectionTitle("Driver Assignment", isDark),
                    const SizedBox(height: 16),
                    _buildDriverDropdown(isDark),
                    if (isEditMode) ...[
                      const SizedBox(height: 32),
                      _buildSectionTitle("Danger Zone", isDark),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _showResetOdometerDialog,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text("Reset Odometer", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isSubmitting 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(isEditMode ? "Save Changes" : "Create Vehicle", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isRequired = false, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 0.5)),
            if (isRequired) const Text(" *", style: TextStyle(color: Colors.red, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          validator: isRequired ? (val) => (val == null || val.isEmpty) ? 'Required' : null : null,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            hintText: "Enter ${label.toLowerCase()}...",
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontWeight: FontWeight.w500, fontSize: 13),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, DateTime? date, Function(DateTime) onSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _selectDate(context, date, onSelected),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    date != null ? DateFormat('dd/MM/yyyy').format(date) : "Select...",
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: date != null ? (isDark ? Colors.white : Colors.black87) : Colors.grey.shade400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.calendar_month_rounded, size: 16, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("ASSIGN DEFAULT DRIVER (OPTIONAL)", style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        _isLoadingDrivers 
            ? const Center(child: CircularProgressIndicator())
            : DropdownButtonFormField<String>(
                value: _defaultDriverId,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  hintText: "Select Driver...",
                  hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontWeight: FontWeight.w500, fontSize: 13),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text("None")),
                  ..._drivers.map((d) {
                    return DropdownMenuItem<String>(
                      value: d['id'].toString(),
                      child: Text(d['name'].toString(), style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600)),
                    );
                  })
                ],
                onChanged: (val) {
                  setState(() {
                    _defaultDriverId = val;
                  });
                },
              ),
      ],
    );
  }
}
