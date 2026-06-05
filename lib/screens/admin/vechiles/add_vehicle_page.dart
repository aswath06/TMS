import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripzo/store/VehicleStore.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';

class AddVehiclePage extends ConsumerStatefulWidget {
  const AddVehiclePage({super.key});

  @override
  ConsumerState<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends ConsumerState<AddVehiclePage> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final TextEditingController _noController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _kmController = TextEditingController();

  String _selectedType = 'Bus';

  // Date States
  DateTime? insuranceDate;
  DateTime? pollutionDate;
  DateTime? rcDate;
  DateTime? fitnessDate;
  DateTime? nextServiceDate;

  /// Handles the API submission logic
  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if all dates are selected
    if (insuranceDate == null ||
        pollutionDate == null ||
        rcDate == null ||
        fitnessDate == null ||
        nextServiceDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select all maintenance dates")),
      );
      return;
    }

    // Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      ),
    );

    // Prepare data as per curl requirements (yyyy-MM-dd)
    final Map<String, dynamic> vehicleData = {
      "vehicle_number": _noController.text.trim().toUpperCase(),
      "vehicle_type": _selectedType,
      "capacity": int.tryParse(_capacityController.text) ?? 0,
      "current_kilometer": int.tryParse(_kmController.text) ?? 0,
      "insurance_date": DateFormat('yyyy-MM-dd').format(insuranceDate!),
      "pollution_date": DateFormat('yyyy-MM-dd').format(pollutionDate!),
      "rc_date": DateFormat('yyyy-MM-dd').format(rcDate!),
      "fc_date": DateFormat('yyyy-MM-dd').format(fitnessDate!),
      "next_service_date": DateFormat('yyyy-MM-dd').format(nextServiceDate!),
    };

    try {
      final vehicleStore = ref.read(vehicleStoreProvider);
      final success = await vehicleStore.addVehicle(vehicleData);

      Navigator.pop(context); // Close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vehicle registered successfully!")),
        );
        Navigator.pop(context); // Go back to vehicle list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to register vehicle. Check your connection."),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("An error occurred: $e")));
    }
  }

  Future<void> _selectDate(BuildContext context, String type) async {
    final DateTime? picked = await CustomDateTimePicker.show(
      context,
      initialDate: DateTime.now(),
      minDate: DateTime(2010),
      showTime: false,
    );
    if (picked != null) {
      setState(() {
        if (type == 'ins') insuranceDate = picked;
        if (type == 'pol') pollutionDate = picked;
        if (type == 'rc') rcDate = picked;
        if (type == 'fit') fitnessDate = picked;
        if (type == 'srv') nextServiceDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color inputColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: titleColor),
        title: Text(
          "Vehicle Registration",
          style: GoogleFonts.plusJakartaSans(
            color: titleColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel("Basic Information", Icons.analytics_rounded, isDark),
              const SizedBox(height: 16),
              _buildTextField(
                "Vehicle Number",
                _noController,
                "e.g. TN-01-AA-1011",
                Icons.badge_rounded,
                isDark,
                inputColor,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownField(
                      "Vehicle Type",
                      isDark,
                      inputColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      "Capacity",
                      _capacityController,
                      "Seats",
                      Icons.airline_seat_recline_extra_rounded,
                      isDark,
                      inputColor,
                      isNumber: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildTextField(
                "Current Kilometer",
                _kmController,
                "00000",
                Icons.speed_rounded,
                isDark,
                inputColor,
                isNumber: true,
              ),
              const SizedBox(height: 40),
              _buildSectionLabel(
                "Compliance & Maintenance",
                Icons.verified_user_rounded,
                isDark,
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 2.1,
                children: [
                  _buildDateTile(
                    "Insurance",
                    insuranceDate,
                    () => _selectDate(context, 'ins'),
                    isDark,
                    inputColor,
                  ),
                  _buildDateTile(
                    "Pollution",
                    pollutionDate,
                    () => _selectDate(context, 'pol'),
                    isDark,
                    inputColor,
                  ),
                  _buildDateTile(
                    "RC Expiry",
                    rcDate,
                    () => _selectDate(context, 'rc'),
                    isDark,
                    inputColor,
                  ),
                  _buildDateTile(
                    "Fitness",
                    fitnessDate,
                    () => _selectDate(context, 'fit'),
                    isDark,
                    inputColor,
                  ),
                  _buildDateTile(
                    "Next Service",
                    nextServiceDate,
                    () => _selectDate(context, 'srv'),
                    isDark,
                    inputColor,
                    highlight: true,
                  ),
                ],
              ),
              const SizedBox(height: 50),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _handleRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    minimumSize: const Size(double.infinity, 64),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    "REGISTER VEHICLE",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF6366F1)),
        ),
        const SizedBox(width: 12),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF6366F1),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint,
    IconData icon,
    bool isDark,
    Color fill, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: GoogleFonts.plusJakartaSans(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.plusJakartaSans(
                color: Colors.grey.withOpacity(0.5),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(icon, color: const Color(0xFF6366F1).withOpacity(0.4), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, bool isDark, Color fill) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedType,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: const Color(0xFF6366F1).withOpacity(0.4)),
              items: ['Bus', 'Staff Car', 'Van', 'Truck']
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(
                        v,
                        style: GoogleFonts.plusJakartaSans(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedType = val!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTile(
    String label,
    DateTime? date,
    VoidCallback onTap,
    bool isDark,
    Color fill, {
    bool highlight = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlight 
                ? const Color(0xFF6366F1).withOpacity(0.5) 
                : (date != null ? const Color(0xFF6366F1).withOpacity(0.1) : Colors.transparent),
            width: 1.5,
          ),
          boxShadow: [
            if (highlight || date != null)
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: highlight
                    ? const Color(0xFF6366F1)
                    : (isDark ? Colors.white38 : Colors.black38),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: 16,
                  color: date == null ? Colors.grey.withOpacity(0.5) : const Color(0xFF6366F1),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date == null ? "SELECT" : DateFormat('dd/MM/yy').format(date),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: date == null
                          ? Colors.grey.withOpacity(0.5)
                          : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
