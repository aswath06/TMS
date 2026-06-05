import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/store/VehicleStore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';

class ServicePage extends ConsumerStatefulWidget {
  const ServicePage({super.key});

  @override
  ConsumerState<ServicePage> createState() => _ServicePageState();
}

class _ServicePageState extends ConsumerState<ServicePage> with SingleTickerProviderStateMixin {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();
  String? _selectedVehicle;
  String? _selectedShop;
  String? _proofPath;
  DateTime _date = DateTime.now();
  bool _isSubmitting = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driverStoreProvider).fetchServiceShops();
      ref.read(vehicleStoreProvider).fetchVehicles(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _topicController.dispose();
    _descController.dispose();
    _costController.dispose();
    _odometerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driverStore = ref.watch(driverStoreProvider);
    final vehicleStore = ref.watch(vehicleStoreProvider);
    final isTamil = LanguageStore.isTamil;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const primary = Color(0xFF10B981); // Emerald
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
                          : [const Color(0xFFECFDF5), const Color(0xFFF1F5F9)],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -30,
                        top: -30,
                        child: CircleAvatar(
                          radius: 90,
                          backgroundColor: primary.withOpacity(isDark ? 0.08 : 0.07),
                        ),
                      ),
                      Positioned(
                        left: -20,
                        bottom: -20,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: primary.withOpacity(isDark ? 0.05 : 0.04),
                        ),
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
                                child: const Icon(Icons.home_repair_service_rounded, color: primary, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isTamil ? "சேவை பதிவு" : "Service Entry",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: titleColor,
                                    ),
                                  ),
                                  Text(
                                    isTamil ? "பராமரிப்பு பதிவை சேர்க்கவும்" : "Log a maintenance record",
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
                child: Column(
                  children: [
                    // Vehicle & Shop
                    _buildSectionCard(
                      icon: Icons.directions_bus_rounded,
                      iconColor: primary,
                      title: isTamil ? "வாகன விவரங்கள்" : "Vehicle Details",
                      surface: surface,
                      titleColor: titleColor,
                      isDark: isDark,
                      children: [
                        _formLabel(isTamil ? "வாகன எண்" : "Vehicle Number", titleColor),
                        const SizedBox(height: 8),
                        _buildDropdown(
                          isTamil ? "வாகனத்தைத் தேர்ந்தெடுக்கவும்" : "Select Vehicle",
                          Icons.directions_bus_rounded,
                          isDark, primary,
                          value: _selectedVehicle,
                          items: vehicleStore.filteredVehicles.map((v) => v['vehicle_number'].toString()).toList(),
                          onChanged: (val) => setState(() => _selectedVehicle = val),
                        ),
                        const SizedBox(height: 18),
                        _formLabel(isTamil ? "சேவை கடை" : "Service Shop", titleColor),
                        const SizedBox(height: 8),
                        _buildDropdown(
                          isTamil ? "கடையைத் தேர்ந்தெடுக்கவும் (விருப்பம்)" : "Select Shop (Optional)",
                          Icons.home_repair_service_rounded,
                          isDark, primary,
                          value: _selectedShop,
                          items: driverStore.serviceShops.map((s) => s['shop_name'].toString()).toList(),
                          onChanged: (val) => setState(() => _selectedShop = val),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Topic & Description
                    _buildSectionCard(
                      icon: Icons.build_circle_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      title: isTamil ? "சேவை விவரங்கள்" : "Service Details",
                      surface: surface,
                      titleColor: titleColor,
                      isDark: isDark,
                      children: [
                        _formLabel(isTamil ? "சேவை தலைப்பு" : "Service Topic", titleColor),
                        const SizedBox(height: 8),
                        _buildTextField(
                          isTamil ? "எ.கா. இன்ஜின் ஆயில் மாற்றம்" : "e.g. Engine Oil Change",
                          Icons.topic_rounded,
                          isDark, primary,
                          controller: _topicController,
                        ),
                        const SizedBox(height: 18),
                        _formLabel(isTamil ? "விளக்கம்" : "Description", titleColor),
                        const SizedBox(height: 8),
                        _buildTextField(
                          isTamil ? "செய்யப்பட்ட வேலையின் விரிவான குறிப்புகள்..." : "Detailed notes on work done...",
                          Icons.description_rounded,
                          isDark, primary,
                          maxLines: 3,
                          controller: _descController,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Date, Cost, Odometer
                    _buildSectionCard(
                      icon: Icons.receipt_long_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      title: isTamil ? "செலவு மற்றும் தேதி" : "Cost & Date",
                      surface: surface,
                      titleColor: titleColor,
                      isDark: isDark,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _formLabel(isTamil ? "தேதி" : "Service Date", titleColor),
                                  const SizedBox(height: 8),
                                  _buildDateField(context, isDark, primary, _date, (d) => setState(() => _date = d)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _formLabel(isTamil ? "செலவு (₹)" : "Cost (₹)", titleColor),
                                  const SizedBox(height: 8),
                                  _buildTextField("0", Icons.currency_rupee_rounded, isDark, primary,
                                      keyboardType: TextInputType.number, controller: _costController),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _formLabel(isTamil ? "ஓடோமீட்டர் (KM)" : "Current Odometer (KM)", titleColor),
                        const SizedBox(height: 8),
                        _buildTextField("KM", Icons.speed_rounded, isDark, primary,
                            keyboardType: TextInputType.number, controller: _odometerController),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Proof Upload
                    _buildSectionCard(
                      icon: Icons.photo_camera_rounded,
                      iconColor: const Color(0xFFEC4899),
                      title: isTamil ? "ஆதாரம்" : "Proof Document",
                      surface: surface,
                      titleColor: titleColor,
                      isDark: isDark,
                      children: [
                        _buildProofUpload(primary, isDark, isTamil),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    isTamil ? "சமர்ப்பிக்கவும்" : "Submit Service Entry",
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
          ],
        ),
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
                Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: titleColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Divider(indent: 20, endIndent: 20, color: titleColor.withOpacity(0.06)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }

  Widget _formLabel(String label, Color color) => Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color.withOpacity(0.7)),
      );

  Widget _buildTextField(
    String hint,
    IconData icon,
    bool isDark,
    Color accent, {
    TextInputType? keyboardType,
    int maxLines = 1,
    TextEditingController? controller,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
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

  Widget _buildDropdown(
    String hint,
    IconData icon,
    bool isDark,
    Color accent, {
    String? value,
    List<String>? items,
    Function(String?)? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items?.contains(value) == true ? value : null,
          hint: Row(
            children: [
              Icon(icon, color: accent.withOpacity(0.5), size: 20),
              const SizedBox(width: 12),
              Text(hint, style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 14)),
            ],
          ),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: accent.withOpacity(0.5)),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          items: items
              ?.map((item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
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
          showTime: false,
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
                DateFormat('dd MMM yyyy').format(date),
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.w600),
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
      onTap: () async {
        final picker = ImagePicker();
        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          setState(() => _proofPath = image.path);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: _proofPath != null
              ? Colors.green.withOpacity(0.08)
              : primary.withOpacity(isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _proofPath != null ? Colors.green.withOpacity(0.4) : primary.withOpacity(0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _proofPath != null ? Icons.check_circle_rounded : Icons.add_a_photo_rounded,
                key: ValueKey(_proofPath != null),
                color: _proofPath != null ? Colors.green : primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _proofPath != null
                  ? (isTamil ? "படம் இணைக்கப்பட்டது ✓" : "Image Attached ✓")
                  : (isTamil ? "ஆதாரத்தை சமர்ப்பிக்கவும்" : "Upload Proof Image"),
              style: TextStyle(
                color: _proofPath != null ? Colors.green : primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _proofPath != null
                  ? _proofPath!.split('/').last
                  : (isTamil ? "JPEG அல்லது PNG (அதிகபட்சம் 5MB)" : "JPEG or PNG  •  Max 5 MB"),
              style: TextStyle(
                color: _proofPath != null ? Colors.green.withOpacity(0.7) : Colors.grey,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (_proofPath != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _proofPath = null),
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

  Future<void> _submit() async {
    if (_selectedVehicle == null ||
        _topicController.text.isEmpty ||
        _costController.text.isEmpty ||
        _odometerController.text.isEmpty) {
      _showSnack(
        LanguageStore.isTamil ? "கட்டாய புலங்களை நிரப்பவும்" : "Please fill all mandatory fields",
        Colors.orange,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final isTamil = LanguageStore.isTamil;

    final data = {
      "vehicle_number": _selectedVehicle,
      "service_shop": _selectedShop,
      "topic": _topicController.text,
      "description": _descController.text,
      "cost": _costController.text,
      "odometer": _odometerController.text,
      "date": _date.toIso8601String(),
    };

    final result = await ref.read(driverStoreProvider).submitServiceEntry(data, _proofPath);
    setState(() => _isSubmitting = false);

    if (result['success']) {
      _showSnack(isTamil ? "வெற்றிகரமாக சமர்ப்பிக்கப்பட்டது!" : "Entry submitted successfully!", Colors.green);
      if (mounted) Navigator.pop(context);
    } else {
      _showSnack(result['message'], Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(
            color == Colors.green ? Icons.check_circle_rounded : color == Colors.orange ? Icons.warning_rounded : Icons.error_rounded,
            color: Colors.white,
            size: 18,
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
