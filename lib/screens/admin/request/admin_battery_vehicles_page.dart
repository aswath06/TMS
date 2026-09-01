import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';

class AdminBatteryVehiclesPage extends ConsumerStatefulWidget {
  const AdminBatteryVehiclesPage({super.key});

  @override
  ConsumerState<AdminBatteryVehiclesPage> createState() =>
      _AdminBatteryVehiclesPageState();
}

class _AdminBatteryVehiclesPageState
    extends ConsumerState<AdminBatteryVehiclesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _selectedDateFilter;
  late ScrollController _dateScrollController;
  final int _infiniteScrollMiddle = 10000;
  bool isFacultyBookingEnabled = true;
  bool isStudentBookingEnabled = true;
  bool isNonTeachingBookingEnabled = true;
  bool isInternBookingEnabled = true;

  late final dynamic _notificationProviderInstance;

  @override
  void initState() {
    super.initState();
    // Auto-refresh bookings when notification arrives (e.g. 60s timeout escalation)
    _notificationProviderInstance = ref.read(notificationProviderFamily);
    _notificationProviderInstance.addListener(_onNotificationReceived);

    _selectedDateFilter = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _dateScrollController = ScrollController(
      initialScrollOffset: (_infiniteScrollMiddle * 68.0) - 100,
    );
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final store = ref.read(batteryVehicleStoreProvider);

      try {
        await store.fetchAllBookings();
      } catch (_) {}
      try {
        await store.fetchEvLocations();
      } catch (_) {}

      try {
        await store.fetchBookingConfig();
        final config = store.bookingConfig ?? {};
        setState(() {
          isFacultyBookingEnabled =
              config['is_faculty_booking_enabled'] ?? true;
          isStudentBookingEnabled =
              config['is_student_booking_enabled'] ?? true;
          isNonTeachingBookingEnabled =
              config['is_non_teaching_booking_enabled'] ?? true;
          isInternBookingEnabled = config['is_intern_booking_enabled'] ?? true;
        });
      } catch (_) {}

      try {
        await store.fetchActiveEvDrivers();
      } catch (_) {}
    });
  }

  void _onNotificationReceived() {
    if (mounted) {
      ref.read(batteryVehicleStoreProvider).fetchAllBookings();
    }
  }

  @override
  void dispose() {
    _notificationProviderInstance.removeListener(_onNotificationReceived);
    _dateScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _updateConfig(String key, bool value) {
    final store = ref.read(batteryVehicleStoreProvider);
    final newConfig = {
      'is_faculty_booking_enabled': isFacultyBookingEnabled,
      'is_student_booking_enabled': isStudentBookingEnabled,
      'is_non_teaching_booking_enabled': isNonTeachingBookingEnabled,
      'is_intern_booking_enabled': isInternBookingEnabled,
    };
    newConfig[key] = value;
    store
        .updateBookingConfig(newConfig)
        .then((_) {
          if (mounted) {
            setState(() {
              if (key == 'is_faculty_booking_enabled')
                isFacultyBookingEnabled = value;
              if (key == 'is_student_booking_enabled')
                isStudentBookingEnabled = value;
              if (key == 'is_non_teaching_booking_enabled')
                isNonTeachingBookingEnabled = value;
              if (key == 'is_intern_booking_enabled')
                isInternBookingEnabled = value;
            });
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Config updated!")));
          }
        })
        .catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("Error: \$e")));
          }
        });
  }

  int? _createFromLocationId;
  int? _createToLocationId;
  final TextEditingController _createReasonController = TextEditingController();
  final TextEditingController _createPassengerController =
      TextEditingController();

  void _showLocationSheet(
    bool isFrom,
    Function(void Function()) setParentModalState,
  ) {
    final store = ref.read(batteryVehicleStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final p = const Color(0xFF6366F1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String searchQuery = "";
        
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredLocations = store.evLocations.where((loc) {
              final name = (loc['name'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();
            
            filteredLocations.sort((a, b) => (a['name']?.toString() ?? '').toLowerCase().compareTo((b['name']?.toString() ?? '').toLowerCase()));

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isFrom ? "Select Pickup Location" : "Select Drop Location",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: p.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.withValues(alpha: 0.15), width: 1),
                        ),
                        child: Text(
                          "${store.evLocations.length} Available",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: p,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Choose the ${isFrom ? 'pickup' : 'drop'} location for this request.",
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey.shade600, 
                      fontWeight: FontWeight.w600, 
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.01),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: "Search location...",
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white24 : Colors.grey.shade400,
                          fontWeight: FontWeight.w700,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: p.withValues(alpha: 0.6),
                          size: 22,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      onChanged: (val) {
                        setSheetState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (filteredLocations.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text("No locations found"),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredLocations.length,
                        itemBuilder: (context, index) {
                          final loc = filteredLocations[index];
                          final val = int.tryParse(loc['id'].toString()) ?? 0;
                          final bool isSelected = isFrom ? _createFromLocationId == val : _createToLocationId == val;
                          
                          return GestureDetector(
                            onTap: () {
                              setParentModalState(() {
                                if (isFrom) {
                                  _createFromLocationId = val;
                                } else {
                                  _createToLocationId = val;
                                }
                              });
                              Navigator.pop(context);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? p.withValues(alpha: 0.08) 
                                    : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade50),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? p : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: isSelected ? [
                                  BoxShadow(
                                    color: p.withValues(alpha: 0.12),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  )
                                ] : [],
                              ),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: isSelected ? 4 : 2,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isSelected ? p : Colors.grey.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      loc['name'] ?? 'Unknown',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: p,
                                      size: 22,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAdminCreateRequestDialog() {
    final store = ref.read(batteryVehicleStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue = const Color(0xFF6366F1);
    final hintColor = isDark ? Colors.white54 : Colors.black54;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    Widget buildInputField({
      required String hint,
      required IconData icon,
      required TextEditingController controller,
      bool isDropdown = false,
      int maxLines = 1,
      VoidCallback? onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AbsorbPointer(
          absorbing: isDropdown,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.01),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextFormField(
              controller: controller,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              maxLines: maxLines,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                  fontWeight: FontWeight.w700,
                ),
                prefixIcon: Icon(
                  icon,
                  color: primaryBlue.withValues(alpha: 0.8),
                  size: 22,
                ),
                suffixIcon: isDropdown
                    ? Icon(Icons.keyboard_arrow_down_rounded, color: hintColor)
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
            ),
          ),
        ),
      );
    }

    _createFromLocationId = null;
    _createToLocationId = null;
    _createReasonController.clear();
    _createPassengerController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            String? fromLocName;
            if (_createFromLocationId != null) {
              fromLocName = store.evLocations.firstWhere(
                (l) => l['id']?.toString() == _createFromLocationId.toString(),
                orElse: () => {'name': ''},
              )['name'];
            }
            String? toLocName;
            if (_createToLocationId != null) {
              toLocName = store.evLocations.firstWhere(
                (l) => l['id']?.toString() == _createToLocationId.toString(),
                orElse: () => {'name': ''},
              )['name'];
            }

            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(36),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Create EV Request",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : Colors.black,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    buildInputField(
                      hint: 'From Location',
                      icon: Icons.my_location_rounded,
                      controller: TextEditingController(text: fromLocName),
                      isDropdown: true,
                      onTap: () => _showLocationSheet(true, setModalState),
                    ),
                    const SizedBox(height: 16),
                    buildInputField(
                      hint: 'To Location',
                      icon: Icons.location_on_rounded,
                      controller: TextEditingController(text: toLocName),
                      isDropdown: true,
                      onTap: () => _showLocationSheet(false, setModalState),
                    ),
                    const SizedBox(height: 16),
                    buildInputField(
                      hint: 'For Whom (Passenger Name)',
                      icon: Icons.person_rounded,
                      controller: _createPassengerController,
                    ),
                    const SizedBox(height: 16),
                    buildInputField(
                      hint: 'Remarks / Reason',
                      icon: Icons.notes_rounded,
                      controller: _createReasonController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_createFromLocationId == null ||
                              _createToLocationId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please select locations"),
                              ),
                            );
                            return;
                          }
                          if (_createPassengerController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please enter passenger name"),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context);
                          try {
                            await store.adminBookBatteryVehicle(
                              _createFromLocationId!,
                              _createToLocationId!,
                              _createReasonController.text.trim(),
                              _createPassengerController.text.trim(),
                            );
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Request created successfully!",
                                  ),
                                ),
                              );
                          } catch (e) {
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Submit Request",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
      },
    );
  }

  void _showAddLocationDialog() {
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue = const Color(0xFF6366F1);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "New EV Location",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: textColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: "Name",
                    labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: latController,
                  style: TextStyle(color: textColor),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: "Latitude",
                    labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: lngController,
                  style: TextStyle(color: textColor),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: "Longitude",
                    labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    try {
                      await ref
                          .read(batteryVehicleStoreProvider)
                          .addEvLocation(
                            nameController.text,
                            double.tryParse(latController.text) ?? 0.0,
                            double.tryParse(lngController.text) ?? 0.0,
                            'ACTIVE',
                          );
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    }
                  },
                  child: const Text(
                    "Save Location",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'COMPLETED') return Colors.green;
    if (status == 'CANCELLED') return Colors.red;
    if (status == 'PENDING' || status == 'REQUESTED') return Colors.orange;
    if (status == 'ACCEPTED' || status == 'STARTED') return Colors.pink;
    if (status == 'ONGOING') return Colors.blue;
    return Colors.grey;
  }

  Widget _buildTimePill(String label, String timeStr, bool isDark) {
    String formatted = timeStr;
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      formatted =
          "${dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}";
    } catch (_) {}
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white54 : Colors.black54,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatted,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildConfigTab(
    Color cardColor,
    Color textColor,
    Color subColor,
    Color primaryBlue,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Access Control",
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black26
                      : Colors.blueGrey.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  "Faculty Booking",
                  isFacultyBookingEnabled,
                  'is_faculty_booking_enabled',
                  textColor,
                  primaryBlue,
                ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
                _buildSwitchTile(
                  "Student Booking",
                  isStudentBookingEnabled,
                  'is_student_booking_enabled',
                  textColor,
                  primaryBlue,
                ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
                _buildSwitchTile(
                  "Non-Teaching Booking",
                  isNonTeachingBookingEnabled,
                  'is_non_teaching_booking_enabled',
                  textColor,
                  primaryBlue,
                ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
                _buildSwitchTile(
                  "Intern Booking",
                  isInternBookingEnabled,
                  'is_intern_booking_enabled',
                  textColor,
                  primaryBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    String key,
    Color textColor,
    Color primaryBlue,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          Switch(
            activeColor: primaryBlue,
            value: value,
            onChanged: (v) => _updateConfig(key, v),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationsTab(
    Color cardColor,
    Color textColor,
    Color subColor,
    Color primaryBlue,
    bool isDark,
  ) {
    final store = ref.watch(batteryVehicleStoreProvider);
    final allDrivers = ref.watch(driverStoreProvider).drivers;
    return store.evLocations.isEmpty
        ? Center(
            child: Text(
              "No EV locations found.",
              style: TextStyle(color: subColor),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: store.evLocations.length,
            itemBuilder: (context, index) {
              final loc = store.evLocations[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black26
                          : Colors.blueGrey.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primaryBlue.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc['name'] ?? 'Unknown',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Lat: ${loc['latitude']} | Lng: ${loc['longitude']}",
                            style: TextStyle(color: subColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (loc['status'] == 'ACTIVE'
                                    ? Colors.green
                                    : Colors.red)
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        loc['status'] ?? 'INACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: loc['status'] == 'ACTIVE'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }

  void _forceAssignDialog(dynamic bookingId) async {
    final parentContext = context;
    if (mounted) {
      showDialog(
        context: parentContext,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );
    }

    await ref.read(batteryVehicleStoreProvider).fetchActiveEvDrivers();

    if (mounted) {
      Navigator.pop(parentContext);
    }

    final isDark = Theme.of(parentContext).brightness == Brightness.dark;

    if (mounted) {
      showModalBottomSheet(
        context: parentContext,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        builder: (sheetContext) {
          final allDrivers = ref.read(batteryVehicleStoreProvider).activeEvDrivers;
          String searchQuery = '';
          return StatefulBuilder(
            builder: (BuildContext sbContext, StateSetter setModalState) {
              final filteredDrivers = allDrivers.where((d) {
                final name = (d['name'] ?? '').toString().toLowerCase();
                final phone = (d['phone'] ?? '').toString().toLowerCase();
                final q = searchQuery.toLowerCase();
                return name.contains(q) || phone.contains(q);
              }).toList();

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                  ),
                  child: FractionallySizedBox(
                    heightFactor: 0.8,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Force Assign Driver",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(sheetContext),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search by name or phone...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 0,
                                horizontal: 16,
                              ),
                            ),
                            onChanged: (val) {
                              setModalState(() {
                                searchQuery = val;
                              });
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        if (filteredDrivers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text("No drivers found."),
                          ),
                        if (filteredDrivers.isNotEmpty)
                          Expanded(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredDrivers.length,
                              itemBuilder: (listContext, index) {
                                final d = filteredDrivers[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.withOpacity(
                                      0.1,
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  title: Text(
                                    d['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(d['phone'] ?? '-'),
                                  onTap: () async {
                                    Navigator.pop(sheetContext); // Pop the bottom sheet
                                    showDialog(
                                      context: parentContext,
                                      barrierDismissible: false,
                                      builder: (c) => const Center(child: CircularProgressIndicator()),
                                    );
                                    try {
                                      await ref
                                          .read(batteryVehicleStoreProvider)
                                          .assignDriver(
                                            bookingId.toString(),
                                            int.parse(d['id'].toString()),
                                          );
                                      if (mounted) {
                                        Navigator.pop(parentContext); // Pop the loading dialog
                                        ScaffoldMessenger.of(
                                          parentContext,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text("Driver Assigned"),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        Navigator.pop(parentContext); // Pop the loading dialog
                                        ScaffoldMessenger.of(
                                          parentContext,
                                        ).showSnackBar(
                                          SnackBar(content: Text("Error: $e")),
                                        );
                                      }
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }
  }

  void _cancelBooking(dynamic bookingId) async {
    try {
      await ref
          .read(batteryVehicleStoreProvider)
          .cancelBooking(bookingId.toString());
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Booking cancelled")));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _deleteBooking(dynamic bookingId) async {
    try {
      await ref
          .read(batteryVehicleStoreProvider)
          .deleteBooking(bookingId.toString());
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Booking deleted")));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  String _getLocationName(dynamic id, List<dynamic> locations) {
    if (id == null) return '-';
    final idStr = id.toString();
    for (var loc in locations) {
      if (loc['id']?.toString() == idStr) {
        return loc['name'] ?? idStr;
      }
    }
    return idStr;
  }

  Widget _buildDateScroller(
    Color primaryBlue,
    Color titleColor,
    Color subColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          // Fixed ALL option
          GestureDetector(
            onTap: () {
              if (_selectedDateFilter == 'ALL') return;
              setState(() => _selectedDateFilter = 'ALL');
            },
            child: Container(
              width: 65,
              height: 70,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: _selectedDateFilter == 'ALL'
                    ? primaryBlue
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedDateFilter == 'ALL'
                      ? primaryBlue
                      : titleColor.withValues(alpha: 0.1),
                ),
                boxShadow: _selectedDateFilter == 'ALL'
                    ? [
                        BoxShadow(
                          color: primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color: _selectedDateFilter == 'ALL'
                        ? Colors.white
                        : subColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "ALL",
                    style: TextStyle(
                      color: _selectedDateFilter == 'ALL'
                          ? Colors.white
                          : titleColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Scrolling dates
          Expanded(
            child: SizedBox(
              height: 70,
              child: ListView.builder(
                itemExtent: 68.0,
                controller: _dateScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final date = DateTime.now().add(
                    Duration(days: index - _infiniteScrollMiddle),
                  );
                  final formattedDateStr = DateFormat(
                    'yyyy-MM-dd',
                  ).format(date);
                  final isSelected = _selectedDateFilter == formattedDateStr;
                  return GestureDetector(
                    onTap: () {
                      if (_selectedDateFilter == formattedDateStr) return;
                      setState(() => _selectedDateFilter = formattedDateStr);
                    },
                    child: Container(
                      width: 60,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryBlue
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? primaryBlue
                              : titleColor.withValues(alpha: 0.1),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: primaryBlue.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('E').format(date).toUpperCase(),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : subColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('dd').format(date),
                            style: TextStyle(
                              color: isSelected ? Colors.white : titleColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            DateFormat('MMM').format(date).toUpperCase(),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : subColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsTab(
    Color cardColor,
    Color textColor,
    Color subColor,
    Color primaryBlue,
    bool isDark,
  ) {
    final store = ref.watch(batteryVehicleStoreProvider);
    final baseDrivers = ref.watch(driverStoreProvider).drivers;
    final allDrivers = [
      ...baseDrivers,
      ...store.activeEvDrivers,
    ];

    final filteredBookings = store.allBookings.where((b) {
      final status = (b['status'] ?? '').toString().toUpperCase();
      if (status == 'CANCELLED') return false;

      if (_selectedDateFilter == 'ALL') return true;

      final createdAt = b['created_at'] != null
          ? b['created_at'].toString()
          : '';
      if (createdAt.isNotEmpty) {
        final datePart = createdAt.split('T')[0];
        if (datePart == _selectedDateFilter) return true;
      }
      return false;
    }).toList();

    return Column(
      children: [
        _buildDateScroller(primaryBlue, textColor, subColor, isDark),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(batteryVehicleStoreProvider).fetchAllBookings(),
            child: filteredBookings.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      Center(
                        child: Text(
                          "No bookings found for $_selectedDateFilter.",
                          style: TextStyle(color: subColor),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  itemCount: filteredBookings.length,
                  itemBuilder: (context, index) {
                    final b = filteredBookings[index];
                    String rawStatus = b['status'] ?? 'UNKNOWN';
                    if (rawStatus == 'EXPIRED') rawStatus = 'PENDING';
                    final status = rawStatus;
                    final statusColor = _getStatusColor(status);

                    String fromName = _getLocName(
                      b,
                      'fromLocation',
                      'from_location_id',
                      store.evLocations,
                    );
                    String toName = _getLocName(
                      b,
                      'toLocation',
                      'to_location_id',
                      store.evLocations,
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black26
                                : Colors.blueGrey.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: primaryBlue.withValues(
                                        alpha: 0.1,
                                      ),
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 16,
                                        color: primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _getPassengerName(b),
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.trip_origin_rounded,
                                size: 16,
                                color: primaryBlue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  fromName,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_right_alt_rounded,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  toName,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.notes,
                                      size: 14,
                                      color: subColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        "Reason: ${b['reason'] ?? '-'}",
                                        style: TextStyle(
                                          color: subColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone,
                                      size: 14,
                                      color: subColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _getPassengerPhone(b),
                                        style: TextStyle(
                                          color: primaryBlue,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.call,
                                        color: Colors.green,
                                      ),
                                      onPressed: () async {
                                        final phone = _getPassengerPhone(b);
                                        if (phone != 'N/A') {
                                          final uri = Uri.parse('tel:$phone');
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri);
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.directions_car_rounded,
                                      size: 14,
                                      color:
                                          (b['driver'] != null ||
                                              b['driver_id'] != null)
                                          ? primaryBlue
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        (b['driver'] != null ||
                                                b['driver_id'] != null)
                                            ? "Driver: ${_getDriverNameHelper(b, allDrivers)}"
                                            : "No Driver Accepted Yet",
                                        style: TextStyle(
                                          color:
                                              (b['driver'] != null ||
                                                  b['driver_id'] != null)
                                              ? primaryBlue
                                              : Colors.orange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              String? completedTime = b['completed_at'] ?? b['ended_at'];
                              if (completedTime == null && status == 'COMPLETED') {
                                completedTime = b['updated_at'];
                              }
                              String? startedTime = b['started_at'];
                              if (startedTime == null && (status == 'STARTED' || status == 'ONGOING')) {
                                startedTime = b['updated_at'];
                              }
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (b['created_at'] != null)
                                    _buildTimePill("Booked", b['created_at'], isDark),
                                  if (b['accepted_at'] != null)
                                    _buildTimePill("Accepted", b['accepted_at'], isDark),
                                  if (startedTime != null)
                                    _buildTimePill("Started", startedTime, isDark),
                                  if (completedTime != null)
                                    _buildTimePill("Completed", completedTime, isDark),
                                ],
                              );
                            }
                          ),
                          if (status == 'PENDING' &&
                              b['driver'] == null &&
                              b['driver_id'] == null) ...[
                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,

                              child: ElevatedButton(
                                onPressed: () => _forceAssignDialog(b['id']),

                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryBlue,

                                  foregroundColor: Colors.white,

                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),

                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),

                                child: const Text(
                                  "Force Assign",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _cancelBooking(b['id']),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.orange,
                                      side: const BorderSide(
                                        color: Colors.orange,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text("Cancel"),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _deleteBooking(b['id']),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text("Delete"),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryBlue = const Color(0xFF6366F1);
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: textColor,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Admin EV Dashboard",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: primaryBlue,
              unselectedLabelColor: subColor,
              indicatorColor: primaryBlue,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              tabs: const [
                Tab(text: "Bookings"),
                Tab(text: "Locations"),
                Tab(text: "Config"),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBookingsTab(
                    cardColor,
                    textColor,
                    subColor,
                    primaryBlue,
                    isDark,
                  ),
                  _buildLocationsTab(
                    cardColor,
                    textColor,
                    subColor,
                    primaryBlue,
                    isDark,
                  ),
                  _buildConfigTab(
                    cardColor,
                    textColor,
                    subColor,
                    primaryBlue,
                    isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: _showAddLocationDialog,
              backgroundColor: primaryBlue,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                "New Location",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : (_tabController.index == 0
                ? FloatingActionButton.extended(
                    onPressed: _showAdminCreateRequestDialog,
                    backgroundColor: primaryBlue,
                    icon: const Icon(
                      Icons.electric_car_rounded,
                      color: Colors.white,
                    ),
                    label: const Text(
                      "Create Request",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null),
    );
  }
}

String _getLocName(
  dynamic b,
  String key,
  String idKey,
  List<dynamic> locations,
) {
  if (b[key] is String) return b[key];
  if (b[key] is Map && b[key]['name'] != null) return b[key]['name'];
  final locId = b[idKey] ?? (b[key] is Map ? b[key]['id'] : null);
  if (locId != null) {
    final matches = locations.where(
      (l) => l['id'].toString() == locId.toString(),
    );
    final loc = matches.isNotEmpty ? matches.first : null;
    if (loc != null && loc['name'] != null) return loc['name'];
  }
  return 'Unknown';
}

String _getPassengerName(dynamic b) {
  if (b['requestUser'] != null && b['requestUser']['name'] != null) {
    return b['requestUser']['name'];
  }
  return b['passenger_name'] ?? b['employee_code'] ?? 'Unknown Passenger';
}

String _getPassengerPhone(dynamic b) {
  if (b['requestUser'] != null) {
    if (b['requestUser']['phone_number'] != null &&
        b['requestUser']['phone_number'].toString().isNotEmpty)
      return b['requestUser']['phone_number'].toString();
    if (b['requestUser']['phone'] != null &&
        b['requestUser']['phone'].toString().isNotEmpty)
      return b['requestUser']['phone'].toString();
    if (b['requestUser']['mobile'] != null &&
        b['requestUser']['mobile'].toString().isNotEmpty)
      return b['requestUser']['mobile'].toString();
  }
  if (b['passenger_phone'] != null &&
      b['passenger_phone'].toString().isNotEmpty)
    return b['passenger_phone'].toString();
  return 'N/A';
}

String _getDriverNameHelper(dynamic b, List<dynamic> allDrivers) {
  if (b['driver'] != null) {
    if (b['driver'] is Map && b['driver']['name'] != null) {
      return b['driver']['name'].toString();
    }
    final driverId =
        b['driver_id'] ??
        (b['driver'] is Map ? b['driver']['id'] : b['driver']);
    if (driverId != null) {
      final matches = allDrivers.where(
        (drv) => drv['id'].toString() == driverId.toString(),
      );
      final d = matches.isNotEmpty ? matches.first : null;
      if (d != null && d['name'] != null) return d['name'].toString();
    }
    if (b['driver'] is Map && b['driver']['first_name'] != null) {
      return "${b['driver']['first_name']} ${b['driver']['last_name'] ?? ''}"
          .trim();
    }
  }

  if (b['driver_id'] != null) {
    final matches = allDrivers.where(
      (drv) => drv['id'].toString() == b['driver_id'].toString(),
    );
    final d = matches.isNotEmpty ? matches.first : null;
    if (d != null && d['name'] != null) return d['name'].toString();
  }
  return 'Unknown';
}
