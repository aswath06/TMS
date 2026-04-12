import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';

class VehicleFuelEntryPage extends StatefulWidget {
  final dynamic vehicleId;
  final String vehicleNumber;

  const VehicleFuelEntryPage({
    super.key,
    required this.vehicleId,
    required this.vehicleNumber,
  });

  @override
  State<VehicleFuelEntryPage> createState() => _VehicleFuelEntryPageState();
}

class _VehicleFuelEntryPageState extends State<VehicleFuelEntryPage> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final TextEditingController _currentKmController = TextEditingController();
  final TextEditingController _litersController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _indentNumberController = TextEditingController();
  DateTime? _fillingDate;
  File? _billImage;

  // Bunk Data
  List<dynamic> _allBunks = [];
  Map<String, dynamic>? _selectedBunk;
  bool _isLoadingBunks = false;
  bool _isSubmitting = false;

  // Verification
  bool _isVerifying = false;
  bool? _billVerified;
  Map<String, dynamic>? _verificationResult;

  @override
  void initState() {
    super.initState();
    _fetchBunks();
  }

  @override
  void dispose() {
    _currentKmController.dispose();
    _litersController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    _indentNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchBunks() async {
    setState(() => _isLoadingBunks = true);
    try {
      final token = await UserStore.getToken();
      final response = await http.get(
        Uri.parse(ApiConstants.fuelBunks),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() => _allBunks = data['data'] ?? []);
        }
      }
    } catch (e) {
      debugPrint("Error fetching bunks: $e");
    } finally {
      setState(() => _isLoadingBunks = false);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false, 











































      
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _billImage = File(result.files.single.path!);
        _billVerified = null;
        _verificationResult = null;
      });
      // Auto verify if fields are filled
      if (_selectedBunk != null && 
          _amountController.text.isNotEmpty && 
          _litersController.text.isNotEmpty) {
        _verifyBill();
      }
    }
  }

  Future<void> _verifyBill() async {
    if (_billImage == null || _selectedBunk == null) return;

    setState(() => _isVerifying = true);

    try {
      final token = await UserStore.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.verifyFuelBill),
      );

      request.headers.addAll({
        'Authorization': token != null ? 'TMS $token' : '',
        'User-Agent': 'insomnia/12.3.0',
        ApiConstants.bypassHeaderKey: ApiConstants.bypassHeaderValue,
      });

      request.files.add(await http.MultipartFile.fromPath('bill_image', _billImage!.path));
      request.fields['bill_amount'] = _amountController.text;
      request.fields['volume'] = _litersController.text;
      request.fields['bunk_name'] = _selectedBunk!['name'] ?? '';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _billVerified = data['verified'] == true;
          _verificationResult = data;
        });
      } else {
        setState(() {
          _billVerified = false;
          _verificationResult = null;
        });
      }
    } catch (e) {
      debugPrint("Error verifying bill: $e");
      setState(() {
        _billVerified = false;
        _verificationResult = null;
      });
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBunk == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a fuel bunk")),
      );
      return;
    }
    if (_fillingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select filling date")),
      );
      return;
    }

    // Verify bill if not already verified
    if (_billVerified == null && _billImage != null) {
      await _verifyBill();
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await UserStore.getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.fuelLog),
      );

      // Set headers (without Content-Type, multipart sets it automatically)
      request.headers.addAll({
        'Authorization': token != null ? 'TMS $token' : '',
        'User-Agent': 'insomnia/12.3.0',
        ApiConstants.bypassHeaderKey: ApiConstants.bypassHeaderValue,
      });

      final userId = await UserStore.getUserId();
      final instanceId = DateFormat('yyyy/MM/dd').format(_fillingDate!);

      // Add form fields
      request.fields['instance_id'] = instanceId;
      request.fields['vehicle_id'] = widget.vehicleId.toString();
      request.fields['bunk_id'] = _selectedBunk!['id'].toString();
      request.fields['filled_by_user_id'] = userId?.toString() ?? "";
      request.fields['volume'] = _litersController.text;
      request.fields['bill_amount'] = _amountController.text;
      request.fields['current_odometer'] = _currentKmController.text;
      request.fields['filled_at'] = DateFormat('yyyy-MM-ddTHH:mm:ss').format(_fillingDate!);
      request.fields['isMatches'] = (_billVerified == true) ? 'true' : 'false';
      request.fields['remarks'] = _remarksController.text.isNotEmpty ? _remarksController.text : "Admin created fuel log for driver";
      request.fields['indent_number'] = _indentNumberController.text;

      // Add bill image if selected
      if (_billImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('bill_file', _billImage!.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fuel entry logged successfully")),
        );
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        String errorMessage = "Failed to log fuel entry";
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    const primaryBlue = Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Fuel Entry", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVehicleInfo(primaryBlue),
              const SizedBox(height: 24),
              _buildBunkSelector(surfaceColor),
              const SizedBox(height: 24),
              _buildSectionTitle("Fuel Details"),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _currentKmController,
                label: "Current Odometer (KM)",
                icon: Icons.speed_outlined,
                keyboardType: TextInputType.number,
                surfaceColor: surfaceColor,
                validator: (v) => v!.isEmpty ? "Enter current KM" : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _litersController,
                label: "Liters",
                icon: Icons.water_drop_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                surfaceColor: surfaceColor,
                validator: (v) => v!.isEmpty ? "Enter liters" : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _amountController,
                label: "Amount (₹)",
                icon: Icons.payments_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                surfaceColor: surfaceColor,
                validator: (v) => v!.isEmpty ? "Enter amount" : null,
              ),
              const SizedBox(height: 16),
              _buildDatePicker(surfaceColor, isDark),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _indentNumberController,
                label: "Indent Number",
                icon: Icons.numbers_rounded,
                surfaceColor: surfaceColor,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _remarksController,
                label: "Remarks",
                icon: Icons.comment_rounded,
                surfaceColor: surfaceColor,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _buildImagePicker(surfaceColor, isDark),
              if (_isVerifying) ...[
                const SizedBox(height: 16),
                const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text("Verifying bill...", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              if (_verificationResult != null && !_isVerifying) ...[
                const SizedBox(height: 16),
                _buildVerificationResult(isDark),
              ],
              const SizedBox(height: 40),
              _buildSubmitButton(primaryBlue),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleInfo(Color primary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.local_gas_station_rounded, color: primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.vehicleNumber,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const Text(
                  "Logging new fuel entry",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBunkSelector(Color surfaceColor) {
    return InkWell(
      onTap: () => _showBunkPicker(),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_gas_station_outlined, color: Color(0xFF3B82F6), size: 24),
            ),
            const SizedBox(width: 16),
// ...
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select Fuel Bunk",
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedBunk?['name'] ?? "Choose a fuel bunk",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _selectedBunk != null ? null : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_isLoadingBunks)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required Color surfaceColor,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDatePicker(Color surfaceColor, bool isDark) {
    return InkWell(
      onTap: () async {
        final picked = await CustomDateTimePicker.show(
          context,
          initialDate: _fillingDate ?? DateTime.now(),
          showTime: true,
        );
        if (picked != null) {
          setState(() => _fillingDate = picked);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_month_outlined, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 16),
// ...
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Filling Date & Time",
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _fillingDate == null
                      ? "Select Date & Time"
                      : DateFormat('dd MMM yyyy, hh:mm a').format(_fillingDate!),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _fillingDate != null ? null : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(Color surfaceColor, bool isDark) {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _billImage != null
                ? const Color(0xFF10B981).withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: _billImage != null
            ? Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _billImage!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Bill Uploaded",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _billImage!.path.split('/').last,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _billImage = null),
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFF3B82F6),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Upload Bill Image",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Tap to select from gallery",
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.add_photo_alternate_outlined, size: 22, color: Colors.grey.shade400),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildSubmitButton(Color primary) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "SUBMIT FUEL RECORD",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.1,
                ),
              ),
      ),
    );
  }

  Widget _buildShimmerList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white10 : Colors.grey[300]!,
      highlightColor: isDark ? Colors.white24 : Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: double.infinity, height: 16, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: 150, height: 12, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBunkPicker() {
    final TextEditingController searchController = TextEditingController();
    List<dynamic> filteredBunks = List.from(_allBunks);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Select Fuel Bunk",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: searchController,
                    onChanged: (val) {
                      setModalState(() {
                        filteredBunks = _allBunks
                            .where((b) => (b['name'] ?? '')
                                .toString()
                                .toLowerCase()
                                .contains(val.toLowerCase()))
                            .toList();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search fuel bunks...",
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF3B82F6)),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                searchController.clear();
                                setModalState(() {
                                  filteredBunks = List.from(_allBunks);
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.04),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoadingBunks
                      ? _buildShimmerList()
                      : filteredBunks.isEmpty
                          ? const Center(
                              child: Text(
                                "No bunks found",
                                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredBunks.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                indent: 70,
                                color: Colors.black12,
                              ),
                              itemBuilder: (context, index) {
                                final bunk = filteredBunks[index];
                                final isSelected = _selectedBunk?['id'] == bunk['id'];
                                return ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.local_gas_station_rounded,
                                      color: Color(0xFF3B82F6),
                                      size: 22,
                                    ),
                                  ),
                                  title: Text(
                                    bunk['name'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bunk['address'] ?? '',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      if (bunk['owner_name'] != null)
                                        Text(
                                          "Owner: ${bunk['owner_name']}",
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF3B82F6),
                                        )
                                      : null,
                                  onTap: () {
                                    setState(() => _selectedBunk = bunk);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerificationResult(bool isDark) {
    final verified = _billVerified == true;
    final matchPct = _verificationResult?['overall_match_percentage'] ?? 0;
    final fieldResults = _verificationResult?['field_results'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: verified
            ? Colors.green.withValues(alpha: isDark ? 0.12 : 0.06)
            : Colors.orange.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: verified ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                verified ? Icons.verified_rounded : Icons.warning_amber_rounded,
                color: verified ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  verified ? "Bill Verified ✓" : "Bill Verification Warning",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: verified ? Colors.green : Colors.orange,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: verified ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${matchPct.toStringAsFixed(0)}% Match",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: verified ? Colors.green : Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (!verified) ...[
            if (fieldResults.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  "Could not extract bill details for comparison.",
                  style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              )
            else ...[
              const SizedBox(height: 12),
              ...fieldResults.entries.map((e) {
              final matched = e.value['matched'] == true;
              final similarity = e.value['similarity'] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      matched ? Icons.check_circle_outline : Icons.highlight_off,
                      color: matched ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (!matched)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                "Input: ${e.value['input']} | Extracted: ${e.value['extracted']}",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${(similarity is num ? similarity : 0).toStringAsFixed(0)}%",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: matched ? Colors.green : Colors.red,
                          ),
                        ),
                        if (!matched)
                          Text(
                            "MISMATCH",
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.red.withOpacity(0.6),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ]
        ],
      ],
    ),
  );
}
}
