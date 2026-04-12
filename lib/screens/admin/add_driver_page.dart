import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';
import 'package:tripzo/store/driver_store.dart';

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
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _bloodGroupCtrl = TextEditingController();
  final TextEditingController _emergencyNameCtrl = TextEditingController();
  final TextEditingController _emergencyPhoneCtrl = TextEditingController();
  final TextEditingController _joiningDateCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  String _selectedBloodGroup = 'O+';
  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-'
  ];

  String? _frontPath;
  String? _backPath;
  bool _isCheckingLicense = false;
  String _selectedVehicleType = 'Bus'; // Default: Bus, Car, Bike
  final List<String> _vehicleTypes = ['Bike', 'Car', 'Bus'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _licenseCtrl.dispose();
    _expiryDateCtrl.dispose();
    _experienceCtrl.dispose();
    _addressCtrl.dispose();
    _ageCtrl.dispose();
    _bloodGroupCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _joiningDateCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _isLoading = false;
  bool _isAutoUpload = true;

  void _pickLicenseImage(bool isFront) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        if (isFront) {
          _frontPath = image.path;
        } else {
          _backPath = image.path;
        }
      });

      if (_frontPath != null &&
          _backPath != null &&
          _nameCtrl.text.isNotEmpty) {
        _performLicenseCheck();
      }
    }
  }

  void _performLicenseCheck() async {
    setState(() => _isCheckingLicense = true);

    final store = Provider.of<DriverStore>(context, listen: false);
    final result = await store.checkLicense(
      driverName: _nameCtrl.text.trim(),
      frontPath: _frontPath!,
      backPath: _backPath!,
    );

    setState(() => _isCheckingLicense = false);

    if (result != null) {
      _licenseCtrl.text = result['license_number'] ?? _licenseCtrl.text;
      _addressCtrl.text = result['extracted_address'] ?? _addressCtrl.text;
      _expiryDateCtrl.text = result['validity_date'] ?? _expiryDateCtrl.text;

      // Mapping vehicle code
      final vCode = (result['vehicle_code'] ?? "").toString().toUpperCase();
      if (vCode.contains("MCWG")) {
        _selectedVehicleType = 'Bike';
      } else if (vCode.contains("LMV")) {
        _selectedVehicleType = 'Car';
      } else {
        _selectedVehicleType = 'Bus';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['name_match'] == true
                ? "License verified: Name matches!"
                : "License extracted (Name mismatch: ${result['extracted_name']})",
          ),
          backgroundColor: result['name_match'] == true
              ? Colors.green
              : Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to extract license details")),
      );
    }
  }

  Future<void> _selectExpiryDate() async {
    DateTime? initialDate;
    if (_expiryDateCtrl.text.isNotEmpty) {
      try {
        initialDate = DateFormat("dd-MM-yyyy").parse(_expiryDateCtrl.text);
      } catch (_) {
        initialDate = DateTime.now();
      }
    }

    final DateTime? picked = await CustomDateTimePicker.show(
      context,
      initialDate: initialDate ?? DateTime.now(),
      minDate: DateTime.now(),
      showTime: false,
    );

    if (picked != null) {
      setState(() {
        _expiryDateCtrl.text = DateFormat("dd-MM-yyyy").format(picked);
      });
    }
  }

  Future<void> _selectJoiningDate() async {
    DateTime? initialDate;
    if (_joiningDateCtrl.text.isNotEmpty) {
      try {
        initialDate = DateFormat("dd-MM-yyyy").parse(_joiningDateCtrl.text);
      } catch (_) {
        initialDate = DateTime.now();
      }
    }

    final DateTime? picked = await CustomDateTimePicker.show(
      context,
      initialDate: initialDate ?? DateTime.now(),
      minDate: DateTime(2000),
      showTime: false,
    );

    if (picked != null) {
      setState(() {
        _joiningDateCtrl.text = DateFormat("dd-MM-yyyy").format(picked);
      });
    }
  }

  String _formatDate(String ddMmYyyy) {
    try {
      final parts = ddMmYyyy.split('-');
      if (parts.length == 3) {
        return "${parts[2]}-${parts[1]}-${parts[0]}";
      }
    } catch (_) {}
    return ddMmYyyy;
  }

  void _submit() async {
    // If OCR is in progress, block submission
    if (_isCheckingLicense) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please wait, license extraction is in progress..."),
        ),
      );
      return;
    }

    // If auto-upload is on, verify we have images and potentially extracted data
    if (_isAutoUpload) {
      if (_frontPath == null || _backPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please upload both sides of the license first."),
          ),
        );
        return;
      }
      if (_licenseCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "License details not extracted. Please try re-uploading or switch to manual input.",
            ),
          ),
        );
        return;
      }
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final int experience = int.tryParse(_experienceCtrl.text) ?? 0;
      final int age = int.tryParse(_ageCtrl.text) ?? 25;

      final Map<String, dynamic> driverData = {
        "role_id": 4, // 4 as per curl (Admin Driver role)
        "name": _nameCtrl.text.trim(),
        "email": _emailCtrl.text.trim(),
        "phone": _phoneCtrl.text.trim(),
        "password": _passwordCtrl.text.trim().isEmpty
            ? "Driver@123"
            : _passwordCtrl.text.trim(),
        "status": "ACTIVE",
        "push_notification_enabled": false,
        "age": age,
        "license_number": _licenseCtrl.text.trim(),
        "license_expiry_date": _formatDate(_expiryDateCtrl.text.trim()),
        "experience_years": experience,
        "blood_group": _selectedBloodGroup,
        "address": _addressCtrl.text.trim(),
        "emergency_contact_name": _emergencyNameCtrl.text.trim(),
        "emergency_contact_phone": _emergencyPhoneCtrl.text.trim(),
        "joining_date": _formatDate(_joiningDateCtrl.text.trim()),
        "driver_status": "AVAILABLE"
      };

      final response = await Provider.of<DriverStore>(
        context,
        listen: false,
      ).addDriver(driverData);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        final bool success = response['success'] ?? false;
        final String message = response['message'] ?? (success ? 'Success' : 'Failed');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );

        if (success) {
          Navigator.pop(context);
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
    final Color primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Register Driver",
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: titleColor),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Photo Header
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryBlue.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        child: Icon(
                          Icons.person_rounded,
                          size: 64,
                          color: primaryBlue.withOpacity(isDark ? 0.3 : 0.1),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryBlue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              _buildSectionCard("Personal details", isDark, inputColor, [
                _buildTextField(
                  "Full Name",
                  _nameCtrl,
                  "e.g. Karthick Raja",
                  Icons.badge_outlined,
                  isDark,
                  inputColor,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  "Email Address",
                  _emailCtrl,
                  "e.g. karthick.r@bitsathy.ac.in",
                  Icons.email_outlined,
                  isDark,
                  inputColor,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  "Password",
                  _passwordCtrl,
                  "Choose a login password",
                  Icons.lock_outline_rounded,
                  isDark,
                  inputColor,
                  isPassword: true,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  "Phone Number",
                  _phoneCtrl,
                  "e.g. +123456789",
                  Icons.phone_iphone_rounded,
                  isDark,
                  inputColor,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Age",
                        _ageCtrl,
                        "e.g. 27",
                        Icons.numbers_rounded,
                        isDark,
                        inputColor,
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdownField(
                        "Blood Group",
                        _selectedBloodGroup,
                        _bloodGroups,
                        (val) => setState(() => _selectedBloodGroup = val!),
                        Icons.bloodtype_outlined,
                        isDark,
                        inputColor,
                      ),
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionCard("License extraction", isDark, inputColor, [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Sync from License",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        Text(
                          "Extract data from image",
                          style: TextStyle(
                            fontSize: 12,
                            color: titleColor.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    Switch.adaptive(
                      value: _isAutoUpload,
                      activeColor: primaryBlue,
                      onChanged: (val) => setState(() => _isAutoUpload = val),
                    ),
                  ],
                ),
                if (_isAutoUpload) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPremiumImageSelector(
                          "Front Side",
                          _frontPath,
                          () => _pickLicenseImage(true),
                          isDark,
                          primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildPremiumImageSelector(
                          "Back Side",
                          _backPath,
                          () => _pickLicenseImage(false),
                          isDark,
                          primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  if (_isCheckingLicense) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primaryBlue.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Processing License OCR...",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primaryBlue,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ]),
              const SizedBox(height: 24),

              _buildSectionCard(
                "Professional Information",
                isDark,
                inputColor,
                [
                  _buildTextField(
                    "License Number",
                    _licenseCtrl,
                    "Identifier code",
                    Icons.contact_emergency_outlined,
                    isDark,
                    inputColor,
                    isExtracting:
                        _isCheckingLicense && _licenseCtrl.text.isEmpty,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    "Expiry Date",
                    _expiryDateCtrl,
                    "DD-MM-YYYY",
                    Icons.event_available_rounded,
                    isDark,
                    inputColor,
                    isExtracting:
                        _isCheckingLicense && _expiryDateCtrl.text.isEmpty,
                    readOnly: true,
                    onTap: _selectExpiryDate,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    "Address",
                    _addressCtrl,
                    "Residential address",
                    Icons.home_work_outlined,
                    isDark,
                    inputColor,
                    isExtracting:
                        _isCheckingLicense && _addressCtrl.text.isEmpty,
                  ),
                  const SizedBox(height: 20),
                  _buildDropdownField(
                    "Vehicle Type",
                    _selectedVehicleType,
                    _vehicleTypes,
                    (val) => setState(() => _selectedVehicleType = val!),
                    Icons.local_shipping_outlined,
                    isDark,
                    inputColor,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    "Total Experience",
                    _experienceCtrl,
                    "In years",
                    Icons.timeline_rounded,
                    isDark,
                    inputColor,
                    isNumber: true,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionCard("Employment Details", isDark, inputColor, [
                _buildTextField(
                  "Joining Date",
                  _joiningDateCtrl,
                  "DD-MM-YYYY",
                  Icons.calendar_today_rounded,
                  isDark,
                  inputColor,
                  readOnly: true,
                  onTap: _selectJoiningDate,
                ),
              ]),
              const SizedBox(height: 24),

              _buildSectionCard("Emergency Contact", isDark, inputColor, [
                _buildTextField(
                  "Person Name",
                  _emergencyNameCtrl,
                  "Relative or friend",
                  Icons.person_pin_outlined,
                  isDark,
                  inputColor,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  "Emergency Phone",
                  _emergencyPhoneCtrl,
                  "e.g. +123456789",
                  Icons.contact_phone_outlined,
                  isDark,
                  inputColor,
                ),
              ]),
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 64,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isCheckingLicense)
                        ? null
                        : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      disabledBackgroundColor: primaryBlue.withOpacity(0.6),
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
                        : Text(
                            _isCheckingLicense
                                ? "Extracting Details..."
                                : "Complete Registration",
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
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

  Widget _buildSectionCard(
    String title,
    bool isDark,
    Color fill,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumImageSelector(
    String label,
    String? path,
    VoidCallback onTap,
    bool isDark,
    Color primary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: path != null
                  ? Colors.transparent
                  : (isDark ? Colors.black26 : Colors.grey.shade50),
              borderRadius: BorderRadius.circular(20),
              image: path != null
                  ? DecorationImage(
                      image: FileImage(File(path)),
                      fit: BoxFit.cover,
                    )
                  : null,
              border: Border.all(
                color: path != null
                    ? const Color(0xFF10B981)
                    : primary.withOpacity(0.2),
                width: 2,
                style: path != null
                    ? BorderStyle.solid
                    : BorderStyle.solid, // Custom paint could do dashed
              ),
            ),
            child: Stack(
              children: [
                if (path == null)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 32,
                          color: primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primary.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (path != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
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

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint,
    IconData icon,
    bool isDark,
    Color fill, {
    bool isNumber = false,
    bool isExtracting = false,
    bool readOnly = false,
    VoidCallback? onTap,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            if (isExtracting)
              Text(
                "Extracting...",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF6366F1),
                  letterSpacing: 0.5,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: isExtracting ? 0.6 : 1.0,
          child: TextFormField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            obscureText: isPassword,
            readOnly: readOnly || isExtracting,
            onTap: isExtracting ? null : onTap,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: isExtracting ? "Extracting from image..." : hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.white24 : Colors.grey.shade400,
                fontSize: 14,
                fontWeight: isExtracting ? FontWeight.w600 : FontWeight.normal,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(12),
                child: isExtracting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF6366F1),
                        ),
                      )
                    : Icon(icon, color: const Color(0xFF6366F1), size: 22),
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.black.withOpacity(0.2)
                  : Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF6366F1),
                  width: 1.5,
                ),
              ),
            ),
            validator: (v) {
              if (_isAutoUpload &&
                  (label == "License Number" ||
                      label == "Expiry Date" ||
                      label == "Address")) {
                return null;
              }
              return (v == null || v.isEmpty) ? "Field required" : null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
    IconData icon,
    bool isDark,
    Color fill,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF6366F1),
              ),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              onChanged: onChanged,
              items: items.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: const Color(0xFF6366F1).withOpacity(0.7),
                      ),
                      const SizedBox(width: 12),
                      Text(type),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
