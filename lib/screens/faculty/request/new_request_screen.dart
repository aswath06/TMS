import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for input formatters
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
  String _selectedCountryCode = "+91";
  String _selectedVehicleType = 'Mini';
  DateTime? _startDate, _endDate;

  // --- Controllers ---
  final TextEditingController _mainPhoneController = TextEditingController();
  final TextEditingController _secondaryPhoneController =
      TextEditingController();
  final TextEditingController _specialReqController = TextEditingController();
  final TextEditingController _luggageController = TextEditingController();
  List<TextEditingController> _guestNameControllers = [TextEditingController()];

  double _totalDistance = 0.0;
  double _totalDuration = 0.0;

  @override
  void dispose() {
    _mainPhoneController.dispose();
    _secondaryPhoneController.dispose();
    _specialReqController.dispose();
    _luggageController.dispose();
    for (var c in _guestNameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addGuest() {
    if (_guestNameControllers.length < _passengerCount) {
      setState(() {
        _guestNameControllers.add(TextEditingController());
      });
    }
  }

  void _removeGuest(int index) {
    if (_guestNameControllers.length > 1) {
      setState(() {
        _guestNameControllers.removeAt(index).dispose();
      });
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
                  key: _formKey, // Form Key attached
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, titleColor, primaryBlue),
                      const SizedBox(height: 32),

                      // --- Section: Travel Info ---
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

                      // --- Section: Location ---
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
                            _totalDistance = distance;
                            _totalDuration = duration;
                          });
                        },
                      ),

                      const SizedBox(height: 32),

                      // --- Section: Passengers ---
                      _buildSectionTitle("Passengers", titleColor, primaryBlue),
                      const SizedBox(height: 16),
                      PassengerSelector(
                        cardColor: cardColor,
                        titleColor: titleColor,
                        passengerCount: _passengerCount,
                        selectedCountryCode: _selectedCountryCode,
                        selectedVehicleType: _selectedVehicleType,
                        onVehicleTypeChanged: (v) =>
                            setState(() => _selectedVehicleType = v),
                        onCountChanged: (v) {
                          setState(() {
                            _passengerCount = v;
                            if (_guestNameControllers.length > v) {
                              _guestNameControllers = _guestNameControllers
                                  .sublist(0, v);
                            }
                          });
                        },
                        onCountryCodeChanged: (v) =>
                            setState(() => _selectedCountryCode = v),
                      ),

                      const SizedBox(height: 24),

                      // --- Contact Details (Conditional) ---
                      if (_passengerCount > 1) ...[
                        _buildSectionTitle(
                          "Contact Details",
                          titleColor,
                          primaryBlue,
                        ),
                        const SizedBox(height: 16),
                        _inputField(
                          "Primary Phone",
                          Icons.phone,
                          cardColor,
                          titleColor,
                          controller: _mainPhoneController,
                          primaryBlue: primaryBlue,
                          isPhone: true,
                        ),
                        if (_passengerCount >= 12) ...[
                          const SizedBox(height: 8),
                          _inputField(
                            "Emergency Phone",
                            Icons.phone_paused_rounded,
                            cardColor,
                            titleColor,
                            controller: _secondaryPhoneController,
                            primaryBlue: primaryBlue,
                            isPhone: true,
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],

                      // --- Guest Names ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle(
                            "Guest Names",
                            titleColor,
                            primaryBlue,
                          ),
                          if (_guestNameControllers.length < _passengerCount)
                            TextButton.icon(
                              onPressed: _addGuest,
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 18,
                              ),
                              label: Text(
                                "Add",
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
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _inputField(
                                  "Guest ${idx + 1} Name",
                                  Icons.person_outline,
                                  cardColor,
                                  titleColor,
                                  controller: entry.value,
                                  primaryBlue: primaryBlue,
                                  isName: true,
                                ),
                              ),
                              if (idx > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () => _removeGuest(idx),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),

                      const SizedBox(height: 32),

                      // --- Requirements ---
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

  // --- UI Components Library ---

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
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: titleColor.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.local_taxi_outlined,
            color: titleColor.withOpacity(0.6),
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color titleColor, Color primaryBlue) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(20),
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
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "This field is required";
          }
          if (isPhone && value.length < 10) {
            return "Enter a valid phone number";
          }
          if (isName && value.length < 2) {
            return "Enter a valid name";
          }
          return null;
        },
        decoration: InputDecoration(
          hintText: h,
          hintStyle: TextStyle(color: t.withOpacity(0.4), fontSize: 13),
          errorStyle: const TextStyle(fontSize: 10, height: 0.8),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(i, size: 18, color: primaryBlue),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(Color acc, Color card, Color txt, Color sub) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: ['One Way', 'Two Way', 'Multi Day'].map((type) {
          bool sel = _travelType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _travelType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: sel ? acc : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Text(
                    type,
                    style: TextStyle(
                      color: sel ? Colors.white : sub,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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
            "Start Date",
            _startDate,
            (d) => setState(() => _startDate = d),
            acc,
            card,
            txt,
            sub,
          ),
        ),
        if (_travelType == 'Multi Day') ...[
          const SizedBox(width: 12),
          Expanded(
            child: _dateTile(
              "End Date",
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: sub,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: acc),
                const SizedBox(width: 8),
                Text(
                  d == null ? "Select" : "${d.day}/${d.month}/${d.year}",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: txt,
                  ),
                ),
              ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: acc.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: acc.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_graph_rounded, color: acc, size: 20),
          const SizedBox(width: 12),
          Text(
            "${_totalDistance.toStringAsFixed(1)} km  •  ${_totalDuration.toStringAsFixed(0)} mins",
            style: TextStyle(
              color: acc,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(Color primaryBlue) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          // --- Trigger Form Validation ---
          if (_formKey.currentState!.validate()) {
            if (_startDate == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please select a Start Date")),
              );
              return;
            }

            // --- Console Logging All Fields ---
            debugPrint("========== NEW REQUEST SUBMISSION ==========");
            debugPrint("Travel Type: $_travelType");
            debugPrint(
              "Start Date: ${_startDate?.toIso8601String() ?? 'Not Selected'}",
            );
            debugPrint(
              "End Date: ${_endDate?.toIso8601String() ?? 'N/A (One/Two Way)'}",
            );

            debugPrint("--- Route Details ---");
            debugPrint("Total Distance: $_totalDistance km");
            debugPrint("Total Duration: $_totalDuration mins");

            debugPrint("--- Passenger & Vehicle ---");
            debugPrint("Passenger Count: $_passengerCount");
            debugPrint("Vehicle Type: $_selectedVehicleType");
            debugPrint("Country Code: $_selectedCountryCode");

            debugPrint("--- Contact Info ---");
            debugPrint("Primary Phone: ${_mainPhoneController.text}");
            if (_passengerCount >= 12) {
              debugPrint("Emergency Phone: ${_secondaryPhoneController.text}");
            }

            debugPrint("--- Guest Names ---");
            for (int i = 0; i < _guestNameControllers.length; i++) {
              debugPrint("Guest ${i + 1}: ${_guestNameControllers[i].text}");
            }

            debugPrint("--- Additional ---");
            debugPrint("Special Requirements: ${_specialReqController.text}");
            debugPrint("Luggage Details: ${_luggageController.text}");
            debugPrint("============================================");

            // Simple UI feedback
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Request logged to console!"),
                backgroundColor: primaryBlue,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: const Text(
          "SUBMIT REQUEST",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
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
              backgroundColor: const Color(
                0xFF6366F1,
              ).withOpacity(isDark ? 0.1 : 0.05),
            ),
          ),
          Positioned(
            bottom: 0,
            left: -50,
            child: CircleAvatar(
              radius: 120,
              backgroundColor: const Color(
                0xFFEC4899,
              ).withOpacity(isDark ? 0.08 : 0.04),
            ),
          ),
        ],
      ),
    );
  }
}
