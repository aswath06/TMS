import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:tripzo/store/admin_allowance_store.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:io' as dart_io;
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';

class AdminAllowanceFormScreen extends StatefulWidget {
  final Map<String, dynamic>? pendingCreation; // If not null -> Create Mode
  final Map<String, dynamic>? allowance; // If not null -> Edit Mode

  const AdminAllowanceFormScreen({
    super.key,
    this.pendingCreation,
    this.allowance,
  });

  @override
  State<AdminAllowanceFormScreen> createState() => _AdminAllowanceFormScreenState();
}

class _AdminAllowanceFormScreenState extends State<AdminAllowanceFormScreen> {
  final _formKey = GlobalKey<FormState>();

  bool get isEditMode => widget.allowance != null;
  bool get isManualMode => widget.pendingCreation == null && widget.allowance == null;

  // Manual Mode State
  List<Map<String, dynamic>> _departments = [];
  String? _selectedDepartmentId;
  final TextEditingController _routeNameController = TextEditingController();
  DateTime? _manualTripStartedAt;
  DateTime? _manualTripEndedAt;
  List<Map<String, dynamic>> _drivers = [];

  bool _isLoadingPurposes = false;
  bool _isLoadingTypes = false;
  bool _isLoadingDepartments = false;
  bool _isLoadingDrivers = false;

  // Form Fields
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _generalReasonController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  String? _selectedPurposeId;
  List<String> _selectedTypeIds = [];
  String _paymentMode = "CASH";

  // Driver Disbursements (For Create Mode)
  List<Map<String, dynamic>> _driverDisbursements = [];

  // Edit Mode Amount
  final TextEditingController _editAmountController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    // Fetch purposes and types if creating
    if (!isEditMode) {
      if (adminAllowanceStore.purposes.isEmpty) {
        _isLoadingPurposes = true;
        adminAllowanceStore.fetchPurposes().then((_) {
          if (mounted) setState(() => _isLoadingPurposes = false);
        });
      }
      if (adminAllowanceStore.types.isEmpty) {
        _isLoadingTypes = true;
        adminAllowanceStore.fetchTypes().then((_) {
          if (mounted) setState(() => _isLoadingTypes = false);
        });
      }
    }
    if (isManualMode) {
      _fetchDepartments();
      _fetchDrivers();
    }
  }

  Future<void> _fetchDepartments() async {
    setState(() => _isLoadingDepartments = true);
    try {
      final token = await UserStore.getToken();
      final response = await http.get(Uri.parse("${ApiConstants.baseUrl}/auth/department"), headers: ApiConstants.getHeaders(token));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _departments = List<Map<String, dynamic>>.from(data['data']);
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching departments: $e");
    } finally {
      if (mounted) setState(() => _isLoadingDepartments = false);
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

  void _initializeData() {
    if (isEditMode) {
      final allowance = widget.allowance!;
      _locationController.text = allowance['allowance_location']?.toString() ?? "";
      _generalReasonController.text = allowance['reason']?.toString() ?? "";
      _remarksController.text = allowance['remarks']?.toString() ?? "";
      _editAmountController.text = allowance['amount']?.toString() ?? "";
      _paymentMode = allowance['payment_mode']?.toString() ?? "CASH";
    } else if (!isManualMode) {
      final pending = widget.pendingCreation!;
      final tripLegs = pending['tripLegs'] as List<dynamic>?;

      if (tripLegs != null && tripLegs.isNotEmpty) {
        final assignments = tripLegs[0]['assignments'] as List<dynamic>?;
        if (assignments != null) {
          for (var assign in assignments) {
            final driver = assign['driver'];
            if (driver != null) {
              _driverDisbursements.add({
                'driver_id': driver['id'].toString(),
                'name': driver['user']?['name'] ?? "Unknown",
                'amount': TextEditingController(),
                'reason': TextEditingController(),
              });
            }
          }
        }
      }
    } else {
      // Manual mode initial driver disbursement slot
      _driverDisbursements.add({
        'driver_id': null, // Will be selected from dropdown
        'name': "Select Driver...",
        'amount': TextEditingController(),
        'reason': TextEditingController(),
      });
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _generalReasonController.dispose();
    _remarksController.dispose();
    _editAmountController.dispose();
    for (var d in _driverDisbursements) {
      (d['amount'] as TextEditingController).dispose();
      (d['reason'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!isEditMode && _selectedPurposeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select Nature of Trip")));
      return;
    }
    if (!isEditMode && _selectedTypeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one Allowance Type")));
      return;
    }

    setState(() => _isSubmitting = true);

    bool success = false;
    if (isEditMode) {
      final allowance = widget.allowance!;
      final data = {
        "amount": _editAmountController.text,
        "reason": _generalReasonController.text,
        "payment_mode": _paymentMode,
        "allowance_location": _locationController.text,
        "remarks": _remarksController.text,
      };
      success = await adminAllowanceStore.updateAllowance(allowance['id'], data);
    } else {
      Map<String, dynamic> data = {};
      if (isManualMode) {
        if (_selectedDepartmentId == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a Requesting Department")));
          setState(() => _isSubmitting = false);
          return;
        }
        data = {
          "request_department_id": _selectedDepartmentId,
          "route_name": _routeNameController.text,
          "manual_trip_started_at": _manualTripStartedAt?.toIso8601String() ?? "",
          "manual_trip_ended_at": _manualTripEndedAt?.toIso8601String() ?? "",
          "purpose_id": _selectedPurposeId,
          "allowance_type_ids": _selectedTypeIds,
          "allowance_location": _locationController.text,
          "payment_mode": _paymentMode,
          "remarks": _remarksController.text,
          "reason": _generalReasonController.text,
          "allowances": _driverDisbursements.map((d) => {
            "driver_id": d['driver_id'],
            "amount": (d['amount'] as TextEditingController).text,
            "reason": (d['reason'] as TextEditingController).text,
          }).toList(),
        };
      } else {
        final pending = widget.pendingCreation!;
        data = {
          "route_request_id": pending['routeRequest']?['id']?.toString() ?? "",
          "trip_id": pending['id']?.toString() ?? "",
          "purpose_id": _selectedPurposeId,
          "allowance_type_ids": _selectedTypeIds,
          "allowance_location": _locationController.text,
          "payment_mode": _paymentMode,
          "remarks": _remarksController.text,
          "reason": _generalReasonController.text,
          "allowances": _driverDisbursements.map((d) => {
            "driver_id": d['driver_id'],
            "amount": (d['amount'] as TextEditingController).text,
            "reason": (d['reason'] as TextEditingController).text,
          }).toList(),
        };
      }
      success = await adminAllowanceStore.createAllowance(data);
    }

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Successfully saved!"), backgroundColor: Colors.green,
      ));
      adminAllowanceStore.fetchAllowances(isRefresh: true);
      adminAllowanceStore.fetchPendingAllowanceCreations();
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Failed to save allowance"), backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(isEditMode ? "Edit Allowance" : "Assign Allowance Breakdown", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
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
                    if (!isEditMode) ...[
                      if (isManualMode)
                        _buildManualRouteInfo(isDark)
                      else
                        _buildRouteInfo(isDark),
                    ],
                    const SizedBox(height: 20),
                    _buildTextField("Allowance Location", _locationController, isRequired: true),
                    const SizedBox(height: 20),
                    if (!isEditMode) ...[
                      _buildDropdown("Nature of Trip", _selectedPurposeId, adminAllowanceStore.purposes, (val) => setState(() => _selectedPurposeId = val), isLoading: _isLoadingPurposes, allowAdd: true, onAdd: (name) async {
                        bool success = await adminAllowanceStore.createPurpose(name);
                        if (success && mounted) {
                          setState(() {});
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to create purpose")));
                        }
                      }),
                      const SizedBox(height: 20),
                      _buildMultiSelectTypes(),
                      const SizedBox(height: 24),
                      const Text("DRIVER DISBURSEMENTS MATRIX", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 12),
                      ..._driverDisbursements.map((d) => _buildDriverDisbursementItem(d, isDark)).toList(),
                      const SizedBox(height: 16),
                    ],
                    if (isManualMode) ...[
                      _buildDropdown("Requesting Department", _selectedDepartmentId, _departments, (val) => setState(() => _selectedDepartmentId = val), isLoading: _isLoadingDepartments),
                      const SizedBox(height: 20),
                    ],
                    if (isEditMode) ...[
                      _buildTextField("Amount (₹)", _editAmountController, isRequired: true, isNumber: true),
                      const SizedBox(height: 20),
                    ],
                    _buildDropdown("Payment Mode", _paymentMode, [
                      {'id': 'CASH', 'name': 'CASH'},
                      {'id': 'BANK', 'name': 'BANK'},
                      {'id': 'UPI', 'name': 'UPI'}
                    ], (val) => setState(() => _paymentMode = val ?? 'CASH')),
                    const SizedBox(height: 20),
                    _buildTextField("General Request Reason", _generalReasonController),
                    const SizedBox(height: 20),
                    _buildTextField("Internal Remarks", _remarksController),
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
                        : Text(isEditMode ? "Save Changes" : "Create Allowances", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker({required String label, required DateTime? value, required VoidCallback onTap, bool isRequired = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 1.0)),
            if (isRequired) const Text(" *", style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value != null ? DateFormat('MMM dd, hh:mm a').format(value) : "Select $label...",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: value != null ? FontWeight.w600 : FontWeight.w500,
                      color: value != null
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : Colors.grey.shade400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.calendar_month_rounded, color: isDark ? Colors.white54 : Colors.grey.shade400, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDateTime(BuildContext context, bool isStart) async {
    DateTime tempDate = (isStart ? _manualTripStartedAt : _manualTripEndedAt) ?? DateTime.now();

    final selectedDate = await CustomDateTimePicker.show(
      context,
      initialDate: tempDate,
      showTime: true,
    );

    if (selectedDate != null) {
      setState(() {
        if (isStart) {
          _manualTripStartedAt = selectedDate;
        } else {
          _manualTripEndedAt = selectedDate;
        }
      });
    }
  }

  Widget _buildDateTimeField(String label, DateTime? date, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 1.0)),
            const Text(" *", style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  date != null ? DateFormat('dd/MM/yyyy HH:mm').format(date) : "Select...",
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: date != null ? (isDark ? Colors.white : Colors.black87) : Colors.grey.shade400),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.calendar_month_rounded, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualRouteInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdown("Requesting Department", _selectedDepartmentId, _departments.map((d) => {'id': d['id'].toString(), 'name': d['department_name'] ?? 'N/A'}).toList(), (val) => setState(() => _selectedDepartmentId = val), isLoading: _isLoadingDepartments),
          const SizedBox(height: 20),
          _buildTextField("Route Name", _routeNameController, isRequired: true),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDateTime(context, true),
                  child: _buildDateTimeField("Trip Started At", _manualTripStartedAt, isDark),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDateTime(context, false),
                  child: _buildDateTimeField("Trip Ended At", _manualTripEndedAt, isDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo(bool isDark) {
    final pending = widget.pendingCreation!;
    final routeRequest = pending['routeRequest'] ?? {};
    final routeName = routeRequest['route_name'] ?? 'Unknown Route';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ROUTE NAME", style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 1.2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 12, color: Colors.green),
                    const SizedBox(width: 4),
                    Text("COMPLETED", style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.green)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(routeName, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isRequired = false, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 1.0)),
            if (isRequired) const Text(" *", style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          validator: isRequired ? (val) => (val == null || val.isEmpty) ? 'Required' : null : null,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            hintText: "Enter ${label.toLowerCase()}...",
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontWeight: FontWeight.w600, fontSize: 13),
            isDense: true,
          ),
        ),
      ],
    );
  }

  void _showCustomBottomSheet(String label, List<Map<String, dynamic>> items, Function(String?) onChanged, {bool allowAdd = false, Future<void> Function(String)? onAdd}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String searchQuery = '';
    final TextEditingController newCategoryController = TextEditingController();
    bool isAdding = false;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredItems = items.where((item) {
              return item['name'].toString().toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75, // taller for search
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Select $label",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: TextField(
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: "Search $label...",
                        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.blueAccent.withValues(alpha: 0.6), size: 20),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
                      ),
                    ),
                  ),
                  if (allowAdd)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newCategoryController,
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                              decoration: InputDecoration(
                                hintText: "New category...",
                                hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade400, fontSize: 14),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.5), width: 1.5)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.5), width: 1.5)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2.0)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isAdding ? null : () async {
                              if (newCategoryController.text.trim().isNotEmpty && onAdd != null) {
                                setModalState(() => isAdding = true);
                                await onAdd(newCategoryController.text.trim());
                                newCategoryController.clear();
                                setModalState(() => isAdding = false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              elevation: 0,
                            ),
                            child: isAdding
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text("Save", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filteredItems.length,
                      padding: const EdgeInsets.all(20),
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return InkWell(
                          onTap: () {
                            onChanged(item['id'].toString());
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.category_rounded, color: Colors.blueAccent, size: 20),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    item['name'].toString(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildDropdown(String label, String? value, List<Map<String, dynamic>> items, Function(String?) onChanged, {bool allowAdd = false, Future<void> Function(String)? onAdd, bool isLoading = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final matches = items.where((e) => e['id'].toString() == value);
    final selectedItem = matches.isNotEmpty ? matches.first : null;
    final selectedName = selectedItem?['name']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 1.0)),
            const Text(" *", style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: isLoading ? null : () => _showCustomBottomSheet(label, items, onChanged, allowAdd: allowAdd, onAdd: onAdd),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    selectedName.isNotEmpty ? selectedName : "Select $label...",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: selectedName.isNotEmpty ? FontWeight.w600 : FontWeight.w500,
                      color: selectedName.isNotEmpty
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : Colors.grey.shade400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLoading)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)))
                else
                  Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.white54 : Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelectTypes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("ALLOWANCE TYPES", style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade500, letterSpacing: 1.0)),
            const Text(" *", style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: adminAllowanceStore.types.map((type) {
            final idStr = type['id'].toString();
            final isSelected = _selectedTypeIds.contains(idStr);
            return FilterChip(
              label: Text(type['name'].toString()),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTypeIds.add(idStr);
                  } else {
                    _selectedTypeIds.remove(idStr);
                  }
                });
              },
              selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
              checkmarkColor: const Color(0xFF6366F1),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDriverDisbursementItem(Map<String, dynamic> driver, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.1), width: 1.5),
        boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!isManualMode) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_rounded, size: 18, color: Color(0xFF6366F1)),
                ),
                const SizedBox(width: 12),
                Text(driver['name'], style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.bold)),
              ] else
                Expanded(
                  child: _buildDropdown(
                    "Assign Driver",
                    driver['driver_id'],
                    _drivers.map((d) {
                      return {'id': d['id'].toString(), 'name': (d['name'] ?? 'Unknown').toString()};
                    }).toList(),
                    (val) {
                      setState(() {
                        driver['driver_id'] = val;
                      });
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTextField("Amount (₹)", driver['amount'], isRequired: true, isNumber: true),
          const SizedBox(height: 16),
          _buildTextField("Specific Reason", driver['reason']),
        ],
      ),
    );
  }
}
