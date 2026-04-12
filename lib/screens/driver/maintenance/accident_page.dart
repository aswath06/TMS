import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/store/VehicleStore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';
import 'package:tripzo/components/single_location_selector.dart';

class AccidentPage extends StatefulWidget {
  const AccidentPage({super.key});

  @override
  State<AccidentPage> createState() => _AccidentPageState();
}

class _AccidentPageState extends State<AccidentPage> with SingleTickerProviderStateMixin {
  final TextEditingController _natureController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _actionTakenController = TextEditingController();
  
  Map<String, dynamic>? _selectedVehicleMap;
  Map<String, dynamic>? _selectedLocationMap;
  String? _ownVehicleDamage;
  String? _oppositeVehicleDamage;
  String? _proofPath;
  DateTime _incidentDateTime = DateTime.now();
  bool _isSubmitting = false;

  bool _policeCaseFiled = true;
  bool _majorCausality = false;
  bool _insuranceClaim = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;


  final List<Map<String, String>> _damageLevels = [
    {"label": "Major Accident", "value": "MAJOR_ACCIDENT"},
    {"label": "Minor Accident", "value": "MINOR_ACCIDENT"},
    {"label": "No Issues", "value": "NO_ISSUES"},
  ];

  final List<Map<String, String>> _damageLevelsTamil = [
    {"label": "பெரிய விபத்து", "value": "MAJOR_ACCIDENT"},
    {"label": "சிறிய விபத்து", "value": "MINOR_ACCIDENT"},
    {"label": "பிரச்சனைகள் இல்லை", "value": "NO_ISSUES"},
  ];
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    
    _actionTakenController.text = "Police informed and vehicle moved to roadside";
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleStore>().fetchVehicles(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _natureController.dispose();
    _placeController.dispose();
    _odometerController.dispose();
    _actionTakenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicleStore = context.watch<VehicleStore>();
    final isTamil = LanguageStore.isTamil;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const primary = Color(0xFFEF4444); // Red for Accident
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
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
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
                          : [const Color(0xFFFFEBEB), const Color(0xFFF1F5F9)],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -30, top: -30,
                        child: CircleAvatar(radius: 90, backgroundColor: primary.withValues(alpha: isDark ? 0.08 : 0.07)),
                      ),
                      Positioned(
                        left: -20, bottom: -20,
                        child: CircleAvatar(radius: 60, backgroundColor: primary.withValues(alpha: isDark ? 0.05 : 0.04)),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: primary.withValues(alpha: 0.25)),
                                ),
                                child: const Icon(Icons.report_problem_rounded, color: primary, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isTamil ? "விபத்து பதிவு" : "Accident Entry",
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: titleColor),
                                  ),
                                  Text(
                                    isTamil ? "சம்பவ விவரங்களைச் சேர்க்கவும்" : "Log incident details",
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
                    // Incident Details
                    _buildSectionCard(
                      icon: Icons.directions_bus_rounded,
                      iconColor: primary,
                      title: isTamil ? "சம்பவ விவரங்கள்" : "Incident Details",
                      surface: surface,
                      titleColor: titleColor,
                      isDark: isDark,
                      children: [
                        _formLabel(isTamil ? "வாகன எண்" : "Vehicle Number", titleColor),
                        const SizedBox(height: 8),
                        _buildSelectionTile(
                          label: isTamil ? "வாகனத்தைத் தேர்ந்தெடுக்கவும்" : "Select Vehicle",
                          hint: _selectedVehicleMap?['vehicle_number'] ?? (isTamil ? "வாகனத்தைத் தேர்ந்தெடுக்கவும்" : "Choose a vehicle"),
                          icon: Icons.directions_bus_rounded,
                          accent: primary,
                          onTap: () => _showVehiclePicker(vehicleStore.filteredVehicles),
                          isDark: isDark,
                          isLoading: vehicleStore.isLoading,
                        ),
                        const SizedBox(height: 18),
                        _formLabel(isTamil ? "சம்பவத்தின் தன்மை" : "Nature of the Incident", titleColor),
                        const SizedBox(height: 8),
                        _buildTextField(
                          isTamil ? "எ.கா. மோதல், டயர் வெடிப்பு" : "e.g. Collision, Tire Burst",
                          Icons.info_outline_rounded,
                          isDark, primary,
                          controller: _natureController,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Damage Assessment
                    _buildSectionCard(
                      icon: Icons.car_crash_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      title: isTamil ? "சேத மதிப்பீடு" : "Damage Assessment",
                      surface: surface,
                      titleColor: titleColor,
                      isDark: isDark,
                      children: [
                        _formLabel(isTamil ? "சொந்த வாகன சேதம்" : "Own Vehicle Damage", titleColor),
                        const SizedBox(height: 8),
                        _buildDropdown(
                          isTamil ? "சேத நிலையைத் தேர்ந்தெடுக்கவும்" : "Select Damage Level",
                          Icons.car_crash_rounded,
                          isDark, primary,
                          value: _ownVehicleDamage,
                          items: (isTamil ? _damageLevelsTamil : _damageLevels).map((e) => e['label']!).toList(),
                          onChanged: (val) {
                            final level = (isTamil ? _damageLevelsTamil : _damageLevels).firstWhere((e) => e['label'] == val);
                            setState(() => _ownVehicleDamage = level['label']);
                          },
                        ),
                        const SizedBox(height: 20),
                        _formLabel(isTamil ? "எதிர்தரப்பு வாகன சேதம்" : "Opposite Vehicle Damage", titleColor),
                        const SizedBox(height: 8),
                        _buildDropdown(
                          isTamil ? "சேத நிலையைத் தேர்ந்தெடுக்கவும்" : "Select Damage Level",
                          Icons.bus_alert_rounded,
                          isDark, primary,
                          value: _oppositeVehicleDamage,
                          items: (isTamil ? _damageLevelsTamil : _damageLevels).map((e) => e['label']!).toList(),
                          onChanged: (val) {
                            final level = (isTamil ? _damageLevelsTamil : _damageLevels).firstWhere((e) => e['label'] == val);
                            setState(() => _oppositeVehicleDamage = level['label']);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Place, Time, Odometer
                    _buildSectionCard(
                      icon: Icons.location_on_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      title: isTamil ? "இடம் மற்றும் நேரம்" : "Location & Time",
                      surface: surface,
                      titleColor: titleColor,
                      isDark: isDark,
                      children: [
                        SingleLocationSelector(
                          label: isTamil ? "சம்பவம் நடந்த இடம் *" : "Incident Location *",
                          initialAddress: _selectedLocationMap?['name'] ?? _placeController.text,
                          initialLat: _selectedLocationMap?['lat'],
                          initialLon: _selectedLocationMap?['lon'],
                          cardColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                          titleColor: titleColor,
                          accentColor: const Color(0xFFF59E0B),
                          onChanged: (loc) {
                            setState(() {
                              _selectedLocationMap = {
                                'id': loc['display_name'],
                                'name': loc['display_name'],
                                'lat': loc['lat'],
                                'lon': loc['lon'],
                              };
                              _placeController.text = loc['display_name'];
                            });
                          },
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _formLabel(isTamil ? "சம்பவம் நடந்த நேரம் *" : "Incident Time *", titleColor),
                                  const SizedBox(height: 8),
                                  _buildDateTimeField(context, isDark, primary, _incidentDateTime, (d) => setState(() => _incidentDateTime = d)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _formLabel(isTamil ? "ஓடோமீட்டர் *" : "ODO METER *", titleColor),
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

                    // Action Taken & Status
                    _buildSectionCard(
                      icon: Icons.gavel_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      title: isTamil ? "நடவடிக்கை மற்றும் நிலை" : "Action & Status",
                      surface: surface,
                      titleColor: titleColor,
                      isDark: isDark,
                      children: [
                        _formLabel(isTamil ? "எடுக்கப்பட்ட நடவடிக்கை *" : "Action taken for Incident *", titleColor),
                        const SizedBox(height: 8),
                        _buildTextField(
                          isTamil ? "எடுக்கப்பட்ட நடவடிக்கைகள்..." : "Immediate actions taken...",
                          Icons.handyman_rounded,
                          isDark, primary,
                          maxLines: 2,
                          controller: _actionTakenController,
                        ),
                        const SizedBox(height: 18),
                        _buildSwitchTile(
                          isTamil ? "போலீஸ் வழக்கு பதிவு செய்யப்பட்டது" : "Police case filed",
                          _policeCaseFiled,
                          (v) => setState(() => _policeCaseFiled = v),
                          isDark, primary,
                        ),
                        _buildSwitchTile(
                          isTamil ? "முக்கிய விபத்து பாதிப்பு" : "Major causality issue",
                          _majorCausality,
                          (v) => setState(() => _majorCausality = v),
                          isDark, primary,
                        ),
                        _buildSwitchTile(
                          isTamil ? "காப்பீட்டு கோரிக்கை" : "Insurance claim",
                          _insuranceClaim,
                          (v) => setState(() => _insuranceClaim = v),
                          isDark, primary,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Proof Upload
                    _buildSectionCard(
                      icon: Icons.photo_camera_rounded,
                      iconColor: const Color(0xFFEC4899),
                      title: isTamil ? "ஆதாரம்" : "Proof Images",
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
                                height: 22, width: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    isTamil ? "சமர்ப்பிக்கவும்" : "Submit Accident Entry",
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
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
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
                    color: iconColor.withValues(alpha: 0.12),
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
          Divider(indent: 20, endIndent: 20, color: titleColor.withValues(alpha: 0.06)),
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
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.7)),
      );

  Widget _buildSelectionTile({
    required String label,
    required String hint,
    required IconData icon,
    required Color accent,
    VoidCallback? onTap,
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
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent.withValues(alpha: 0.6), size: 20),
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

  void _showVehiclePicker(List<dynamic> vehicles) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPickerSheet(
        title: LanguageStore.isTamil ? "வாகனத்தைத் தேர்ந்தெடுக்கவும்" : "Select Vehicle",
        items: vehicles,
        nameKey: 'vehicle_number',
        subtitleKey: 'vehicle_type_name',
        extraKey: 'make',
        icon: Icons.directions_bus_rounded,
        iconColor: const Color(0xFFEF4444),
        selectedId: _selectedVehicleMap?['id'],
        onSelect: (item) => setState(() => _selectedVehicleMap = item),
      ),
    );
  }


  Widget _buildPickerSheet({
    required String title,
    required List<dynamic> items,
    required String nameKey,
    String? subtitleKey,
    required IconData icon,
    required Color iconColor,
    dynamic selectedId,
    String? extraKey,
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
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 40, offset: const Offset(0, -10))],
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
                    fillColor: Colors.black.withValues(alpha: 0.04),
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
                        separatorBuilder: (_, _) => const Divider(height: 1, indent: 70, color: Colors.black12),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isSelected = selectedId == item['id'];
                          final subtitleParts = <String>[];
                          if (subtitleKey != null && item[subtitleKey] != null) subtitleParts.add(item[subtitleKey].toString());
                          if (extraKey != null && item[extraKey] != null) subtitleParts.add(item[extraKey].toString());
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: iconColor, size: 22),
                            ),
                            title: Text(item[nameKey] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: subtitleParts.isNotEmpty
                                ? Text(subtitleParts.join(' \u2022 '), style: const TextStyle(fontSize: 12, color: Colors.grey))
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
        prefixIcon: Icon(icon, color: accent.withValues(alpha: 0.6), size: 20),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.4), width: 1.5),
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
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items?.contains(value) == true ? value : null,
          hint: Row(
            children: [
              Icon(icon, color: accent.withValues(alpha: 0.5), size: 20),
              const SizedBox(width: 12),
              Text(hint, style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 14)),
            ],
          ),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: accent.withValues(alpha: 0.5)),
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

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged, bool isDark, Color accent) {
    return SwitchListTile.adaptive(
      title: Text(title, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: accent,
      activeTrackColor: accent.withValues(alpha: 0.3),
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildDateTimeField(BuildContext ctx, bool isDark, Color accent, DateTime date, Function(DateTime) onPicked) {
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
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: accent.withValues(alpha: 0.6), size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                DateFormat('dd MMM yyyy, hh:mm a').format(date),
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.w600),
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
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 50,
          maxWidth: 1080,
          maxHeight: 1080,
        );
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
              ? Colors.green.withValues(alpha: 0.08)
              : primary.withValues(alpha: isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _proofPath != null ? Colors.green.withValues(alpha: 0.4) : primary.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _proofPath != null ? Icons.check_circle_rounded : Icons.add_a_photo_rounded,
              color: _proofPath != null ? Colors.green : primary,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(
              _proofPath != null
                  ? (isTamil ? "படம் இணைக்கப்பட்டது ✓" : "Image Attached ✓")
                  : (isTamil ? "ஆதார புகைப்படத்தைச் சேர்க்கவும்" : "Upload Proof Image"),
              style: TextStyle(
                color: _proofPath != null ? Colors.green : primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            if (_proofPath != null) ...[
              const SizedBox(height: 4),
              Text(_proofPath!.split('/').last, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              TextButton(
                onPressed: () => setState(() => _proofPath = null),
                child: Text(isTamil ? "நீக்கு" : "Remove", style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final isTamil = LanguageStore.isTamil;
    if (_selectedVehicleMap == null ||
        _natureController.text.isEmpty ||
        _placeController.text.isEmpty ||
        _odometerController.text.isEmpty ||
        _actionTakenController.text.isEmpty) {
      _showSnack(
        isTamil ? "கட்டாய புலங்களை நிரப்பவும் *" : "Please fill all required fields *",
        Colors.orange,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final data = {
      "vehicle_id": _selectedVehicleMap?['id'] ?? "",
      "description": _natureController.text,
      "own_vehicle_damage": (isTamil ? _damageLevelsTamil : _damageLevels).firstWhere((e) => e['label'] == _ownVehicleDamage, orElse: () => {"value": "NO_ISSUES"})['value'],
      "opposite_vehicle_damage": (isTamil ? _damageLevelsTamil : _damageLevels).firstWhere((e) => e['label'] == _oppositeVehicleDamage, orElse: () => {"value": "NO_ISSUES"})['value'],
      "place_name": _placeController.text,
      "latitude": _selectedLocationMap?['lat'],
      "longitude": _selectedLocationMap?['lon'],
      "incident_date_time": _incidentDateTime.toIso8601String(),
      "incident_current_odometer": _odometerController.text,
      "action_taken": _actionTakenController.text,
      "police_case_filed": _policeCaseFiled.toString(),
      "major_casualty_issue": _majorCausality.toString(),
      "insurance_claim_required": _insuranceClaim.toString(),
    };

    final result = await context.read<DriverStore>().submitAccidentEntry(data, _proofPath);
    setState(() => _isSubmitting = false);

    if (result['success']) {
      _showSnack(isTamil ? "வெற்றிகரமாக பதிவு செய்யப்பட்டது!" : "Incident reported successfully!", Colors.green);
      if (mounted) Navigator.pop(context);
    } else {
      _showSnack(result['message'], Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }
}
