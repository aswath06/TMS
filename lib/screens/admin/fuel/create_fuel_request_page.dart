import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../components/common/custom_date_time_picker.dart';
import '../../../utils/api_constants.dart';
import '../../../store/user_store.dart';
import 'package:tripzo/utils/api_error_parser.dart';

class CreateFuelRequestPage extends StatefulWidget {
  final Map<String, dynamic>? initialFuelData;
  final bool isApproveMode;
  final bool isCompletedEditMode;
  const CreateFuelRequestPage({super.key, this.initialFuelData, this.isApproveMode = false, this.isCompletedEditMode = false});

  @override
  State<CreateFuelRequestPage> createState() => _CreateFuelRequestPageState();
}

class _CreateFuelRequestPageState extends State<CreateFuelRequestPage> {
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _filledVolumeController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _editRemarkController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  File? _billImage;
  DateTime _selectedDate = DateTime.now();
  
  Map<String, dynamic>? _selectedVehicle;
  Map<String, dynamic>? _selectedDriver;
  Map<String, dynamic>? _selectedBunk;
  final TextEditingController _amountController = TextEditingController();

  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _bunks = [];
  bool _isLoadingVehicles = true;
  bool _isLoadingDrivers = true;
  bool _isLoadingBunks = true;
  bool _isSubmitting = false;
  String? _userRole;

  final List<Map<String, dynamic>> _fuelTypes = [
    {'id': 1, 'name': 'DIESEL'},
    {'id': 2, 'name': 'PETROL'},
    {'id': 3, 'name': 'CNG'},
    {'id': 4, 'name': 'AD_BLUE'},
  ];
  Map<String, dynamic>? _selectedFluidType;

  @override
  void initState() {
    super.initState();
    _volumeController.addListener(() => setState(() {}));
    _filledVolumeController.addListener(() => setState(() {}));
    _amountController.addListener(() => setState(() {}));

    if (widget.initialFuelData != null) {
      final data = widget.initialFuelData!;
      _volumeController.text = data['required_volume']?.toString() ?? data['filled_volume']?.toString() ?? '';
      _filledVolumeController.text = data['filled_volume']?.toString() ?? '';
      _amountController.text = data['bill_amount']?.toString() ?? '';
      _odometerController.text = data['current_odometer']?.toString() ?? data['odometer_reading']?.toString() ?? '';
      _remarksController.text = data['internal_ledger_remarks']?.toString() ?? '';
      
      if (data['fluid_type'] != null) {
        _selectedFluidType = _fuelTypes.firstWhere(
          (f) => f['name'].toString().toUpperCase() == data['fluid_type'].toString().toUpperCase(),
          orElse: () => _fuelTypes.first,
        );
      }
      
      if (data['filled_at'] != null) {
        try {
          _selectedDate = DateTime.parse(data['filled_at']).toLocal();
        } catch (_) {}
      }
    }

    _initializeRole();
    _fetchVehicles();
    _fetchDrivers();
    _fetchBunks();
  }

  Future<void> _initializeRole() async {
    final role = await UserStore.getRole();
    setState(() => _userRole = role?.toLowerCase());
  }

  String _amountToWords(int number) {
    if (number == 0) return "Zero";
    if (number < 0) return "Negative ${_amountToWords(-number)}";
    final ones = ["", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen", "Eighteen", "Nineteen"];
    final tens = ["", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"];
    
    String convert(int n) {
      if (n < 20) return ones[n];
      if (n < 100) return tens[n ~/ 10] + (n % 10 != 0 ? " ${ones[n % 10]}" : "");
      if (n < 1000) return "${ones[n ~/ 100]} Hundred${n % 100 != 0 ? " ${convert(n % 100)}" : ""}";
      if (n < 100000) return "${convert(n ~/ 1000)} Thousand${n % 1000 != 0 ? " ${convert(n % 1000)}" : ""}";
      if (n < 10000000) return "${convert(n ~/ 100000)} Lakh${n % 100000 != 0 ? " ${convert(n % 100000)}" : ""}";
      return "${convert(n ~/ 10000000)} Crore${n % 10000000 != 0 ? " ${convert(n % 10000000)}" : ""}";
    }
    return "${convert(number)} Rupees Only";
  }

  Future<void> _fetchBunks() async {
    try {
      final token = await UserStore.getToken();
      final role = await UserStore.getRole();
      final response = await http.get(
        Uri.parse(ApiConstants.fuelBunks),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<Map<String, dynamic>> fetchedBunks = List<Map<String, dynamic>>.from(responseData['data']);
          
          if (role?.toLowerCase() == 'driver') {
            fetchedBunks = fetchedBunks.where((b) {
              return b['owner_name']?.toString().toUpperCase().startsWith('BIT') != true;
            }).toList();
          }

          if (widget.initialFuelData != null) {
            final bId = widget.initialFuelData!['fuel_bunk_id'] ?? widget.initialFuelData!['bunk_id'] ?? widget.initialFuelData!['bunk']?['id'];
            if (bId != null) {
              final idx = fetchedBunks.indexWhere((b) => b['id'].toString() == bId.toString());
              if (idx != -1) _selectedBunk = fetchedBunks[idx];
            }
          }

          setState(() {
            _bunks = fetchedBunks;
            _isLoadingBunks = false;
          });
        }
      } else {
        setState(() => _isLoadingBunks = false);
        debugPrint(ApiErrorParser.parse(response, fallback: "Failed to load bunks"));
      }
    } catch (e) {
      setState(() => _isLoadingBunks = false);
      debugPrint("Error fetching bunks: $e");
    }
  }

  Future<void> _fetchDrivers() async {
    try {
      final token = await UserStore.getToken();
      final response = await http.get(
        Uri.parse(ApiConstants.getAllDriversWithoutPagination),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final fetchedDrivers = List<Map<String, dynamic>>.from(responseData['data']);
          Map<String, dynamic>? autoSelectedDriver;
          
          final role = await UserStore.getRole();
          if (widget.initialFuelData != null) {
            final dId = widget.initialFuelData!['driver_id'] ?? widget.initialFuelData!['driver']?['id'];
            if (dId != null) {
              final idx = fetchedDrivers.indexWhere((d) => d['id'].toString() == dId.toString());
              if (idx != -1) {
                autoSelectedDriver = fetchedDrivers[idx];
              }
            }
          } else if (role?.toLowerCase() == 'driver') {
            final dId = await UserStore.getDriverId();
            if (dId != null) {
              final idx = fetchedDrivers.indexWhere((d) => d['id'] == dId);
              if (idx != -1) {
                autoSelectedDriver = fetchedDrivers[idx];
              }
            }
          }

          setState(() {
            _drivers = fetchedDrivers;
            _selectedDriver = autoSelectedDriver ?? _selectedDriver;
            _isLoadingDrivers = false;
          });
        }
      } else {
        setState(() => _isLoadingDrivers = false);
        debugPrint(ApiErrorParser.parse(response, fallback: "Failed to load drivers"));
      }
    } catch (e) {
      setState(() => _isLoadingDrivers = false);
      debugPrint("Error fetching drivers: $e");
    }
  }

  Future<void> _fetchVehicles() async {
    try {
      final token = await UserStore.getToken();
      final response = await http.get(
        Uri.parse(ApiConstants.getAllVehiclesWithoutPagination),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final fetchedVehicles = List<Map<String, dynamic>>.from(responseData['data']);
          Map<String, dynamic>? preSelected;
          
          if (widget.initialFuelData != null) {
            final vId = widget.initialFuelData!['vehicle_id'] ?? widget.initialFuelData!['vehicle']?['id'];
            if (vId != null) {
              final idx = fetchedVehicles.indexWhere((v) => v['id'].toString() == vId.toString());
              if (idx != -1) preSelected = fetchedVehicles[idx];
            }
          }
          
          setState(() {
            _vehicles = fetchedVehicles;
            _selectedVehicle = preSelected ?? _selectedVehicle;
            
            if (_selectedVehicle != null && _selectedFluidType == null) {
              final vFuelType = (_selectedVehicle!['fuel_type'] ?? 'DIESEL').toString().toUpperCase();
              _selectedFluidType = _fuelTypes.firstWhere(
                (f) => f['name'] == vFuelType,
                orElse: () => _fuelTypes.first,
              );
            }
            
            _isLoadingVehicles = false;
          });
        }
      } else {
        setState(() => _isLoadingVehicles = false);
        debugPrint(ApiErrorParser.parse(response, fallback: "Failed to load vehicles"));
      }
    } catch (e) {
      setState(() => _isLoadingVehicles = false);
      debugPrint("Error fetching vehicles: $e");
    }
  }

  @override
  void dispose() {
    _volumeController.dispose();
    _filledVolumeController.dispose();
    _odometerController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isBITBunk => _selectedBunk?['owner_name']?.toString().toUpperCase().startsWith('BIT') == true;

  double get _pricePerLiter {
    if (_selectedBunk == null || _selectedVehicle == null) return 0.0;
    if (!_isBITBunk) return 0.0;

    final String fuelType = (_selectedVehicle?['fuel_type'] ?? '').toString().toUpperCase();
    if (fuelType == 'PETROL') {
      return double.tryParse(_selectedBunk?['petrol_price']?.toString() ?? '0.0') ?? 0.0;
    } else if (fuelType == 'DIESEL') {
      return double.tryParse(_selectedBunk?['diesel_price']?.toString() ?? '0.0') ?? 0.0;
    } else if (fuelType == 'CNG') {
      return double.tryParse(_selectedBunk?['cng_price']?.toString() ?? '0.0') ?? 0.0;
    }
    return 0.0;
  }

  String _getBunkPriceString(Map<String, dynamic> bunk) {
    if (_selectedVehicle == null) return "";
    final isBit = bunk['owner_name']?.toString().toUpperCase().startsWith('BIT') == true;
    if (!isBit) return "";
    
    final String fuelType = (_selectedVehicle?['fuel_type'] ?? '').toString().toUpperCase();
    double price = 0.0;
    if (fuelType == 'PETROL') {
      price = double.tryParse(bunk['petrol_price']?.toString() ?? '0.0') ?? 0.0;
    } else if (fuelType == 'DIESEL') {
      price = double.tryParse(bunk['diesel_price']?.toString() ?? '0.0') ?? 0.0;
    } else if (fuelType == 'CNG') {
      price = double.tryParse(bunk['cng_price']?.toString() ?? '0.0') ?? 0.0;
    }
    return " • ₹${price.toStringAsFixed(2)} / L ($fuelType)";
  }

  double get _totalAmount {
    if (widget.isCompletedEditMode) {
      if (_amountController.text.trim().isNotEmpty) {
        return double.tryParse(_amountController.text.trim()) ?? 0.0;
      }
      final volStr = _filledVolumeController.text.trim().isNotEmpty
          ? _filledVolumeController.text.trim()
          : _volumeController.text.trim();
      final vol = double.tryParse(volStr) ?? 0.0;
      return vol * _pricePerLiter;
    }
    if (_amountController.text.trim().isNotEmpty && !_isBITBunk) {
      return double.tryParse(_amountController.text.trim()) ?? 0.0;
    }
    if (_isBITBunk) {
      final vol = double.tryParse(_volumeController.text.trim()) ?? 0.0;
      return vol * _pricePerLiter;
    } else {
      return double.tryParse(_amountController.text.trim()) ?? 0.0;
    }
  }

  Future<void> _showSelectionSheet({
    required String title,
    required List<dynamic> items,
    required dynamic selected,
    required Function(dynamic) onSelect,
    required bool isVehicle,
    required bool isDriver,
    bool isFuelType = false,
  }) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color p = const Color(0xFF6366F1);
    final Color t = isDark ? Colors.white : const Color(0xFF0F172A);

    String searchQuery = "";

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            final List<dynamic> currentFilteredList = items.where((item) {
              if (searchQuery.isEmpty) return true;
              if (isVehicle) {
                final vNumber = (item['vehicle_number'] ?? "").toString().toLowerCase();
                final vType = (item['vehicle_type_name'] ?? "").toString().toLowerCase();
                final bNumber = (item['bus_number'] ?? "").toString().toLowerCase();
                return vNumber.contains(searchQuery.toLowerCase()) || 
                       vType.contains(searchQuery.toLowerCase()) ||
                       bNumber.contains(searchQuery.toLowerCase());
              } else if (isDriver) {
                final dName = (item['name'] ?? "").toString().toLowerCase();
                final dPhone = (item['phone'] ?? "").toString().toLowerCase();
                return dName.contains(searchQuery.toLowerCase()) || 
                       dPhone.contains(searchQuery.toLowerCase());
              } else if (isFuelType) {
                final fName = (item['name'] ?? "").toString().toLowerCase();
                return fName.contains(searchQuery.toLowerCase());
              } else {
                final bName = (item['name'] ?? "").toString().toLowerCase();
                final bOwner = (item['owner_name'] ?? "").toString().toLowerCase();
                return bName.contains(searchQuery.toLowerCase()) || 
                       bOwner.contains(searchQuery.toLowerCase());
              }
            }).toList();

            // Sort drivers to put default at top
            if (isDriver && _selectedVehicle != null && _selectedVehicle?['default_driver'] != null) {
              final defaultId = _selectedVehicle?['default_driver']?['id'];
              currentFilteredList.sort((a, b) {
                if (a['id'] == defaultId) return -1;
                if (b['id'] == defaultId) return 1;
                return 0;
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
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
                            color: t,
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
                            child: Icon(Icons.close_rounded, size: 20, color: t.withValues(alpha: 0.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Sleek Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t),
                        decoration: InputDecoration(
                          hintText: isVehicle ? "Search vehicle..." : "Search...",
                          hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white24 : Colors.grey.shade400, fontWeight: FontWeight.w700),
                          prefixIcon: Icon(Icons.search_rounded, color: p.withValues(alpha: 0.6), size: 22),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (val) => setModalState(() => searchQuery = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: currentFilteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(isVehicle ? Icons.directions_bus_rounded : Icons.person_off_rounded, size: 48, color: t.withValues(alpha: 0.1)),
                                const SizedBox(height: 16),
                                Text(
                                  searchQuery.isEmpty 
                                      ? (isDriver ? "No drivers available" : "No items available")
                                      : "No matches found", 
                                  style: TextStyle(color: t.withValues(alpha: 0.3), fontWeight: FontWeight.w600)
                                ),
                                if (searchQuery.isEmpty && isDriver) ...[
                                  const SizedBox(height: 24),
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _fetchDrivers();
                                    },
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text("Retry Loading Drivers"),
                                    style: TextButton.styleFrom(foregroundColor: p),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                            itemCount: currentFilteredList.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (ctx2, i) {
                              final item = currentFilteredList[i];
                              bool isSelected = selected != null && (item['id'] == selected['id']);
                              
                              String mainText = isVehicle 
                                  ? item['vehicle_number'] 
                                  : (isDriver 
                                      ? item['name'] 
                                      : item['name']);
                              String subText = isVehicle 
                                  ? "${item['bus_number'] != null ? '${item['bus_number']} • ' : ''}${item['default_driver'] != null ? 'Driver: ${item['default_driver']['name']}' : (item['vehicle_type_name'] ?? 'Vehicle')} • Fuel: ${item['fuel_type'] ?? 'N/A'}"
                                  : (isDriver 
                                      ? "${item['employee_code'] ?? 'N/A'} • ${(item['status'] ?? 'UNKNOWN').toString().replaceAll('_', ' ')} • 📞 ${item['phone'] ?? 'No Contact'}" 
                                      : (isFuelType ? "Fluid Type" : _getBunkPriceString(item)));
                              
                              return GestureDetector(
                                onTap: () {
                                  onSelect(item);
                                  Navigator.pop(ctx);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected ? p.withValues(alpha: 0.1) : t.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isSelected ? p : Colors.transparent, width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: (isSelected ? p : t).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          isVehicle ? Icons.directions_bus_filled_rounded : (isDriver ? Icons.person_rounded : Icons.store_rounded), 
                                          size: 20, 
                                          color: isSelected ? p : t.withValues(alpha: 0.5)
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(child: Text(mainText, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: t))),
                                                if (isDriver && _selectedVehicle != null && item['id'] == _selectedVehicle?['default_driver']?['id'])
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text("DEFAULT", style: TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.w900)),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(subText, style: TextStyle(fontSize: 12, color: t.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                      if (isSelected) Icon(Icons.check_circle_rounded, color: p, size: 20),
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
        ),
      ),
    );
  }

  void _showIndentPopup(String indentNumber, String vehicleNumber, {String title = "Indent Generated", String subtitle = "Your fuel indent number is:"}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_bus_rounded, color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      vehicleNumber,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Text(
                  indentNumber,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.blue,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context, true); // Return to list with success
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    "Close",
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isApproveMode 
              ? "Approve Fuel Log"
              : widget.isCompletedEditMode
                  ? "Edit Fuel Log"
                  : widget.initialFuelData != null 
                      ? "Update Fuel Log" 
                      : "Generate Indent",
          style: GoogleFonts.plusJakartaSans(
            color: titleColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isCompletedEditMode) ...[
              _buildSelectTile(
                "Select Vehicle",
                _selectedVehicle?['vehicle_number'] ?? "Choose Vehicle",
                _selectedVehicle != null
                    ? "${_selectedVehicle?['vehicle_type_name'] ?? 'Vehicle'} • Fuel: ${_selectedVehicle?['fuel_type'] ?? 'N/A'}"
                    : null,
                Icons.directions_bus_filled_rounded,
                _selectedVehicle != null,
                () {
                  if (_isLoadingVehicles) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Loading vehicles, please wait...")),
                    );
                    return;
                  }
                  _showSelectionSheet(
                    title: "Select Vehicle",
                    items: _vehicles,
                    selected: _selectedVehicle,
                    onSelect: (v) {
                      setState(() {
                        _selectedVehicle = v;
                        final vFuelType = (v['fuel_type'] ?? 'DIESEL').toString().toUpperCase();
                        _selectedFluidType = _fuelTypes.firstWhere(
                          (f) => f['name'] == vFuelType,
                          orElse: () => _fuelTypes.first,
                        );
                        if (_userRole != 'driver') {
                          if (v['default_driver'] != null) {
                            try {
                              _selectedDriver = _drivers.firstWhere(
                                (d) => d['id'] == v['default_driver']['id'] || d['name'] == v['default_driver']['name']
                              );
                            } catch (e) {
                              _selectedDriver = v['default_driver'];
                            }
                          } else {
                            _selectedDriver = null;
                          }
                        }
                      });
                    },
                    isVehicle: true,
                    isDriver: false,
                  );
                },
                surfaceColor, titleColor, isDark, primaryBlue,
                defaultDriver: _selectedVehicle?['default_driver']?['name'],
                isRequired: true,
                isLoading: _isLoadingVehicles,
              ),
              if (_userRole != 'driver') ...[
                const SizedBox(height: 12),
                _buildSelectTile(
                  "Driver Assignment",
                  _selectedDriver?['name'] ?? "Choose Driver",
                  _selectedDriver != null ? "📞 ${_selectedDriver?['phone'] ?? 'No Contact'}" : null,
                  Icons.person_rounded,
                  _selectedDriver != null,
                  () {
                    if (_isLoadingDrivers) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Loading drivers, please wait...")),
                      );
                      return;
                    }
                    _showSelectionSheet(
                      title: "Select Driver",
                      items: _drivers,
                      selected: _selectedDriver,
                      onSelect: (d) => setState(() => _selectedDriver = d),
                      isVehicle: false,
                      isDriver: true,
                    );
                  },
                  surfaceColor, titleColor, isDark, primaryBlue,
                  isDefault: _selectedVehicle != null && 
                            _selectedVehicle?['default_driver'] != null && 
                            _selectedVehicle?['default_driver']?['name'] == _selectedDriver?['name'],
                  isRequired: true,
                  isLoading: _isLoadingDrivers,
                ),
              ],
              const SizedBox(height: 12),
              _buildSelectTile(
                "Fuel Bunk Name",
                _selectedBunk != null 
                    ? _selectedBunk!['name'] 
                    : "Choose Fuel Bunk",
                null,
                Icons.store_rounded,
                _selectedBunk != null,
                () {
                  if (_isLoadingBunks) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Loading bunks, please wait...")),
                    );
                    return;
                  }
                  _showSelectionSheet(
                    title: "Select Fuel Bunk",
                    items: _bunks,
                    selected: _selectedBunk,
                    onSelect: (b) => setState(() => _selectedBunk = b),
                    isVehicle: false,
                    isDriver: false,
                  );
                },
                surfaceColor, titleColor, isDark, primaryBlue,
                isRequired: true,
                isLoading: _isLoadingBunks,
              ),
              if (_selectedBunk != null) ...[
                const SizedBox(height: 12),
                _buildSelectTile(
                  "Fluid Type",
                  _selectedFluidType != null ? _selectedFluidType!['name'] : "Choose Fluid Type",
                  null,
                  Icons.local_gas_station_rounded,
                  _selectedFluidType != null,
                  () {
                    List<Map<String, dynamic>> allowedFuelTypes = [];
                    if (_selectedVehicle != null) {
                      final vFuelType = (_selectedVehicle!['fuel_type'] ?? 'DIESEL').toString().toUpperCase();
                      final isAdBlue = _selectedVehicle!['is_adblue'] == true || _selectedVehicle!['is_adblue'] == 1;
                      
                      allowedFuelTypes = _fuelTypes.where((f) {
                        if (f['name'] == vFuelType) return true;
                        if (f['name'] == 'AD_BLUE' && isAdBlue) return true;
                        return false;
                      }).toList();
                    } else {
                      allowedFuelTypes = _fuelTypes;
                    }

                    _showSelectionSheet(
                      title: "Select Fluid Type",
                      items: allowedFuelTypes,
                      selected: _selectedFluidType,
                      onSelect: (f) => setState(() => _selectedFluidType = f),
                      isVehicle: false,
                      isDriver: false,
                      isFuelType: true,
                    );
                  },
                  surfaceColor, titleColor, isDark, primaryBlue,
                  isRequired: true,
                ),
              ],
              const SizedBox(height: 24),
            ],
            
            if (widget.isCompletedEditMode || _selectedBunk != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(widget.isCompletedEditMode ? "Filled Volume" : (_isBITBunk ? "Required Volume" : "Volume"), primaryBlue, isRequired: true),
                        const SizedBox(height: 12),
                        _buildTextField(widget.isCompletedEditMode ? _filledVolumeController : _volumeController, "e.g. 50", Icons.opacity_rounded, surfaceColor, titleColor, isDark, isNumber: true),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel(widget.isCompletedEditMode ? "Date & Time" : "Date", primaryBlue, isRequired: true),
                        const SizedBox(height: 12),
                        _buildDatePickerTile(surfaceColor, titleColor, isDark, primaryBlue, showTime: widget.isCompletedEditMode),
                      ],
                    ),
                  ),
                ],
              ),
              
              if ((_selectedBunk != null && !_isBITBunk) || widget.isCompletedEditMode) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel("Odometer", primaryBlue, isRequired: true),
                          const SizedBox(height: 12),
                          _buildTextField(_odometerController, "e.g. 45200", Icons.speed_rounded, surfaceColor, titleColor, isDark, isNumber: true),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Spacer(),
                  ],
                ),
                if (!widget.isCompletedEditMode) ...[
                  const SizedBox(height: 24),
                  _buildLabel("Bill Image", primaryBlue, isRequired: true),
                  const SizedBox(height: 12),
                  _buildImagePicker(surfaceColor, titleColor, isDark, primaryBlue),
                ],
              ],
            ],
            
            if (!widget.isCompletedEditMode) ...[
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("Remarks (Optional)", primaryBlue),
                  const SizedBox(height: 12),
                  _buildTextField(_remarksController, "e.g. Special trip for BIT", Icons.notes_rounded, surfaceColor, titleColor, isDark),
                ],
              ),
            ],
            if (widget.isCompletedEditMode) ...[
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("Reason for Edit", primaryBlue, isRequired: true),
                  const SizedBox(height: 12),
                  _buildTextField(_editRemarkController, "e.g. Wrong odometer reading entered previously", Icons.edit_note_rounded, surfaceColor, titleColor, isDark),
                ],
              ),
            ],
            const SizedBox(height: 40),
            if (_selectedBunk != null) ...[
              const SizedBox(height: 24),
              _buildLabel(_isBITBunk ? "Estimated Cost" : "Filled Amount", primaryBlue),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isBITBunk ? "AUTO CALCULATION" : "MANUAL ENTRY",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: subColor,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isBITBunk 
                                  ? "₹${_pricePerLiter.toStringAsFixed(2)} / liter (${_selectedVehicle?['fuel_type'] ?? 'N/A'})" 
                                  : "Enter total amount",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: primaryBlue,
                              ),
                            ),
                          ],
                        ),
                        if (_isBITBunk)
                          Text(
                            "₹${_totalAmount.toStringAsFixed(2)}",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                            ),
                          ),
                      ],
                    ),
                    if (!_isBITBunk || widget.isCompletedEditMode) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: _buildTextField(_amountController, "Amount", Icons.payments_rounded, Colors.transparent, titleColor, isDark, isNumber: true),
                      ),
                      if (_totalAmount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                          child: Text(
                            _amountToWords(_totalAmount.toInt()),
                            style: TextStyle(
                              color: primaryBlue,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            _buildCreateButton(primaryBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color color, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 1.2,
          ),
        ),
        if (isRequired)
          const Text(" *", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSelectTile(
    String label, 
    String value, 
    String? subValue,
    IconData icon, 
    bool hasValue, 
    VoidCallback onTap, 
    Color surface, 
    Color title, 
    bool isDark, 
    Color primary, 
    {bool isDefault = false, String? defaultDriver, bool isRequired = false, bool isLoading = false}
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: title.withValues(alpha: 0.04), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel(label, primary, isRequired: isRequired),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (hasValue ? primary : title).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon, 
                    color: hasValue ? primary : title.withValues(alpha: 0.3), 
                    size: 20
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: hasValue ? title : title.withValues(alpha: 0.3),
                        ),
                      ),
                      if (subValue != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subValue,
                          style: TextStyle(
                            fontSize: 12,
                            color: title.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (defaultDriver != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "DEFAULT: $defaultDriver",
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isDefault) 
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: const Text(
                      "DEFAULT", 
                      style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w900)
                    ),
                  ),
                if (isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  )
                else
                  Icon(Icons.expand_more_rounded, color: title.withValues(alpha: 0.2), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, Color surface, Color title, bool isDark, {bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: title.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: TextStyle(color: title, fontWeight: FontWeight.bold, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.blue.withValues(alpha: 0.3), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildDatePickerTile(Color surface, Color title, bool isDark, Color primary, {bool showTime = false}) {
    return GestureDetector(
      onTap: () async {
        final picked = await CustomDateTimePicker.show(
          context,
          initialDate: _selectedDate,
          showTime: showTime,
          maxDate: DateTime.now(),
          accent: primary,
          titleColor: title,
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: title.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: primary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                showTime ? DateFormat('MMM dd, hh:mm a').format(_selectedDate) : DateFormat('MMM dd').format(_selectedDate),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: title,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton(Color primary) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _generateFuelRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          elevation: 8,
          shadowColor: primary.withValues(alpha: 0.4),
        ),
        child: _isSubmitting 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(
              widget.isApproveMode 
                  ? "APPROVE FUEL LOG" 
                  : (widget.isCompletedEditMode ? "SAVE EDITS" : (widget.initialFuelData != null ? "UPDATE FUEL LOG" : (_isBITBunk ? "GENERATE INDENT" : "COMPLETE FUEL LOG"))),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
      ),
    );
  }

  Widget _buildImagePicker(Color surface, Color title, bool isDark, Color primary) {
    String? existingImageUrl;
    if (widget.initialFuelData != null && widget.initialFuelData!['bill_file_url'] != null) {
      existingImageUrl = widget.initialFuelData!['bill_file_url'];
      if (existingImageUrl!.startsWith('/')) {
        existingImageUrl = "${ApiConstants.baseUrl}$existingImageUrl";
      }
    }

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: title.withValues(alpha: 0.05)),
          image: _billImage != null 
              ? DecorationImage(image: FileImage(_billImage!), fit: BoxFit.cover) 
              : (existingImageUrl != null 
                  ? DecorationImage(image: NetworkImage(existingImageUrl, headers: const {ApiConstants.bypassHeaderKey: ApiConstants.bypassHeaderValue}), fit: BoxFit.cover) 
                  : null),
        ),
        child: (_billImage == null && existingImageUrl == null) ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_rounded, color: primary.withValues(alpha: 0.5), size: 32),
            const SizedBox(height: 8),
            Text("Tap to upload bill receipt", style: TextStyle(color: title.withValues(alpha: 0.3), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ) : Container(
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(child: Icon(Icons.edit_rounded, color: Colors.white)),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: titleColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Select Bill Image",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildSourceTile(
                    Icons.camera_alt_rounded,
                    "Camera",
                    () async {
                      Navigator.pop(context);
                      final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
                      if (picked != null) setState(() => _billImage = File(picked.path));
                    },
                    primaryBlue, titleColor, isDark,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSourceTile(
                    Icons.photo_library_rounded,
                    "Gallery",
                    () async {
                      Navigator.pop(context);
                      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
                      if (picked != null) setState(() => _billImage = File(picked.path));
                    },
                    primaryBlue, titleColor, isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceTile(IconData icon, String label, VoidCallback onTap, Color primary, Color title, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: primary.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: primary, size: 32),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: title,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateFuelRequest() async {
    // Validation
    bool hasBasicFields = _selectedVehicle != null && 
                          (_userRole == 'driver' || _selectedDriver != null) && 
                          _selectedBunk != null && 
                          _volumeController.text.isNotEmpty;
    
    if (!hasBasicFields) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields")));
      return;
    }

    if (!_isBITBunk) {
      if (_odometerController.text.isEmpty || _amountController.text.isEmpty || _billImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields and upload bill image for Non-BIT bunk"), backgroundColor: Colors.red));
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await UserStore.getToken();
      final bool isEdit = widget.initialFuelData != null;
      
      final uri = widget.isApproveMode 
          ? Uri.parse(ApiConstants.approveFuelLog(widget.initialFuelData!['id']))
          : (isEdit 
              ? Uri.parse(ApiConstants.updateFuelLog(widget.initialFuelData!['id']))
              : Uri.parse(ApiConstants.fuelLog));
          
      final headers = ApiConstants.getHeaders(token);
      
      final Map<String, String> fields = {
        'vehicle_id': _selectedVehicle!['id'].toString(),
        'bunk_id': _selectedBunk!['id'].toString(),
        'required_volume': _volumeController.text,
        'filled_at': _selectedDate.toIso8601String(),
        'remarks': _remarksController.text,
        'bill_amount': _totalAmount.toString(),
        'current_odometer': _odometerController.text,
      };

      if (_selectedDriver != null) {
        fields['driver_id'] = _selectedDriver!['id'].toString();
      }

      if (_selectedFluidType != null) {
        fields['fluid_type'] = _selectedFluidType!['name'];
      }

      if (!_isBITBunk) {
        fields['filled_volume'] = _volumeController.text; // Sending same as required_volume
      }

      http.Response response;

      if (widget.isApproveMode) {
        // Approve endpoint expects JSON, not multipart/form-data
        headers['Content-Type'] = 'application/json';
        
        log("\n--- REQUEST CURL ---\ncurl --location --request PATCH '$uri' \\");
        headers.forEach((k, v) => log("--header '$k: $v' \\"));
        log("--data '${json.encode(fields)}'\n-------------------\n");

        response = await http.patch(uri, headers: headers, body: json.encode(fields));
      } else if (widget.isCompletedEditMode) {
        if (_editRemarkController.text.isEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide a reason for the edit", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
          setState(() => _isSubmitting = false);
          return;
        }
        headers['Content-Type'] = 'application/json';
        final editFields = {
          'new_odometer': _odometerController.text,
          'new_price': _totalAmount.toString(),
          'new_filled_at': _selectedDate.toUtc().toIso8601String(),
          'new_volume': _filledVolumeController.text,
          'remark': _editRemarkController.text,
        };
        final editUri = Uri.parse(ApiConstants.editCompletedFuelLog(widget.initialFuelData!['id']));
        response = await http.put(editUri, headers: headers, body: json.encode(editFields));
      } else {
        var request = http.MultipartRequest(isEdit ? 'PUT' : 'POST', uri);
        request.headers.addAll(headers);
        request.fields.addAll(fields);
        
        if (!_isBITBunk && _billImage != null) {
          request.files.add(await http.MultipartFile.fromPath('bill_file', _billImage!.path));
        }

        // Console log curl equivalent
        StringBuffer curl = StringBuffer();
        curl.write('curl --location --request ${isEdit ? 'PUT' : 'POST'} ');
        curl.write("'$uri' \\\n");
        headers.forEach((k, v) => curl.write("--header '$k: $v' \\\n"));
        request.fields.forEach((k, v) => curl.write("--form '$k=\"$v\"' \\\n"));
        if (_billImage != null) curl.write("--form 'bill_file=@\"${_billImage!.path}\"'");
        log("\n--- REQUEST CURL ---\n${curl.toString()}\n-------------------\n");

        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      }

      log("\n--- FUEL LOG RESPONSE ---\nStatus: ${response.statusCode}\nBody: ${response.body}\n-------------------\n");
      log(ApiErrorParser.parse(response, fallback: "\n--- PARSED RESPONSE ---\nStatus"));
      if (!mounted) return;

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final instanceId = responseData['data']?['instance_id'] ?? responseData['fuelLog']?['instance_id'] ?? "SUCCESS";
          final successMessage = responseData['message'] ?? (widget.isApproveMode ? "Fuel order approved successfully" : (isEdit ? "Fuel order updated successfully" : "Success"));
          
          if (widget.isApproveMode) {
            if (_userRole != 'driver' && _selectedBunk != null) {
              final bunkName = _selectedBunk!['name']?.toString().toLowerCase() ?? '';
              if (!bunkName.contains('other')) {
                await _createAdminRoute(instanceId);
              }
            }

            _showIndentPopup(
              instanceId, 
              _selectedVehicle!['vehicle_number'] ?? 'Unknown Vehicle',
              title: successMessage,
              subtitle: "Indent Number:"
            );
          } else if (isEdit) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(successMessage),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true); // Return true to indicate refresh needed
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(successMessage),
                backgroundColor: Colors.green,
              ),
            );

            if (_userRole != 'driver' && _selectedBunk != null) {
              final bunkName = _selectedBunk!['name']?.toString().toLowerCase() ?? '';
              if (!bunkName.contains('other')) {
                await _createAdminRoute(instanceId);
              }
            }

            _showIndentPopup(instanceId, _selectedVehicle!['vehicle_number'] ?? 'Unknown Vehicle');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? "Error"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        String errorMsg = "Something went wrong, please try again";
        try {
          final Map<String, dynamic> responseData = json.decode(response.body);
          if (responseData['message'] != null) {
            errorMsg = responseData['message'];
          }
        } catch (_) {}
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Network error"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _createAdminRoute(String indentNumber) async {
    try {
      final token = await UserStore.getToken();
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final startTimeStr = "${DateFormat('yyyy-MM-ddTHH:mm:00').format(now)}+05:30";
      final endTimeStr = "${DateFormat('yyyy-MM-ddTHH:mm:00').format(now.add(const Duration(hours: 2)))}+05:30";
      final returnEndTimeStr = "${DateFormat('yyyy-MM-ddTHH:mm:00').format(now.add(const Duration(hours: 4)))}+05:30";
      
      final routeName = "${indentNumber}_$dateStr";
      final bunkName = _selectedBunk!['name']?.toString() ?? "Bunk";
      final bunkAddress = _selectedBunk!['address']?.toString() ?? bunkName;
      final bunkLat = double.tryParse(_selectedBunk!['latitude']?.toString() ?? '11.3468483') ?? 11.3468483;
      final bunkLng = double.tryParse(_selectedBunk!['longitude']?.toString() ?? '77.720001') ?? 77.720001;
      
      final vehicleId = _selectedVehicle?['id'] ?? 1;
      final driverId = _selectedDriver?['id'] ?? 1;

      final body = {
        "route_name": routeName,
        "trip_type": "ROUND_TRIP",
        "requested_for_date": dateStr,
        "start_datetime": startTimeStr,
        "end_datetime": returnEndTimeStr,
        "purpose": "Fuel filling",
        "passenger_count": 1,
        "vehicle_count": 1,
        "suggested_vehicle_type_id": 1,
        "luggage_details": "",
        "special_instructions": "",
        "approx_distance_km": 55.8553,
        "approx_duration_minutes": 83,
        "passengers": [
          {
            "passenger_name": "guest",
            "phone": "1234567890",
            "country_code": "+91",
            "is_primary_contact": true
          }
        ],
        "department_id": 1,
        "stops": [
          {
            "stop_name": "Bannari Amman Institute of Technology",
            "address": "Bannari Amman Institute of Technology",
            "latitude": 11.49518076229493,
            "longitude": 77.27954948427481,
            "stop_order": 1,
            "stop_type": "START"
          },
          {
            "stop_name": bunkName,
            "address": bunkAddress,
            "latitude": bunkLat,
            "longitude": bunkLng,
            "stop_order": 2,
            "stop_type": "END"
          }
        ],
        "legs": [
          {
            "leg_code": "LEG-1",
            "leg_type": "OUTBOUND",
            "travel_direction": "START_TO_END",
            "planned_start_at": startTimeStr,
            "planned_end_at": endTimeStr,
            "required_vehicle_count": 1,
            "stops": [
              {
                "stop_name": "Bannari Amman Institute of Technology",
                "address": "Bannari Amman Institute of Technology",
                "latitude": 11.49518076229493,
                "longitude": 77.27954948427481,
                "stop_order": 1,
                "stop_type": "START"
              },
              {
                "stop_name": bunkName,
                "address": bunkAddress,
                "latitude": bunkLat,
                "longitude": bunkLng,
                "stop_order": 2,
                "stop_type": "END"
              }
            ],
            "linked_leg_index": null,
            "allow_same_vehicle_as_linked_leg": true
          },
          {
            "leg_code": "LEG-2",
            "leg_type": "RETURN",
            "travel_direction": "END_TO_START",
            "planned_start_at": endTimeStr,
            "planned_end_at": returnEndTimeStr,
            "required_vehicle_count": 1,
            "stops": [
              {
                "stop_name": bunkName,
                "address": bunkAddress,
                "latitude": bunkLat,
                "longitude": bunkLng,
                "stop_order": 1,
                "stop_type": "START"
              },
              {
                "stop_name": "Bannari Amman Institute of Technology",
                "address": "Bannari Amman Institute of Technology",
                "latitude": 11.49518076229493,
                "longitude": 77.27954948427481,
                "stop_order": 2,
                "stop_type": "END"
              }
            ],
            "linked_leg_index": 0,
            "allow_same_vehicle_as_linked_leg": true
          }
        ],
        "admin_assignments": [
          {
            "leg_code": "LEG-1",
            "vehicles": [
              {
                "vehicle_id": vehicleId,
                "driver_id": driverId,
                "passenger_ids": [1]
              }
            ]
          },
          {
            "leg_code": "LEG-2",
            "vehicles": [
              {
                "vehicle_id": vehicleId,
                "driver_id": driverId,
                "passenger_ids": [1]
              }
            ]
          }
        ]
      };

      StringBuffer curl = StringBuffer();
      curl.write('curl --location ');
      curl.write("'${ApiConstants.adminCreateFull}' \\\n");
      final headers = ApiConstants.getHeaders(token);
      headers.forEach((k, v) => curl.write("--header '$k: $v' \\\n"));
      if (!headers.containsKey('Content-Type')) {
        curl.write("--header 'Content-Type: application/json' \\\n");
      }
      curl.write("--data '${json.encode(body)}'");
      log("\n--- ADMIN CURL SENDING (Main Journey) ---\n${curl.toString()}\n-------------------\n");

      final response = await http.post(
        Uri.parse(ApiConstants.adminCreateFull),
        headers: headers..addAll({'Content-Type': 'application/json'}),
        body: json.encode(body),
      );
      
      log("📥 [SERVER RESPONSE (Main Journey)] (${response.statusCode}): ${response.body}");

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        try {
          final responseData = json.decode(response.body);
          if (responseData['success'] == false || (response.statusCode != 200 && response.statusCode != 201)) {
            final message = responseData['message'] ?? 'Failed to create admin route';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Admin Route Error: $message"),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          } else {
            final message = responseData['message'] ?? 'Admin Route created successfully';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } catch (_) {
          if (response.statusCode != 200 && response.statusCode != 201) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to create admin route'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      log("Error creating admin route: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error creating admin route"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
