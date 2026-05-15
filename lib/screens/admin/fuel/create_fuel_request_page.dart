import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../components/common/custom_date_time_picker.dart';

class CreateFuelRequestPage extends StatefulWidget {
  const CreateFuelRequestPage({super.key});

  @override
  State<CreateFuelRequestPage> createState() => _CreateFuelRequestPageState();
}

class _CreateFuelRequestPageState extends State<CreateFuelRequestPage> {
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  
  Map<String, dynamic>? _selectedVehicle;
  Map<String, dynamic>? _selectedDriver;
  String? _selectedBunk;

  final double _fuelPricePerLiter = 100.0; // Default price as requested

  // Mock data for demo
  final List<Map<String, dynamic>> _vehicles = [
    {"id": 1, "number": "TN 37 B 1234", "type": "SUV", "default_driver": {"id": 101, "name": "Rajesh Kumar"}},
    {"id": 2, "number": "TN 38 C 5678", "type": "Bus", "default_driver": {"id": 102, "name": "Suresh Raina"}},
    {"id": 3, "number": "TN 39 D 9012", "type": "Truck", "default_driver": null},
  ];

  final List<Map<String, dynamic>> _drivers = [
    {"id": 101, "name": "Rajesh Kumar", "phone": "9876543210"},
    {"id": 102, "name": "Suresh Raina", "phone": "9876543211"},
    {"id": 103, "name": "MS Dhoni", "phone": "9876543212"},
    {"id": 104, "name": "Virat Kohli", "phone": "9876543213"},
  ];

  final List<String> _bunks = ["HP Fuel - Kovai Road", "Indian Oil - Sathyamangalam", "Bharat Petroleum - Anthiyur", "Other"];

  @override
  void initState() {
    super.initState();
    _volumeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _volumeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double get _totalAmount {
    final vol = double.tryParse(_volumeController.text) ?? 0.0;
    return vol * _fuelPricePerLiter;
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
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    List<dynamic> filteredItems = List.from(items);
    _searchController.clear();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: titleColor)),
                        const Spacer(),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded))
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: titleColor),
                        decoration: InputDecoration(
                          hintText: "Search...",
                          hintStyle: TextStyle(color: subColor.withValues(alpha: 0.5)),
                          border: InputBorder.none,
                          icon: Icon(Icons.search_rounded, color: primaryBlue, size: 20),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            filteredItems = items.where((item) {
                              final String searchTarget = isVehicle 
                                  ? item['number'].toString().toLowerCase() 
                                  : (isDriver ? item['name'].toString().toLowerCase() : item.toString().toLowerCase());
                              return searchTarget.contains(val.toLowerCase());
                            }).toList();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                      itemCount: filteredItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final item = filteredItems[i];
                        bool isSelected = false;
                        if (isVehicle || isDriver) {
                          isSelected = selected != null && (item['id'] == selected['id']);
                        } else {
                          isSelected = selected == item;
                        }
                        
                        String mainText = isVehicle ? item['number'] : (isDriver ? item['name'] : item.toString());
                        String subText = isVehicle ? item['type'] : (isDriver ? item['phone'] : "Fuel Bunk");
                        
                        return GestureDetector(
                          onTap: () {
                            onSelect(item);
                            Navigator.pop(ctx);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryBlue.withValues(alpha: 0.1) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isSelected ? primaryBlue : Colors.transparent, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: (isSelected ? primaryBlue : titleColor).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                                  child: Icon(isVehicle ? Icons.directions_bus_rounded : (isDriver ? Icons.person_rounded : Icons.store_rounded), size: 20, color: isSelected ? primaryBlue : titleColor.withValues(alpha: 0.5)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(mainText, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: titleColor)),
                                      const SizedBox(height: 4),
                                      Text(subText, style: TextStyle(fontSize: 12, color: subColor.withValues(alpha: 0.6), fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                if (isSelected) Icon(Icons.check_circle_rounded, color: primaryBlue, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showIndentPopup() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String indentNumber = "IND-${1000 + (DateTime.now().millisecond % 1000)}";

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
            _buildLabel("Select Vehicle", primaryBlue),
            const SizedBox(height: 12),
            _buildSelectTile(
              _selectedVehicle?['number'] ?? "Choose Vehicle",
              Icons.directions_bus_rounded,
              _selectedVehicle != null,
              () => _showSelectionSheet(
                title: "Select Vehicle",
                items: _vehicles,
                selected: _selectedVehicle,
                onSelect: (v) {
                  setState(() {
                    _selectedVehicle = v;
                    _selectedDriver = v['default_driver'];
                  });
                },
                isVehicle: true,
                isDriver: false,
              ),
              surfaceColor, titleColor, isDark, primaryBlue
            ),
            const SizedBox(height: 24),
            _buildLabel("Driver Assignment", primaryBlue),
            const SizedBox(height: 12),
            _buildSelectTile(
              _selectedDriver?['name'] ?? "Choose Driver",
              Icons.person_rounded,
              _selectedDriver != null,
              () => _showSelectionSheet(
                title: "Select Driver",
                items: _drivers,
                selected: _selectedDriver,
                onSelect: (d) => setState(() => _selectedDriver = d),
                isVehicle: false,
                isDriver: true,
              ),
              surfaceColor, titleColor, isDark, primaryBlue,
              isDefault: _selectedVehicle != null && _selectedVehicle?['default_driver']?['id'] == _selectedDriver?['id']
            ),
            const SizedBox(height: 24),
            _buildLabel("Fuel Bunk Name", primaryBlue),
            const SizedBox(height: 12),
            _buildSelectTile(
              _selectedBunk ?? "Choose Fuel Bunk",
              Icons.store_rounded,
              _selectedBunk != null,
              () => _showSelectionSheet(
                title: "Select Fuel Bunk",
                items: _bunks,
                selected: _selectedBunk,
                onSelect: (b) => setState(() => _selectedBunk = b),
                isVehicle: false,
                isDriver: false,
              ),
              surfaceColor, titleColor, isDark, primaryBlue
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel("Volume (Liters)", primaryBlue),
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
                      _buildLabel("Date of Filled", primaryBlue),
                      const SizedBox(height: 12),
                      _buildDatePickerTile(surfaceColor, titleColor, isDark, primaryBlue),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            // Total Amount Display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ESTIMATED COST",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: subColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "₹$_fuelPricePerLiter / liter",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primaryBlue,
                        ),
                      ),
                    ],
                  ),
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
            ),
            const SizedBox(height: 32),
            _buildCreateButton(primaryBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSelectTile(String value, IconData icon, bool hasValue, VoidCallback onTap, Color surface, Color title, bool isDark, Color primary, {bool isDefault = false}) {
    return GestureDetector(
      onTap: onTap,
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
            Icon(icon, color: hasValue ? primary : Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: hasValue ? title : Colors.grey,
                ),
              ),
            ),
            if (isDefault) 
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text("DEFAULT", style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            Icon(Icons.expand_more_rounded, color: Colors.grey, size: 20),
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
        onPressed: () {
          if (_selectedVehicle == null || _selectedBunk == null || _volumeController.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please fill all fields")),
            );
            return;
          }
          _showIndentPopup();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          elevation: 8,
          shadowColor: primary.withValues(alpha: 0.4),
        ),
        child: Text(
          "CREATE REQUEST",
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
}
