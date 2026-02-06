import 'package:flutter/material.dart';
import 'package:tms/components/location_selector.dart';
import 'package:tms/components/passenger_selector.dart';

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  String _travelType = 'One Way';
  int _passengerCount = 1;
  String _selectedCountryCode = "+91";
  DateTime? _startDate, _endDate;
  List<String> _locationResults = ["", ""];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    const Color primaryIndigo = Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(titleColor),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header("Travel Information", Icons.map_rounded, primaryIndigo),
              _buildTypeSelector(primaryIndigo, cardColor, titleColor),
              const SizedBox(height: 16),
              _buildDateRow(primaryIndigo, cardColor, titleColor),

              const SizedBox(height: 32),
              _header("Location Details", Icons.route_rounded, primaryIndigo),
              LocationSelector(
                cardColor: cardColor,
                titleColor: titleColor,
                accentColor: primaryIndigo,
                onChanged: (v) => _locationResults = v,
              ),

              const SizedBox(height: 32),
              _header(
                "Passenger Information",
                Icons.people_rounded,
                primaryIndigo,
              ),
              PassengerSelector(
                cardColor: cardColor,
                titleColor: titleColor,
                passengerCount: _passengerCount,
                selectedCountryCode: _selectedCountryCode,
                onCountChanged: (v) => setState(() => _passengerCount = v),
                onCountryCodeChanged: (v) =>
                    setState(() => _selectedCountryCode = v),
              ),
              _input(
                "Guest Names",
                Icons.badge_outlined,
                cardColor,
                titleColor,
                max: 2,
              ),

              const SizedBox(height: 32),
              _header(
                "Additional Requirements",
                Icons.auto_awesome_rounded,
                primaryIndigo,
              ),
              _input(
                "Special Requirements",
                Icons.notes_rounded,
                cardColor,
                titleColor,
                max: 3,
              ),
              _input(
                "Luggage Details",
                Icons.luggage_rounded,
                cardColor,
                titleColor,
              ),
              _input(
                "Accessibility",
                Icons.accessible_rounded,
                cardColor,
                titleColor,
              ),

              const SizedBox(height: 40),
              _buildSubmit(primaryIndigo),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // --- COMPACT UI HELPERS ---

  PreferredSizeWidget _buildAppBar(Color color) => AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: true,
    leading: IconButton(
      icon: Icon(Icons.arrow_back_ios_new, color: color, size: 20),
      onPressed: () => Navigator.pop(context),
    ),
    title: Text(
      "New Request",
      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18),
    ),
  );

  Widget _header(String t, IconData i, Color c) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Icon(i, size: 18, color: c),
        const SizedBox(width: 8),
        Text(
          t,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );

  Widget _buildTypeSelector(Color acc, Color card, Color txt) => Row(
    children: ['One Way', 'Two Way', 'Multi Day'].map((type) {
      bool sel = _travelType == type;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _travelType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: sel ? acc : card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                type,
                style: TextStyle(
                  color: sel ? Colors.white : txt,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );

  Widget _buildDateRow(Color acc, Color card, Color txt) => Row(
    children: [
      Expanded(
        child: _datePicker(
          "Start Date",
          _startDate,
          (d) => setState(() => _startDate = d),
          acc,
          card,
          txt,
        ),
      ),
      if (_travelType == 'Multi Day') ...[
        const SizedBox(width: 12),
        Expanded(
          child: _datePicker(
            "End Date",
            _endDate,
            (d) => setState(() => _endDate = d),
            acc,
            card,
            txt,
          ),
        ),
      ],
    ],
  );

  Widget _datePicker(
    String l,
    DateTime? d,
    Function(DateTime) onP,
    Color acc,
    Color card,
    Color txt,
  ) => GestureDetector(
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
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_month, size: 16, color: acc),
              const SizedBox(width: 8),
              Text(
                d == null ? "Select" : "${d.day}/${d.month}/${d.year}",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: txt,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _input(String h, IconData i, Color c, Color t, {int max = 1}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextField(
          maxLines: max,
          style: TextStyle(color: t, fontSize: 14),
          decoration: InputDecoration(
            hintText: h,
            prefixIcon: Icon(i, size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
      );

  Widget _buildSubmit(Color acc) => SizedBox(
    width: double.infinity,
    height: 60,
    child: ElevatedButton(
      onPressed: () => debugPrint("Locations: $_locationResults"),
      style: ElevatedButton.styleFrom(
        backgroundColor: acc,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      child: const Text(
        "SUBMIT REQUEST",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    ),
  );
}
