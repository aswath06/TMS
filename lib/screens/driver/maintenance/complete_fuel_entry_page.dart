import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/utils/toast_utils.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';

class CompleteFuelEntryPage extends StatefulWidget {
  final Map<String, dynamic> entry;

  const CompleteFuelEntryPage({super.key, required this.entry});

  @override
  State<CompleteFuelEntryPage> createState() => _CompleteFuelEntryPageState();
}

class _CompleteFuelEntryPageState extends State<CompleteFuelEntryPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _volumeController = TextEditingController();
  DateTime _filledAt = DateTime.now();
  File? _billImage;

  bool _isSubmitting = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack))
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _odometerController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    
    if (image == null) return;

    final file = File(image.path);
    final compressedFile = await _compressImage(file);
    
    if (mounted) {
      setState(() {
        _billImage = compressedFile;
      });
    }
  }

  Future<File?> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/compressed_fuel_bill_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      path,
      quality: 70,
    );
    
    return result != null ? File(result.path) : null;
  }

  void _showImagePickerOptions() {
    final isTamil = LanguageStore.isTamil;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)],
        ),
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
            ),
            Text(
              isTamil ? "ஆதாரத்தைத் தேர்ந்தெடுக்கவும்" : "Select Proof Source",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPickerOption(
                  icon: Icons.camera_alt_rounded,
                  label: isTamil ? "கேமரா" : "Camera",
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildPickerOption(
                  icon: Icons.photo_library_rounded,
                  label: isTamil ? "கேலரி" : "Gallery",
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_billImage == null) {
      showTopToast(context, LanguageStore.isTamil ? "பில் படத்தை பதிவேற்றவும்" : "Please upload bill image", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await useDriverStore.completeFuelEntry(
      fuelLogId: widget.entry['id'],
      vehicleId: widget.entry['vehicle_id'],
      driverId: widget.entry['driver_id'],
      currentOdometer: _odometerController.text,
      filledVolume: _volumeController.text,
      billAmount: "0", // Amount removed as per user request
      filledAt: _filledAt.toIso8601String(),
      billFilePath: _billImage?.path,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      showTopToast(context, result['message'], isError: !result['success']);
      if (result['success']) {
        if (result['mileage_data'] != null) {
          _showMileagePopup(result['mileage_data']);
        } else {
          Navigator.pop(context, true);
        }
      }
    }
  }

  void _showMileagePopup(Map<String, dynamic> mileageData) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final isTamil = LanguageStore.isTamil;

    final double nowMileage = (mileageData['now_mileage'] ?? 0).toDouble();
    final double lastMileage = (mileageData['last_mileage'] ?? 0).toDouble();
    final String status = mileageData['status'] ?? "N/A";
    final String message = mileageData['message'] ?? "";

    IconData statusIcon = Icons.info_outline_rounded;
    Color statusColor = Colors.grey;
    if (status == 'INCREASED') {
      statusIcon = Icons.trending_up_rounded;
      statusColor = Colors.green;
    } else if (status == 'DECREASED') {
      statusIcon = Icons.trending_down_rounded;
      statusColor = Colors.red;
    } else if (status == 'SAME') {
      statusIcon = Icons.trending_flat_rounded;
      statusColor = Colors.blue;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  isTamil ? "மைலேஜ் தரவு" : "Mileage Report",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMileageStat(
                      label: isTamil ? "முந்தைய" : "Last",
                      value: lastMileage.toStringAsFixed(1),
                      isDark: isDark,
                      color: Colors.grey,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    _buildMileageStat(
                      label: isTamil ? "தற்போதைய" : "Current",
                      value: nowMileage.toStringAsFixed(1),
                      isDark: isDark,
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (message.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context, true); // Pop the complete_fuel_entry_page
                    },
                    child: Text(
                      isTamil ? "மூடு" : "Close",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMileageStat({required String label, required String value, required bool isDark, required Color color}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              "km/l",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = LanguageStore.isTamil;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const primary = Color(0xFF6366F1);
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final vehicleNumber = widget.entry['vehicle']?['vehicle_number'] ?? "N/A";
    final driverName = widget.entry['driver']?['user']?['name'] ?? "N/A";
    final instanceId = widget.entry['instance_id'] ?? "N/A";
    final bunkName = widget.entry['bunk']?['name'] ?? "N/A";

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark, primary),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(context, titleColor, primary, isTamil),
                          const SizedBox(height: 32),
                        // Premium Info Section
                        _buildInfoSection(isTamil, surface, titleColor, subColor, vehicleNumber, driverName, bunkName, instanceId, isDark),
                        const SizedBox(height: 32),
                        
                        // Input Section Title
                        Row(
                          children: [
                            Container(width: 4, height: 24, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 12),
                            Text(
                              isTamil ? "விவரங்களை உள்ளிடவும்" : "Filling Details",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: titleColor, letterSpacing: -0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        _buildTextField(
                          controller: _odometerController,
                          label: isTamil ? "ஓடோமீட்டர் (KM)" : "Current Odometer (KM)",
                          hintText: "E.g. 15000",
                          icon: Icons.speed_rounded,
                          keyboardType: TextInputType.number,
                          isDark: isDark,
                          accent: primary,
                        ),
                        const SizedBox(height: 20),
                        
                        _buildTextField(
                          controller: _volumeController,
                          label: isTamil ? "நிரப்பப்பட்ட அளவு (லிட்டர்)" : "Filled Volume (Ltrs)",
                          hintText: "E.g. 40.5",
                          icon: Icons.opacity_rounded,
                          keyboardType: TextInputType.number,
                          isDark: isDark,
                          accent: primary,
                        ),
                        const SizedBox(height: 20),
                        
                        _buildDateField(context, isDark, primary, _filledAt, (date) => setState(() => _filledAt = date)),
                        const SizedBox(height: 32),
                        
                        // Bill Upload
                        _buildUploadSection(isTamil, isDark, primary, titleColor, subColor),
                        const SizedBox(height: 48),
                        
                        // Premium Submit Button
                        Container(
                          width: double.infinity,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        isTamil ? "பதிவைப் பூர்த்தி செய்யவும்" : "Complete Log",
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                      ),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.arrow_forward_rounded, size: 20),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(bool isTamil, Color surface, Color titleColor, Color subColor, String vehicle, String driver, String bunk, String instance, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(color: titleColor.withValues(alpha: 0.03)),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: subColor),
                const SizedBox(width: 10),
                Text(
                  isTamil ? "ஒதுக்கீட்டு சுருக்கம்" : "Assignment Summary",
                  style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              children: [
                _buildInfoRow(isTamil ? "வாகன எண்" : "Vehicle Number", vehicle, titleColor, subColor, Icons.directions_bus_rounded),
                _buildInfoRow(isTamil ? "ஓட்டுநர்" : "Driver Name", driver, titleColor, subColor, Icons.person_rounded),
                _buildInfoRow(isTamil ? "பங்க் பெயர்" : "Bunk Name", bunk, titleColor, subColor, Icons.local_gas_station_rounded),
                _buildInfoRow(isTamil ? "நிகழ்வு ஐடி" : "Instance ID", instance, titleColor, subColor, Icons.tag_rounded, isLast: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color titleColor, Color subColor, IconData icon, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: titleColor.withValues(alpha: 0.05), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: subColor.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: subColor.withValues(alpha: 0.6)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w700)),
                Text(value, style: TextStyle(color: titleColor, fontSize: 15, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(BuildContext ctx, bool isDark, Color accent, DateTime date, Function(DateTime) onPicked) {
    final isTamil = LanguageStore.isTamil;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            isTamil ? "நிரப்பப்பட்ட நேரம்" : "Filled Date & Time",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor(isDark)),
          ),
        ),
        InkWell(
          onTap: () async {
            final picked = await CustomDateTimePicker.show(
              ctx,
              initialDate: date,
              minDate: DateTime(2020),
              maxDate: DateTime.now(),
              showTime: true,
              accent: accent,
            );
            if (picked != null) onPicked(picked);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.1), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 22, color: accent),
                const SizedBox(width: 16),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(date),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                const Spacer(),
                Icon(Icons.edit_calendar_rounded, size: 20, color: accent.withValues(alpha: 0.4)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color titleColor(bool isDark) => isDark ? Colors.white : const Color(0xFF0F172A);

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required bool isDark,
    required Color accent,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor(isDark)),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 22, color: accent.withValues(alpha: 0.7)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
            hintText: hintText,
            hintStyle: TextStyle(color: titleColor(isDark).withValues(alpha: 0.3), fontWeight: FontWeight.normal),
            contentPadding: const EdgeInsets.all(20),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: accent.withValues(alpha: 0.3), width: 2),
            ),
          ),
          validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
        ),
      ],
    );
  }
  // --- Helpers ---
  Widget _buildHeader(BuildContext context, Color titleColor, Color primaryBlue, bool isTamil) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back_ios,
                      size: 18,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isTamil ? "பராமரிப்பு" : "MAINTENANCE",
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w900,
                        color: primaryBlue,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isTamil ? "எரிபொருள் பதிவு" : "Fuel Entry",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: titleColor.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.local_gas_station_rounded,
            color: titleColor.withValues(alpha: 0.6),
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundDecor(bool isDark, Color primaryBlue) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: primaryBlue.withValues(alpha: isDark ? 0.1 : 0.05),
            ),
          ),
          Positioned(
            bottom: 0,
            left: -50,
            child: CircleAvatar(
              radius: 120,
              backgroundColor: const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.08 : 0.04),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection(bool isTamil, bool isDark, Color primary, Color titleColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            isTamil ? "பில் பதிவேற்றம்" : "Bill Attachment",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor),
          ),
        ),
        GestureDetector(
          onTap: _showImagePickerOptions,
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _billImage != null ? primary.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.2),
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _billImage != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(_billImage!, fit: BoxFit.cover),
                      Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.4), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
                      Positioned(
                        right: 12, top: 12,
                        child: GestureDetector(
                          onTap: () => setState(() => _billImage = null),
                          child: CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 16,
                            child: const Icon(Icons.close_rounded, color: Colors.red, size: 20),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16, bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                              const SizedBox(width: 6),
                              Text(isTamil ? "பதிவேற்றப்பட்டது" : "Attached", style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: primary.withValues(alpha: 0.05), shape: BoxShape.circle),
                        child: Icon(Icons.cloud_upload_outlined, size: 36, color: primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isTamil ? "பதிவேற்ற இங்கே கிளிக் செய்யவும்" : "Click to attach fuel bill",
                        style: TextStyle(color: subColor, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isTamil ? "கேமரா அல்லது கேலரி" : "Camera or Photo Library",
                        style: TextStyle(color: subColor.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
