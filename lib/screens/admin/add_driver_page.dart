import 'package:flutter/material.dart';

class AddDriverPage extends StatefulWidget {
  const AddDriverPage({super.key});

  @override
  State<AddDriverPage> createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _bloodGroupCtrl = TextEditingController();
  final TextEditingController _licenseCtrl = TextEditingController();
  final TextEditingController _expiryDateCtrl = TextEditingController();
  final TextEditingController _experienceCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _bloodGroupCtrl.dispose();
    _licenseCtrl.dispose();
    _expiryDateCtrl.dispose();
    _experienceCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // TODO: Handle API Submission here
      Navigator.pop(context);
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
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      "Phone Number",
                      _phoneCtrl,
                      "e.g. +123456789",
                      Icons.phone_outlined,
                      isDark,
                      inputColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      "Blood Group",
                      _bloodGroupCtrl,
                      "e.g. O+",
                      Icons.bloodtype_outlined,
                      isDark,
                      inputColor,
                    ),
                  ),
                ],
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
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
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
