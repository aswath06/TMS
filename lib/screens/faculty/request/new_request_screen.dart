import 'dart:convert'; // Added for JSON encoding
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:intl/intl.dart';
import 'package:tms/components/passenger_selector.dart';
import 'package:tms/components/location_selector.dart';

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
  List<String> _selectedAddresses = []; // Captures the address strings

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
      // Data Collection for API or Console
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

      // --- Beautiful Console Logging ---
      debugPrint("================= SUBMISSION DATA =================");
      debugPrint("TRAVEL TYPE: ${requestData['travel_info']['type']}");
      debugPrint("LOCATIONS:");
      for (var i = 0; i < _selectedAddresses.length; i++) {
        debugPrint("  Stop ${i + 1}: ${_selectedAddresses[i]}");
      }
      debugPrint("STATS: ${_totalDistance}km | ${_totalDuration}mins");
      debugPrint("VEHICLE: $_selectedVehicleType for $_passengerCount pax");
      debugPrint("GUESTS: ${requestData['guests'].length}");
      debugPrint("JSON PAYLOAD:");
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
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark),
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

                      _buildSectionTitle(
                        "Travel Plan",
                        titleColor,
                        primaryBlue,
                      ),
                      const SizedBox(height: 16),
                      _buildTypeSelector(
                        primaryBlue,
                        cardColor,
                        titleColor,
                        subTitleColor,
                      ),
                      const SizedBox(height: 12),
                      _buildDateRow(
                        primaryBlue,
                        cardColor,
                        titleColor,
                        subTitleColor,
                      ),

                      const SizedBox(height: 32),

                      _buildSectionTitle(
                        "Route Details",
                        titleColor,
                        primaryBlue,
                      ),
                      const SizedBox(height: 16),
                      LocationSelector(
                        cardColor: cardColor,
                        titleColor: titleColor,
                        accentColor: primaryBlue,
                        onChanged: (addresses, distance, duration) {
                          setState(() {
                            _selectedAddresses =
                                addresses; // Capturing locations
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
                              _guestNameControllers = _guestNameControllers
                                  .sublist(0, v);
                              _guestPhoneControllers = _guestPhoneControllers
                                  .sublist(0, v);
                              _guestCountryCodes = _guestCountryCodes.sublist(
                                0,
                                v,
                              );
                            }
                          });
                        },
                      ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle(
                            "Guest Details",
                            titleColor,
                            primaryBlue,
                          ),
                          if (_passengerCount > 5)
                            TextButton.icon(
                              onPressed: _handleBulkUpload,
                              icon: const Icon(
                                Icons.upload_file_rounded,
                                size: 18,
                              ),
                              label: Text(
                                "Bulk Upload",
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else if (_guestNameControllers.length <
                              _passengerCount)
                            TextButton.icon(
                              onPressed: _addGuest,
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 18,
                              ),
                              label: Text(
                                "Add Guest",
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ..._guestNameControllers.asMap().entries.map((entry) {
                        int idx = entry.key;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: titleColor.withOpacity(0.05),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _inputField(
                                      "Guest ${idx + 1} Name",
                                      Icons.person_outline,
                                      cardColor,
                                      titleColor,
                                      controller: _guestNameControllers[idx],
                                      primaryBlue: primaryBlue,
                                      isName: true,
                                    ),
                                  ),
                                  if (idx > 0)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      onPressed: () => _removeGuest(idx),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: bgColor.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Row(
                                  children: [
                                    CountryCodePicker(
                                      onChanged: (country) =>
                                          _guestCountryCodes[idx] =
                                              country.dialCode!,
                                      initialSelection: 'IN',
                                      favorite: const ['+91', 'US'],
                                      textStyle: TextStyle(
                                        color: titleColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      showFlagMain: true,
                                      flagWidth: 20,
                                      padding: EdgeInsets.zero,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 20,
                                      color: Colors.grey.withOpacity(0.3),
                                    ),
                                    Expanded(
                                      child: _inputField(
                                        "Phone Number",
                                        Icons.phone_android_outlined,
                                        Colors.transparent,
                                        titleColor,
                                        controller: _guestPhoneControllers[idx],
                                        primaryBlue: primaryBlue,
                                        isPhone: true,
                                        noMargin: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),

                      const SizedBox(height: 32),

                      _buildSectionTitle("Additional", titleColor, primaryBlue),
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

  // --- UI Helpers ---

  Widget _buildHeader(
    BuildContext context,
    Color titleColor,
    Color primaryBlue,
  ) {
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
                  child: Icon(
                    Icons.arrow_back_ios,
                    size: 18,
                    color: primaryBlue,
                  ),
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

  Widget _buildSectionTitle(String title, Color titleColor, Color primaryBlue) {
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
          contentPadding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(Color acc, Color card, Color txt, Color sub) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: ['One Way', 'Two Way', 'Multi Day'].map((type) {
          bool sel = _travelType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _travelType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? acc : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    type,
                    style: TextStyle(
                      color: sel ? Colors.white : sub,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateRow(Color acc, Color card, Color txt, Color sub) {
    return Row(
      children: [
        Expanded(
          child: _dateTile(
            "Start",
            _startDate,
            (d) => setState(() => _startDate = d),
            acc,
            card,
            txt,
            sub,
          ),
        ),
        if (_travelType == 'Multi Day') ...[
          const SizedBox(width: 8),
          Expanded(
            child: _dateTile(
              "End",
              _endDate,
              (d) => setState(() => _endDate = d),
              acc,
              card,
              txt,
              sub,
            ),
          ),
        ],
      ],
    );
  }

  Widget _dateTile(
    String l,
    DateTime? d,
    Function(DateTime) onP,
    Color acc,
    Color card,
    Color txt,
    Color sub,
  ) {
    return GestureDetector(
      onTap: () async {
        final p = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (p != null) onP(p);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month, size: 16, color: acc),
            const SizedBox(width: 8),
            Text(
              d == null ? l : "${d.day}/${d.month}",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: txt,
              ),
            ),
          ],
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
            color: acc,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: const Text(
          "SUBMIT",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildBackgroundDecor(bool isDark) {
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
