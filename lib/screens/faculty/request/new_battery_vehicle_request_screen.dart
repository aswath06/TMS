import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/utils/animated_notification.dart';

class NewBatteryVehicleRequestScreen extends ConsumerStatefulWidget {
  const NewBatteryVehicleRequestScreen({super.key});

  @override
  ConsumerState<NewBatteryVehicleRequestScreen> createState() => _NewBatteryVehicleRequestScreenState();
}

class _NewBatteryVehicleRequestScreenState extends ConsumerState<NewBatteryVehicleRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  
  dynamic _fromLocationId;
  dynamic _toLocationId;
  String? _department;
  final TextEditingController _remarkController = TextEditingController();

  bool _isLoadingDepartments = false;
  List<Map<String, dynamic>> _departments = [];

  Future<void> _fetchDepartments() async {
    if (_departments.isNotEmpty) return;
    setState(() => _isLoadingDepartments = true);
    try {
      final token = await UserStore.getToken();
      final url = "${ApiConstants.baseUrl}/auth/department";
      debugPrint("Fetching departments: $url");
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _departments = List<Map<String, dynamic>>.from(data['data']);
          });
        }
      }
    } catch (e) {
      debugPrint("Err fetching departments: $e");
    } finally {
      if (mounted) setState(() => _isLoadingDepartments = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = ref.read(batteryVehicleStoreProvider);
      store.fetchLocations();
      store.fetchBookingConfig();
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final store = ref.read(batteryVehicleStoreProvider);
      try {
        final message = await ref.read(batteryVehicleStoreProvider).bookVehicle(
          _fromLocationId,
          _toLocationId,
          0.0, // lat
          0.0, // lng
          _remarkController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
        }
      }
    }
  }

  void _showLocationSheet(bool isFrom) {
    final store = ref.read(batteryVehicleStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final p = Theme.of(context).primaryColor;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredLocations = store.locations.where((loc) {
              final name = loc['name']?.toString() ?? "";
              return searchQuery.isEmpty || name.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();
            filteredLocations.sort((a, b) => (a['name']?.toString() ?? '').toLowerCase().compareTo((b['name']?.toString() ?? '').toLowerCase()));

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isFrom ? "Select Departure" : "Select Destination",
                        style: const TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: p.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.withValues(alpha: 0.15), width: 1),
                        ),
                        child: Text(
                          "${store.locations.length} Available",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: p,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Choose the ${isFrom ? 'departure' : 'destination'} location for your request.",
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey.shade600, 
                      fontWeight: FontWeight.w600, 
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.01),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: "Search location...",
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white24 : Colors.grey.shade400,
                          fontWeight: FontWeight.w700,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: p.withValues(alpha: 0.6),
                          size: 22,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (filteredLocations.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text("No locations found"),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredLocations.length,
                        itemBuilder: (context, index) {
                          final loc = filteredLocations[index];
                          final bool isSelected = isFrom ? _fromLocationId == loc['id'] : _toLocationId == loc['id'];
                          
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isFrom) {
                                  _fromLocationId = loc['id'];
                                } else {
                                  _toLocationId = loc['id'];
                                }
                              });
                              Navigator.pop(context);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? p.withValues(alpha: 0.08) 
                                    : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade50),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? p : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: p.withValues(alpha: 0.12),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  )
                                ] : [],
                              ),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: isSelected ? 4 : 2,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isSelected ? p : Colors.grey.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      loc['name'] ?? 'Unknown',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: p,
                                      size: 22,
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
          },
        );
      },
    );
  }

  void _showDepartmentSheet() async {
    if (_departments.isEmpty) {
      setState(() => _isLoadingDepartments = true);
      await _fetchDepartments();
    }
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final p = Theme.of(context).primaryColor;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredDepartments = _departments.where((dep) {
              final name = dep['department_name'] ?? "";
              return searchQuery.isEmpty || name.toString().toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Select Department",
                        style: TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: p.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.withValues(alpha: 0.15), width: 1),
                        ),
                        child: Text(
                          "${_departments.length} Available",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: p,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Choose the department associated with this request.",
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey.shade600, 
                      fontWeight: FontWeight.w600, 
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.01),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: "Search department...",
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white24 : Colors.grey.shade400,
                          fontWeight: FontWeight.w700,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: p.withValues(alpha: 0.6),
                          size: 22,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isLoadingDepartments && _departments.isEmpty)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (filteredDepartments.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text("No departments found"),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredDepartments.length,
                        itemBuilder: (context, index) {
                          final dep = filteredDepartments[index];
                          final name = dep['department_name'] ?? "";
                          final bool isSelected = _department == name;
                          
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _department = name;
                              });
                              Navigator.pop(context);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? p.withValues(alpha: 0.08) 
                                    : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade50),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? p : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: p.withValues(alpha: 0.12),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  )
                                ] : [],
                              ),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: isSelected ? 4 : 2,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isSelected ? p : Colors.grey.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: p,
                                      size: 22,
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(batteryVehicleStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue = const Color(0xFF6366F1);
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final hintColor = isDark ? Colors.white54 : Colors.black54;

    InputDecoration premiumDeco(String hint, IconData icon) {
      return InputDecoration(
        labelText: hint,
        labelStyle: TextStyle(color: hintColor, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: primaryBlue, size: 22),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text('Request Battery Vehicle', style: TextStyle(color: textColor, fontWeight: FontWeight.w800)),
      ),
      body: store.isLoading && store.locations.isEmpty
        ? Center(child: CircularProgressIndicator(color: primaryBlue))
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: () => _showLocationSheet(true),
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: TextEditingController(
                          text: _fromLocationId != null 
                              ? store.locations.firstWhere((l) => l['id'] == _fromLocationId, orElse: () => {'name': ''})['name']
                              : null,
                        ),
                        style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: premiumDeco('From Location*', Icons.my_location_rounded).copyWith(
                          suffixIcon: Icon(Icons.keyboard_arrow_down_rounded, color: hintColor),
                        ),
                        validator: (val) => _fromLocationId == null ? 'Required' : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => _showLocationSheet(false),
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: TextEditingController(
                          text: _toLocationId != null 
                              ? store.locations.firstWhere((l) => l['id'] == _toLocationId, orElse: () => {'name': ''})['name']
                              : null,
                        ),
                        style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: premiumDeco('To Location*', Icons.location_on_rounded).copyWith(
                          suffixIcon: Icon(Icons.keyboard_arrow_down_rounded, color: hintColor),
                        ),
                        validator: (val) => _toLocationId == null ? 'Required' : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _showDepartmentSheet,
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: TextEditingController(text: _department),
                        style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
                        decoration: premiumDeco('Department (Optional)', Icons.business_rounded).copyWith(
                          suffixIcon: Icon(Icons.keyboard_arrow_down_rounded, color: hintColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _remarkController,
                    style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
                    decoration: premiumDeco('Purpose for request*', Icons.notes_rounded).copyWith(
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              minimumSize: const Size(double.infinity, 56),
            ),
            onPressed: store.isLoading ? null : _submit,
            child: store.isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Request Vehicle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}
