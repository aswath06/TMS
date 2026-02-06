import 'package:flutter/material.dart';

// --- MODELS ---
class LocationStopData {
  final int id;
  final TextEditingController controller;
  LocationStopData({required this.id, required this.controller});
}

// --- COMPONENT: LOCATION SELECTOR ---
class LocationSelector extends StatefulWidget {
  final Color cardColor;
  final Color titleColor;
  final Color accentColor;
  final Function(List<String>) onChanged;

  const LocationSelector({
    super.key,
    required this.cardColor,
    required this.titleColor,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  State<LocationSelector> createState() => _LocationSelectorState();
}

class _LocationSelectorState extends State<LocationSelector> {
  final List<LocationStopData> _stops = [
    LocationStopData(id: 0, controller: TextEditingController()),
    LocationStopData(id: 1, controller: TextEditingController()),
  ];

  @override
  void dispose() {
    for (var stop in _stops) {
      stop.controller.dispose();
    }
    super.dispose();
  }

  void _notify() =>
      widget.onChanged(_stops.map((s) => s.controller.text).toList());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false, // Using custom handle
          itemCount: _stops.length,
          onReorder: (oldIdx, newIdx) {
            setState(() {
              if (newIdx > oldIdx) newIdx -= 1;
              _stops.insert(newIdx, _stops.removeAt(oldIdx));
            });
            _notify();
          },
          itemBuilder: (context, i) {
            bool isFirst = i == 0;
            bool isLast = i == _stops.length - 1;
            return Container(
              key: ValueKey(_stops[i].id),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: widget.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Icon(
                  isFirst
                      ? Icons.trip_origin
                      : (isLast ? Icons.location_on : Icons.circle),
                  size: 18,
                  color: isFirst
                      ? Colors.green
                      : (isLast ? Colors.red : Colors.grey),
                ),
                title: TextField(
                  controller: _stops[i].controller,
                  onChanged: (_) => _notify(),
                  style: TextStyle(
                    color: widget.titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: isFirst
                        ? "Pickup Location"
                        : (isLast ? "Drop Location" : "Stop $i"),
                    border: InputBorder.none,
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ),
                trailing: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_indicator, color: Colors.grey),
                ),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                // Insert new stop before the last item (Drop Location)
                _stops.insert(
                  _stops.length - 1,
                  LocationStopData(
                    id: DateTime.now().millisecondsSinceEpoch,
                    controller: TextEditingController(),
                  ),
                );
              });
              _notify();
            },
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text("Add Stop"),
            style: TextButton.styleFrom(foregroundColor: widget.accentColor),
          ),
        ),
      ],
    );
  }
}

// --- MAIN SCREEN ---
class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  // State Variables
  String _travelType = 'One Way';
  int _passengerCount = 1;
  String _selectedCountryCode = "+91 (India)";
  DateTime? _startDate;
  DateTime? _endDate;

  // Holds the data emitted from the component
  List<String> _locationResults = ["", ""];

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    const Color primaryIndigo = Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(context, titleColor),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.06,
          vertical: 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                "Travel Information",
                Icons.map_rounded,
                primaryIndigo,
              ),
              _buildTypeSelector(primaryIndigo, cardColor, titleColor),
              const SizedBox(height: 16),
              _buildDateRow(primaryIndigo, cardColor, titleColor),

              const SizedBox(height: 32),

              _buildSectionHeader(
                "Location Details",
                Icons.route_rounded,
                primaryIndigo,
              ),
              // --- INTEGRATED COMPONENT ---
              LocationSelector(
                cardColor: cardColor,
                titleColor: titleColor,
                accentColor: primaryIndigo,
                onChanged: (values) {
                  _locationResults = values;
                },
              ),

              const SizedBox(height: 32),

              _buildSectionHeader(
                "Passenger Information",
                Icons.people_rounded,
                primaryIndigo,
              ),
              _buildPassengerRow(cardColor, titleColor, primaryIndigo),
              const SizedBox(height: 12),
              _buildInputField(
                "Guest Names",
                Icons.badge_outlined,
                cardColor,
                titleColor,
                maxLines: 2,
              ),

              const SizedBox(height: 32),

              _buildSectionHeader(
                "Additional Requirements",
                Icons.auto_awesome_rounded,
                primaryIndigo,
              ),
              _buildInputField(
                "Special Requirements",
                Icons.notes_rounded,
                cardColor,
                titleColor,
                maxLines: 3,
              ),
              _buildInputField(
                "Luggage Details",
                Icons.luggage_rounded,
                cardColor,
                titleColor,
              ),
              _buildInputField(
                "Accessibility Requirements",
                Icons.accessible_rounded,
                cardColor,
                titleColor,
              ),

              const SizedBox(height: 40),
              _buildSubmitButton(primaryIndigo, size),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  PreferredSizeWidget _buildAppBar(BuildContext context, Color titleColor) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: titleColor,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        "New Request",
        style: TextStyle(
          color: titleColor,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(Color accent, Color card, Color text) {
    final types = ['One Way', 'Two Way', 'Multi Day'];
    return Row(
      children: types.map((type) {
        bool isSelected = _travelType == type;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _travelType = type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? accent : card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  type,
                  style: TextStyle(
                    color: isSelected ? Colors.white : text,
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
  }

  Widget _buildDateRow(Color accent, Color card, Color text) {
    return Row(
      children: [
        Expanded(
          child: _buildDatePicker(
            "Start Date",
            _startDate,
            (d) => setState(() => _startDate = d),
            accent,
            card,
            text,
          ),
        ),
        if (_travelType == 'Multi Day') ...[
          const SizedBox(width: 12),
          Expanded(
            child: _buildDatePicker(
              "End Date",
              _endDate,
              (d) => setState(() => _endDate = d),
              accent,
              card,
              text,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? date,
    Function(DateTime) onPick,
    Color accent,
    Color card,
    Color text,
  ) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onPick(picked);
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
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 16, color: accent),
                const SizedBox(width: 8),
                Text(
                  date == null
                      ? "Select"
                      : "${date.day}/${date.month}/${date.year}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: text,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerRow(Color card, Color text, Color accent) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonFormField<int>(
              value: _passengerCount,
              dropdownColor: card,
              decoration: const InputDecoration(
                border: InputBorder.none,
                labelText: "Count",
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              items: List.generate(10, (index) => index + 1)
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        "$e",
                        style: TextStyle(
                          color: text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _passengerCount = v!),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _selectedCountryCode,
                  underline: const SizedBox(),
                  items: ["+91 (India)", "+1 (USA)", "+44 (UK)"]
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e.split(" ")[0],
                            style: TextStyle(
                              color: text,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCountryCode = v!),
                ),
                const VerticalDivider(width: 20),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.phone,
                    style: TextStyle(
                      color: text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      hintText: "Contact Details",
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(
    String hint,
    IconData icon,
    Color card,
    Color text, {
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        maxLines: maxLines,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 18, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(Color accent, Size size) {
    return Container(
      width: size.width,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          // Access the values from the internal component
          debugPrint("Submitting Request with Locations: $_locationResults");
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          elevation: 0,
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
}
