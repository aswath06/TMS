import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../utils/api_constants.dart';
import '../../../store/user_store.dart';
import '../../../store/istamil.dart';
import '../../../components/common/custom_date_time_picker.dart';
import '../../../components/common/structural_loading.dart';
import 'package:tripzo/utils/api_error_parser.dart';

class DriverFuelRequestPage extends StatefulWidget {
  const DriverFuelRequestPage({Key? key}) : super(key: key);

  @override
  State<DriverFuelRequestPage> createState() => _DriverFuelRequestPageState();
}

class _DriverFuelRequestPageState extends State<DriverFuelRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _volumeController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  Map<String, dynamic>? _selectedVehicle;
  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoadingVehicles = false;
  bool _isSubmitting = false;

  String? _errorMessage;
  String? _selectedFuelType;
  List<String> _availableFuelTypes = [];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchVehicles() async {
    try {
      final token = await UserStore.getToken();
      final url = ApiConstants.getAllVehiclesWithoutPagination;
      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _vehicles = List<Map<String, dynamic>>.from(data['data']);
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching vehicles: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingVehicles = false);
      }
    }
  }

  Future<void> _handleSubmit() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LanguageStore.isTamil ? "வாகனத்தைத் தேர்ந்தெடுக்கவும்" : "Please select a vehicle")));
      return;
    }
    if (_selectedFuelType == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LanguageStore.isTamil ? "எரிபொருள் வகையைத் தேர்ந்தெடுக்கவும்" : "Please select a fuel type")));
      return;
    }

    final requiredVolume = double.tryParse(_volumeController.text) ?? 0;
    final tankCapacity = _selectedVehicle!['fuel_tank_capacity'] != null ? double.tryParse(_selectedVehicle!['fuel_tank_capacity'].toString()) ?? 0 : 0;

    if (tankCapacity > 0 && requiredVolume > tankCapacity) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(LanguageStore.isTamil 
          ? "கோரப்பட்ட அளவு தொட்டியின் அளவை விட அதிகமாக உள்ளது ($tankCapacity லிட்டர்)" 
          : "Requested volume exceeds tank capacity ($tankCapacity Liters)"),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await UserStore.getToken();
      final url = ApiConstants.fuelLog;
      
      final driverId = await UserStore.getDriverId();

      final body = {
        'vehicle_id': _selectedVehicle!['id'],
        'driver_id': driverId, // Needed for frontend queries later
        'required_volume': _volumeController.text,
        'filled_volume': _volumeController.text, // Backend requires this not to be null
        'current_odometer': "0", // Backend requires this not to be null
        'filled_at': _selectedDate.toIso8601String(),
        'is_fuel_request': true,
        'fluid_type': _selectedFuelType,
      };

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode(body),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 201 || result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(LanguageStore.isTamil ? "கோரிக்கை வெற்றிகரமாக அனுப்பப்பட்டது" : "Fuel request submitted successfully"),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      } else {
        final errorMsg = ApiErrorParser.parse(response, fallback: "Failed to submit request");
        debugPrint("API Error Response: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      debugPrint("Exception during fuel request submission: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(LanguageStore.isTamil ? "பிழை ஏற்பட்டது: $e" : "An error occurred: $e"),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = LanguageStore.isTamil;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF8F9FA),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isTamil ? "எரிபொருள் கோரிக்கை" : "Fuel Request",
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoadingVehicles 
        ? const StructuralLoading(padding: 24)
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSelectTile(
                    isTamil ? "வாகனத்தைத் தேர்ந்தெடுக்கவும் *" : "SELECT VEHICLE *",
                    _selectedVehicle?['vehicle_number'] ?? (isTamil ? "வாகனத்தைத் தேர்ந்தெடுக்கவும்" : "Choose Vehicle"),
                    _selectedVehicle != null
                        ? "${_selectedVehicle?['vehicle_type_name'] ?? 'Vehicle'} • Fuel: ${_selectedVehicle?['fuel_type'] ?? 'N/A'}"
                        : null,
                    Icons.directions_bus_filled_rounded,
                    _selectedVehicle != null,
                    () async {
                      if (_vehicles.isEmpty) {
                        setState(() => _isLoadingVehicles = true);
                        await _fetchVehicles();
                        if (!mounted) return;
                      }
                      if (_isLoadingVehicles) return;
                      _showSelectionSheet(
                        title: isTamil ? "வாகனத்தைத் தேர்ந்தெடுக்கவும்" : "Select Vehicle",
                        items: _vehicles,
                        selected: _selectedVehicle,
                        onSelect: (v) {
                          setState(() {
                            _selectedVehicle = v;
                            _errorMessage = null;
                            
                            final vFuelType = (v['fuel_type'] ?? 'DIESEL').toString().toUpperCase();
                            final isAdBlue = v['is_adblue'] == true || v['is_adblue'] == 1;
                            
                            _availableFuelTypes = [vFuelType];
                            if (isAdBlue) _availableFuelTypes.add('AD_BLUE');
                            
                            if (_availableFuelTypes.length == 1) {
                              _selectedFuelType = _availableFuelTypes.first;
                            } else {
                              _selectedFuelType = null;
                            }
                          });
                        },
                      );
                    },
                  ),
                  if (_availableFuelTypes.length > 1) ...[
                    const SizedBox(height: 24),
                    _buildSelectTile(
                      isTamil ? "எரிபொருள் வகை *" : "FUEL TYPE *",
                      _selectedFuelType ?? (isTamil ? "தேர்ந்தெடுக்கவும்" : "Choose Fuel Type"),
                      null,
                      Icons.local_gas_station_rounded,
                      _selectedFuelType != null,
                      () {
                        _showFuelTypeSheet(isTamil);
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: isTamil ? "அளவு *" : "VOLUME *",
                          controller: _volumeController,
                          hint: "e.g. 50",
                          icon: Icons.water_drop_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) => v!.isEmpty ? (isTamil ? "தேவை" : "Required") : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDateField(
                          label: isTamil ? "தேதி *" : "DATE *",
                          icon: Icons.calendar_today_outlined,
                          value: DateFormat('MMM dd, yyyy h:mm a').format(_selectedDate),
                          onTap: () async {
                            final picked = await CustomDateTimePicker.show(context, initialDate: _selectedDate);
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            isTamil ? "கோரிக்கையை சமர்ப்பிக்கவும்" : "SUBMIT REQUEST",
                            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF6366F1),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF1E293B), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8)),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF94A3B8), size: 18),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFF1F5F9), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF6366F1),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF94A3B8), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(color: const Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectTile(
    String label,
    String valueText,
    String? subText,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF6366F1),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        valueText,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                      ),
                      if (subText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8), size: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSelectionSheet({
    required String title,
    required List<dynamic> items,
    required dynamic selected,
    required Function(dynamic) onSelect,
  }) {
    String searchQuery = '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            List<dynamic> filteredItems = items.where((item) {
              final String searchLower = searchQuery.toLowerCase();
              final String vNum = (item['vehicle_number'] ?? '').toString().toLowerCase();
              final String bNum = (item['bus_number'] ?? '').toString().toLowerCase();
              return vNum.contains(searchLower) || bNum.contains(searchLower);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, size: 20, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: "Search vehicle...",
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400, fontWeight: FontWeight.w700),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6366F1), size: 22),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (val) => setModalState(() => searchQuery = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: filteredItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.directions_bus_rounded, size: 48, color: Colors.black12),
                                const SizedBox(height: 16),
                                Text(
                                  searchQuery.isEmpty ? "No vehicles available" : "No matches found",
                                  style: const TextStyle(color: Colors.black38, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                            itemCount: filteredItems.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (ctx2, i) {
                              final item = filteredItems[i];
                              bool isSelected = selected != null && (item['id'] == selected['id']);
                              
                              String mainText = item['vehicle_number'] ?? 'Unknown';
                              String subText = item['bus_number'] != null 
                                  ? "${item['bus_number']} • Fuel: ${item['fuel_type'] ?? 'N/A'}"
                                  : "${item['vehicle_type_name'] ?? 'Vehicle'} • Fuel: ${item['fuel_type'] ?? 'N/A'}";
                              
                              return GestureDetector(
                                onTap: () {
                                  onSelect(item);
                                  Navigator.pop(ctx);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isSelected ? const Color(0xFF6366F1) : Colors.transparent, width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: (isSelected ? const Color(0xFF6366F1) : Colors.black).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          Icons.directions_bus_filled_rounded, 
                                          size: 20, 
                                          color: isSelected ? const Color(0xFF6366F1) : Colors.black54
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(mainText, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                                            const SizedBox(height: 4),
                                            Text(subText, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                      if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1), size: 20),
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
          },
        );
      },
    );
  }

  void _showFuelTypeSheet(bool isTamil) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    isTamil ? "எரிபொருள் வகையைத் தேர்ந்தெடுக்கவும்" : "Select Fuel Type",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 20, color: Colors.black54),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ..._availableFuelTypes.map((fuel) {
                final bool isSelected = _selectedFuelType == fuel;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedFuelType = fuel;
                        _errorMessage = null;
                      });
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.05) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_gas_station_rounded,
                            color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              fuel == 'AD_BLUE' ? 'AdBlue' : fuel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF6366F1), size: 24),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        );
      },
    );
  }
}
