import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';

class FuelPage extends StatefulWidget {
  const FuelPage({super.key});

  @override
  State<FuelPage> createState() => _FuelPageState();
}

class _FuelPageState extends State<FuelPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();
  DateTime _fillingDate = DateTime.now();
  File? _billImage;

  // Data
  List<dynamic> _allBunks = [];
  List<dynamic> _driverVehicles = [];
  Map<String, dynamic>? _selectedBunk;
  Map<String, dynamic>? _selectedVehicle;

  bool _isSubmitting = false;
  bool _isLoadingBunks = false;
  bool _isLoadingVehicles = false;
  bool _isVerifying = false;

  // Verification result
  bool? _billVerified;
  Map<String, dynamic>? _verificationResult;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _fetchBunks();
    _fetchDriverVehicles();
  }

  @override
  void dispose() {
    _animController.dispose();
    _volumeController.dispose();
    _amountController.dispose();
    _odometerController.dispose();
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
      debugPrint("Fuel bunks response status: ${response.statusCode}");
      debugPrint("Fuel bunks response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}");
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> bunks = [];
        if (data is Map && data['data'] != null) {
          bunks = data['data'];
        } else if (data is List) {
          bunks = data;
        }
        debugPrint("Parsed ${bunks.length} fuel bunks");
        setState(() => _allBunks = bunks);
      }
    } catch (e) {
      debugPrint("Error fetching bunks: $e");
    } finally {
      setState(() => _isLoadingBunks = false);
    }
  }

  Future<void> _fetchDriverVehicles() async {
    setState(() => _isLoadingVehicles = true);
    try {
      final token = await UserStore.getToken();
      final userId = await UserStore.getUserId();
      debugPrint("Fetching driver vehicles for user_id: $userId");
      final response = await http.get(
        Uri.parse("${ApiConstants.driverVehicles}?user_id=$userId"),
        headers: ApiConstants.getHeaders(token),
      );
      debugPrint("Driver vehicles response status: ${response.statusCode}");
      debugPrint("Driver vehicles response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}");
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> vehicles = [];
        if (data is Map && data['data'] != null) {
          vehicles = data['data'];
        } else if (data is List) {
          vehicles = data;
        }
        debugPrint("Parsed ${vehicles.length} driver vehicles");
        setState(() => _driverVehicles = vehicles);
      }
    } catch (e) {
      debugPrint("Error fetching driver vehicles: $e");
    } finally {
      setState(() => _isLoadingVehicles = false);
    }
  }

  Future<void> _pickAndVerifyBill() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    setState(() {
      _billImage = file;
      _billVerified = null;
      _verificationResult = null;
    });

    // Only verify if we have the required fields
    if (_selectedBunk != null &&
        _amountController.text.isNotEmpty &&
        _volumeController.text.isNotEmpty) {
      await _verifyBill();
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
      request.fields['volume'] = _volumeController.text;
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
    if (_selectedVehicle == null) {
      _showSnack("Please select a vehicle", Colors.orange);
      return;
    }
    if (_selectedBunk == null) {
      _showSnack("Please select a fuel bunk", Colors.orange);
      return;
    }
    if (_volumeController.text.isEmpty ||
        _amountController.text.isEmpty ||
        _odometerController.text.isEmpty) {
      _showSnack("Please fill all required fields", Colors.orange);
      return;
    }
    if (_billImage == null) {
      _showSnack("Please upload proof document", Colors.orange);
      return;
    }

    // Verify bill if not already verified
    if (_billVerified == null) {
      await _verifyBill();
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await UserStore.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.fuelLog),
      );

      request.headers.addAll({
        'Authorization': token != null ? 'TMS $token' : '',
        'User-Agent': 'insomnia/12.3.0',
        ApiConstants.bypassHeaderKey: ApiConstants.bypassHeaderValue,
      });

      request.fields['vehicle_id'] = _selectedVehicle!['id'].toString();
      request.fields['bunk_id'] = _selectedBunk!['id'].toString();
      request.fields['volume'] = _volumeController.text;
      request.fields['bill_amount'] = _amountController.text;
      request.fields['curr_km'] = _odometerController.text;
      request.fields['filled_at'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(_fillingDate);
      request.fields['isMatches'] = (_billVerified == true) ? 'true' : 'false';

      request.files.add(await http.MultipartFile.fromPath('bill_file', _billImage!.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        _showSnack("Fuel entry submitted successfully!", Colors.green);
        Navigator.pop(context, true);
      } else {
        if (!mounted) return;
        String errorMessage = "Failed to submit fuel entry";
        try {
          final errorData = json.decode(response.body);
          if (errorData['message'] != null) errorMessage = errorData['message'];
        } catch (_) {}
        _showSnack(errorMessage, Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = LanguageStore.isTamil;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const primary = Color(0xFF3B82F6);
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ─── Header ───────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              backgroundColor: bg,
              elevation: 0,
              leading: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white12 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)],
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: titleColor),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                          : [const Color(0xFFEFF6FF), const Color(0xFFF1F5F9)],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -30, top: -30,
                        child: CircleAvatar(radius: 90, backgroundColor: primary.withOpacity(isDark ? 0.08 : 0.06)),
                      ),
                      Positioned(
                        left: -20, bottom: -20,
                        child: CircleAvatar(radius: 60, backgroundColor: primary.withOpacity(isDark ? 0.05 : 0.04)),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: primary.withOpacity(0.25)),
                                ),
                                child: const Icon(Icons.local_gas_station_rounded, color: primary, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isTamil ? "எரிபொருள் பதிவு" : "Fuel Entry",
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: titleColor),
                                  ),
                                  Text(
                                    isTamil ? "இன்றைய நிரப்பல் பதிவு" : "Log today's refuel",
                                    style: TextStyle(fontSize: 13, color: subColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── Form Body ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Vehicle Number
                      _buildSectionCard(
                        icon: Icons.directions_bus_rounded,
                        iconColor: primary,
                        title: isTamil ? "வாகன எண்" : "Vehicle Number",
                        surface: surface,
                        titleColor: titleColor,
                        subColor: subColor,
                        isDark: isDark,
                        children: [
                          _buildSelectionTile(
                            label: isTamil ? "வாகனத்தைத் தேர்ந்தெடுக்கவும்" : "Select Vehicle",
                            hint: _selectedVehicle?['vehicle_number'] ?? (isTamil ? "வாகனத்தைத் தேர்ந்தெடுக்கவும்" : "Choose a vehicle"),
                            icon: Icons.directions_bus_rounded,
                            onTap: () => _showVehiclePicker(),
                            surface: surface,
                            isDark: isDark,
                            isLoading: _isLoadingVehicles,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Bunk Selection
                      _buildSectionCard(
                        icon: Icons.local_gas_station_rounded,
                        iconColor: const Color(0xFF06B6D4),
                        title: isTamil ? "எரிபொருள் பங்க்" : "Fuel Bunk",
                        surface: surface,
                        titleColor: titleColor,
                        subColor: subColor,
                        isDark: isDark,
                        children: [
                          _buildSelectionTile(
                            label: isTamil ? "பங்க் தேர்ந்தெடுக்கவும்" : "Select Bunk",
                            hint: _selectedBunk?['name'] ?? (isTamil ? "பங்க் தேர்ந்தெடுக்கவும்" : "Choose a fuel bunk"),
                            icon: Icons.local_gas_station_rounded,
                            onTap: () => _showBunkPicker(),
                            surface: surface,
                            isDark: isDark,
                            isLoading: _isLoadingBunks,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Volume, Amount, Date, Odometer
                      _buildSectionCard(
                        icon: Icons.opacity_rounded,
                        iconColor: const Color(0xFF06B6D4),
                        title: isTamil ? "நிரப்பல் விவரங்கள்" : "Refuel Details",
                        surface: surface,
                        titleColor: titleColor,
                        subColor: subColor,
                        isDark: isDark,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _formLabel(isTamil ? "அளவு (லிட்டர்)" : "Volume (Ltrs)", titleColor),
                                    const SizedBox(height: 8),
                                    _buildTextField("0.00", Icons.opacity_rounded, isDark, primary,
                                        keyboardType: TextInputType.number, controller: _volumeController),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _formLabel(isTamil ? "மொத்த தொகை" : "Amount (₹)", titleColor),
                                    const SizedBox(height: 8),
                                    _buildTextField("0", Icons.currency_rupee_rounded, isDark, primary,
                                        keyboardType: TextInputType.number, controller: _amountController),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _formLabel(isTamil ? "நிரப்பும் தேதி" : "Filling Date", titleColor),
                                    const SizedBox(height: 8),
                                    _buildDateField(context, isDark, primary, _fillingDate,
                                        (d) => setState(() => _fillingDate = d)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _formLabel(isTamil ? "ஓடோமீட்டர் (KM)" : "Odometer (KM)", titleColor),
                                    const SizedBox(height: 8),
                                    _buildTextField("KM", Icons.speed_rounded, isDark, primary,
                                        keyboardType: TextInputType.number, controller: _odometerController),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Proof Upload with Verification
                      _buildSectionCard(
                        icon: Icons.photo_camera_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        title: isTamil ? "ஆதாரம்" : "Proof Document (Required)",
                        surface: surface,
                        titleColor: titleColor,
                        subColor: subColor,
                        isDark: isDark,
                        children: [
                          _buildProofUpload(primary, isDark, isTamil),
                          if (_isVerifying) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isTamil ? "பில் சரிபார்க்கப்படுகிறது..." : "Verifying bill...",
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black54,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_verificationResult != null && !_isVerifying) ...[
                            const SizedBox(height: 16),
                            _buildVerificationResult(isDark),
                          ],
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: primary.withOpacity(0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 22, width: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      isTamil ? "சமர்ப்பிக்கவும்" : "Submit Fuel Entry",
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Verification Result Card ──────────────────────────────────────
  Widget _buildVerificationResult(bool isDark) {
    final verified = _billVerified == true;
    final matchPct = _verificationResult?['overall_match_percentage'] ?? 0;
    final fieldResults = _verificationResult?['field_results'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: verified
            ? Colors.green.withOpacity(isDark ? 0.12 : 0.06)
            : Colors.orange.withOpacity(isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: verified ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
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
                  color: verified ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
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
          if (fieldResults.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...fieldResults.entries.map((e) {
              final matched = e.value['matched'] == true;
              final similarity = e.value['similarity'] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      matched ? Icons.check_circle_outline : Icons.highlight_off,
                      color: matched ? Colors.green : Colors.red,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.key.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                    Text(
                      "${(similarity is num ? similarity : 0).toStringAsFixed(0)}%",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: matched ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color surface,
    required Color titleColor,
    required Color subColor,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: titleColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Divider(indent: 20, endIndent: 20, color: titleColor.withOpacity(0.06)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionTile({
    required String label,
    required String hint,
    required IconData icon,
    VoidCallback? onTap,
    required Color surface,
    required bool isDark,
    bool isLoading = false,
  }) {
    final hasValue = onTap != null && hint != label;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF3B82F6).withOpacity(0.6), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hint,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                  color: hasValue
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? Colors.white30 : Colors.black38),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isLoading)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _formLabel(String label, Color color) => Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color.withOpacity(0.7)),
      );

  Widget _buildTextField(
    String hint, IconData icon, bool isDark, Color accent, {
    TextInputType? keyboardType,
    TextEditingController? controller,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, color: accent.withOpacity(0.6), size: 20),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent.withOpacity(0.4), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDateField(BuildContext ctx, bool isDark, Color accent, DateTime date, Function(DateTime) onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await CustomDateTimePicker.show(
          ctx,
          initialDate: date,
          minDate: DateTime(2000),
          showTime: true,
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: accent.withOpacity(0.6), size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                DateFormat('dd MMM, hh:mm a').format(date),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProofUpload(Color primary, bool isDark, bool isTamil) {
    return GestureDetector(
      onTap: _pickAndVerifyBill,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: _billImage != null
              ? (_billVerified == true
                  ? Colors.green.withOpacity(0.08)
                  : _billVerified == false
                      ? Colors.orange.withOpacity(0.08)
                      : primary.withOpacity(0.05))
              : primary.withOpacity(isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _billImage != null
                ? (_billVerified == true
                    ? Colors.green.withOpacity(0.4)
                    : _billVerified == false
                        ? Colors.orange.withOpacity(0.4)
                        : primary.withOpacity(0.25))
                : primary.withOpacity(0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _billImage != null
                    ? (_billVerified == true ? Icons.check_circle_rounded : Icons.receipt_long_rounded)
                    : Icons.add_a_photo_rounded,
                key: ValueKey('${_billImage != null}_$_billVerified'),
                color: _billImage != null
                    ? (_billVerified == true ? Colors.green : Colors.orange)
                    : primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _billImage != null
                  ? (isTamil ? "படம் இணைக்கப்பட்டது ✓" : "Bill Image Attached ✓")
                  : (isTamil ? "ஆதாரத்தை சமர்ப்பிக்கவும்" : "Upload Proof Image"),
              style: TextStyle(
                color: _billImage != null
                    ? (_billVerified == true ? Colors.green : Colors.orange)
                    : primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _billImage != null
                  ? _billImage!.path.split('/').last
                  : (isTamil ? "JPEG அல்லது PNG (அதிகபட்சம் 5MB)" : "JPEG or PNG  •  Max 5 MB"),
              style: TextStyle(
                color: _billImage != null ? Colors.grey : Colors.grey,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (_billImage != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() {
                  _billImage = null;
                  _billVerified = null;
                  _verificationResult = null;
                }),
                icon: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
                label: Text(
                  isTamil ? "நீக்கு" : "Remove",
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Pickers ──────────────────────────────────────────────────────────

  void _showVehiclePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPickerSheet(
        title: "Select Vehicle",
        items: _driverVehicles,
        nameKey: 'vehicle_number',
        subtitleKey: 'vehicle_type',
        icon: Icons.directions_bus_rounded,
        iconColor: const Color(0xFF3B82F6),
        selectedId: _selectedVehicle?['id'],
        onSelect: (item) => setState(() => _selectedVehicle = item),
      ),
    );
  }

  void _showBunkPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPickerSheet(
        title: "Select Fuel Bunk",
        items: _allBunks,
        nameKey: 'name',
        subtitleKey: 'address',
        icon: Icons.local_gas_station_rounded,
        iconColor: const Color(0xFF06B6D4),
        selectedId: _selectedBunk?['id'],
        onSelect: (item) => setState(() => _selectedBunk = item),
      ),
    );
  }

  Widget _buildPickerSheet({
    required String title,
    required List<dynamic> items,
    required String nameKey,
    required String subtitleKey,
    required IconData icon,
    required Color iconColor,
    dynamic selectedId,
    required Function(Map<String, dynamic>) onSelect,
  }) {
    final searchCtrl = TextEditingController();
    List<dynamic> filtered = List.from(items);

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, -10))],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.grey)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (val) {
                    setModalState(() {
                      filtered = items.where((i) =>
                          (i[nameKey] ?? '').toString().toLowerCase().contains(val.toLowerCase())).toList();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Search...",
                    prefixIcon: Icon(Icons.search_rounded, color: iconColor),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text("No records found", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 70, color: Colors.black12),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isSelected = selectedId == item['id'];
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: iconColor, size: 22),
                            ),
                            title: Text(item[nameKey] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: item[subtitleKey] != null
                                ? Text(item[subtitleKey].toString(), style: const TextStyle(fontSize: 12, color: Colors.grey))
                                : null,
                            trailing: isSelected
                                ? Icon(Icons.check_circle_rounded, color: iconColor)
                                : null,
                            onTap: () {
                              onSelect(Map<String, dynamic>.from(item));
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
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(
            color == Colors.green ? Icons.check_circle_rounded
                : color == Colors.orange ? Icons.warning_rounded : Icons.error_rounded,
            color: Colors.white, size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }
}
