import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tripzo/components/location_selector.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';

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

  Map<String, dynamic> toJson() => { "passenger_name": name, "phone": phone, "country_code": countryCode, "is_primary_contact": false };
  factory Guest.fromJson(Map<String, dynamic> json) => Guest(name: json['passenger_name'] ?? "", phone: json['phone'] ?? "", countryCode: json['country_code'] ?? "+91");
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- Step Logic ---
  int _currentStep = 0;
  String _userRole = 'faculty';
  int _totalSteps = 2;

  // --- Step 1: Details ---
  String _routeType = 'One Way';
  DateTime? _startDate, _endDate;
  final TextEditingController _routeNameController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _passengerCountController = TextEditingController(text: "1");
  final TextEditingController _vehicleCountController = TextEditingController(text: "1");
  final TextEditingController _luggageController = TextEditingController();
  final TextEditingController _specialReqController = TextEditingController();

  List<String> _stops = [];
  List<Guest> _guests = [Guest(name: "", phone: "")];

  // --- Step 2: Grouping ---
  List<Guest> _unassignedGuests = [];
  Map<int, List<Guest>> _guestGroups = {};

  // --- Step 3: Vehicles ---
  List<Map<String, dynamic>> _availableVehicles = [];
  Map<int, Map<String, dynamic>?> _selectedVehicles = {};
  bool _isLoadingVehicles = false;

  // --- Step 4: Drivers ---
  List<Map<String, dynamic>> _availableDrivers = [];
  Map<int, Map<String, dynamic>?> _selectedDrivers = {};
  bool _isLoadingDrivers = false;
  double _travelDurationMinutes = 0;
  double _approxDistanceKm = 0;
  bool _isSubmitting = false;

  final ScrollController _mainScroll = ScrollController();
  final PageStorageKey _scrollKey = const PageStorageKey("request_scroll");
  int _visibleGuestSlots = 2;

  @override
  void initState() { 
    super.initState(); 
    _checkRole(); 
    _passengerCountController.addListener(_syncGuests);
  }

  void _syncGuests() {
    final count = int.tryParse(_passengerCountController.text) ?? 1;
    if (count > _guests.length) {
      setState(() {
        while (_guests.length < count) _guests.add(Guest(name: "", phone: ""));
      });
    }
    if (_visibleGuestSlots > count) setState(() => _visibleGuestSlots = count);
    if (_visibleGuestSlots < 2 && count >= 2) setState(() => _visibleGuestSlots = 2);
  }

  Future<void> _checkRole() async {
    final role = await UserStore.getRole();
    if (mounted) setState(() { 
      _userRole = role?.toLowerCase() ?? 'faculty'; 
      _totalSteps = _userRole.contains('admin') ? 5 : 2; 
      if (_stops.isEmpty) _stops = ["Chennai", "Tiruppur"];
    });
  }

  @override
  void dispose() { _routeNameController.dispose(); _purposeController.dispose(); _passengerCountController.dispose(); _vehicleCountController.dispose(); _luggageController.dispose(); _specialReqController.dispose(); super.dispose(); }

  // --- Logic Helpers ---

  Future<void> _fetchAvailableVehicles() async {
    if (_startDate == null) return; setState(() => _isLoadingVehicles = true);
    try {
      final token = await UserStore.getToken(); final start = _toIso(_startDate!); final end = _endDate != null ? _toIso(_endDate!) : start;
      final url = "${ApiConstants.getAvailableVehicles}?start_datetime=$start&end_datetime=$end";
      debugPrint("Fetching vehicles: $url");
      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));
      debugPrint("Vehicles Response [${response.statusCode}]: ${response.body}");
      if (response.statusCode == 200) { 
        final data = json.decode(response.body); 
        setState(() => _availableVehicles = List<Map<String, dynamic>>.from(data['data']['vehicles'] ?? [])); 
      }
    } catch (e) { debugPrint("Err: $e"); } finally { setState(() => _isLoadingVehicles = false); }
  }

  Future<void> _fetchAvailableDrivers() async {
    if (_startDate == null) return; setState(() => _isLoadingDrivers = true);
    try {
      final token = await UserStore.getToken(); final start = _toIso(_startDate!); final end = _endDate != null ? _toIso(_endDate!) : start;
      final url = "${ApiConstants.getAvailableDrivers}?start_datetime=$start&end_datetime=$end";
      debugPrint("Fetching drivers: $url");
      final response = await http.get(Uri.parse(url), headers: ApiConstants.getHeaders(token));
      debugPrint("Drivers Response [${response.statusCode}]: ${response.body}");
      if (response.statusCode == 200) { 
        final data = json.decode(response.body); 
        setState(() => _availableDrivers = List<Map<String, dynamic>>.from(data['data']['drivers'] ?? [])); 
        _autoProposeDrivers(); 
      }
    } catch (e) { debugPrint("Err: $e"); } finally { setState(() => _isLoadingDrivers = false); }
  }

  void _autoProposeDrivers() {
    _selectedVehicles.forEach((groupId, vehicle) {
      if (vehicle != null && vehicle['default_driver'] != null) {
        final defDriver = vehicle['default_driver'];
        final found = _availableDrivers.firstWhere((d) => d['id'] == defDriver['driver_id'], orElse: () => <String, dynamic>{});
        if (found.isNotEmpty) setState(() => _selectedDrivers[groupId] = found);
      }
    });
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
      for (int i = 0; i < vCount; i++) _guestGroups[i] = []; 
    });
  }

  void _updateEndDate() {
    if (_routeType != 'Multi Day' && _startDate != null) {
      final addedMinutes = (_travelDurationMinutes * 2) + (5 * 60);
      _endDate = _startDate!.add(Duration(minutes: addedMinutes.toInt()));
    }
  }

  String _toIso(DateTime dt) => DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(dt);

  Future<void> _submitForm() async {
    setState(() => _isSubmitting = true);
    try {
      final token = await UserStore.getToken();
      
      // Constructing passengers list (Fill generic names for empty ones)
      int pLimit = int.tryParse(_passengerCountController.text) ?? 1;
      List<Map<String, dynamic>> passengers = [];
      for (int i = 0; i < pLimit; i++) {
        String name = _guests[i].name.trim();
        passengers.add({
          "passenger_name": name.isEmpty ? "Guest ${i + 1}" : name,
          "phone": _guests[i].phone.trim(),
          "country_code": _guests[i].countryCode,
          "is_primary_contact": i == 0
        });
      }

      // LEG-1 Vehicles
      List<Map<String, dynamic>> leg1Vehicles = [];
      _guestGroups.forEach((idx, guests) {
        leg1Vehicles.add({
          "vehicle_id": _selectedVehicles[idx]?['id'],
          "driver_id": _selectedDrivers[idx]?['id'],
          // MUST use original _guests list to get stable 1-based indices for the server
          "passenger_ids": guests.map((g) => _guests.indexOf(g) + 1).toList() 
        });
      });

      // Date Logic for Round Trip
      DateTime? outboundEnd;
      DateTime? returnStart;
      
      if (_routeType != 'One Way' && _startDate != null) {
        outboundEnd = _startDate!.add(Duration(minutes: _travelDurationMinutes.toInt()));
        returnStart = outboundEnd.add(const Duration(hours: 5)); // Stay duration
      }

      // Constructing the full request body
      final Map<String, dynamic> body = {
        "route_name": _routeNameController.text.trim(),
        "trip_type": _routeType == 'One Way' ? 'ONE_WAY' : 'ROUND_TRIP',
        "requested_for_date": DateFormat('yyyy-MM-dd').format(_startDate ?? DateTime.now()),
        "start_datetime": _startDate != null ? _toIso(_startDate!) : null,
        "end_datetime": outboundEnd != null ? _toIso(outboundEnd) : (_endDate != null ? _toIso(_endDate!) : null),
        if (_routeType != 'One Way' && returnStart != null)
          "return_start_datetime": _toIso(returnStart),
        "purpose": _purposeController.text.trim(),
        "passenger_count": int.tryParse(_passengerCountController.text) ?? 1,
        "vehicle_count": int.tryParse(_vehicleCountController.text) ?? 1,
        "approx_distance_km": _approxDistanceKm,
        "approx_duration_minutes": _travelDurationMinutes.toInt(),
        "luggage_details": _luggageController.text.trim(),
        "special_instructions": _specialReqController.text.trim(),
        "stops": _stops.map((s) => {"stop_name": s}).toList(),
        "passengers": passengers,
        "admin_assignments": [
          {"leg_code": "LEG-1", "vehicles": leg1Vehicles},
          if (_routeType != 'One Way')
            {"leg_code": "LEG-2", "vehicles": leg1Vehicles}
        ]
      };

      // Logging as a CURL with pretty-printed JSON
      const encoder = JsonEncoder.withIndent('  ');
      String prettyJson = encoder.convert(body);
      
      String curl = "curl --location '${ApiConstants.adminCreateFull}' \\\n"
          "--header 'Authorization: TMS $token' \\\n"
          "--header 'Content-Type: application/json' \\\n"
          "--data '$prettyJson'";
      
      debugPrint("\n🚀 [FINAL CURL SENDING]:\n$curl\n");

      final resp = await http.post(
        Uri.parse(ApiConstants.adminCreateFull),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(body),
      );

      debugPrint("📥 [SERVER RESPONSE] (${resp.statusCode}): ${resp.body}");

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Route Created Successfully!")));
        Navigator.pop(context, true);
      } else {
        final err = json.decode(resp.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Failed: ${err['message'] ?? 'Unknown error'}")));
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
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color pColor = const Color(0xFF6366F1);

    return Theme(
      data: Theme.of(context).copyWith(textTheme: GoogleFonts.interTextTheme()),
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

  Widget _buildMeshBg(Color p) => Positioned(top: -100, right: -100, child: Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [p.withOpacity(0.08), Colors.transparent]))));

  Widget _buildPremiumHeader(BuildContext context, Color p, bool d) {
    double prg = (_currentStep + 1) / _totalSteps;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(onTap: () { Navigator.pop(context); }, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: p.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.close_rounded, color: p, size: 22))),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("TRANSPORT", style: GoogleFonts.montserrat(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w900, color: p)),
                    Text("New Request", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: d ? Colors.white : const Color(0xFF0F172A))),
                  ]),
                ],
              ),
              _buildProgressCircle(p, prg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCircle(Color p, double prg) => Stack(alignment: Alignment.center, children: [
    SizedBox(width: 50, height: 50, child: CircularProgressIndicator(value: prg, strokeWidth: 4, backgroundColor: p.withOpacity(0.05), valueColor: AlwaysStoppedAnimation<Color>(p))),
    Text("${(prg * 100).toInt()}%", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: p)),
  ]);

  Widget _buildCurrentStage(Color p, bool d) {
    switch (_currentStep) {
      case 0: return _stageRouteDetails(p, d);
      case 1: return _stageGrouping(p, d);
      case 2: return _stageVehicles(p, d);
      case 3: return _stageDrivers(p, d);
      case 4: return _stageReview(p, d);
      default: return Container();
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
                  onTap: () => setState(() { _routeType = type; }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8), 
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    decoration: BoxDecoration(
                      color: act ? p : p.withOpacity(0.04), 
                      borderRadius: BorderRadius.circular(16), 
                      border: Border.all(color: act ? p : Colors.transparent, width: 1.5)
                    ),
                    child: Center(child: Text(type, style: TextStyle(color: act ? Colors.white : p, fontWeight: FontWeight.w800, fontSize: 13))),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          _premiumInput("Journey Name*", _routeNameController, "e.g. Science Fair visit", Icons.route_rounded, c, t, p, isReq: true),
          _premiumInput("Journey Purpose", _purposeController, "e.g. Industrial visit for Dept", Icons.info_outline, c, t, p),
          _buildGlassLabel("Journey Schedule", p),
          const SizedBox(height: 16),
          _buildEnhancedScheduleCards(p, c, t, d),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(child: _premiumInput("Passengers*", _passengerCountController, "1", Icons.people_outline, c, t, p, isNum: true, isReq: true)),
            const SizedBox(width: 16),
            Expanded(child: _premiumInput("Vehicles*", _vehicleCountController, "1", Icons.directions_bus_filled_outlined, c, t, p, isNum: true, isReq: true)),
          ]),
          _buildGlassLabel("Passenger Details", p),
          const SizedBox(height: 16),
          ...List.generate(_visibleGuestSlots, (i) {
            if (i >= _guests.length) return const SizedBox.shrink();
            bool isCompulsory = i < 2;
            return _premiumGuestEntry(i, _guests[i], c, t, p, isReq: isCompulsory);
          }),
          _addGuestBtn(p),
          const SizedBox(height: 32),
          _buildGlassLabel("Route Stops", p),
          const SizedBox(height: 12),
          LocationSelector(
            cardColor: c, 
            titleColor: t, 
            accentColor: p, 
            initialAddresses: _stops,
            onChanged: (a, dist, dur) { setState(() { _stops = a; _travelDurationMinutes = dur; _approxDistanceKm = dist; _updateEndDate(); }); }
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildEnhancedScheduleCards(Color p, Color c, Color t, bool isDark) {
    return Column(children: [
      _niceScheduleTile("Departure Date & Time*", _startDate, (v) {
        setState(() { 
          _startDate = v; 
          _updateEndDate();
        });
      }, p, c, t),
      if (_routeType == 'Multi Day') ...[
        const SizedBox(height: 12),
        _niceScheduleTile("Expected Return*", _endDate, (v) => setState(() { _endDate = v; }), p, c, t),
      ] else if (_startDate != null && _endDate != null) ...[
        const SizedBox(height: 12),
        _buildReadOnlyEndTile(isDark, p, c, t),
      ],
    ]);
  }

  Widget _buildReadOnlyEndTile(bool isDark, Color p, Color c, Color t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: c.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: t.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 18, color: p.withOpacity(0.5)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("AUTO-CALCULATED RETURN", style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: p, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(DateFormat('EEE, MMM dd • hh:mm a').format(_endDate!), style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: t.withOpacity(0.6))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _niceScheduleTile(String h, DateTime? val, Function(DateTime) onPick, Color p, Color c, Color t) {
    return GestureDetector(
      onTap: () async {
        final picked = await CustomDateTimePicker.show(
          context,
          initialDate: val ?? DateTime.now(),
          minDate: DateTime.now(),
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
          border: Border.all(color: t.withOpacity(0.04), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [p.withOpacity(0.15), p.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.withOpacity(0.1)),
            ),
            child: Icon(Icons.calendar_today_rounded, size: 20, color: p),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.replaceFirst('*', '').trim().toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: t.withOpacity(0.4), letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(val == null ? "Set Schedule" : DateFormat('EEE, MMM dd • hh:mm a').format(val), style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: val == null ? Colors.grey : t)),
            ]),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: t.withOpacity(0.03), shape: BoxShape.circle),
            child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: t.withOpacity(0.2)),
          ),
        ]),
      ),
    );
  }


  Widget _premiumGuestEntry(int i, Guest g, Color c, Color t, Color p, {bool isReq = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("PASSENGER ${i + 1}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: p)),
            if (i > 0) GestureDetector(onTap: () => setState(() { _guests.removeAt(i); }), child: const Text("REMOVE", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 12),
          _premiumInputInline("Full Name", g.name, (v) { g.name = v; setState(() {}); }, Icons.person_outline_rounded, c, t, p, isReq: isReq),
          const SizedBox(height: 12),
          _premiumInputInline("Contact Number", g.phone, (v) { g.phone = v; }, Icons.phone_android_rounded, c, t, p, isNum: true, isReq: isReq),
        ],
      ),
    );
  }

  Widget _premiumInputInline(String label, String initial, Function(String) onC, IconData icon, Color c, Color t, Color p, {bool isNum = false, bool isReq = true}) {
    return Container(
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.withOpacity(0.04)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: TextFormField(
        initialValue: initial, 
        keyboardType: isNum ? TextInputType.number : TextInputType.text, 
        onChanged: onC,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          hintText: label, 
          hintStyle: TextStyle(color: t.withOpacity(0.1), fontSize: 13), 
          prefixIcon: Icon(icon, color: p.withOpacity(0.35), size: 20), 
          border: InputBorder.none, 
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), 
          prefixText: isNum ? "+91 " : null, 
          prefixStyle: const TextStyle(fontWeight: FontWeight.w900, color: Colors.grey),
          counterText: "",
        ),
        maxLength: isNum ? 10 : null,
        inputFormatters: isNum ? [FilteringTextInputFormatter.digitsOnly] : null,
        validator: (v) {
          if (isReq && (v == null || v.trim().isEmpty)) return "Required";
          if (isNum && v != null && v.isNotEmpty && v.length != 10) return "Must be 10 digits";
          return null;
        },
      ),
    );
  }

  Widget _premiumInput(String label, TextEditingController ctrl, String hint, IconData icon, Color c, Color t, Color p, {bool isReq = false, bool isNum = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t.withOpacity(0.3))),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.withOpacity(0.04)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
        child: TextFormField(
          controller: ctrl, keyboardType: isNum ? TextInputType.number : TextInputType.text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: t.withOpacity(0.1), fontSize: 13), prefixIcon: Icon(icon, color: p.withOpacity(0.35), size: 20), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
          validator: isReq ? (v) => (v == null || v.isEmpty) ? "Req" : null : null,
        ),
      ),
      const SizedBox(height: 20),
    ]);
  }

  Widget _addGuestBtn(Color p) {
    int max = int.tryParse(_passengerCountController.text) ?? 1;
    if (_visibleGuestSlots >= max) return const SizedBox.shrink();
    
    return GestureDetector(
      onTap: () => setState(() { _visibleGuestSlots++; }), 
      child: Container(
        margin: const EdgeInsets.only(top: 8), 
        padding: const EdgeInsets.symmetric(vertical: 14), 
        decoration: BoxDecoration(color: p.withOpacity(0.05), borderRadius: BorderRadius.circular(16)), 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            Icon(Icons.person_add_alt_1_rounded, size: 18, color: p), 
            const SizedBox(width: 8), 
            Text("Add Specific Guest Detail (${_visibleGuestSlots + 1}/$max)", style: TextStyle(color: p, fontWeight: FontWeight.w800, fontSize: 13))
          ]
        )
      )
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
                Text("GROUPING", style: GoogleFonts.montserrat(fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w900, color: p)),
                Text("Allocate Guests", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: t)),
              ],
            ),
            const Spacer(),
            if (_unassignedGuests.isNotEmpty)
              TextButton.icon(
                onPressed: _autoAllocateGuests,
                icon: Icon(Icons.auto_awesome_rounded, size: 16, color: p),
                label: Text("Smart Split", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: p)),
                style: TextButton.styleFrom(backgroundColor: p.withOpacity(0.05), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Text("${_guests.where((g) => !_unassignedGuests.contains(g) && g.name.isNotEmpty).length}/${_guests.where((g) => g.name.isNotEmpty).length} Assigned", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.green)),
                ]),
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
                color: c.withOpacity(0.3),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: t.withOpacity(0.04)),
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
              Icon(Icons.done_all_rounded, color: Colors.green.withOpacity(0.5), size: 32),
              const SizedBox(height: 8),
              Text("All passengers allocated", style: TextStyle(color: t.withOpacity(0.4), fontWeight: FontWeight.w700, fontSize: 13)),
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
    String label = g.name.trim().isEmpty ? "Guest ${_guests.indexOf(g) + 1}" : g.name;
    return Draggable<Guest>(
      data: g,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: p,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: p.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: t.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.withOpacity(0.2))),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.withOpacity(0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.drag_indicator_rounded, size: 14, color: p.withOpacity(0.4)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: t)),
          ],
        ),
      ),
    );
  }

  Widget _groupList(Color p, Color c, bool d, Color t) {
    return Column(
      children: _guestGroups.entries.map((ent) => DragTarget<Guest>(
        onAccept: (g) {
          setState(() {
            _unassignedGuests.remove(g);
            for (var l in _guestGroups.values) l.remove(g);
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
              color: isO ? p.withOpacity(0.12) : c,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: isO ? p : t.withOpacity(0.02), width: 2),
              boxShadow: [
                BoxShadow(color: isO ? p.withOpacity(0.1) : Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8)),
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
                          decoration: BoxDecoration(color: p.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.directions_bus_filled_rounded, size: 16, color: p),
                        ),
                        const SizedBox(width: 12),
                        Text("VEHICLE ${ent.key + 1}", style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w900, color: t, letterSpacing: 0.5)),
                      ],
                    ),
                    if (ent.value.isNotEmpty)
                      Text("${ent.value.length} Assigned", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: t.withOpacity(0.3))),
                  ],
                ),
                const SizedBox(height: 20),
                if (ent.value.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text("Drag guests here", style: TextStyle(fontSize: 11, color: t.withOpacity(0.2), fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ent.value.map((g) => _assignedGuestChip(g, ent.key, p, t, c)).toList(),
                  ),
              ],
            ),
          );
        },
      )).toList(),
    );
  }

  Widget _assignedGuestChip(Guest g, int gIndex, Color p, Color t, Color c) {
    String label = g.name.trim().isEmpty ? "Guest ${_guests.indexOf(g) + 1}" : g.name;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Chip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: p)),
        backgroundColor: p.withOpacity(0.08),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        deleteIcon: Icon(Icons.close_rounded, size: 14, color: p.withOpacity(0.5)),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      _buildGlassLabel("Fleet Selection", p),
      const SizedBox(height: 12),
      Text("Select available vehicles for your trip segments.", style: TextStyle(fontSize: 13, color: t.withOpacity(0.5))),
      const SizedBox(height: 32),
      if (_isLoadingVehicles) 
        const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())) 
      else ..._guestGroups.keys.map((idx) {
        int gCount = _guestGroups[idx]?.length ?? 0;
        return _resSelector(
          "VEHICLE FOR SLOT ${idx + 1}", 
          _availableVehicles, 
          _selectedVehicles[idx], 
          (v) => setState(() => _selectedVehicles[idx] = v), 
          c, t, p, isV: true, guestCount: gCount
        );
      }).toList(),
      const SizedBox(height: 40),
    ]);
  }

  Widget _stageDrivers(Color p, bool d) {
    Color c = d ? const Color(0xFF1E293B) : Colors.white;
    Color t = d ? Colors.white : const Color(0xFF0F172A);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 24),
      _buildGlassLabel("Driver Assignment", p),
      const SizedBox(height: 12),
      Text("Assign drivers to the selected vehicles.", style: TextStyle(fontSize: 13, color: t.withOpacity(0.5))),
      const SizedBox(height: 32),
      if (_isLoadingDrivers) 
        const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())) 
      else ..._guestGroups.keys.map((idx) => _resSelector(
        "DRIVER FOR ${_selectedVehicles[idx]?['vehicle_number'] ?? 'SLOT ${idx + 1}'}", 
        _availableDrivers, 
        _selectedDrivers[idx], 
        (v) => setState(() => _selectedDrivers[idx] = v), 
        c, t, p, isV: false
      )).toList(),
      const SizedBox(height: 40),
    ]);
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
      filteredItems = filteredItems.where((v) => !assignedIds.contains(v['id'])).toList();

      if (currentGuestCount != null) {
        filteredItems.sort((a, b) {
          int ac = int.tryParse(a['capacity']?.toString() ?? "0") ?? 0;
          int bc = int.tryParse(b['capacity']?.toString() ?? "0") ?? 0;
          
          bool as = ac < currentGuestCount;
          bool al = ac > (currentGuestCount + 5);
          bool bs = bc < currentGuestCount;
          bool bl = bc > (currentGuestCount + 5);

          bool aAvail = a['status'] == "ACTIVE" || a['status'] == "AVAILABLE";
          bool bAvail = b['status'] == "ACTIVE" || b['status'] == "AVAILABLE";

          bool aFit = !as && !al;
          bool bFit = !bs && !bl;

          // Priority: 
          // 0: Available & Fit & Default Driver
          // 1: Available & Fit (no Default Driver)
          // 2: Available & Too Large
          // 3: Available & Too Small
          // 4: Not Available
          int aPrio = !aAvail ? 4 : (aFit ? (a['default_driver'] != null ? 0 : 1) : (as ? 3 : 2));
          int bPrio = !bAvail ? 4 : (bFit ? (b['default_driver'] != null ? 0 : 1) : (bs ? 3 : 2));

          if (aPrio != bPrio) return aPrio.compareTo(bPrio);
          return bc.compareTo(ac); // Within same group, prefer higher capacity
        });
      }
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B).withOpacity(0.9) : Colors.white.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: t)),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
                            child: Icon(Icons.close_rounded, size: 20, color: t.withOpacity(0.5)),
                          ),
                        ),
                      ],
                    ),
                    if (isVehicle && currentGuestCount != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: p.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          "REQUIRED CAPACITY: $currentGuestCount - ${currentGuestCount + 5} SEATS",
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: p, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (filteredItems.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isVehicle ? Icons.directions_bus_rounded : Icons.person_off_rounded, size: 48, color: t.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text("No ${isVehicle ? 'vehicles' : 'drivers'} available", style: TextStyle(color: t.withOpacity(0.3), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final item = filteredItems[i];
                      final bool isSelected = selected != null && (item['id'] == selected['id']);

                      String mainText = "";
                      String subText = "";
                      String? extraText;
                      int capacity = 0;

                      if (isVehicle) {
                        mainText = item['vehicle_number'] ?? "Unknown";
                        subText = item['vehicle_type_name'] ?? "General";
                        capacity = int.tryParse(item['capacity']?.toString() ?? "0") ?? 0;
                        if (item['default_driver'] != null) {
                          extraText = "👤 ${item['default_driver']['name']}";
                        }
                      } else {
                        mainText = item['user']?['name'] ?? item['name'] ?? "Unknown";
                        subText = "📞 ${item['user']?['phone'] ?? 'No Contact'}";
                      }

                      String status = (item['status'] ?? "AVAILABLE").toString().toUpperCase();
                      bool isNotAvailable = isVehicle 
                          ? (status != "AVAILABLE" && status != "ACTIVE")
                          : (status == "ON_LEAVE"); // Block drivers only if they are on leave
                      bool tooSmall = false;
                      bool tooLarge = false;
                      if (isVehicle && currentGuestCount != null && capacity > 0) {
                        tooSmall = capacity < currentGuestCount;
                        tooLarge = capacity > (currentGuestCount + 5);
                      }
                      bool isDisabled = isVehicle ? (tooSmall || isNotAvailable) : isNotAvailable;

                      return GestureDetector(
                        onTap: isDisabled ? () {
                          String msg = isNotAvailable ? "⚠️ Status: $status" : "⚠️ Too Small";
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
                        } : () {
                          onSelect(item); // PASS ORIGINAL ITEM
                          Navigator.pop(ctx);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? p.withOpacity(0.1) : (isDisabled ? t.withOpacity(0.01) : t.withOpacity(0.03)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? p : (isDisabled ? Colors.red.withOpacity(0.2) : Colors.transparent), width: 1.5),
                          ),
                          child: Opacity(
                            opacity: isDisabled ? 0.4 : 1.0,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: (isSelected ? p : t).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                                  child: Icon(isVehicle ? Icons.directions_bus_filled_rounded : Icons.person_rounded, size: 20, color: isSelected ? p : t.withOpacity(0.5)),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(mainText, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: t), overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(subText, style: TextStyle(fontSize: 12, color: t.withOpacity(0.4), fontWeight: FontWeight.w600)),
                                          if (isVehicle) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: (isDisabled ? Colors.red : p).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                              child: Text("Cap: $capacity", style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: (isDisabled ? Colors.red : p))),
                                            ),
                                            if (!isDisabled)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                                child: const Text("AVAILABLE", style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.green)),
                                              ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (isDisabled)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                    child: Text(status == "ON_LEAVE" ? "ON LEAVE" : (isNotAvailable ? status : "TOO SMALL"), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.red)),
                                  )
                                else if (tooLarge)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                    child: const Text("LARGE VEHICLE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.orange)),
                                  )
                                else if (!isVehicle && status == "ON_TRIP")
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                    child: const Text("ON TRIP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.cyan)),
                                  )
                                else if (!isVehicle && status == "AVAILABLE")
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                    child: const Text("AVAILABLE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.green)),
                                  )
                                else if (extraText != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                    child: Text(extraText, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.green)),
                                  )
                                else if (isSelected)
                                  Icon(Icons.check_circle_rounded, color: p, size: 20),
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
        ),
      ),
    );
  }

  Widget _resSelector(String lbl, List<Map<String, dynamic>> items, Map<String, dynamic>? sel, Function(Map<String, dynamic>) onS, Color c, Color t, Color p, {required bool isV, int? guestCount}) {
    String dispTitle = sel != null ? (isV ? sel['vehicle_number'] : (sel['user']?['name'] ?? sel['name'] ?? "Unknown")) : (isV ? "Choose Vehicle" : "Choose Driver");
    String? dispSub = sel != null ? (isV ? sel['vehicle_type_name'] : "📞 ${sel['user']?['phone'] ?? 'No Contact'}") : null;
    String? defDriver = (isV && sel != null && sel['default_driver'] != null) ? sel['default_driver']['name'] : null;
    String? driverStatus = (!isV && sel != null) ? (sel['status'] ?? "AVAILABLE").toString().toUpperCase() : null;

    return GestureDetector(
      onTap: () => _showSelectionSheet(
        title: isV ? "Select Vehicle" : "Select Driver",
        items: items,
        selected: sel,
        onSelect: onS,
        isVehicle: isV,
        p: p, c: c, t: t,
        currentGuestCount: isV ? guestCount : null,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: t.withOpacity(0.04), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lbl, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: p, letterSpacing: 1)),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: (sel != null ? p : t).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                  child: Icon(isV ? Icons.directions_bus_filled_rounded : Icons.person_rounded, size: 20, color: sel != null ? p : t.withOpacity(0.3)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dispTitle, style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: sel != null ? t : t.withOpacity(0.3))),
                      if (dispSub != null) ...[
                        const SizedBox(height: 2),
                        Text(dispSub, style: TextStyle(fontSize: 12, color: t.withOpacity(0.4), fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ),
                if (defDriver != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text("👤 $defDriver", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.green)),
                  ),
                if (driverStatus != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (driverStatus == "ON_LEAVE" ? Colors.red : (driverStatus == "ON_TRIP" ? Colors.cyan : Colors.green)).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      driverStatus.replaceAll("_", " "),
                      style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.w800, 
                        color: (driverStatus == "ON_LEAVE" ? Colors.red : (driverStatus == "ON_TRIP" ? Colors.cyan : Colors.green)),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.keyboard_arrow_down_rounded, color: t.withOpacity(0.2), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassLabel(String txt, Color p) => Row(children: [Container(width: 4, height: 16, decoration: BoxDecoration(color: p, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 8), Text(txt.toUpperCase(), style: GoogleFonts.montserrat(fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w900, color: p.withOpacity(0.6)))]);


  Widget _stageReview(Color p, bool d) {
    Color c = d ? const Color(0xFF1E293B) : Colors.white;
    Color t = d ? Colors.white : const Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildGlassLabel("Verify Request", p),
        const SizedBox(height: 12),
        Text("Final review before creating the full route request.", style: TextStyle(fontSize: 13, color: t.withOpacity(0.5))),
        const SizedBox(height: 32),
        _sumCard("MISSION DETAILS", Icons.map_outlined, [
          {"label": "Route Name", "value": _routeNameController.text},
          {"label": "Purpose", "value": _purposeController.text},
          {"label": "Guests", "value": "${int.tryParse(_passengerCountController.text) ?? 1} People"},
          {"label": "Journey", "value": _routeType},
        ], p, c, t),
        _sumCard("SCHEDULE", Icons.calendar_today_rounded, [
          {"label": "Start", "value": _startDate != null ? DateFormat('EEE, MMM dd • hh:mm a').format(_startDate!) : 'N/A'},
          {"label": "Return", "value": _endDate != null ? DateFormat('EEE, MMM dd • hh:mm a').format(_endDate!) : 'N/A'},
        ], p, c, t),
        _buildGlassLabel("Vehicle & Driver Assignments", p),
        const SizedBox(height: 16),
        ..._guestGroups.entries.map((ent) {
          final veh = _selectedVehicles[ent.key];
          final dri = _selectedDrivers[ent.key];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(24), border: Border.all(color: t.withOpacity(0.04))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: p.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.directions_bus_filled_rounded, size: 16, color: p)),
                    const SizedBox(width: 12),
                    Text("GROUP ${ent.key + 1}", style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w900, color: t)),
                  ],
                ),
                const SizedBox(height: 16),
                _revRow(Icons.local_shipping_rounded, veh?['vehicle_number'] ?? "No Vehicle Selected", t),
                _revRow(Icons.person_rounded, dri?['user']?['name'] ?? dri?['name'] ?? "No Driver Assigned", t),
                const SizedBox(height: 12),
                Text("GUESTS: ${ent.value.map((g) => g.name.isEmpty ? 'Guest' : g.name).join(', ')}", style: TextStyle(fontSize: 11, color: t.withOpacity(0.5))),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _revRow(IconData icon, String val, Color t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Icon(icon, size: 16, color: t.withOpacity(0.3)), const SizedBox(width: 12), Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.withOpacity(0.8)))]));

  Widget _sumCard(String title, IconData icon, List<Map<String, String>> stats, Color p, Color c, Color t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(28), border: Border.all(color: t.withOpacity(0.02)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 18, color: p), const SizedBox(width: 12), Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: p))]),
          const SizedBox(height: 20),
          ...stats.map((s) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(s['label']!, style: TextStyle(fontSize: 12, color: t.withOpacity(0.4), fontWeight: FontWeight.w700)), Text(s['value']!, style: TextStyle(fontSize: 12, color: t, fontWeight: FontWeight.w900))]))),
        ],
      ),
    );
  }

  Widget _buildActionToolbar(Color p) {
    bool isL = _currentStep == _totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24), decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1)))),
      child: Row(children: [
        if (_currentStep > 0) Expanded(child: TextButton(onPressed: () => setState(() => _currentStep--), child: const Text("BACK", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, fontSize: 13)))),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: ElevatedButton(
          onPressed: _isSubmitting ? null : () { 
            if (_currentStep == 0) { 
              if (_formKey.currentState!.validate()) { 
                int pCount = int.tryParse(_passengerCountController.text) ?? 1;
                int vCount = int.tryParse(_vehicleCountController.text) ?? 1;
                if (vCount > pCount) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Vehicle count cannot exceed passenger count"))); return; }
                if (_startDate == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select departure date and time"))); return; }
                if (_routeType != 'One Way' && _endDate == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select return date and time"))); return; }
                _prepareGrouping(); 
                setState(() => _currentStep++); 
              } 
            } else if (_currentStep == 1) { 
              if (_unassignedGuests.isNotEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please assign all guests to vehicles"))); return; }
              _fetchAvailableVehicles(); 
              setState(() => _currentStep++); 
            } else if (_currentStep == 2) { 
              int vCount = int.tryParse(_vehicleCountController.text) ?? 1;
              if (_selectedVehicles.length < vCount || _selectedVehicles.values.any((v) => v == null)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a vehicle for each segment"))); return; }
              _fetchAvailableDrivers(); 
              setState(() => _currentStep++); 
            } else if (_currentStep == 3) {
              int vCount = int.tryParse(_vehicleCountController.text) ?? 1;
              if (_selectedDrivers.length < vCount || _selectedDrivers.values.any((d) => d == null)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a driver for each segment"))); return; }
              setState(() => _currentStep++); 
            } else if (_currentStep == 4) {
              _submitForm(); 
            } else {
              _submitForm();
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: p, minimumSize: const Size(double.infinity, 64), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 4),
          child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(isL ? "CREATE FULL ROUTE" : "CONTINUE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        )),
      ]),
    );
  }
}
