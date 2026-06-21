import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import '../../../components/common/custom_date_time_picker.dart';
import '../../../utils/api_constants.dart';
import '../../../store/user_store.dart';

class CreateFuelRequestPage extends StatefulWidget {
  const CreateFuelRequestPage({super.key});

  @override
  State<CreateFuelRequestPage> createState() => _CreateFuelRequestPageState();
}

class _CreateFuelRequestPageState extends State<CreateFuelRequestPage> {
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _filledVolumeController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    _volumeController.addListener(() => setState(() {}));
    _amountController.addListener(() => setState(() {}));
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
      if (n < 1000) return "${ones[n ~/ 100]} Hundred" + (n % 100 != 0 ? " ${convert(n % 100)}" : "");
      if (n < 100000) return "${convert(n ~/ 1000)} Thousand" + (n % 1000 != 0 ? " ${convert(n % 1000)}" : "");
      if (n < 10000000) return "${convert(n ~/ 100000)} Lakh" + (n % 100000 != 0 ? " ${convert(n % 100000)}" : "");
      return "${convert(n ~/ 10000000)} Crore" + (n % 10000000 != 0 ? " ${convert(n % 10000000)}" : "");
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

          setState(() {
            _bunks = fetchedBunks;
            _isLoadingBunks = false;
          });
        }
      } else {
        setState(() => _isLoadingBunks = false);
        debugPrint("Failed to load bunks: ${response.statusCode}");
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
          if (role?.toLowerCase() == 'driver') {
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
        debugPrint("Failed to load drivers: ${response.statusCode}");
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
          setState(() {
            _vehicles = List<Map<String, dynamic>>.from(responseData['data']);
            _isLoadingVehicles = false;
          });
        }
      } else {
        setState(() => _isLoadingVehicles = false);
        debugPrint("Failed to load vehicles: ${response.statusCode}");
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
    return " • ₹${price.toStringAsFixed(2)} / L (${fuelType})";
  }

  double get _totalAmount {
    if (_isBITBunk) {
      final vol = double.tryParse(_volumeController.text) ?? 0.0;
      return vol * _pricePerLiter;
    } else {
      return double.tryParse(_amountController.text) ?? 0.0;
    }
  }

  Future<void> _showSelectionSheet({
    required String title,
    required List<dynamic> items,
    required dynamic selected,
    required Function(dynamic) onSelect,
    required bool isVehicle,
    required bool isDriver,
  }) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color p = const Color(0xFF6366F1);
    final Color t = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color s = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

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
                return vNumber.contains(searchQuery.toLowerCase()) || 
                       vType.contains(searchQuery.toLowerCase());
              } else if (isDriver) {
                final dName = (item['name'] ?? "").toString().toLowerCase();
                final dPhone = (item['phone'] ?? "").toString().toLowerCase();
                return dName.contains(searchQuery.toLowerCase()) || 
                       dPhone.contains(searchQuery.toLowerCase());
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
                                      : (item['owner_name']?.toString().toUpperCase().startsWith('BIT') == true ? item['owner_name'] : item['name']));
                              String subText = isVehicle 
                                  ? "${item['default_driver'] != null ? 'Driver: ' + item['default_driver']['name'] : (item['vehicle_type_name'] ?? 'Vehicle')} • Fuel: ${item['fuel_type'] ?? 'N/A'}"
                                  : (isDriver 
                                      ? "${item['employee_code'] ?? 'N/A'} • ${(item['status'] ?? 'UNKNOWN').toString().replaceAll('_', ' ')} • 📞 ${item['phone'] ?? 'No Contact'}" 
                                      : "Owner: ${item['owner_name'] ?? 'Unknown'}${_getBunkPriceString(item)}");
                              
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

  void _showIndentPopup(String indentNumber) {
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
                "Request Generated",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Your fuel indent number is:",
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
          "Generate Indent",
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
              ),
            ],
            const SizedBox(height: 12),
            _buildSelectTile(
              "Fuel Bunk Name",
              _selectedBunk != null 
                  ? (_isBITBunk ? _selectedBunk!['owner_name'] : _selectedBunk!['name']) 
                  : "Choose Fuel Bunk",
              _selectedBunk != null ? "Owner: ${_selectedBunk?['owner_name']}" : null,
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
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel(_isBITBunk ? "Required Volume" : "Volume", primaryBlue, isRequired: true),
                      const SizedBox(height: 12),
                      _buildTextField(_volumeController, "e.g. 50", Icons.opacity_rounded, surfaceColor, titleColor, isDark, isNumber: true),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Date", primaryBlue, isRequired: true),
                      const SizedBox(height: 12),
                      _buildDatePickerTile(surfaceColor, titleColor, isDark, primaryBlue),
                    ],
                  ),
                ),
              ],
            ),
            
            if (_selectedBunk != null && !_isBITBunk) ...[
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
                  const Spacer(), // Keeps layout consistent
                ],
              ),
              const SizedBox(height: 24),
              _buildLabel("Bill Image", primaryBlue, isRequired: true),
              const SizedBox(height: 12),
              _buildImagePicker(surfaceColor, titleColor, isDark, primaryBlue),
            ],

            const SizedBox(height: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel("Remarks (Optional)", primaryBlue),
                const SizedBox(height: 12),
                _buildTextField(_remarksController, "e.g. Special trip for BIT", Icons.notes_rounded, surfaceColor, titleColor, isDark),
              ],
            ),
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
                    if (!_isBITBunk) ...[
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
    {bool isDefault = false, String? defaultDriver, bool isRequired = false}
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

  Widget _buildDatePickerTile(Color surface, Color title, bool isDark, Color primary) {
    return GestureDetector(
      onTap: () async {
        final picked = await CustomDateTimePicker.show(
          context,
          initialDate: _selectedDate,
          showTime: false,
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
            Text(
              DateFormat('MMM dd').format(_selectedDate),
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
              _isBITBunk ? "GENERATE INDENT" : "COMPLETE FUEL LOG",
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
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: title.withValues(alpha: 0.05)),
          image: _billImage != null ? DecorationImage(image: FileImage(_billImage!), fit: BoxFit.cover) : null,
        ),
        child: _billImage == null ? Column(
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
      var request = http.MultipartRequest('POST', Uri.parse(ApiConstants.fuelLog));
      request.headers.addAll(ApiConstants.getHeaders(token));
      
      request.fields['vehicle_id'] = _selectedVehicle!['id'].toString();
      if (_selectedDriver != null) {
        request.fields['driver_id'] = _selectedDriver!['id'].toString();
      }
      request.fields['bunk_id'] = _selectedBunk!['id'].toString();
      request.fields['required_volume'] = _volumeController.text;
      request.fields['filled_at'] = _selectedDate.toIso8601String();
      request.fields['remarks'] = _remarksController.text;
      request.fields['bill_amount'] = _totalAmount.toString();

      if (!_isBITBunk) {
        request.fields['current_odometer'] = _odometerController.text;
        request.fields['filled_volume'] = _volumeController.text; // Sending same as required_volume
        request.files.add(await http.MultipartFile.fromPath('bill_file', _billImage!.path));
      }

      // Console log curl equivalent
      StringBuffer curl = StringBuffer();
      curl.write('curl --location ');
      if (!_isBITBunk) curl.write('--request POST ');
      curl.write("'${ApiConstants.fuelLog}' \\\n");
      ApiConstants.getHeaders(token).forEach((k, v) => curl.write("--header '$k: $v' \\\n"));
      request.fields.forEach((k, v) => curl.write("--form '$k=\"$v\"' \\\n"));
      if (_billImage != null) curl.write("--form 'bill_file=@\"${_billImage!.path}\"'");
      log("\n--- REQUEST CURL ---\n${curl.toString()}\n-------------------\n");

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      log("\n--- RESPONSE ---\nStatus: ${response.statusCode}\nBody: ${response.body}\n----------------\n");

      if (response.statusCode == 201 || response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final instanceId = responseData['data']['instance_id'] ?? "SUCCESS";
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? "Success"),
              backgroundColor: Colors.green,
            ),
          );

          _showIndentPopup(instanceId);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Network error"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}
