import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tms/store/driver_store.dart';

class AddDriverPage extends StatefulWidget {
  const AddDriverPage({super.key});

  @override
  State<AddDriverPage> createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _licenseCtrl = TextEditingController();
  final TextEditingController _expiryDateCtrl = TextEditingController();
  final TextEditingController _experienceCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _licenseCtrl.dispose();
    _expiryDateCtrl.dispose();
    _experienceCtrl.dispose();
    super.dispose();
  }

  bool _isLoading = false;

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // API expects experience as an integer, default if empty or invalid
      int experience = int.tryParse(_experienceCtrl.text) ?? 0;

      // Construct a default email for the API from the name if needed (API requirement workaround)
      String cleanName = _nameCtrl.text.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        '.',
      );
      if (cleanName.isEmpty) cleanName = 'driver';
      String defaultEmail = '$cleanName@example.com';

      // Format date snippet if they just enter MM/YYYY -> mock 1st of month
      String formattedExpiry = _expiryDateCtrl.text;
      if (formattedExpiry.contains('/')) {
        final parts = formattedExpiry.split('/');
        if (parts.length == 2) {
          formattedExpiry = '${parts[1]}-${parts[0]}-01'; // YYYY-MM-DD
        }
      } else {
        formattedExpiry = '2030-01-01'; // Fallback if no valid parsing
      }

      final Map<String, dynamic> driverData = {
        "name": _nameCtrl.text.trim(),
        "email": defaultEmail,
        "password": "Driver@123", // Default per requirements
        "role_id": 3,
        "phone": _phoneCtrl.text.trim(),
        "license_number": _licenseCtrl.text.trim(),
        "license_expiry": formattedExpiry,
        "experience_years": experience,
      };

      final success = await Provider.of<DriverStore>(
        context,
        listen: false,
      ).addDriver(driverData);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Driver Registered Successfully!')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to Register Driver. Please check inputs.'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color inputColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Register Driver",
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: titleColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Photo Placeholder
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: isDark ? Colors.white38 : Colors.grey.shade400,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF6366F1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildSectionLabel("Personal Information", Icons.person_outline),
              const SizedBox(height: 12),
              _buildTextField(
                "Full Name",
                _nameCtrl,
                "e.g. John Doe",
                Icons.badge_outlined,
                isDark,
                inputColor,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                "Phone Number",
                _phoneCtrl,
                "e.g. +123456789",
                Icons.phone_outlined,
                isDark,
                inputColor,
              ),
              const SizedBox(height: 32),

              _buildSectionLabel("Professional Details", Icons.work_outline),
              const SizedBox(height: 12),
              _buildTextField(
                "License Number",
                _licenseCtrl,
                "e.g. DL-12345678",
                Icons.credit_card_outlined,
                isDark,
                inputColor,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      "Expiry Date",
                      _expiryDateCtrl,
                      "MM/YYYY",
                      Icons.calendar_today_outlined,
                      isDark,
                      inputColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      "Experience",
                      _experienceCtrl,
                      "Years",
                      Icons.timeline,
                      isDark,
                      inputColor,
                      isNumber: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Register Driver",
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
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
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
}
