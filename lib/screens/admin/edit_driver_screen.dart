import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/utils/toast_utils.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';
import 'package:intl/intl.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_cropper/image_cropper.dart';

class EditDriverScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> driver;

  const EditDriverScreen({super.key, required this.driver});

  @override
  ConsumerState<EditDriverScreen> createState() => _EditDriverScreenState();
}

class _EditDriverScreenState extends ConsumerState<EditDriverScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();
  final _formKey4 = GlobalKey<FormState>();

  // Profile Image
  XFile? _profileImage;
  String? _existingProfilePhotoUrl;

  // Documents
  XFile? _licenseFrontImage, _licenseBackImage, _aadharImage, _panImage;
  String? _existingLicenseFront, _existingLicenseBack, _existingAadhar, _existingPan;

  // Step 1: Personal Info
  late TextEditingController _nameCtrl, _emailCtrl, _phoneCtrl, _altPhoneCtrl;
  late TextEditingController _fatherNameCtrl, _motherNameCtrl, _spouseNameCtrl;
  late TextEditingController _religionCtrl, _casteCtrl, _communityCtrl, _aadharCtrl;
  late TextEditingController _addressCtrl, _ageCtrl, _genderCtrl, _bloodGroupCtrl, _maritalStatusCtrl;
  DateTime? _dobDate;

  // Step 2: Account & Role
  late TextEditingController _usernameCtrl;
  late TextEditingController _nomineeNameCtrl, _nomineeRelationCtrl;
  DateTime? _nomineeDobDate;

  // Step 3: Role Details
  late TextEditingController _licenseNumCtrl, _vehicleTypeCtrl, _experienceCtrl, _expAtBitCtrl;
  late TextEditingController _emergencyNameCtrl, _emergencyPhoneCtrl;
  DateTime? _licenseExpiryDate, _joiningDate, _nonTransportExpiryDate;
  String _driverStatus = 'AVAILABLE';
  String _shift = 'MORNING';

  // Step 4: Financial & Bank
  late TextEditingController _salaryBasicCtrl, _grossSalaryCtrl, _daCtrl, _saCtrl, _epfoCtrl;
  late TextEditingController _bankNameCtrl, _accNumCtrl, _ifscCtrl, _branchCtrl;
  late TextEditingController _subBankNameCtrl, _subAccNumCtrl, _subIfscCtrl, _subBranchCtrl;

  @override
  void initState() {
    super.initState();
    final d = widget.driver;
    final dp = d['driverProfile'] ?? {};

    _existingProfilePhotoUrl = _getImageUrl(d['profile_photo']);
    _existingLicenseFront = _getImageUrl(dp['licence_image_front']);
    _existingLicenseBack = _getImageUrl(dp['licence_image_back']);
    _existingAadhar = _getImageUrl(d['aadhar_photo']);
    _existingPan = _getImageUrl(dp['pan_image']);

    // Step 1
    _nameCtrl = TextEditingController(text: d['name'] ?? '');
    _emailCtrl = TextEditingController(text: d['email'] ?? '');
    _phoneCtrl = TextEditingController(text: d['phone'] ?? '');
    _altPhoneCtrl = TextEditingController(text: d['mobile_number_2'] ?? d['mobile_2'] ?? '');
    _fatherNameCtrl = TextEditingController(text: d['father_name'] ?? '');
    _motherNameCtrl = TextEditingController(text: d['mother_name'] ?? '');
    _spouseNameCtrl = TextEditingController(text: d['spouse_name'] ?? '');
    _religionCtrl = TextEditingController(text: d['religious'] ?? d['religion'] ?? '');
    _casteCtrl = TextEditingController(text: d['caste'] ?? '');
    _communityCtrl = TextEditingController(text: d['community'] ?? '');
    _aadharCtrl = TextEditingController(text: d['aadhar_number'] ?? '');
    _addressCtrl = TextEditingController(text: dp['address'] ?? d['address'] ?? '');
    _ageCtrl = TextEditingController(text: (d['age'] ?? dp['age'] ?? '').toString());
    _genderCtrl = TextEditingController(text: d['gender'] ?? 'Male');
    _bloodGroupCtrl = TextEditingController(text: dp['blood_group'] ?? d['blood_group'] ?? '');
    _maritalStatusCtrl = TextEditingController(text: dp['marital_status'] ?? '');
    _dobDate = _parseDate(d['dob']);

    // Step 2
    _usernameCtrl = TextEditingController(text: d['username'] ?? '');
    _nomineeNameCtrl = TextEditingController(text: dp['nominee_name'] ?? '');
    _nomineeRelationCtrl = TextEditingController(text: dp['nominee_relation'] ?? '');
    _nomineeDobDate = _parseDate(dp['nominee_dob']);

    // Step 3
    _licenseNumCtrl = TextEditingController(text: dp['license_number'] ?? '');
    _vehicleTypeCtrl = TextEditingController(text: dp['Vehicle_type'] ?? '');
    _experienceCtrl = TextEditingController(text: (dp['experience_years'] ?? '').toString());
    _expAtBitCtrl = TextEditingController(text: (dp['experience_at_Bit'] ?? '').toString());
    _emergencyNameCtrl = TextEditingController(text: dp['emergency_contact_name'] ?? '');
    _emergencyPhoneCtrl = TextEditingController(text: dp['emergency_contact_phone'] ?? '');
    _licenseExpiryDate = _parseDate(dp['license_expiry_date']);
    _joiningDate = _parseDate(dp['joining_date']);
    _nonTransportExpiryDate = _parseDate(dp['non_transport_expiry_date']);
    final rawStatus = (dp['status'] ?? d['status'] ?? 'AVAILABLE').toString().toUpperCase();
    _driverStatus = ['AVAILABLE', 'ASSIGNED', 'ON_TRIP', 'ON_LEAVE'].contains(rawStatus) ? rawStatus : 'AVAILABLE';

    final rawShift = (dp['shift'] ?? 'MORNING').toString().toUpperCase();
    _shift = ['MORNING', 'AFTERNOON', 'NIGHT'].contains(rawShift) ? rawShift : 'MORNING';

    // Step 4
    _salaryBasicCtrl = TextEditingController(text: (dp['salary_basic'] ?? '').toString());
    _grossSalaryCtrl = TextEditingController(text: (dp['gross_salary'] ?? '').toString());
    _daCtrl = TextEditingController(text: (dp['da'] ?? '').toString());
    _saCtrl = TextEditingController(text: (dp['sa'] ?? '').toString());
    _epfoCtrl = TextEditingController(text: (dp['epfo_management_contribution'] ?? '').toString());
    _bankNameCtrl = TextEditingController(text: d['bank_name'] ?? '');
    _accNumCtrl = TextEditingController(text: d['account_number'] ?? '');
    _ifscCtrl = TextEditingController(text: d['ifsc_code'] ?? '');
    _branchCtrl = TextEditingController(text: d['branch_name'] ?? '');
    _subBankNameCtrl = TextEditingController(text: d['sub_bank_name'] ?? '');
    _subAccNumCtrl = TextEditingController(text: d['sub_account_number'] ?? '');
    _subIfscCtrl = TextEditingController(text: d['sub_bank_ifsc_code'] ?? '');
    _subBranchCtrl = TextEditingController(text: d['sub_bank_branch_name'] ?? '');
  }

  String? _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    final base = ApiConstants.baseUrl.endsWith('/') ? ApiConstants.baseUrl.substring(0, ApiConstants.baseUrl.length - 1) : ApiConstants.baseUrl;
    final relative = path.startsWith('/') ? path : '/$path';
    final url = '$base$relative';
    return url.contains('?') ? '$url&v=2' : '$url?v=2';
  }

  DateTime? _parseDate(dynamic dateStr) {
    if (dateStr == null || dateStr == '1970-01-01') return null;
    try {
      return DateTime.parse(dateStr.toString());
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose(); _altPhoneCtrl.dispose();
    _fatherNameCtrl.dispose(); _motherNameCtrl.dispose(); _spouseNameCtrl.dispose();
    _religionCtrl.dispose(); _casteCtrl.dispose(); _communityCtrl.dispose(); _aadharCtrl.dispose();
    _addressCtrl.dispose(); _ageCtrl.dispose(); _genderCtrl.dispose(); _bloodGroupCtrl.dispose();
    _maritalStatusCtrl.dispose();
    
    _usernameCtrl.dispose(); _nomineeNameCtrl.dispose(); _nomineeRelationCtrl.dispose();
    
    _licenseNumCtrl.dispose(); _vehicleTypeCtrl.dispose(); _experienceCtrl.dispose(); _expAtBitCtrl.dispose();
    _emergencyNameCtrl.dispose(); _emergencyPhoneCtrl.dispose();
    
    _salaryBasicCtrl.dispose(); _grossSalaryCtrl.dispose(); _daCtrl.dispose(); _saCtrl.dispose(); _epfoCtrl.dispose();
    _bankNameCtrl.dispose(); _accNumCtrl.dispose(); _ifscCtrl.dispose(); _branchCtrl.dispose();
    _subBankNameCtrl.dispose(); _subAccNumCtrl.dispose(); _subIfscCtrl.dispose(); _subBranchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(Function(XFile?) onPicked) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Select Image Source',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF6366F1)),
                title: const Text('Camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF6366F1)),
                title: const Text('Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    final XFile? image = await _picker.pickImage(source: source, imageQuality: 100);
    if (image != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: const Color(0xFF6366F1),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9
            ],
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9
            ],
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() => _isLoading = true);
        try {
          final dir = await getTemporaryDirectory();
          final targetPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';
          
          final compressedFile = await FlutterImageCompress.compressAndGetFile(
            croppedFile.path, 
            targetPath,
            quality: 60,
          );
          
          if (compressedFile != null) {
            setState(() => onPicked(XFile(compressedFile.path)));
          } else {
            setState(() => onPicked(XFile(croppedFile.path)));
          }
        } catch (e) {
          setState(() => onPicked(XFile(croppedFile.path)));
        } finally {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _submitForm() async {
    bool isValid = true;
    if (!(_formKey1.currentState?.validate() ?? true)) isValid = false;
    if (!(_formKey2.currentState?.validate() ?? true)) isValid = false;
    if (!(_formKey3.currentState?.validate() ?? true)) isValid = false;
    if (!(_formKey4.currentState?.validate() ?? true)) isValid = false;

    if (!isValid) {
      showTopToast(context, "Please check all steps for errors.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    Map<String, String> payload = {
      "id": (widget.driver['user_id'] ?? widget.driver['id']).toString(),
      "role_id": "4",
      "name": _nameCtrl.text,
      "email": _emailCtrl.text,
      "phone": _phoneCtrl.text,
      "mobile_2": _altPhoneCtrl.text,
      "father_name": _fatherNameCtrl.text,
      "mother_name": _motherNameCtrl.text,
      "spouse_name": _spouseNameCtrl.text,
      "religion": _religionCtrl.text,
      "caste": _casteCtrl.text,
      "community": _communityCtrl.text,
      "aadhar_number": _aadharCtrl.text,
      "address": _addressCtrl.text,
      "age": _ageCtrl.text,
      "gender": _genderCtrl.text,
      "blood_group": _bloodGroupCtrl.text,
      "marital_status": _maritalStatusCtrl.text,
      "dob": _dobDate != null ? DateFormat('yyyy-MM-dd').format(_dobDate!) : '',
      
      "username": _usernameCtrl.text,
      "nominee_name": _nomineeNameCtrl.text,
      "nominee_relation": _nomineeRelationCtrl.text,
      "nominee_dob": _nomineeDobDate != null ? DateFormat('yyyy-MM-dd').format(_nomineeDobDate!) : '',
      
      "license_number": _licenseNumCtrl.text,
      "Vehicle_type": _vehicleTypeCtrl.text,
      "experience_years": _experienceCtrl.text,
      "experience_at_Bit": _expAtBitCtrl.text,
      "driver_status": _driverStatus,
      "shift": _shift,
      "emergency_contact_name": _emergencyNameCtrl.text,
      "emergency_contact_phone": _emergencyPhoneCtrl.text,
      "license_expiry_date": _licenseExpiryDate != null ? DateFormat('yyyy-MM-dd').format(_licenseExpiryDate!) : '',
      "joining_date": _joiningDate != null ? DateFormat('yyyy-MM-dd').format(_joiningDate!) : '',
      "non_transport_expiry_date": _nonTransportExpiryDate != null ? DateFormat('yyyy-MM-dd').format(_nonTransportExpiryDate!) : '',
      
      "salary_basic": _salaryBasicCtrl.text,
      "gross_salary": _grossSalaryCtrl.text,
      "da": _daCtrl.text,
      "sa": _saCtrl.text,
      "epfo_management_contribution": _epfoCtrl.text,
      "bank_name": _bankNameCtrl.text,
      "account_number": _accNumCtrl.text,
      "ifsc_code": _ifscCtrl.text,
      "branch_name": _branchCtrl.text,
      "sub_bank_name": _subBankNameCtrl.text,
      "sub_account_number": _subAccNumCtrl.text,
      "sub_bank_ifsc_code": _subIfscCtrl.text,
      "sub_bank_branch_name": _subBranchCtrl.text,
    };

    Map<String, dynamic> files = {};
    if (_profileImage != null) files['profile_photo'] = File(_profileImage!.path);
    if (_licenseFrontImage != null) files['licence_image_front'] = File(_licenseFrontImage!.path);
    if (_licenseBackImage != null) files['licence_image_back'] = File(_licenseBackImage!.path);
    if (_aadharImage != null) files['aadhar_photo'] = File(_aadharImage!.path);
    if (_panImage != null) files['pan_image'] = File(_panImage!.path);

    final store = useDriverStore;
    final result = await store.updateDriverMultipart(payload, files: files);

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        showTopToast(context, result['message']);
        Navigator.pop(context, true);
      } else {
        showTopToast(context, result['message'], isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color primaryBlue = const Color(0xFF6366F1);
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
          "Edit Driver Profile",
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Profile Photo Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                      border: Border.all(color: primaryBlue.withOpacity(0.5), width: 2),
                    ),
                    child: ClipOval(
                      child: _profileImage != null
                          ? Image.file(File(_profileImage!.path), fit: BoxFit.cover)
                          : _existingProfilePhotoUrl != null
                              ? Image.network(_existingProfilePhotoUrl!, fit: BoxFit.cover, headers: const {'X-Tunnel-Skip-Anti-Phishing-Page': 'true'})
                              : Icon(Icons.person, size: 60, color: Colors.grey[400]),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _pickImage((img) => _profileImage = img),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: bgColor, width: 3),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Stepper
          Expanded(
            child: Stepper(
              type: StepperType.vertical,
              physics: const BouncingScrollPhysics(),
              currentStep: _currentStep,
              onStepTapped: (step) => setState(() => _currentStep = step),
              onStepContinue: () {
                if (_currentStep < 4) {
                  setState(() => _currentStep += 1);
                } else {
                  _submitForm();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep -= 1);
                }
              },
              controlsBuilder: (BuildContext context, ControlsDetails details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : details.onStepContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading && _currentStep == 4
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_currentStep == 4 ? 'SAVE CHANGES' : 'CONTINUE', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (_currentStep > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: details.onStepCancel,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(color: isDark ? Colors.white30 : Colors.black26),
                            ),
                            child: Text('BACK', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                );
              },
              steps: <Step>[
                Step(
                  title: Text('Personal Info', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  content: Form(
                    key: _formKey1,
                    child: Column(
                      children: [
                        _buildTextField("Full Name *", _nameCtrl, Icons.person, isDark, required: true),
                        _buildTextField("Email *", _emailCtrl, Icons.email, isDark, type: TextInputType.emailAddress, required: true),
                        _buildTextField("Primary Phone *", _phoneCtrl, Icons.phone, isDark, type: TextInputType.phone, required: true),
                        _buildTextField("Alternate Phone", _altPhoneCtrl, Icons.phone_android, isDark, type: TextInputType.phone),
                        _buildTextField("Father Name", _fatherNameCtrl, Icons.man, isDark),
                        _buildTextField("Mother Name", _motherNameCtrl, Icons.woman, isDark),
                        _buildTextField("Spouse Name", _spouseNameCtrl, Icons.favorite, isDark),
                        _buildTextField("Religion", _religionCtrl, Icons.mosque, isDark),
                        _buildTextField("Caste", _casteCtrl, Icons.groups, isDark),
                        _buildTextField("Community", _communityCtrl, Icons.group_work, isDark),
                        _buildTextField("Aadhaar Number", _aadharCtrl, Icons.credit_card, isDark, type: TextInputType.number),
                        _buildTextField("Full Address", _addressCtrl, Icons.location_on, isDark),
                        Row(
                          children: [
                            Expanded(child: _buildDatePicker("Date of Birth", _dobDate, Icons.cake, isDark, (d) => setState(() => _dobDate = d))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField("Age", _ageCtrl, Icons.person_pin, isDark, type: TextInputType.number)),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(child: _buildTextField("Gender", _genderCtrl, Icons.wc, isDark)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField("Blood Group", _bloodGroupCtrl, Icons.bloodtype, isDark)),
                          ],
                        ),
                        _buildTextField("Marital Status", _maritalStatusCtrl, Icons.family_restroom, isDark),
                      ],
                    ),
                  ),
                ),
                Step(
                  title: Text('Account & Role', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  content: Form(
                    key: _formKey2,
                    child: Column(
                      children: [
                        _buildTextField("Username *", _usernameCtrl, Icons.alternate_email, isDark, required: true),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Nominee Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField("Nominee Name", _nomineeNameCtrl, Icons.person_outline, isDark),
                        _buildDatePicker("Nominee DOB", _nomineeDobDate, Icons.event, isDark, (d) => setState(() => _nomineeDobDate = d)),
                        _buildTextField("Relation (e.g. Wife, Father)", _nomineeRelationCtrl, Icons.people_outline, isDark),
                      ],
                    ),
                  ),
                ),
                Step(
                  title: Text('Role Details', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                  isActive: _currentStep >= 2,
                  state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                  content: Form(
                    key: _formKey3,
                    child: Column(
                      children: [
                        _buildTextField("License Number *", _licenseNumCtrl, Icons.badge, isDark, required: true),
                        _buildDatePicker("License Expiry", _licenseExpiryDate, Icons.event, isDark, (d) => setState(() => _licenseExpiryDate = d)),
                        _buildDatePicker("Non-Transport Expiry", _nonTransportExpiryDate, Icons.event_busy, isDark, (d) => setState(() => _nonTransportExpiryDate = d)),
                        _buildTextField("Vehicle/License Type (e.g. Heavy, Batch)", _vehicleTypeCtrl, Icons.directions_car, isDark),
                        Row(
                          children: [
                            Expanded(child: _buildTextField("Experience (Years)", _experienceCtrl, Icons.history, isDark, type: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField("Exp at BIT", _expAtBitCtrl, Icons.work_history, isDark, type: TextInputType.number)),
                          ],
                        ),
                        _buildDatePicker("Joining Date", _joiningDate, Icons.calendar_today, isDark, (d) => setState(() => _joiningDate = d)),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _driverStatus.toUpperCase(),
                          items: const [
                            DropdownMenuItem(value: 'AVAILABLE', child: Text('AVAILABLE')),
                            DropdownMenuItem(value: 'ASSIGNED', child: Text('ASSIGNED')),
                            DropdownMenuItem(value: 'ON_TRIP', child: Text('ON_TRIP')),
                            DropdownMenuItem(value: 'ON_LEAVE', child: Text('ON_LEAVE')),
                          ],
                          onChanged: (v) => setState(() => _driverStatus = v!),
                          dropdownColor: surfaceColor,
                          decoration: _inputDecoration("Status", Icons.info_outline, isDark),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _shift.toUpperCase(),
                          items: const [
                            DropdownMenuItem(value: 'MORNING', child: Text('MORNING')),
                            DropdownMenuItem(value: 'AFTERNOON', child: Text('AFTERNOON')),
                            DropdownMenuItem(value: 'NIGHT', child: Text('NIGHT')),
                          ],
                          onChanged: (v) => setState(() => _shift = v!),
                          dropdownColor: surfaceColor,
                          decoration: _inputDecoration("Shift", Icons.schedule, isDark),
                        ),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Emergency Contact", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField("Emergency Name", _emergencyNameCtrl, Icons.contact_emergency, isDark),
                        _buildTextField("Emergency Phone", _emergencyPhoneCtrl, Icons.phone_callback, isDark, type: TextInputType.phone),
                      ],
                    ),
                  ),
                ),
                Step(
                  title: Text('Financial & Bank', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                  isActive: _currentStep >= 3,
                  state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                  content: Form(
                    key: _formKey4,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildTextField("Basic Salary", _salaryBasicCtrl, Icons.payments, isDark, type: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField("Gross Salary", _grossSalaryCtrl, Icons.account_balance_wallet, isDark, type: TextInputType.number)),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(child: _buildTextField("DA", _daCtrl, Icons.trending_up, isDark, type: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField("SA", _saCtrl, Icons.card_membership, isDark, type: TextInputType.number)),
                          ],
                        ),
                        _buildTextField("EPFO Management Cont.", _epfoCtrl, Icons.security, isDark, type: TextInputType.number),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Primary Bank Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField("Bank Name", _bankNameCtrl, Icons.account_balance, isDark),
                        _buildTextField("Account Number", _accNumCtrl, Icons.numbers, isDark, type: TextInputType.number),
                        _buildTextField("IFSC Code", _ifscCtrl, Icons.code, isDark),
                        _buildTextField("Branch Name", _branchCtrl, Icons.store, isDark),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("Sub Bank Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField("Sub Bank Name", _subBankNameCtrl, Icons.account_balance, isDark),
                        _buildTextField("Sub Account Number", _subAccNumCtrl, Icons.numbers, isDark, type: TextInputType.number),
                        _buildTextField("Sub IFSC Code", _subIfscCtrl, Icons.code, isDark),
                        _buildTextField("Sub Branch Name", _subBranchCtrl, Icons.store, isDark),
                      ],
                    ),
                  ),
                ),
                Step(
                  title: Text('Documents', style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                  isActive: _currentStep >= 4,
                  state: _currentStep == 4 ? StepState.editing : StepState.complete,
                  content: Column(
                    children: [
                      _buildDocumentUploader("Driving Licence (Front)", _licenseFrontImage, _existingLicenseFront, (img) => _licenseFrontImage = img, isDark, primaryBlue, surfaceColor),
                      _buildDocumentUploader("Driving Licence (Back)", _licenseBackImage, _existingLicenseBack, (img) => _licenseBackImage = img, isDark, primaryBlue, surfaceColor),
                      _buildDocumentUploader("Aadhaar Card Photo", _aadharImage, _existingAadhar, (img) => _aadharImage = img, isDark, primaryBlue, surfaceColor),
                      _buildDocumentUploader("PAN Card Photo", _panImage, _existingPan, (img) => _panImage = img, isDark, primaryBlue, surfaceColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentUploader(String label, XFile? currentImage, String? existingUrl, Function(XFile?) onPicked, bool isDark, Color primaryBlue, Color surfaceColor) {
    bool hasImage = currentImage != null || existingUrl != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12, style: BorderStyle.solid),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _pickImage(onPicked),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black12 : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: currentImage != null
                        ? Image.file(File(currentImage.path), fit: BoxFit.cover)
                        : existingUrl != null
                            ? Image.network(existingUrl, fit: BoxFit.cover, headers: const {'X-Tunnel-Skip-Anti-Phishing-Page': 'true'}, errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: Colors.grey[400]))
                            : Icon(Icons.description, color: Colors.grey[400], size: 30),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        hasImage ? "Tap to change image" : "Tap to upload image",
                        style: TextStyle(color: primaryBlue, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.upload_file, color: primaryBlue),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
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
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
        validator: required ? (val) => val == null || val.trim().isEmpty ? "Required" : null : null,
        decoration: _inputDecoration(label, icon, isDark),
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
          final date = await CustomDateTimePicker.show(context, initialDate: selectedDate ?? DateTime.now(), showTime: false);
          if (date != null) onPicked(date);
        },
        child: InputDecorator(
          decoration: _inputDecoration(label, icon, isDark),
          child: Text(
            selectedDate != null ? DateFormat('MMM dd, yyyy').format(selectedDate) : 'Select Date',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
