import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:tms/components/passenger_selector.dart';
import 'package:tms/components/location_selector.dart';
import 'package:tms/components/travel_plan_selector.dart';
import 'package:tms/components/guest_details_form.dart';

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- State Variables ---
  String _travelType = 'One Way';
  int _passengerCount = 1;
  String _selectedVehicleType = 'Mini';
  DateTime? _startDate, _endDate;

  // --- Location State ---
  double _totalDistance = 0.0;
  double _totalDuration = 0.0;
  List<String> _selectedAddresses = [];

  // --- Controllers & Dynamic Lists ---
  final TextEditingController _specialReqController = TextEditingController();
  final TextEditingController _luggageController = TextEditingController();

  List<TextEditingController> _guestNameControllers = [TextEditingController()];
  List<TextEditingController> _guestPhoneControllers = [
    TextEditingController(),
  ];
  List<String> _guestCountryCodes = ["+91"];

  @override
  void dispose() {
    _specialReqController.dispose();
    _luggageController.dispose();
    for (var c in _guestNameControllers) {
      c.dispose();
    }
    for (var c in _guestPhoneControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // --- Logic Helpers ---

  void _addGuest() {
    if (_guestNameControllers.length < _passengerCount) {
      setState(() {
        _guestNameControllers.add(TextEditingController());
        _guestPhoneControllers.add(TextEditingController());
        _guestCountryCodes.add("+91");
      });
    }
  }

  void _removeGuest(int index) {
    if (_guestNameControllers.length > 1) {
      setState(() {
        _guestNameControllers.removeAt(index).dispose();
        _guestPhoneControllers.removeAt(index).dispose();
        _guestCountryCodes.removeAt(index);
      });
    }
  }

  void _handleBulkUpload() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Bulk Upload Clicked: Import CSV/Excel template"),
      ),
    );
  }

  List<Map<String, String>> _getFormattedGuestData() {
    List<Map<String, String>> guests = [];
    for (int i = 0; i < _guestNameControllers.length; i++) {
      guests.add({
        "name": _guestNameControllers[i].text.trim(),
        "country_code": _guestCountryCodes[i],
        "phone": _guestPhoneControllers[i].text.trim(),
        "full_phone":
            "${_guestCountryCodes[i]}${_guestPhoneControllers[i].text.trim()}",
      });
    }
    return guests;
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final Map<String, dynamic> requestData = {
        "travel_info": {
          "type": _travelType,
          "start_date": _startDate != null
              ? DateFormat('yyyy-MM-dd').format(_startDate!)
              : null,
          "end_date": _endDate != null
              ? DateFormat('yyyy-MM-dd').format(_endDate!)
              : null,
        },
        "route_details": {
          "selected_locations": _selectedAddresses,
          "distance_km": _totalDistance,
          "duration_mins": _totalDuration,
        },
        "vehicle_config": {
          "passenger_count": _passengerCount,
          "vehicle_type": _selectedVehicleType,
        },
        "guests": _getFormattedGuestData(),
        "additional_info": {
          "special_requirements": _specialReqController.text.trim(),
          "luggage_details": _luggageController.text.trim(),
        },
        "submitted_at": DateTime.now().toIso8601String(),
      };

      debugPrint("================= SUBMISSION DATA =================");
      debugPrint(const JsonEncoder.withIndent('  ').convert(requestData));
      debugPrint("====================================================");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Request submitted successfully! Check console."),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTitleColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundDecor(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, titleColor, primaryBlue),
                      const SizedBox(height: 32),
                      _buildSectionHeader("Travel Plan", titleColor, primaryBlue),
                      const SizedBox(height: 16),
                      TravelPlanSelector(
                        travelType: _travelType,
                        startDate: _startDate,
                        endDate: _endDate,
                        primaryBlue: primaryBlue,
                        cardColor: cardColor,
                        titleColor: titleColor,
                        subTitleColor: subTitleColor,
                        onTypeChanged: (type) =>
                            setState(() => _travelType = type),
                        onStartDateChanged: (date) =>
                            setState(() => _startDate = date),
                        onEndDateChanged: (date) =>
                            setState(() => _endDate = date),
                      ),
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                          "Route Details", titleColor, primaryBlue),
                      const SizedBox(height: 16),
                      LocationSelector(
                        cardColor: cardColor,
                        titleColor: titleColor,
                        accentColor: primaryBlue,
                        onChanged: (addresses, distance, duration) {
                          setState(() {
                            _selectedAddresses = addresses;
                            _totalDistance = distance;
                            _totalDuration = duration;
                          });
                        },
                      ),
                      const SizedBox(height: 32),
                      PassengerSelector(
                        cardColor: cardColor,
                        titleColor: titleColor,
                        passengerCount: _passengerCount,
                        selectedVehicleType: _selectedVehicleType,
                        onVehicleTypeChanged: (v) =>
                            setState(() => _selectedVehicleType = v),
                        onCountChanged: (v) {
                          setState(() {
                            _passengerCount = v;
                            if (_guestNameControllers.length > v) {
                              _guestNameControllers =
                                  _guestNameControllers.sublist(0, v);
                              _guestPhoneControllers =
                                  _guestPhoneControllers.sublist(0, v);
                              _guestCountryCodes =
                                  _guestCountryCodes.sublist(0, v);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      GuestDetailsForm(
                        nameControllers: _guestNameControllers,
                        phoneControllers: _guestPhoneControllers,
                        countryCodes: _guestCountryCodes,
                        passengerCount: _passengerCount,
                        cardColor: cardColor,
                        titleColor: titleColor,
                        primaryBlue: primaryBlue,
                        bgColor: bgColor,
                        onAddGuest: _addGuest,
                        onRemoveGuest: _removeGuest,
                        onBulkUpload: _handleBulkUpload,
                      ),
                      const SizedBox(height: 32),
                      _buildSectionHeader("Additional", titleColor, primaryBlue),
                      const SizedBox(height: 16),
                      _inputField(
                        "Special Requirements",
                        Icons.notes_rounded,
                        cardColor,
                        titleColor,
                        max: 3,
                        controller: _specialReqController,
                        primaryBlue: primaryBlue,
                      ),
                      _inputField(
                        "Luggage Details",
                        Icons.luggage_rounded,
                        cardColor,
                        titleColor,
                        controller: _luggageController,
                        primaryBlue: primaryBlue,
                      ),
                      const SizedBox(height: 40),
                      if (_totalDistance > 0) _buildEstimate(primaryBlue),
                      _buildSubmitButton(primaryBlue),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color titleColor, Color primaryBlue) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back_ios, size: 18, color: primaryBlue),
                ),
                const SizedBox(width: 8),
                Text(
                  "TRANSPORT",
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "New Request",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
          ],
        ),
        Icon(
          Icons.local_taxi_outlined,
          color: titleColor.withOpacity(0.2),
          size: 30,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color titleColor, Color primaryBlue) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
      ],
    );
  }

  Widget _inputField(
    String h,
    IconData i,
    Color c,
    Color t, {
    int max = 1,
    TextEditingController? controller,
    required Color primaryBlue,
    bool isPhone = false,
    bool isName = false,
    bool noMargin = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: noMargin ? 0 : 8),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: max,
        style: TextStyle(color: t, fontSize: 14, fontWeight: FontWeight.w600),
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        inputFormatters: [
          if (isPhone) FilteringTextInputFormatter.digitsOnly,
          if (isName) FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
        ],
        validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
        decoration: InputDecoration(
          hintText: h,
          hintStyle: TextStyle(color: t.withOpacity(0.4), fontSize: 13),
          prefixIcon: Icon(i, size: 16, color: primaryBlue.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
        ),
      ),
    );
  }

  Widget _buildEstimate(Color acc) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: acc.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Center(
        child: Text(
          "${_totalDistance.toStringAsFixed(1)} km  •  ${_totalDuration.toStringAsFixed(0)} mins",
          style: TextStyle(
              color: acc, fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(Color primaryBlue) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: const Text(
          "SUBMIT",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildBackgroundDecor() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: const Color(0xFF6366F1).withOpacity(0.05),
            ),
          ),
        ],
      ),
    );
  }
}
