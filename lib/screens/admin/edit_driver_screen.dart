import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/utils/toast_utils.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';
import 'package:intl/intl.dart';

class EditDriverScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> driver;

  const EditDriverScreen({super.key, required this.driver});

  @override
  ConsumerState<EditDriverScreen> createState() => _EditDriverScreenState();
}

class _EditDriverScreenState extends ConsumerState<EditDriverScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _usernameController;
  late TextEditingController _ageController;
  late TextEditingController _licenseNumController;
  late TextEditingController _experienceController;
  late TextEditingController _bloodGroupController;
  late TextEditingController _addressController;
  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;

  DateTime? _licenseExpiryDate;
  DateTime? _joiningDate;
  String _driverStatus = 'AVAILABLE';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final d = widget.driver;
    final dp = d['driverProfile'] ?? {};

    _nameController = TextEditingController(text: d['name'] ?? '');
    _emailController = TextEditingController(text: d['email'] ?? '');
    _phoneController = TextEditingController(text: d['phone'] ?? '');
    _usernameController = TextEditingController(text: d['username'] ?? '');
    _ageController = TextEditingController(text: (dp['age'] ?? '').toString());
    _licenseNumController = TextEditingController(text: dp['license_number'] ?? '');
    _experienceController = TextEditingController(text: (dp['experience_years'] ?? '').toString());
    _bloodGroupController = TextEditingController(text: dp['blood_group'] ?? '');
    _addressController = TextEditingController(text: dp['address'] ?? '');
    _emergencyNameController = TextEditingController(text: dp['emergency_contact_name'] ?? '');
    _emergencyPhoneController = TextEditingController(text: dp['emergency_contact_phone'] ?? '');

    _driverStatus = d['status'] ?? 'AVAILABLE';

    if (dp['license_expiry_date'] != null && dp['license_expiry_date'] != '1970-01-01') {
      try {
        _licenseExpiryDate = DateTime.parse(dp['license_expiry_date']);
      } catch (_) {}
    }
    if (dp['joining_date'] != null && dp['joining_date'] != '1970-01-01') {
      try {
        _joiningDate = DateTime.parse(dp['joining_date']);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _ageController.dispose();
    _licenseNumController.dispose();
    _experienceController.dispose();
    _bloodGroupController.dispose();
    _addressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _updateDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final payload = {
      "id": widget.driver['user_id'] ?? widget.driver['id'],
      "name": _nameController.text,
      "email": _emailController.text,
      "role_id": 4, // Assuming 4 is driver role
      "phone": _phoneController.text,
      "username": _usernameController.text,
      "age": int.tryParse(_ageController.text) ?? 0,
      "license_number": _licenseNumController.text,
      "license_expiry_date": _licenseExpiryDate != null
          ? DateFormat('yyyy-MM-dd').format(_licenseExpiryDate!)
          : "1970-01-01",
      "experience_years": int.tryParse(_experienceController.text) ?? 0,
      "blood_group": _bloodGroupController.text,
      "address": _addressController.text,
      "emergency_contact_name": _emergencyNameController.text,
      "emergency_contact_phone": _emergencyPhoneController.text,
      "joining_date": _joiningDate != null
          ? DateFormat('yyyy-MM-dd').format(_joiningDate!)
          : "1970-01-01",
      "driver_status": _driverStatus,
    };

    final store = useDriverStore;
    final result = await store.updateDriver(payload);

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        showTopToast(context, result['message']);
        Navigator.pop(context, true); // Pop back and indicate success
      } else {
        showTopToast(context, result['message'], isError: true);
      }
    }
  }

  Widget _buildSectionTitle(String title, Color titleColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child, required bool isDark, required Color surfaceColor}) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFF6366F1).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
    bool isDark, {
    TextInputType type = TextInputType.text,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        validator: required
            ? (val) => val == null || val.isEmpty ? "Required" : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey[200]!,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? selectedDate,
    IconData icon,
    bool isDark,
    ValueChanged<DateTime?> onPicked,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final date = await CustomDateTimePicker.show(
            context,
            initialDate: selectedDate ?? DateTime.now(),
            showTime: false,
          );
          if (date != null) {
            onPicked(date);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey[200]!,
              ),
            ),
          ),
          child: Text(
            selectedDate != null
                ? DateFormat('MMM dd, yyyy').format(selectedDate)
                : 'Select Date',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _driverStatus,
        items: const [
          DropdownMenuItem(value: 'AVAILABLE', child: Text('AVAILABLE')),
          DropdownMenuItem(value: 'ASSIGNED', child: Text('ASSIGNED')),
          DropdownMenuItem(value: 'ON_TRIP', child: Text('ON_TRIP')),
          DropdownMenuItem(value: 'ON_LEAVE', child: Text('ON_LEAVE')),
        ],
        onChanged: (v) => setState(() => _driverStatus = v!),
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: 'Driver Status',
          labelStyle: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.info_outline, color: Color(0xFF6366F1), size: 20),
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey[200]!,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Edit Driver",
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Personal Information", titleColor),
              _buildCard(
                isDark: isDark,
                surfaceColor: surfaceColor,
                child: Column(
                  children: [
                    _buildTextField("Full Name", _nameController, Icons.person, isDark, required: true),
                    _buildTextField("Username", _usernameController, Icons.alternate_email, isDark, required: true),
                    _buildTextField("Email", _emailController, Icons.email, isDark, type: TextInputType.emailAddress),
                    _buildTextField("Phone", _phoneController, Icons.phone, isDark, type: TextInputType.phone, required: true),
                    _buildTextField("Age", _ageController, Icons.cake, isDark, type: TextInputType.number),
                    _buildTextField("Blood Group", _bloodGroupController, Icons.bloodtype, isDark),
                    _buildTextField("Address", _addressController, Icons.location_on, isDark),
                  ],
                ),
              ),

              _buildSectionTitle("Professional Details", titleColor),
              _buildCard(
                isDark: isDark,
                surfaceColor: surfaceColor,
                child: Column(
                  children: [
                    _buildTextField("License Number", _licenseNumController, Icons.badge, isDark),
                    _buildDatePicker("License Expiry Date", _licenseExpiryDate, Icons.event, isDark, (d) => setState(() => _licenseExpiryDate = d)),
                    _buildTextField("Experience (Years)", _experienceController, Icons.history, isDark, type: TextInputType.number),
                    _buildDatePicker("Joining Date", _joiningDate, Icons.calendar_today, isDark, (d) => setState(() => _joiningDate = d)),
                    _buildStatusDropdown(isDark),
                  ],
                ),
              ),

              _buildSectionTitle("Emergency Contact", titleColor),
              _buildCard(
                isDark: isDark,
                surfaceColor: surfaceColor,
                child: Column(
                  children: [
                    _buildTextField("Contact Name", _emergencyNameController, Icons.contact_emergency, isDark),
                    _buildTextField("Contact Phone", _emergencyPhoneController, Icons.phone_callback, isDark, type: TextInputType.phone),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Save Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateDriver,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          "Save Changes",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
