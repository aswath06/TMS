import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tripzo/components/location_selector.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';
import 'package:tripzo/utils/api_error_parser.dart';

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class Guest {
  String name;
  String phone;
  String countryCode;
  Guest({required this.name, required this.phone, this.countryCode = "+91"});

  Map<String, dynamic> toJson() => {
    "passenger_name": name,
    "phone": phone,
    "country_code": countryCode,
    "is_primary_contact": false,
  };
  factory Guest.fromJson(Map<String, dynamic> json) => Guest(
    name: json['passenger_name'] ?? "",
    phone: json['phone'] ?? "",
    countryCode: json['country_code'] ?? "+91",
  );
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isTransitionFinished = false;
  bool _showValidationError = false;

  // --- Step Logic ---
  int _currentStep = 0;
  String _userRole = 'faculty';
  int _totalSteps = 2;

  // --- Step 1: Details ---
  String? _routeType;
  DateTime? _startDate, _endDate;
  final TextEditingController _routeNameController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();

  bool _enableReturnJourney = false;
  DateTime? _returnStartDate;
  final TextEditingController _returnRouteNameController = TextEditingController();

  final TextEditingController _passengerCountController = TextEditingController(
    text: "1",
  );
  final TextEditingController _vehicleCountController = TextEditingController(
    text: "1",
  );
  final TextEditingController _luggageController = TextEditingController();
  final TextEditingController _specialReqController = TextEditingController();

  int? _selectedDepartmentId;
  String? _selectedDepartmentName;
  List<Map<String, dynamic>> _departments = [];
  bool _isLoadingDepartments = false;

  final List<Map<String, dynamic>> _stops = [];
  final List<Guest> _guests = [Guest(name: "", phone: "")];

  // --- Step 2: Grouping ---
  List<Guest> _unassignedGuests = [];
  Map<int, List<Guest>> _guestGroups = {};

  // --- Step 3: Vehicles ---
  List<Map<String, dynamic>> _availableVehicles = [];
  final Map<int, Map<String, dynamic>?> _selectedVehicles = {};
  bool _isLoadingVehicles = false;

  bool _sameVehicleForBoth = true;
  List<Map<String, dynamic>> _availableVehiclesReturn = [];
  final Map<int, Map<String, dynamic>?> _selectedVehiclesReturn = {};
  bool _isLoadingVehiclesReturn = false;

  // --- Step 4: Drivers ---
  List<Map<String, dynamic>> _availableDrivers = [];
  final Map<int, Map<String, dynamic>?> _selectedDrivers = {};
  bool _isLoadingDrivers = false;

  bool _sameDriverForBoth = true;
  List<Map<String, dynamic>> _availableDriversReturn = [];
  final Map<int, Map<String, dynamic>?> _selectedDriversReturn = {};
  bool _isLoadingDriversReturn = false;

  double _travelDurationMinutes = 0;
  double _approxDistanceKm = 0;
  bool _isSubmitting = false;

  final ScrollController _mainScroll = ScrollController();
  final PageStorageKey _scrollKey = const PageStorageKey("request_scroll");
  int _visibleGuestSlots = 1;

  List<Map<String, String>> _dynamicPurposeOptions = [];
  bool _isLoadingPurposes = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
    _passengerCountController.addListener(_syncGuests);
    _fetchDepartments();
    _fetchPurposes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isTransitionFinished = true;
          });
        }
      });
    });
  }

  void _syncGuests() {
    final count = int.tryParse(_passengerCountController.text) ?? 1;
    if (count > _guests.length) {
      setState(() {
        while (_guests.length < count) {
          _guests.add(Guest(name: "", phone: ""));
        }
      });
    }
    if (_visibleGuestSlots > count) setState(() => _visibleGuestSlots = count);
    if (_visibleGuestSlots < 1 && count >= 1) {
      setState(() => _visibleGuestSlots = 1);
    }
  }

  Future<void> _checkRole() async {
    final role = await UserStore.getRole();
    if (mounted) {
      setState(() {
        _userRole = role?.toLowerCase() ?? 'faculty';
        _totalSteps = _userRole.contains('admin') ? 5 : 3;
      });
    }
  }

  @override
  void dispose() {
    _routeNameController.dispose();
    _purposeController.dispose();
    _passengerCountController.dispose();
    _vehicleCountController.dispose();
    _luggageController.dispose();
    _specialReqController.dispose();
    super.dispose();
  }

  // --- Logic Helpers ---

  Future<void> _fetchPurposes() async {
    setState(() {
      _isLoadingPurposes = true;
    });
    try {
      final token = await UserStore.getToken();
      final url = ApiConstants.getRequestPurposes;
      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          final List<dynamic> purposes = data['data'] ?? [];
          setState(() {
            _dynamicPurposeOptions = purposes.map((p) => {
              "id": p['id'].toString(),
              "key": p['name'].toString(),
              "label": p['name'].toString()
            }).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching purposes: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPurposes = false;
        });
      }
    }
  }

  Future<void> _createNewPurpose(String name) async {
    if (name.trim().isEmpty) return;
    try {
      final token = await UserStore.getToken();
      final url = ApiConstants.createRequestPurpose;
      final body = jsonEncode({"name": name.trim()});
      final response = await http.post(
        Uri.parse(url), 
        headers: ApiConstants.getHeaders(token),
        body: body,
      );
      
      if (response.statusCode == 201) {
        await _fetchPurposes();
        setState(() {
          _purposeController.text = name.trim();
        });
      }
    } catch (e) {
      debugPrint("Error creating purpose: $e");
    }
  }

  Future<void> _deletePurpose(String id) async {
    try {
      final token = await UserStore.getToken();
      final url = ApiConstants.deleteRequestPurpose(id);
      final response = await http.delete(
        Uri.parse(url), 
        headers: ApiConstants.getHeaders(token),
      );
      
      if (response.statusCode == 200) {
        if (_purposeController.text == _dynamicPurposeOptions.firstWhere((element) => element['id'] == id, orElse: () => {})['key']) {
          setState(() {
            _purposeController.text = "";
          });
        }
        await _fetchPurposes();
      }
    } catch (e) {
      debugPrint("Error deleting purpose: $e");
    }
  }


  Future<void> _fetchAvailableVehicles() async {
    if (_startDate == null) return;
    setState(() {
      _isLoadingVehicles = true;
      if (_enableReturnJourney) _isLoadingVehiclesReturn = true;
    });
    try {
      final token = await UserStore.getToken();
      final start = Uri.encodeComponent(_toIso(_startDate!));
      final end = _endDate != null ? Uri.encodeComponent(_toIso(_endDate!)) : start;
      final url = "${ApiConstants.getAvailableVehicles}?start_datetime=$start&end_datetime=$end";
      
      debugPrint("\n🚀 [FETCH VEHICLES CURL SENDING (Main Journey)]:\ncurl --location '$url' \\\n--header 'Authorization: TMS $token'\n");
      final req1 = http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));
      Future<http.Response>? req2;

      if (_enableReturnJourney && _returnStartDate != null) {
        final returnOneLegMinutes = _travelDurationMinutes + 60;
        final returnEndDatetime = _returnStartDate!.add(Duration(minutes: returnOneLegMinutes.toInt()));
        final rStart = Uri.encodeComponent(_toIso(_returnStartDate!));
        final rEnd = Uri.encodeComponent(_toIso(returnEndDatetime));
        final rUrl = "${ApiConstants.getAvailableVehicles}?start_datetime=$rStart&end_datetime=$rEnd";
        debugPrint("\n🚀 [FETCH VEHICLES CURL SENDING (Return Journey)]:\ncurl --location '$rUrl' \\\n--header 'Authorization: TMS $token'\n");
        req2 = http.get(Uri.parse(rUrl), headers: ApiConstants.getHeaders(token));
      }

      final response1 = await req1;
      debugPrint("📥 [SERVER RESPONSE (Fetch Vehicles Main)] (${response1.statusCode}): ${response1.body}");
      if (response1.statusCode == 200) {
        final data = json.decode(response1.body);
        setState(() => _availableVehicles = List<Map<String, dynamic>>.from(data['data']['vehicles'] ?? []));
      }

      if (req2 != null) {
        final response2 = await req2;
        debugPrint("📥 [SERVER RESPONSE (Fetch Vehicles Return)] (${response2.statusCode}): ${response2.body}");
        if (response2.statusCode == 200) {
          final data = json.decode(response2.body);
          setState(() => _availableVehiclesReturn = List<Map<String, dynamic>>.from(data['data']['vehicles'] ?? []));
        }
      }
    } catch (e) {
      debugPrint("Err: $e");
    } finally {
      setState(() {
        _isLoadingVehicles = false;
        _isLoadingVehiclesReturn = false;
      });
    }
  }

  Future<void> _fetchAvailableDrivers() async {
    if (_startDate == null) return;
    setState(() {
      _isLoadingDrivers = true;
      if (_enableReturnJourney) _isLoadingDriversReturn = true;
    });
    try {
      final token = await UserStore.getToken();
      final start = Uri.encodeComponent(_toIso(_startDate!));
      final end = _endDate != null ? Uri.encodeComponent(_toIso(_endDate!)) : start;
      final url = "${ApiConstants.getAvailableDrivers}?start_datetime=$start&end_datetime=$end";
      
      debugPrint("\n🚀 [FETCH DRIVERS CURL SENDING (Main Journey)]:\ncurl --location '$url' \\\n--header 'Authorization: TMS $token'\n");
      final req1 = http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));
      Future<http.Response>? req2;

      if (_enableReturnJourney && _returnStartDate != null) {
        final returnOneLegMinutes = _travelDurationMinutes + 60;
        final returnEndDatetime = _returnStartDate!.add(Duration(minutes: returnOneLegMinutes.toInt()));
        final rStart = Uri.encodeComponent(_toIso(_returnStartDate!));
        final rEnd = Uri.encodeComponent(_toIso(returnEndDatetime));
        final rUrl = "${ApiConstants.getAvailableDrivers}?start_datetime=$rStart&end_datetime=$rEnd";
        debugPrint("\n🚀 [FETCH DRIVERS CURL SENDING (Return Journey)]:\ncurl --location '$rUrl' \\\n--header 'Authorization: TMS $token'\n");
        req2 = http.get(Uri.parse(rUrl), headers: ApiConstants.getHeaders(token));
      }

      final response1 = await req1;
      debugPrint("📥 [SERVER RESPONSE (Fetch Drivers Main)] (${response1.statusCode}): ${response1.body}");
      if (response1.statusCode == 200) {
        final data = json.decode(response1.body);
        setState(() => _availableDrivers = List<Map<String, dynamic>>.from(data['data']['drivers'] ?? []));
        _autoProposeDrivers();
      }

      if (req2 != null) {
        final response2 = await req2;
        debugPrint("📥 [SERVER RESPONSE (Fetch Drivers Return)] (${response2.statusCode}): ${response2.body}");
        if (response2.statusCode == 200) {
          final data = json.decode(response2.body);
          setState(() => _availableDriversReturn = List<Map<String, dynamic>>.from(data['data']['drivers'] ?? []));
          // Propose first matching driver for return logic? Not strictly required unless UI needs it.
        }
      }
    } catch (e) {
      debugPrint("Err: $e");
    } finally {
      setState(() {
        _isLoadingDrivers = false;
        _isLoadingDriversReturn = false;
      });
    }
  }

  void _autoProposeDrivers() {
    _selectedVehicles.forEach((groupId, vehicle) {
      if (vehicle != null && vehicle['default_driver'] != null) {
        final defDriver = vehicle['default_driver'];
        final found = _availableDrivers.firstWhere(
          (d) => d['id'] == defDriver['driver_id'],
          orElse: () => <String, dynamic>{},
        );
        if (found.isNotEmpty) setState(() => _selectedDrivers[groupId] = found);
      }
    });
  }

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
      debugPrint(ApiErrorParser.parse(response, fallback: "Departments Response ["));
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

  void _showDepartmentSelectionSheet(Color p, bool d) async {
    if (_departments.isEmpty) {
      setState(() => _isLoadingDepartments = true);
      await _fetchDepartments();
    }
    if (!mounted) return;

    String searchQuery = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
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
                  // Modern Premium Search Bar
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
                  else if (_departments.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text("No departments found"),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _departments.length,
                        itemBuilder: (context, idx) {
                          final dept = _departments[idx];
                          final name = dept['department_name'] ?? "";
                          
                          if (searchQuery.isNotEmpty &&
                              !name.toLowerCase().contains(searchQuery.toLowerCase())) {
                            return const SizedBox.shrink();
                          }

                          final bool isSelected = _selectedDepartmentId == dept['id'];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDepartmentId = dept['id'];
                                _selectedDepartmentName = dept['department_name'];
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
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? p : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: p,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 14,
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
          },
        );
      },
    );
  }

  Future<void> _showPurposeSelectionSheet(Color p, bool d) async {
    Color c = d ? const Color(0xFF1E293B) : Colors.white;
    Color t = d ? Colors.white : const Color(0xFF0F172A);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: c,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: 16,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: t.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Select Purpose",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: t,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: p.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${_dynamicPurposeOptions.length} OPTIONS",
                          style: GoogleFonts.montserrat(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: p,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _showAddPurposeDialog(p, d, c, t);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: p,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "+ Add New",
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_isLoadingPurposes)
                const Center(child: CircularProgressIndicator())
              else if (_dynamicPurposeOptions.isEmpty)
                Center(
                  child: Text(
                    "No purposes found. Add one!",
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: t.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _dynamicPurposeOptions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _dynamicPurposeOptions[index];
                    final isSelected = _purposeController.text == item['key'];
                    final isSuperAdmin = _userRole.toLowerCase() == 'super admin';

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _purposeController.text = item['key']!;
                      });
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isSelected ? p.withValues(alpha: 0.04) : c,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? p.withValues(alpha: 0.4) : t.withValues(alpha: 0.06),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: p.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isSelected ? p : Colors.transparent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(width: isSelected ? 12 : 0),
                          Expanded(
                            child: Text(
                              item['label']!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                color: isSelected ? p : t.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          if (isSuperAdmin)
                            GestureDetector(
                              onTap: () {
                                _deletePurpose(item['id']!);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                margin: EdgeInsets.only(right: isSelected ? 8 : 0),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              ),
                            ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: p.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check_rounded, size: 12, color: p),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddPurposeDialog(Color p, bool d, Color c, Color t) {
    final TextEditingController newPurposeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: t.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Add New Purpose",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: t,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPurposeCtrl,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t,
                    ),
                    decoration: InputDecoration(
                      hintText: "Enter purpose name",
                      hintStyle: GoogleFonts.montserrat(
                        color: t.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: t.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          "Cancel",
                          style: GoogleFonts.montserrat(
                            color: t.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final name = newPurposeCtrl.text.trim();
                          if (name.isNotEmpty) {
                            Navigator.pop(ctx);
                            await _createNewPurpose(name);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: p,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          "Add",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _autoAllocateGuests() {
    if (_unassignedGuests.isEmpty) return;
    int vCount = _guestGroups.length;
    if (vCount == 0) return;

    setState(() {
      for (int i = 0; i < _unassignedGuests.length; i++) {
        int groupIdx = i % vCount;
        _guestGroups[groupIdx]!.add(_unassignedGuests[i]);
      }
      _unassignedGuests.clear();
    });
  }

  void _prepareGrouping() {
    int vCount = int.tryParse(_vehicleCountController.text) ?? 1;
    int pLimit = int.tryParse(_passengerCountController.text) ?? 1;
    setState(() {
      _unassignedGuests = [];
      for (int i = 0; i < pLimit; i++) {
        // Use ORIGINAL object so indexOf works correctly
        _unassignedGuests.add(_guests[i]);
      }
      _guestGroups = {};
      for (int i = 0; i < vCount; i++) {
        _guestGroups[i] = [];
      }
    });
  }

  void _updateEndDate() {
    if (_routeType == null) return;
    if (_routeType != 'Multi Day' && _startDate != null) {
      if (_routeType == 'One Way') {
        final addedMinutes = _travelDurationMinutes + (1 * 60);
        _endDate = _startDate!.add(Duration(minutes: addedMinutes.toInt()));
      } else { // Two Way
        final addedMinutes = (_travelDurationMinutes * 2) + (2 * 60);
        _endDate = _startDate!.add(Duration(minutes: addedMinutes.toInt()));
      }
    }
  }

  String _toIso(DateTime dt) {
    final datePart = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(dt);
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? "-" : "+";
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return "$datePart$sign$hours:$minutes";
  }

  Future<void> _submitForm() async {
    setState(() => _isSubmitting = true);
    try {
      final token = await UserStore.getToken();
      final bool isAdmin = _userRole.toLowerCase().contains('admin');

      // Constructing passengers list
      int pLimit = int.tryParse(_passengerCountController.text) ?? 1;
      List<Map<String, dynamic>> passengers = [];
      for (int i = 0; i < pLimit; i++) {
        String name = _guests[i].name.trim();
        passengers.add({
          "passenger_name": name.isEmpty ? "Guest ${i + 1}" : name,
          "phone": _guests[i].phone.trim(),
          "country_code": _guests[i].countryCode,
          "is_primary_contact": i == 0,
        });
      }

      final goingStart = _startDate;
      DateTime? rootEndDatetime;
      DateTime? leg1Start;
      DateTime? leg1End;
      DateTime? leg2Start;
      DateTime? leg2End;

      if (goingStart != null) {
        final oneLegMinutes = _travelDurationMinutes + 60; // 1 hr buffer
        leg1Start = goingStart;
        
        if (_routeType == 'One Way') {
          leg1End = goingStart.add(Duration(minutes: oneLegMinutes.toInt()));
          rootEndDatetime = leg1End;
        } else if (_routeType == 'Two Way') {
          leg1End = goingStart.add(Duration(minutes: oneLegMinutes.toInt()));
          leg2Start = leg1End;
          leg2End = leg2Start.add(Duration(minutes: oneLegMinutes.toInt()));
          rootEndDatetime = leg1End; // Usually same as leg1End in Round Trip (or could be leg2End, but keeping it as before)
        } else if (_routeType == 'Multi Day') {
          if (_endDate != null) {
            leg1End = goingStart.add(Duration(minutes: oneLegMinutes.toInt()));
            leg2Start = _endDate!.subtract(Duration(minutes: oneLegMinutes.toInt()));
            leg2End = _endDate;
            rootEndDatetime = _endDate;
          }
        }
      }

      final Map<String, dynamic> body = {
        "route_name": _routeNameController.text.trim(),
        "trip_type": _routeType == 'One Way'
            ? 'ONE_WAY'
            : (_routeType == 'Multi Day' ? 'MULTI_DAY' : 'ROUND_TRIP'),
        "requested_for_date": DateFormat('yyyy-MM-dd').format(_startDate ?? DateTime.now()),
        "start_datetime": goingStart != null ? _toIso(goingStart) : null,
        "end_datetime": rootEndDatetime != null ? _toIso(rootEndDatetime) : null,
        "purpose": _purposeController.text.trim(),
        "passenger_count": int.tryParse(_passengerCountController.text) ?? 1,
        "vehicle_count": int.tryParse(_vehicleCountController.text) ?? 1,
        "suggested_vehicle_type_id": 1, // Default or mapped
        "luggage_details": _luggageController.text.trim(),
        "special_instructions": _specialReqController.text.trim(),
        "approx_distance_km": _approxDistanceKm,
        "approx_duration_minutes": _travelDurationMinutes.toInt(),
        "passengers": passengers,
        "department_id": _selectedDepartmentId,
      };

      if (_routeType != 'One Way') {
        body["return_start_datetime"] = leg2Start != null ? _toIso(leg2Start) : null;
        body["return_end_datetime"] = leg2End != null ? _toIso(leg2End) : null;
      }

      if (isAdmin) {
        // ADMIN FLOW: Uses admin_assignments and legs
        List<Map<String, dynamic>> leg1Vehicles = [];
        _guestGroups.forEach((idx, guests) {
          leg1Vehicles.add({
            "vehicle_id": _selectedVehicles[idx]?['id'],
            "driver_id": _selectedDrivers[idx]?['id'],
            "passenger_ids": guests.map((g) => _guests.indexOf(g) + 1).toList(),
          });
        });

        final outboundStops = _stops.asMap().entries.map((entry) {
          final idx = entry.key;
          final s = entry.value;
          return {
            "stop_name": s['address'] ?? "",
            "address": s['address'] ?? "",
            "latitude": s['lat'],
            "longitude": s['lon'],
            "stop_order": idx + 1,
            "stop_type": idx == 0
                ? "START"
                : (idx == _stops.length - 1 ? "END" : "VIA"),
          };
        }).toList();

        body["stops"] = outboundStops;

        final returnStops = outboundStops.reversed.toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            return {
              "stop_name": s['stop_name'],
              "address": s['address'],
              "latitude": s['latitude'],
              "longitude": s['longitude'],
              "stop_order": idx + 1,
              "stop_type": idx == 0
                  ? "START"
                  : (idx == outboundStops.length - 1 ? "END" : "VIA"),
            };
        }).toList();

        body["legs"] = [
          {
            "leg_code": "LEG-1",
            "leg_type": "OUTBOUND",
            "travel_direction": "START_TO_END",
            "planned_start_at": leg1Start != null ? _toIso(leg1Start) : null,
            "planned_end_at": leg1End != null ? _toIso(leg1End) : null,
            "required_vehicle_count": int.tryParse(_vehicleCountController.text) ?? 1,
            "stops": outboundStops,
            "linked_leg_index": _routeType != 'One Way' ? 1 : null,
            "allow_same_vehicle_as_linked_leg": true
          },
          if (_routeType != 'One Way')
          {
            "leg_code": "LEG-2",
            "leg_type": "RETURN",
            "travel_direction": "END_TO_START",
            "planned_start_at": leg2Start != null ? _toIso(leg2Start) : null,
            "planned_end_at": leg2End != null ? _toIso(leg2End) : null,
            "required_vehicle_count": int.tryParse(_vehicleCountController.text) ?? 1,
            "stops": returnStops,
            "linked_leg_index": 0,
            "allow_same_vehicle_as_linked_leg": true
          }
        ];

        body["admin_assignments"] = [
          {"leg_code": "LEG-1", "vehicles": leg1Vehicles},
          if (_routeType != 'One Way')
            {"leg_code": "LEG-2", "vehicles": leg1Vehicles},
        ];
      } else {
        // FACULTY FLOW: Uses groupings
        body["stops"] = _stops
            .map((s) => {"stop_name": s['address'] ?? ""})
            .toList();

        List<Map<String, dynamic>> groupings = [];
        _guestGroups.forEach((idx, guests) {
          groupings.add({
            "group_label": "Vehicle Group \${idx + 1}",
            "passenger_ids": guests.map((g) => _guests.indexOf(g) + 1).toList(),
          });
        });
        body["groupings"] = groupings;
      }

      final String apiUrl = isAdmin
          ? ApiConstants.adminCreateFull
          : ApiConstants.facultyCreate;
      final String tokenLabel = isAdmin ? "ADMIN" : "FACULTY";

      Future<http.Response> submitSingle(Map<String, dynamic> requestBody, String label) async {
        const encoder = JsonEncoder.withIndent('  ');
        String prettyJson = encoder.convert(requestBody);
        debugPrint(
          "\n🚀 [$tokenLabel CURL SENDING ($label)]:\ncurl --location '$apiUrl' \\\n"
          "--header 'Authorization: TMS $token' \\\n--header 'Content-Type: application/json' \\\n--data '$prettyJson'\n",
        );

        final r = await http.post(
          Uri.parse(apiUrl),
          headers: ApiConstants.getHeaders(token),
          body: json.encode(requestBody),
        );

        debugPrint("📥 [SERVER RESPONSE ($label)] (${r.statusCode}): ${r.body}");
        return r;
      }

      final resp1 = await submitSingle(body, "Main Journey");
      http.Response? resp2;

      if (_enableReturnJourney && _returnStartDate != null) {
        final Map<String, dynamic> body2 = json.decode(json.encode(body)); // Deep copy
        
        final returnOneLegMinutes = _travelDurationMinutes + 60;
        final returnEndDatetime = _returnStartDate!.add(Duration(minutes: returnOneLegMinutes.toInt()));

        body2["route_name"] = _returnRouteNameController.text.trim();
        body2["requested_for_date"] = DateFormat('yyyy-MM-dd').format(_returnStartDate!);
        body2["start_datetime"] = _toIso(_returnStartDate!);
        body2["end_datetime"] = _toIso(returnEndDatetime);
        
        body2.remove("return_start_datetime");
        body2.remove("return_end_datetime");
        
        if (isAdmin && body2["legs"] != null) {
           final legs = List<Map<String, dynamic>>.from(body2["legs"] as List);
           if (legs.isNotEmpty) {
             final leg1 = Map<String, dynamic>.from(legs[0]);
             leg1["planned_start_at"] = _toIso(_returnStartDate!);
             leg1["planned_end_at"] = _toIso(returnEndDatetime);
             legs[0] = leg1;
           }
           if (legs.length > 1) {
             legs.removeAt(1);
           }
           body2["legs"] = legs;

           List<Map<String, dynamic>> leg2Vehicles = [];
           _guestGroups.forEach((idx, guests) {
             final v = _sameVehicleForBoth ? _selectedVehicles[idx] : _selectedVehiclesReturn[idx];
             final d = _sameDriverForBoth ? _selectedDrivers[idx] : _selectedDriversReturn[idx];
             leg2Vehicles.add({
               "vehicle_id": v?['id'],
               "driver_id": d?['id'],
               "passenger_ids": guests.map((g) => _guests.indexOf(g) + 1).toList(),
             });
           });
           
           if (body2["admin_assignments"] != null) {
             final assignments = List<Map<String, dynamic>>.from(body2["admin_assignments"] as List);
             if (assignments.isNotEmpty) {
               final a1 = Map<String, dynamic>.from(assignments[0]);
               a1["vehicles"] = leg2Vehicles;
               assignments[0] = a1;
             }
             if (assignments.length > 1) {
               assignments.removeAt(1);
             }
             body2["admin_assignments"] = assignments;
           }
        }

        resp2 = await submitSingle(body2, "Return Journey");
      }

      if (!mounted) return;
      
      bool success1 = (resp1.statusCode == 200 || resp1.statusCode == 201);
      bool success2 = resp2 == null || (resp2.statusCode == 200 || resp2.statusCode == 201);

      if (success1 && success2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Request Submitted Successfully!")),
        );
        Navigator.pop(context, true);
      } else {
        if (!success1) {
          final err = json.decode(resp1.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ Main Failed: ${err['message'] ?? 'Unknown'}")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Main Journey Created!")),
          );
        }

        if (resp2 != null) {
          await Future.delayed(const Duration(seconds: 4));
          if (!mounted) return;
          if (!success2) {
            final err = json.decode(resp2.body);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("❌ Return Failed: ${err['message'] ?? 'Unknown'}")),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✅ Return Journey Created!")),
            );
          }
        }

        await Future.delayed(const Duration(seconds: 2));
        if (mounted && (success1 || success2)) {
           Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint("Err: $e");
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final Color pColor = const Color(0xFF6366F1);

    if (!_isTransitionFinished) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Inter'),
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          children: [
            _buildMeshBg(pColor),
            SafeArea(
              child: Column(
                children: [
                  _buildPremiumHeader(context, pColor, isDark),
                  Expanded(
                    child: SingleChildScrollView(
                      key: _scrollKey,
                      controller: _mainScroll,
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildCurrentStage(pColor, isDark),
                    ),
                  ),
                  _buildActionToolbar(pColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeshBg(Color p) => Positioned(
    top: -100,
    right: -100,
    child: Container(
      width: 400,
      height: 400,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [p.withValues(alpha: 0.08), Colors.transparent],
        ),
      ),
    ),
  );

  Widget _buildPremiumHeader(BuildContext context, Color p, bool d) {
    double prg = (_currentStep + 1) / _totalSteps;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: p.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, color: p, size: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TRANSPORT",
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                          color: p,
                        ),
                      ),
                      Text(
                        "New Request",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: d ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _buildProgressCircle(p, prg),
            ],
          ),
        );
  }

  Widget _buildProgressCircle(Color p, double prg) => Stack(
    alignment: Alignment.center,
    children: [
      SizedBox(
        width: 50,
        height: 50,
        child: CircularProgressIndicator(
          value: prg,
          strokeWidth: 4,
          backgroundColor: p.withValues(alpha: 0.05),
          valueColor: AlwaysStoppedAnimation<Color>(p),
        ),
      ),
      Text(
        "${(prg * 100).toInt()}%",
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: p),
      ),
    ],
  );

  Widget _buildCurrentStage(Color p, bool d) {
    bool isAdmin = _userRole.toLowerCase().contains('admin');
    if (isAdmin) {
      switch (_currentStep) {
        case 0: return _stageRouteDetails(p, d);
        case 1: return _stageGrouping(p, d);
        case 2: return _stageVehicles(p, d);
        case 3: return _stageDrivers(p, d);
        case 4: return _stageReview(p, d);
        default: return Container();
      }
    } else {
      switch (_currentStep) {
        case 0: return _stageRouteDetails(p, d);
        case 1: return _stageGrouping(p, d);
        case 2: return _stageReview(p, d);
        default: return Container();
      }
    }
  }

  Widget _stageRouteDetails(Color p, bool d) {
    final Color c = d ? const Color(0xFF1E293B) : Colors.white;
    final Color t = d ? Colors.white : const Color(0xFF0F172A);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildGlassLabel("Route Selection", p),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: ["One Way", "Two Way", "Multi Day"].map((type) {
                bool act = _routeType == type;
                return GestureDetector(
                  onTap: () => setState(() {
                    _routeType = type;
                    _updateEndDate();
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: act ? p : p.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: act ? p : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        type,
                        style: TextStyle(
                          color: act ? Colors.white : p,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          _premiumInput(
            "Journey Name*",
            _routeNameController,
            "e.g. TSC Visit, Campus Tour",
            Icons.route_rounded,
            c,
            t,
            p,
            isReq: true,
            helperText: "Give your trip a short, recognizable title (Do not enter the purpose here).",
          ),
          _premiumSelect(
            "Journey Purpose*",
            _purposeController.text.isNotEmpty ? _purposeController.text : null,
            "Select Purpose",
            Icons.info_outline,
            c,
            t,
            p,
            () => _showPurposeSelectionSheet(p, d),
            isReq: true,
          ),
          _premiumSelect(
            "Department*",
            _selectedDepartmentName,
            "Select Department",
            Icons.business_rounded,
            c,
            t,
            p,
            () => _showDepartmentSelectionSheet(p, d),
            isReq: true,
          ),
          _buildGlassLabel("Journey Schedule", p),
          const SizedBox(height: 16),
          _buildEnhancedScheduleCards(p, c, t, d),
          const SizedBox(height: 32),
          if (_routeType != 'Multi Day') ...[
            _buildGlassLabel("Return Journey (Optional)", p),
            const SizedBox(height: 12),
            _buildReturnToggleSection(p, c, t, d),
            const SizedBox(height: 32),
          ],
          Row(
            children: [
              Expanded(
                child: _premiumInput(
                  "Passengers*",
                  _passengerCountController,
                  "1",
                  Icons.people_outline,
                  c,
                  t,
                  p,
                  isNum: true,
                  isReq: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _premiumInput(
                  "Vehicles*",
                  _vehicleCountController,
                  "1",
                  Icons.directions_bus_filled_outlined,
                  c,
                  t,
                  p,
                  isNum: true,
                  isReq: true,
                ),
              ),
            ],
          ),
          _buildGlassLabel("Passenger Details", p),
          const SizedBox(height: 16),
          ...List.generate(_visibleGuestSlots, (i) {
            if (i >= _guests.length) return const SizedBox.shrink();
            bool isCompulsory = i < 1;
            return _premiumGuestEntry(
              i,
              _guests[i],
              c,
              t,
              p,
              isReq: isCompulsory,
            );
          }),
          _addGuestBtn(p),
          const SizedBox(height: 32),
          _buildGlassLabel("Route Stops", p),
          const SizedBox(height: 12),
          LocationSelector(
            cardColor: c,
            titleColor: t,
            accentColor: p,
            initialStops: _stops,
            onChanged: (stops, dist, dur) {
              setState(() {
                _stops.clear();
                _stops.addAll(stops);
                _travelDurationMinutes = dur;
                _approxDistanceKm = dist;
                _updateEndDate();
              });
            },
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildReturnToggleSection(Color p, Color c, Color t, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.withValues(alpha: 0.04), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(
              "Return date and time",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: t,
              ),
            ),
            subtitle: Text(
              "Creates a separate return request automatically",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: t.withValues(alpha: 0.5),
              ),
            ),
            value: _enableReturnJourney,
            activeThumbColor: p,
            inactiveTrackColor: t.withValues(alpha: 0.05),
            onChanged: (val) {
              setState(() {
                _enableReturnJourney = val;
                if (!val) {
                  _returnStartDate = null;
                  _returnRouteNameController.clear();
                }
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
          if (_enableReturnJourney) ...[
            const SizedBox(height: 16),
            _premiumInputInline(
              "Return Journey Name*",
              _returnRouteNameController.text,
              (v) => _returnRouteNameController.text = v,
              Icons.route_rounded,
              c,
              t,
              p,
              isReq: true,
            ),
            const SizedBox(height: 12),
            _niceScheduleTile(
              "Return Date & Time*",
              _returnStartDate,
              (v) {
                setState(() {
                  _returnStartDate = v;
                });
              },
              p,
              c,
              t,
              minDate: _endDate,
              hasError: _showValidationError && _enableReturnJourney && _returnStartDate == null,
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildEnhancedScheduleCards(Color p, Color c, Color t, bool isDark) {
    return Column(
      children: [
        _niceScheduleTile(
          "Departure Date & Time*",
          _startDate,
          (v) {
            setState(() {
              _startDate = v;
              _updateEndDate();
            });
          },
          p,
          c,
          t,
          hasError: _showValidationError && _startDate == null,
        ),
        if (_routeType == 'Multi Day') ...[
          const SizedBox(height: 12),
          _niceScheduleTile(
            "Expected Return*",
            _endDate,
            (v) => setState(() {
              _endDate = v;
            }),
            p,
            c,
            t,
            hasError: _showValidationError && _routeType != 'One Way' && _endDate == null,
          ),
        ] else if (_startDate != null && _endDate != null) ...[
          const SizedBox(height: 12),
          _buildReadOnlyEndTile(isDark, p, c, t),
        ],
      ],
    );
  }

  Widget _buildReadOnlyEndTile(bool isDark, Color p, Color c, Color t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 18,
            color: p.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "AUTO-CALCULATED RETURN",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: p,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEE, MMM dd • hh:mm a').format(_endDate!.toLocal()),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: t.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _niceScheduleTile(
    String h,
    DateTime? val,
    Function(DateTime) onPick,
    Color p,
    Color c,
    Color t, {
    DateTime? minDate,
    bool hasError = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () async {
            setState(() => _showValidationError = true);
            final picked = await CustomDateTimePicker.show(
              context,
              initialDate: val ?? (minDate != null && minDate.isAfter(DateTime.now()) ? minDate : DateTime.now()),
              minDate: minDate ?? DateTime.now(),
              accent: p,
              cardColor: c,
              titleColor: t,
            );
            if (picked != null) onPick(picked);
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: hasError ? const Color(0xFFEF4444) : t.withValues(alpha: 0.04),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        p.withValues(alpha: 0.15),
                        p.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: p.withValues(alpha: 0.1)),
                  ),
                  child: Icon(Icons.calendar_today_rounded, size: 20, color: p),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.replaceFirst('*', '').trim().toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: t.withValues(alpha: 0.4),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        val == null
                            ? "Set Schedule"
                            : DateFormat('EEE, MMM dd • hh:mm a').format(val.toLocal()),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: val == null ? Colors.grey : t,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: t.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8),
            child: Text(
              "  * Please select ${h.replaceAll('*', '').toLowerCase().trim()}",
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFEF4444),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _premiumGuestEntry(
    int i,
    Guest g,
    Color c,
    Color t,
    Color p, {
    bool isReq = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "PASSENGER ${i + 1}",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: p,
                ),
              ),
              if (i > 0)
                GestureDetector(
                  onTap: () => setState(() {
                    _guests.removeAt(i);
                  }),
                  child: const Text(
                    "REMOVE",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _premiumInputInline(
            "Full Name",
            g.name,
            (v) {
              g.name = v;
              setState(() {});
            },
            Icons.person_outline_rounded,
            c,
            t,
            p,
            isReq: isReq,
          ),
          const SizedBox(height: 12),
          _premiumInputInline(
            "Contact Number",
            g.phone,
            (v) {
              g.phone = v;
            },
            Icons.phone_android_rounded,
            c,
            t,
            p,
            isNum: true,
            isReq: isReq,
          ),
        ],
      ),
    );
  }

  Widget _premiumInputInline(
    String label,
    String initial,
    Function(String) onC,
    IconData icon,
    Color c,
    Color t,
    Color p, {
    bool isNum = false,
    bool isReq = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
          ),
        ],
      ),
      child: TextFormField(
        initialValue: initial,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        onChanged: onC,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          filled: true,
          fillColor: c,
          hintText: label,
          hintStyle: TextStyle(color: t.withValues(alpha: 0.1), fontSize: 13),
          prefixIcon: Icon(icon, color: p.withValues(alpha: 0.35), size: 20),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          prefixText: isNum ? "+91 " : null,
          prefixStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.grey,
          ),
          counterText: "",
          errorStyle: GoogleFonts.plusJakartaSans(
            color: const Color(0xFFEF4444),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: t.withValues(alpha: 0.04), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: p.withValues(alpha: 0.4), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
          ),
        ),
        maxLength: isNum ? 10 : null,
        inputFormatters: isNum
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        validator: (v) {
          if (isReq && (v == null || v.trim().isEmpty)) {
            return "  * $label is required";
          }
          if (isNum && v != null && v.isNotEmpty && v.length != 10) {
            return "  * Must be 10 digits";
          }
          return null;
        },
      ),
    );
  }

  Widget _premiumSelect(
    String label,
    String? value,
    String hint,
    IconData icon,
    Color c,
    Color t,
    Color p,
    VoidCallback onTap, {
    bool isReq = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: t.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        FormField<String>(
          initialValue: value,
          validator: isReq
              ? (v) => (value == null || value.isEmpty)
                  ? "Please select ${label.replaceAll('*', '').toLowerCase().trim()}"
                  : null
              : null,
          builder: (FormFieldState<String> state) {
            final hasError = state.hasError;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasError
                            ? const Color(0xFFEF4444)
                            : t.withValues(alpha: 0.04),
                        width: hasError ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            color: p.withValues(alpha: 0.35),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              (value != null && value.isNotEmpty) ? value : hint,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: (value != null && value.isNotEmpty)
                                    ? (t == Colors.white ? Colors.white : const Color(0xFF0F172A))
                                    : t.withValues(alpha: 0.1),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: t.withValues(alpha: 0.3),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 8),
                    child: Text(
                      "  * ${state.errorText}",
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFEF4444),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _premiumInput(
    String label,
    TextEditingController ctrl,
    String hint,
    IconData icon,
    Color c,
    Color t,
    Color p, {
    bool isReq = false,
    bool isNum = false,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: t.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
              ),
            ],
          ),
          child: TextFormField(
            controller: ctrl,
            keyboardType: isNum ? TextInputType.number : TextInputType.text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              filled: true,
              fillColor: c,
              hintText: hint,
              hintStyle: TextStyle(
                color: t.withValues(alpha: 0.1),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                icon,
                color: p.withValues(alpha: 0.35),
                size: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              errorStyle: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFEF4444),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: t.withValues(alpha: 0.04), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: p.withValues(alpha: 0.4), width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
              ),
            ),
            validator: isReq
                ? (v) => (v == null || v.isEmpty)
                    ? "  * ${label.replaceAll('*', '').trim()} is required"
                    : null
                : null,
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              helperText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: t.withValues(alpha: 0.4),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _addGuestBtn(Color p) {
    int max = int.tryParse(_passengerCountController.text) ?? 1;
    if (_visibleGuestSlots >= max) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => setState(() {
        _visibleGuestSlots++;
      }),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: p.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add_alt_1_rounded, size: 18, color: p),
            const SizedBox(width: 8),
            Text(
              "Add Specific Guest Detail (${_visibleGuestSlots + 1}/$max)",
              style: TextStyle(
                color: p,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Multi-Step Stages (Mapping/Vehicles/Drivers) ---

  Widget _stageGrouping(Color p, bool d) {
    Color c = d ? const Color(0xFF1E293B) : Colors.white;
    Color t = d ? Colors.white : const Color(0xFF0F172A);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "GROUPING",
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                    color: p,
                  ),
                ),
                Text(
                  "Allocate Guests",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: t,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (_unassignedGuests.isNotEmpty)
              TextButton.icon(
                onPressed: _autoAllocateGuests,
                icon: Icon(Icons.auto_awesome_rounded, size: 16, color: p),
                label: Text(
                  "Smart Split",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: p,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: p.withValues(alpha: 0.05),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 14,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${_guests.where((g) => !_unassignedGuests.contains(g) && g.name.isNotEmpty).length}/${_guests.where((g) => g.name.isNotEmpty).length} Assigned",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 32),
        Column(
          children: [
            _buildGlassLabel("Unassigned Passengers", p),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: t.withValues(alpha: 0.04)),
              ),
              child: _guestSrc(p, c, t),
            ),
            const SizedBox(height: 32),
            _buildGlassLabel("Vehicle Assignments", p),
            const SizedBox(height: 16),
            _groupList(p, c, d, t),
          ],
        ),
      ],
    );
  }

  Widget _guestSrc(Color p, Color c, Color t) {
    if (_unassignedGuests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(
                Icons.done_all_rounded,
                color: Colors.green.withValues(alpha: 0.5),
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                "All passengers allocated",
                style: TextStyle(
                  color: t.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _unassignedGuests.map((g) => _dragGuest(g, p, c, t)).toList(),
    );
  }

  Widget _dragGuest(Guest g, Color p, Color c, Color t) {
    String label = g.name.trim().isEmpty
        ? "Guest ${_guests.indexOf(g) + 1}"
        : g.name;
    return Draggable<Guest>(
      data: g,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: p,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: p.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: t.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.withValues(alpha: 0.2),
            ),
          ),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 5,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.drag_indicator_rounded,
              size: 14,
              color: p.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: t,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupList(Color p, Color c, bool d, Color t) {
    return Column(
      children: _guestGroups.entries
          .map(
            (ent) => DragTarget<Guest>(
              onAcceptWithDetails: (details) {
                final g = details.data;
                setState(() {
                  _unassignedGuests.remove(g);
                  for (var l in _guestGroups.values) {
                    l.remove(g);
                  }
                  _guestGroups[ent.key]!.add(g);
                });
              },
              builder: (ctx, cand, rej) {
                bool isO = cand.isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isO ? p.withValues(alpha: 0.12) : c,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isO ? p : t.withValues(alpha: 0.02),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isO
                            ? p.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: p.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.directions_bus_filled_rounded,
                                  size: 16,
                                  color: p,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "VEHICLE ${ent.key + 1}",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: t,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          if (ent.value.isNotEmpty)
                            Text(
                              "${ent.value.length} Assigned",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: t.withValues(alpha: 0.3),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (ent.value.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              "Drag guests here",
                              style: TextStyle(
                                fontSize: 11,
                                color: t.withValues(alpha: 0.2),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ent.value
                              .map(
                                (g) => _assignedGuestChip(g, ent.key, p, t, c),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                );
              },
            ),
          )
          .toList(),
    );
  }

  Widget _assignedGuestChip(Guest g, int gIndex, Color p, Color t, Color c) {
    String label = g.name.trim().isEmpty
        ? "Guest ${_guests.indexOf(g) + 1}"
        : g.name;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Chip(
        label: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: p),
        ),
        backgroundColor: p.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        deleteIcon: Icon(
          Icons.close_rounded,
          size: 14,
          color: p.withValues(alpha: 0.5),
        ),
        onDeleted: () {
          setState(() {
            _guestGroups[gIndex]!.remove(g);
            _unassignedGuests.add(g);
          });
        },
      ),
    );
  }

  Widget _stageVehicles(Color p, bool d) {
    Color c = d ? const Color(0xFF1E293B) : Colors.white;
    Color t = d ? Colors.white : const Color(0xFF0F172A);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildGlassLabel("Fleet Selection", p),
        const SizedBox(height: 12),
        Text(
          "Select available vehicles for your trip segments.",
          style: TextStyle(fontSize: 13, color: t.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 32),
        if (_isLoadingVehicles)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else
          ..._guestGroups.keys.map((idx) {
            int gCount = _guestGroups[idx]?.length ?? 0;
            return Column(
              children: [
                _resSelector(
                  _enableReturnJourney ? "OUTBOUND VEHICLE (SLOT ${idx + 1})" : "VEHICLE FOR SLOT ${idx + 1}",
                  _availableVehicles,
                  _selectedVehicles[idx],
                  (v) => setState(() => _selectedVehicles[idx] = v),
                  c,
                  t,
                  p,
                  isV: true,
                  guestCount: gCount,
                ),
                if (_enableReturnJourney) ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text("Use same vehicle for return journey", style: TextStyle(color: t, fontWeight: FontWeight.w600, fontSize: 14)),
                    activeThumbColor: p,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    value: _sameVehicleForBoth,
                    onChanged: (val) {
                      setState(() {
                        _sameVehicleForBoth = val;
                        if (val) _selectedVehiclesReturn[idx] = null;
                      });
                    },
                  ),
                  if (!_sameVehicleForBoth) ...[
                    const SizedBox(height: 16),
                    if (_isLoadingVehiclesReturn)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                    else
                      _resSelector(
                        "RETURN VEHICLE (SLOT ${idx + 1})",
                        _availableVehiclesReturn,
                        _selectedVehiclesReturn[idx],
                        (v) => setState(() => _selectedVehiclesReturn[idx] = v),
                        c,
                        t,
                        p,
                        isV: true,
                        guestCount: gCount,
                      ),
                  ]
                ]
              ],
            );
          }),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _stageDrivers(Color p, bool d) {
    Color c = d ? const Color(0xFF1E293B) : Colors.white;
    Color t = d ? Colors.white : const Color(0xFF0F172A);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildGlassLabel("Driver Assignment", p),
        const SizedBox(height: 12),
        Text(
          "Assign drivers to the selected vehicles.",
          style: TextStyle(fontSize: 13, color: t.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 32),
        if (_isLoadingDrivers)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else
          ..._guestGroups.keys.map((idx) {
            return Column(
              children: [
                _resSelector(
                  _enableReturnJourney ? "OUTBOUND DRIVER (${_selectedVehicles[idx]?['vehicle_number'] ?? 'SLOT ${idx + 1}'})" : "DRIVER FOR ${_selectedVehicles[idx]?['vehicle_number'] ?? 'SLOT ${idx + 1}'}",
                  _availableDrivers,
                  _selectedDrivers[idx],
                  (v) => setState(() => _selectedDrivers[idx] = v),
                  c,
                  t,
                  p,
                  isV: false,
                ),
                if (_enableReturnJourney) ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text("Use same driver for return journey", style: TextStyle(color: t, fontWeight: FontWeight.w600, fontSize: 14)),
                    activeThumbColor: p,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    value: _sameDriverForBoth,
                    onChanged: (val) {
                      setState(() {
                        _sameDriverForBoth = val;
                        if (val) _selectedDriversReturn[idx] = null;
                      });
                    },
                  ),
                  if (!_sameDriverForBoth) ...[
                    const SizedBox(height: 16),
                    if (_isLoadingDriversReturn)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                    else
                      _resSelector(
                        "RETURN DRIVER (${_selectedVehiclesReturn[idx]?['vehicle_number'] ?? 'SLOT ${idx + 1}'})",
                        _availableDriversReturn,
                        _selectedDriversReturn[idx],
                        (v) => setState(() => _selectedDriversReturn[idx] = v),
                        c,
                        t,
                        p,
                        isV: false,
                      ),
                  ]
                ]
              ],
            );
          }),
        const SizedBox(height: 40),
      ],
    );
  }

  Future<void> _showSelectionSheet({
    required String title,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic>? selected,
    required Function(Map<String, dynamic>) onSelect,
    required bool isVehicle,
    required Color p,
    required Color c,
    required Color t,
    int? currentGuestCount,
  }) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter and Sort items before building the sheet
    List<Map<String, dynamic>> filteredItems = List.from(items);
    if (isVehicle) {
      Set<int> assignedIds = _selectedVehicles.values
          .where((v) => v != null && v['id'] != (selected?['id']))
          .map((v) => v!['id'] as int)
          .toSet();
      filteredItems = filteredItems
          .where((v) => !assignedIds.contains(v['id']))
          .toList();

      if (currentGuestCount != null) {
        filteredItems.sort((a, b) {
          int ac = int.tryParse(a['capacity']?.toString() ?? "0") ?? 0;
          int bc = int.tryParse(b['capacity']?.toString() ?? "0") ?? 0;
          
          bool aAvail = (a['available'] != false);
          bool bAvail = (b['available'] != false);

          if (aAvail != bAvail) return aAvail ? -1 : 1;
          
          bool aDef = a['default_driver'] != null;
          bool bDef = b['default_driver'] != null;
          if (aDef != bDef) return aDef ? -1 : 1;

          return ac.compareTo(bc);
        });
      }
    }

    String searchQuery = "";

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final bool isDark = Theme.of(context).brightness == Brightness.dark;

            // Filter the items list dynamically
            final List<Map<String, dynamic>> currentFilteredList = filteredItems.where((item) {
              if (searchQuery.isEmpty) return true;
              if (isVehicle) {
                final vNumber = (item['vehicle_number'] ?? "").toString().toLowerCase();
                final vType = (item['vehicle_type_name'] ?? "").toString().toLowerCase();
                return vNumber.contains(searchQuery.toLowerCase()) || 
                       vType.contains(searchQuery.toLowerCase());
              } else {
                final dName = (item['user']?['name'] ?? item['name'] ?? "").toString().toLowerCase();
                final dPhone = (item['user']?['phone'] ?? "").toString().toLowerCase();
                return dName.contains(searchQuery.toLowerCase()) || 
                       dPhone.contains(searchQuery.toLowerCase());
              }
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.95),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: t.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isVehicle && currentGuestCount != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: p.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "REQUIRED CAPACITY: $currentGuestCount SEATS",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: p,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Sleek Search Bar for vehicles or drivers
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
                          hintText: isVehicle ? "Search vehicle number..." : "Search driver name...",
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
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            searchQuery = val;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (currentFilteredList.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isVehicle
                                  ? Icons.directions_bus_rounded
                                  : Icons.person_off_rounded,
                              size: 48,
                              color: t.withValues(alpha: 0.1),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No matching ${isVehicle ? 'vehicles' : 'drivers'} found",
                              style: TextStyle(
                                color: t.withValues(alpha: 0.3),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                        itemCount: currentFilteredList.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final item = currentFilteredList[i];
                          final bool isSelected =
                              selected != null && (item['id'] == selected['id']);

                          String mainText = "";
                          String subText = "";
                          int capacity = 0;

                          if (isVehicle) {
                            mainText = item['vehicle_number'] ?? "Unknown";
                            subText = item['vehicle_type_name'] ?? "General";
                            capacity =
                                int.tryParse(item['capacity']?.toString() ?? "0") ??
                                0;
                          } else {
                            mainText =
                                item['user']?['name'] ?? item['name'] ?? "Unknown";
                            subText =
                                "📞 ${item['user']?['phone'] ?? 'No Contact'}";
                          }

                          String status = (item['status'] ?? "AVAILABLE")
                              .toString()
                              .toUpperCase();
                          bool isDisabled = (item['available'] == false);

                          return GestureDetector(
                            onTap: isDisabled
                                ? () {
                                    String msg = "⚠️ Not Available for this schedule";
                                    ScaffoldMessenger.of(
                                      ctx,
                                    ).showSnackBar(SnackBar(content: Text(msg)));
                                  }
                                : () {
                                    onSelect(item); // PASS ORIGINAL ITEM
                                    Navigator.pop(ctx);
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? p.withValues(alpha: 0.1)
                                    : (isDisabled
                                          ? t.withValues(alpha: 0.01)
                                          : t.withValues(alpha: 0.03)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? p
                                      : (isDisabled
                                            ? Colors.red.withValues(alpha: 0.2)
                                            : Colors.transparent),
                                  width: 1.5,
                                ),
                              ),
                              child: Opacity(
                                opacity: isDisabled ? 0.4 : 1.0,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: (isSelected ? p : t).withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        isVehicle
                                            ? Icons.directions_bus_filled_rounded
                                            : Icons.person_rounded,
                                        size: 20,
                                        color: isSelected
                                            ? p
                                            : t.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            mainText,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: t,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                subText,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: t.withValues(alpha: 0.4),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (isVehicle &&
                                                  item['default_driver'] != null)
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      "•",
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: t.withValues(
                                                          alpha: 0.2,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Icon(
                                                      Icons.person_rounded,
                                                      size: 12,
                                                      color: Colors.green
                                                          .withValues(alpha: 0.7),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      item['default_driver']['name'],
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.green,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              if (isVehicle) ...[
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        (isDisabled
                                                                ? Colors.red
                                                                : p)
                                                            .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    "Cap: $capacity",
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w900,
                                                      color: (isDisabled
                                                          ? Colors.red
                                                          : p),
                                                    ),
                                                  ),
                                                ),
                                                if (!isDisabled)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green
                                                          .withValues(alpha: 0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      "AVAILABLE",
                                                      style: TextStyle(
                                                        fontSize: 8,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.green,
                                                      ),
                                                    ),
                                                  )
                                                else if (isDisabled &&
                                                    isVehicle &&
                                                    item['available'] == false)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.withValues(
                                                        alpha: 0.1,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      "UNAVAILABLE",
                                                      style: TextStyle(
                                                        fontSize: 8,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isDisabled)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          item['available'] == false
                                              ? "UNAVAILABLE"
                                              : (status == "ON_LEAVE"
                                                    ? "ON LEAVE"
                                                    : status),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.red,
                                          ),
                                        ),
                                      )
                                    else if (!isVehicle && status == "ON_TRIP")
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.cyan.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          "ON TRIP",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.cyan,
                                          ),
                                        ),
                                      )
                                    else if (!isVehicle && status == "AVAILABLE")
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          "AVAILABLE",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.green,
                                          ),
                                        ),
                                      )
                                    else if (isSelected)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: p,
                                        size: 20,
                                      ),
                                  ],
                                ),
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

  Widget _resSelector(
    String lbl,
    List<Map<String, dynamic>> items,
    Map<String, dynamic>? sel,
    Function(Map<String, dynamic>) onS,
    Color c,
    Color t,
    Color p, {
    required bool isV,
    int? guestCount,
  }) {
    String dispTitle = sel != null
        ? (isV
              ? sel['vehicle_number']
              : (sel['user']?['name'] ?? sel['name'] ?? "Unknown"))
        : (isV ? "Choose Vehicle" : "Choose Driver");
    String? dispSub = sel != null
        ? (isV
              ? sel['vehicle_type_name']
              : "📞 ${sel['user']?['phone'] ?? 'No Contact'}")
        : null;
    String? defDriver = (isV && sel != null && sel['default_driver'] != null)
        ? sel['default_driver']['name']
        : null;
    String? driverStatus = (!isV && sel != null)
        ? (sel['status'] ?? "AVAILABLE").toString().toUpperCase()
        : null;

    return GestureDetector(
      onTap: () => _showSelectionSheet(
        title: isV ? "Select Vehicle" : "Select Driver",
        items: items,
        selected: sel,
        onSelect: onS,
        isVehicle: isV,
        p: p,
        c: c,
        t: t,
        currentGuestCount: isV ? guestCount : null,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: t.withValues(alpha: 0.04), width: 1.5),
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
            Text(
              lbl,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: p,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (sel != null ? p : t).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isV
                        ? Icons.directions_bus_filled_rounded
                        : Icons.person_rounded,
                    size: 20,
                    color: sel != null ? p : t.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dispTitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: sel != null ? t : t.withValues(alpha: 0.3),
                        ),
                      ),
                      if (dispSub != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          dispSub,
                          style: TextStyle(
                            fontSize: 12,
                            color: t.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (defDriver != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "👤 $defDriver",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.green,
                      ),
                    ),
                  ),
                if (driverStatus != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (driverStatus == "ON_LEAVE"
                                  ? Colors.red
                                  : (driverStatus == "ON_TRIP"
                                        ? Colors.cyan
                                        : Colors.green))
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      driverStatus.replaceAll("_", " "),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: (driverStatus == "ON_LEAVE"
                            ? Colors.red
                            : (driverStatus == "ON_TRIP"
                                  ? Colors.cyan
                                  : Colors.green)),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: t.withValues(alpha: 0.2),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassLabel(String txt, Color p) => Row(
    children: [
      Container(
        width: 4,
        height: 16,
        decoration: BoxDecoration(
          color: p,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        txt.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w900,
          color: p.withValues(alpha: 0.6),
        ),
      ),
    ],
  );

  Widget _stageReview(Color p, bool d) {
    Color c = d ? const Color(0xFF1E293B) : Colors.white;
    Color t = d ? Colors.white : const Color(0xFF0F172A);
    bool isAdmin = _userRole.toLowerCase().contains('admin');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildGlassLabel("Verify Request", p),
        const SizedBox(height: 12),
        Text(
          "Final review before creating the full route request.",
          style: TextStyle(fontSize: 13, color: t.withValues(alpha: 0.5)),
        ),
        if (_enableReturnJourney && _returnStartDate != null) ...[
          _buildGlassLabel("Route 1 Details (Outbound)", p),
          const SizedBox(height: 16),
        ],
        _sumCard(
          _enableReturnJourney ? "OUTBOUND MISSION" : "MISSION DETAILS",
          Icons.map_outlined,
          [
            {"label": "Route Name", "value": _routeNameController.text},
            {"label": "Purpose", "value": _purposeController.text},
            {"label": "Department", "value": _selectedDepartmentName ?? "Not Selected"},
            {
              "label": "Guests",
              "value":
                  "${int.tryParse(_passengerCountController.text) ?? 1} People",
            },
            {"label": "Journey", "value": _routeType ?? "Not Selected"},
          ],
          p,
          c,
          t,
        ),
        _sumCard(
          _enableReturnJourney ? "OUTBOUND SCHEDULE" : "SCHEDULE",
          Icons.calendar_today_rounded,
          [
            {
              "label": "Start",
              "value": _startDate != null
                  ? DateFormat('EEE, MMM dd • hh:mm a').format(_startDate!)
                  : 'N/A',
            },
            {
              "label": "End",
              "value": _startDate != null
                  ? DateFormat('EEE, MMM dd • hh:mm a').format(_startDate!.add(Duration(minutes: (_travelDurationMinutes + 60).toInt())))
                  : 'N/A',
            },
            {
              "label": "Est. Time",
              "value": _travelDurationMinutes > 0
                  ? (_travelDurationMinutes >= 60
                      ? '${_travelDurationMinutes ~/ 60}h ${(_travelDurationMinutes % 60).toInt()}m'
                      : '${_travelDurationMinutes.toInt()} mins')
                  : 'N/A',
            },
            {
              "label": "Approx Distance",
              "value": _approxDistanceKm > 0
                  ? '${_approxDistanceKm.toStringAsFixed(1)} km'
                  : 'N/A',
            },
          ],
          p,
          c,
          t,
        ),
        if (_enableReturnJourney && _returnStartDate != null) ...[
          const SizedBox(height: 16),
          _buildGlassLabel("Route 2 Details (Return)", p),
          const SizedBox(height: 16),
          _sumCard(
            "RETURN MISSION",
            Icons.map_outlined,
            [
              {"label": "Route Name", "value": _returnRouteNameController.text},
              {"label": "Purpose", "value": _purposeController.text},
              {"label": "Department", "value": _selectedDepartmentName ?? "Not Selected"},
              {
                "label": "Guests",
                "value":
                    "${int.tryParse(_passengerCountController.text) ?? 1} People",
              },
              {"label": "Journey", "value": _routeType ?? "Not Selected"},
            ],
            p,
            c,
            t,
          ),
          _sumCard(
            "RETURN SCHEDULE",
            Icons.calendar_today_rounded,
            [
              {
                "label": "Start",
                "value": DateFormat('EEE, MMM dd • hh:mm a').format(_returnStartDate!),
              },
              {
                "label": "End",
                "value": DateFormat('EEE, MMM dd • hh:mm a').format(_returnStartDate!.add(Duration(minutes: (_travelDurationMinutes + 60).toInt()))),
              },
              {
                "label": "Est. Time",
                "value": _travelDurationMinutes > 0
                    ? (_travelDurationMinutes >= 60
                        ? '${_travelDurationMinutes ~/ 60}h ${(_travelDurationMinutes % 60).toInt()}m'
                        : '${_travelDurationMinutes.toInt()} mins')
                    : 'N/A',
              },
              {
                "label": "Approx Distance",
                "value": _approxDistanceKm > 0
                    ? '${_approxDistanceKm.toStringAsFixed(1)} km'
                    : 'N/A',
              },
            ],
            p,
            c,
            t,
          ),
        ],
        if (isAdmin) ...[
          _buildGlassLabel("Vehicle & Driver Assignments", p),
          const SizedBox(height: 16),
          ..._guestGroups.entries.map((ent) {
            final veh = _selectedVehicles[ent.key];
            final dri = _selectedDrivers[ent.key];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: t.withValues(alpha: 0.04)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: p.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.directions_bus_filled_rounded,
                          size: 16,
                          color: p,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "GROUP ${ent.key + 1}",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: t,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _revRow(
                    Icons.local_shipping_rounded,
                    "Outbound Vehicle: ${veh?['vehicle_number'] ?? "No Vehicle Selected"}",
                    t,
                  ),
                  _revRow(
                    Icons.person_rounded,
                    "Outbound Driver: ${dri?['user']?['name'] ?? dri?['name'] ?? "No Driver Assigned"}",
                    t,
                  ),
                  if (_enableReturnJourney) ...[
                    const SizedBox(height: 8),
                    _revRow(
                      Icons.local_shipping_rounded,
                      "Return Vehicle: ${_sameVehicleForBoth ? (veh?['vehicle_number'] ?? 'Same as Outbound') : (_selectedVehiclesReturn[ent.key]?['vehicle_number'] ?? 'No Vehicle Selected')}",
                      t,
                    ),
                    _revRow(
                      Icons.person_rounded,
                      "Return Driver: ${_sameDriverForBoth ? (dri?['user']?['name'] ?? dri?['name'] ?? 'Same as Outbound') : (_selectedDriversReturn[ent.key]?['user']?['name'] ?? _selectedDriversReturn[ent.key]?['name'] ?? 'No Driver Assigned')}",
                      t,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    "GUESTS: ${ent.value.map((g) => g.name.isEmpty ? 'Guest' : g.name).join(', ')}",
                    style: TextStyle(
                      fontSize: 11,
                      color: t.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _revRow(IconData icon, String val, Color t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 16, color: t.withValues(alpha: 0.3)),
        const SizedBox(width: 12),
        Text(
          val,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: t.withValues(alpha: 0.8),
          ),
        ),
      ],
    ),
  );

  Widget _sumCard(
    String title,
    IconData icon,
    List<Map<String, String>> stats,
    Color p,
    Color c,
    Color t,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: p),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: p,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...stats.map(
            (s) {
              final label = s['label'] ?? "";
              final val = s['value'];
              
              if (val == null || val.isEmpty || val.trim() == 'null' || val.trim() == 'Not Selected') {
                return const SizedBox.shrink();
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            color: t.withValues(alpha: 0.45),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Text(
                            val,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              color: t,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (stats.indexOf(s) != stats.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade200,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionToolbar(Color p) {
    final bool isAdmin = _userRole.toLowerCase().contains('admin');
    bool isL = _currentStep == _totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: TextButton(
                onPressed: () {
                  int vCount = int.tryParse(_vehicleCountController.text) ?? 1;
                  if (_currentStep == 2 && vCount == 1) {
                    setState(() => _currentStep = 0);
                  } else {
                    setState(() => _currentStep--);
                  }
                },
                child: const Text(
                  "BACK",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      if (_currentStep == 0) {
                        if (_routeType == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Please select a route type (One Way, Two Way, or Multi Day)",
                              ),
                            ),
                          );
                          return;
                        }
                        
                        bool hasDateErrors = false;
                        if (_startDate == null) hasDateErrors = true;
                        if (_routeType != 'One Way' && _endDate == null) hasDateErrors = true;
                        if (_enableReturnJourney && _returnStartDate == null) hasDateErrors = true;
                        
                        if (hasDateErrors) {
                          setState(() {
                            _showValidationError = true;
                          });
                        }

                        if (_formKey.currentState!.validate()) {
                          int pCount =
                              int.tryParse(_passengerCountController.text) ?? 1;
                          int vCount =
                              int.tryParse(_vehicleCountController.text) ?? 1;
                          if (vCount > pCount) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Error: Vehicle count cannot exceed passenger count",
                                ),
                              ),
                            );
                            return;
                          }
                          if (_startDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Please select departure date and time",
                                ),
                              ),
                            );
                            return;
                          }
                          if (_routeType != 'One Way' && _endDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Please select return date and time",
                                ),
                              ),
                            );
                            return;
                          }
                          if (_enableReturnJourney && _returnStartDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Please select return journey date and time",
                                ),
                              ),
                            );
                            return;
                          }

                          // Location Validation
                          if (_stops.length < 2 || 
                              _stops.first['address'].toString().isEmpty || 
                              _stops.last['address'].toString().isEmpty ||
                              _stops.first['lat'] == null ||
                              _stops.last['lat'] == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please select both Start and End locations"),
                              ),
                            );
                            return;
                          }
                          _prepareGrouping();
                          if (vCount == 1) {
                            _autoAllocateGuests();
                            if (!isAdmin) {
                              setState(() => _currentStep = 2); // Jump to Verify
                            } else {
                              _fetchAvailableVehicles();
                              setState(() => _currentStep = 2);
                            }
                          } else {
                            setState(() => _currentStep++);
                          }
                        }
                      } else if (_currentStep == 1) {
                        if (_unassignedGuests.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Please assign all guests to vehicles",
                              ),
                            ),
                          );
                          return;
                        }

                        if (!isAdmin) {
                          setState(() => _currentStep++);
                        } else {
                          // For Admin, proceed to Fleet Selection
                          _fetchAvailableVehicles();
                          setState(() => _currentStep++);
                        }
                      } else if (_currentStep == 2 && isAdmin) {
                        int vCount =
                            int.tryParse(_vehicleCountController.text) ?? 1;
                        if (_selectedVehicles.length < vCount ||
                            _selectedVehicles.values.any((v) => v == null)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Please select a vehicle for each segment",
                              ),
                            ),
                          );
                          return;
                        }
                        _fetchAvailableDrivers();
                        setState(() => _currentStep++);
                      } else if (_currentStep == 3 && isAdmin) {
                        int vCount = int.tryParse(_vehicleCountController.text) ?? 1;
                        if (_selectedDrivers.length < vCount || _selectedDrivers.values.any((d) => d == null)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please select a driver for each segment"),
                            ),
                          );
                          return;
                        }
                        setState(() => _currentStep++);
                      } else if (_currentStep == 4 || (!isAdmin && _currentStep == 2)) {
                        _submitForm();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: p,
                minimumSize: const Size(double.infinity, 64),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isL ? "CREATE FULL ROUTE" : "CONTINUE",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
