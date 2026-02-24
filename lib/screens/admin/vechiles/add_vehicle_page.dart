import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tms/store/VehicleStore.dart';

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({super.key});

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
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
      final vehicleStore = Provider.of<VehicleStore>(context, listen: false);
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
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime(2040),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
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
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: titleColor),
        title: Text(
          "Vehicle Registration",
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel("Basic Information", Icons.info_outline),
              const SizedBox(height: 12),
              _buildTextField(
                "Vehicle Number",
                _noController,
                "e.g. TN-01-AA-1011",
                Icons.badge_outlined,
                isDark,
                inputColor,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownField(
                      "Vehicle Type",
                      isDark,
                      inputColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      "Capacity",
                      _capacityController,
                      "Seats",
                      Icons.people_outline,
                      isDark,
                      inputColor,
                      isNumber: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                "Current Kilometer",
                _kmController,
                "00000",
                Icons.speed_rounded,
                isDark,
                inputColor,
                isNumber: true,
              ),
              const SizedBox(height: 32),
              _buildSectionLabel(
                "Compliance & Maintenance",
                Icons.fact_check_outlined,
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.2,
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
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _handleRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Register Vehicle",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6366F1)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6366F1),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
            filled: true,
            fillColor: fill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (v) => v!.isEmpty ? "Required" : null,
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, bool isDark, Color fill) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedType,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              items: ['Bus', 'Staff Car', 'Van', 'Truck']
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(
                        v,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: highlight
              ? Border.all(
                  color: const Color(0xFF6366F1).withOpacity(0.5),
                  width: 1,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: highlight
                    ? const Color(0xFF6366F1)
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.event_note_outlined,
                  size: 16,
                  color: date == null ? Colors.grey : const Color(0xFF6366F1),
                ),
                const SizedBox(width: 8),
                Text(
                  date == null ? "Select" : DateFormat('dd/MM/yy').format(date),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: date == null
                        ? Colors.grey
                        : (isDark ? Colors.white : Colors.black),
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
