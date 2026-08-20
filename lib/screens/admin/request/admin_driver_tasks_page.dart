import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/utils/task_icon_helper.dart';
import 'package:tripzo/screens/driver/driver_task_details_page.dart';

class AdminDriverTasksPage extends ConsumerStatefulWidget {
  const AdminDriverTasksPage({super.key});

  @override
  ConsumerState<AdminDriverTasksPage> createState() => _AdminDriverTasksPageState();
}

class _AdminDriverTasksPageState extends ConsumerState<AdminDriverTasksPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driverTaskStoreProvider).fetchAllTasks();
      ref.read(driverTaskStoreProvider).fetchTaskTypes();
      ref.read(driverTaskStoreProvider).fetchAvailableDrivers();
      ref.read(driverStoreProvider).fetchProfile();
      ref.read(vehicleStoreProvider).fetchVehicles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Create Task Modal supporting Outer Location & In-Campus Location
  void _showCreateTaskDialog(BuildContext context) {
    final taskStore = ref.read(driverTaskStoreProvider);

    final titleController = TextEditingController();
    final descController = TextEditingController();
    final fromLocController = TextEditingController(text: "Coimbatore Main Bunk");
    final toLocController = TextEditingController(text: "Sitra Square");
    final inCampusController = TextEditingController(text: "Block 2 Lobby");
    final durationController = TextEditingController(text: "60");
    final remarksController = TextEditingController(text: "Priority task");

    // Location mode: 'OUTER' vs 'CAMPUS'
    String locationMode = 'OUTER';

    final availableDrivers = taskStore.availableDrivers;
    final firstDriverId = availableDrivers.isNotEmpty ? availableDrivers.first['id'] : 241;

    int? selectedDriverId = firstDriverId;
    int? selectedVehicleId = 56;
    int? selectedTaskTypeId = taskStore.taskTypes.isNotEmpty ? taskStore.taskTypes.first['id'] : 1;
    DateTime selectedDateTime = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
            final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
            final primaryBlue = const Color(0xFF6366F1);

            InputDecoration customInputDecoration({required String label, required IconData icon, String? hint}) {
              return InputDecoration(
                labelText: label,
                hintText: hint,
                labelStyle: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w600),
                prefixIcon: Icon(icon, color: primaryBlue, size: 20),
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: primaryBlue, width: 1.8),
                ),
              );
            }

            return Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Create Driver Task",
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: titleColor,
                              ),
                            ),
                            Text(
                              "Schedule a new task for fleet drivers",
                              style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.close_rounded, color: titleColor, size: 18),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Task Title
                    TextField(
                      controller: titleController,
                      style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: customInputDecoration(
                        label: "Task Title *",
                        icon: Icons.title_rounded,
                        hint: "e.g. Outer Delivery Run / Shuttle Run",
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: descController,
                      style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: customInputDecoration(
                        label: "Description",
                        icon: Icons.description_rounded,
                        hint: "Clean vehicle or deliver items",
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location Mode Switcher (Outer vs In-Campus)
                    Text(
                      "LOCATION MODE",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: primaryBlue, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => locationMode = 'OUTER'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: locationMode == 'OUTER' ? primaryBlue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    "📍 Outer Location",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: locationMode == 'OUTER' ? Colors.white : titleColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => locationMode = 'CAMPUS'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: locationMode == 'CAMPUS' ? primaryBlue : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    "🏢 In-Campus",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: locationMode == 'CAMPUS' ? Colors.white : titleColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (locationMode == 'OUTER') ...[
                      TextField(
                        controller: fromLocController,
                        style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
                        decoration: customInputDecoration(
                          label: "From Location *",
                          icon: Icons.my_location_rounded,
                          hint: "Coimbatore Main Bunk",
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: toLocController,
                        style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
                        decoration: customInputDecoration(
                          label: "To Location *",
                          icon: Icons.location_on_rounded,
                          hint: "Sitra Square",
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: inCampusController,
                        style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
                        decoration: customInputDecoration(
                          label: "In-Campus Location *",
                          icon: Icons.domain_rounded,
                          hint: "Block 2 Lobby",
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    // Searchable Driver Selector Field
                    () {
                      final selectedDriverObj = taskStore.availableDrivers.firstWhere(
                        (d) => d['id'] == selectedDriverId,
                        orElse: () => <String, dynamic>{'name': 'Driver #$selectedDriverId', 'status': 'AVAILABLE'},
                      );
                      final selectedDriverName = selectedDriverObj['name'] ?? "Driver #$selectedDriverId";
                      final selectedDriverStatus = (selectedDriverObj['status'] ?? 'AVAILABLE').toString().toUpperCase();
                      final isAvailable = selectedDriverStatus == 'AVAILABLE';

                      return InkWell(
                        onTap: () {
                          _showDriverSearchPickerModal(
                            context: context,
                            availableDrivers: taskStore.availableDrivers,
                            selectedDriverId: selectedDriverId,
                            onSelect: (id) => setModalState(() => selectedDriverId = id),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person_rounded, color: primaryBlue, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Assigned Driver", style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(
                                      selectedDriverName,
                                      style: TextStyle(color: titleColor, fontSize: 14, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isAvailable ? const Color(0x1F10B981) : const Color(0x1FF59E0B),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  selectedDriverStatus,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isAvailable ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.search_rounded, color: primaryBlue, size: 20),
                            ],
                          ),
                        ),
                      );
                    }(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: durationController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
                            decoration: customInputDecoration(
                              label: "Duration (mins)",
                              icon: Icons.timer_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: remarksController,
                            style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
                            decoration: customInputDecoration(
                              label: "Remarks",
                              icon: Icons.notes_rounded,
                              hint: "Priority task",
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_task_rounded, color: Colors.white, size: 20),
                        label: const Text(
                          "Create Task",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          if (titleController.text.trim().isEmpty) return;

                          final Map<String, dynamic> body = {
                            "driver_id": selectedDriverId ?? 241,
                            "vehicle_id": selectedVehicleId ?? 56,
                            "task_type_id": selectedTaskTypeId ?? 1,
                            "title": titleController.text.trim(),
                            "description": descController.text.trim(),
                            "starts_at": selectedDateTime.toUtc().toIso8601String(),
                            "duration_minutes": int.tryParse(durationController.text) ?? 60,
                            "remarks": remarksController.text.trim(),
                          };

                          if (locationMode == 'OUTER') {
                            final fromVal = fromLocController.text.trim();
                            final toVal = toLocController.text.trim();
                            body["from_location"] = fromVal;
                            body["start_location"] = fromVal;
                            body["to_location"] = toVal;
                            body["end_location"] = toVal;
                            body["destination"] = toVal;
                            body["location_name"] = fromVal;
                            body["location"] = fromVal;
                            body["in_campus"] = null;
                          } else {
                            final campusVal = inCampusController.text.trim();
                            body["in_campus"] = campusVal;
                            body["location_name"] = campusVal;
                            body["location"] = campusVal;
                            body["from_location"] = null;
                            body["to_location"] = null;
                            body["start_location"] = null;
                            body["end_location"] = null;
                          }

                          final success = await ref.read(driverTaskStoreProvider).createTask(body);
                          if (ctx.mounted && success) {
                            Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Task created successfully!")),
                              );
                            }
                          }
                        },
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

  /// Update Location Fields Bottom Sheet
  void _showUpdateLocationsDialog(BuildContext context, Map<String, dynamic> task) {
    final taskId = task['id'];
    final String currentFrom = (task['from_location'] ?? task['start_location'] ?? task['pickup_location'] ?? task['from'] ?? task['location_name'] ?? task['location'] ?? '').toString();
    final String currentTo = (task['to_location'] ?? task['end_location'] ?? task['destination_location'] ?? task['destination'] ?? task['to'] ?? '').toString();
    final String currentInCampus = (task['in_campus'] ?? task['campus_location'] ?? task['campus_site'] ?? '').toString();

    final fromLocController = TextEditingController(text: currentFrom);
    final toLocController = TextEditingController(text: currentTo);
    final inCampusController = TextEditingController(text: currentInCampus.isNotEmpty ? currentInCampus : currentFrom);
    String locationMode = (currentInCampus.isNotEmpty || (currentFrom.isEmpty && currentTo.isEmpty && task['in_campus'] != null)) ? 'CAMPUS' : 'OUTER';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
            final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
            final primaryBlue = const Color(0xFF6366F1);

            InputDecoration customInputDecoration({required String label, required IconData icon, String? hint}) {
              return InputDecoration(
                labelText: label,
                hintText: hint,
                labelStyle: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w600),
                prefixIcon: Icon(icon, color: primaryBlue, size: 20),
                filled: true,
                fillColor: inputBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: primaryBlue, width: 1.8),
                ),
              );
            }

            return Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Color(0x1F14B8A6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_location_alt_rounded, color: Color(0xFF14B8A6), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Update Locations", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: titleColor)),
                            Text("Switch outer vs in-campus locations", style: TextStyle(fontSize: 12, color: subColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => locationMode = 'OUTER'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: locationMode == 'OUTER' ? primaryBlue : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  "📍 Outer Location",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: locationMode == 'OUTER' ? Colors.white : titleColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => locationMode = 'CAMPUS'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: locationMode == 'CAMPUS' ? primaryBlue : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  "🏢 In-Campus",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: locationMode == 'CAMPUS' ? Colors.white : titleColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (locationMode == 'OUTER') ...[
                    TextField(
                      controller: fromLocController,
                      style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: customInputDecoration(label: "From Location", icon: Icons.my_location_rounded),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: toLocController,
                      style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: customInputDecoration(label: "To Location", icon: Icons.location_on_rounded),
                    ),
                  ] else ...[
                    TextField(
                      controller: inCampusController,
                      style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: customInputDecoration(label: "In-Campus Location", icon: Icons.domain_rounded),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text("Cancel", style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                          label: const Text("Save Locations", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            final Map<String, dynamic> body = {};
                            if (locationMode == 'OUTER') {
                              final fromVal = fromLocController.text.trim();
                              final toVal = toLocController.text.trim();
                              body["from_location"] = fromVal;
                              body["start_location"] = fromVal;
                              body["to_location"] = toVal;
                              body["end_location"] = toVal;
                              body["destination"] = toVal;
                              body["location_name"] = fromVal;
                              body["location"] = fromVal;
                              body["in_campus"] = null;
                            } else {
                              final campusVal = inCampusController.text.trim();
                              body["in_campus"] = campusVal;
                              body["location_name"] = campusVal;
                              body["location"] = campusVal;
                              body["from_location"] = null;
                              body["to_location"] = null;
                              body["start_location"] = null;
                              body["end_location"] = null;
                            }

                            final success = await ref.read(driverTaskStoreProvider).updateTask(taskId, body);
                            if (ctx.mounted && success) {
                              Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Location fields updated!")),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Transfer Driver Bottom Sheet (enforcing ASSIGNED status & driver availability)
  void _showTransferDriverDialog(BuildContext context, Map<String, dynamic> task) {
    final taskId = task['id'];
    final availableDrivers = ref.read(driverTaskStoreProvider).availableDrivers;
    int? selectedDriverId = availableDrivers.isNotEmpty ? availableDrivers.first['id'] : 242;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
            final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
            final primaryBlue = const Color(0xFF6366F1);

            return Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Color(0x1F6366F1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF6366F1), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Transfer Driver", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: titleColor)),
                            Text("Reassign task to available driver", style: TextStyle(fontSize: 12, color: subColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  () {
                    final selectedDriverObj = availableDrivers.firstWhere(
                      (d) => d['id'] == selectedDriverId,
                      orElse: () => <String, dynamic>{'name': 'Driver #$selectedDriverId', 'status': 'AVAILABLE'},
                    );
                    final selectedDriverName = selectedDriverObj['name'] ?? "Driver #$selectedDriverId";
                    final selectedDriverStatus = (selectedDriverObj['status'] ?? 'AVAILABLE').toString().toUpperCase();
                    final isAvailable = selectedDriverStatus == 'AVAILABLE';

                    return InkWell(
                      onTap: () {
                        _showDriverSearchPickerModal(
                          context: context,
                          availableDrivers: availableDrivers,
                          selectedDriverId: selectedDriverId,
                          onSelect: (id) => setModalState(() => selectedDriverId = id),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person_rounded, color: primaryBlue, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Target Driver", style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedDriverName,
                                    style: TextStyle(color: titleColor, fontSize: 14, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isAvailable ? const Color(0x1F10B981) : const Color(0x1FF59E0B),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                selectedDriverStatus,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isAvailable ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.search_rounded, color: primaryBlue, size: 20),
                          ],
                        ),
                      ),
                    );
                  }(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text("Cancel", style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 18),
                          label: const Text("Transfer", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            if (selectedDriverId == null) return;
                            final success = await ref.read(driverTaskStoreProvider).updateTask(taskId, {
                              "driver_id": selectedDriverId,
                            });
                            if (ctx.mounted && success) {
                              Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Driver transferred to ID $selectedDriverId!")),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Driver Availability Bottom Sheet
  void _showDriverAvailabilityModal(BuildContext context) {
    final availableDrivers = ref.read(driverTaskStoreProvider).availableDrivers;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
        final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Container(
          padding: EdgeInsets.only(
            top: 16,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Driver Availability",
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor),
                      ),
                      Text(
                        "Live drivers status overview",
                        style: TextStyle(fontSize: 12, color: subColor),
                      ),
                    ],
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.close_rounded, color: titleColor, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: availableDrivers.isEmpty
                    ? Center(child: Text("No drivers found", style: TextStyle(color: subColor, fontWeight: FontWeight.bold)))
                    : ListView.builder(
                        itemCount: availableDrivers.length,
                        itemBuilder: (context, index) {
                          final d = availableDrivers[index];
                          final String name = d['name'] ?? "Driver #${d['id']}";
                          final String status = (d['status'] ?? 'AVAILABLE').toString().toUpperCase();
                          final bool isAvailable = status == 'AVAILABLE';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: isAvailable ? const Color(0x1F10B981) : const Color(0x1FF59E0B),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isAvailable ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                                    color: isAvailable ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(fontWeight: FontWeight.bold, color: titleColor, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (d['phone'] != null)
                                        Text(
                                          "Phone: ${d['phone']}",
                                          style: TextStyle(fontSize: 12, color: subColor),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isAvailable ? const Color(0x1F10B981) : const Color(0x1FF59E0B),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: isAvailable ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
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
  }

  /// Unified Verify Task Bottom Sheet Modal (Combines Verify, Points, and Convert to Route)
  void _showUnifiedVerifyTaskModal(BuildContext context, Map<String, dynamic> task) {
    final taskId = task['id'];
    bool convertToRoute = false;
    final pointsController = TextEditingController(text: "30");
    final remarksController = TextEditingController(text: "Good job");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
            final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
            final primaryEmerald = const Color(0xFF10B981);

            return Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0x1F10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Verify Task",
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: titleColor,
                                ),
                              ),
                              Text(
                                "Approve task & set reward configuration",
                                style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Convert to Route Switch Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: convertToRoute
                              ? primaryEmerald
                              : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                          width: convertToRoute ? 1.8 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: convertToRoute
                                  ? primaryEmerald.withValues(alpha: 0.15)
                                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.alt_route_rounded,
                              color: convertToRoute ? primaryEmerald : subColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Convert to Route",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: titleColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Automatically convert task to a standard route",
                                  style: TextStyle(fontSize: 12, color: subColor),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: convertToRoute,
                            activeTrackColor: primaryEmerald,
                            onChanged: (val) {
                              setModalState(() {
                                convertToRoute = val;
                                if (val && pointsController.text.trim().isEmpty) {
                                  pointsController.text = "30";
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Reward Points Input
                    TextField(
                      controller: pointsController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Reward Points",
                        hintText: "e.g. 30 or 50",
                        labelStyle: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w600),
                        prefixIcon: const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 20),
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Verification Remarks
                    TextField(
                      controller: remarksController,
                      style: TextStyle(color: titleColor, fontWeight: FontWeight.w600, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Verification Remarks",
                        hintText: "e.g. Task completed satisfactorily",
                        labelStyle: TextStyle(color: subColor, fontSize: 13, fontWeight: FontWeight.w600),
                        prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF6366F1), size: 20),
                        filled: true,
                        fillColor: inputBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: Text("Cancel", style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                            label: const Text("Verify Task", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryEmerald,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () async {
                              final pointsVal = int.tryParse(pointsController.text.trim()) ?? 30;
                              final remarksVal = remarksController.text.trim();
                              final success = await ref.read(driverTaskStoreProvider).updateTask(taskId, {
                                "status": "VERIFIED",
                                "convert_to_route": convertToRoute,
                                "points": pointsVal,
                                "remarks": remarksVal.isNotEmpty ? remarksVal : "Verified by Admin",
                              });
                              if (ctx.mounted && success) {
                                Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(convertToRoute
                                          ? "Task verified & converted to route!"
                                          : "Task verified with $pointsVal reward points!"),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
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

  /// Confirmation Bottom Sheet Modal for Delete / Cancel Actions
  void _showConfirmActionModal({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmButtonText,
    required IconData icon,
    required Color color,
    required VoidCallback onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
        final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Container(
          padding: EdgeInsets.only(
            top: 16,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: subColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text("Keep Task", style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(icon, color: Colors.white, size: 18),
                      label: Text(confirmButtonText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onConfirm();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTaskActionDialog(BuildContext context, Map<String, dynamic> task) {
    final taskId = task['id'];
    final status = (task['status'] ?? 'ASSIGNED').toString().toUpperCase();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'] ?? "Task Options",
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text("Status: $status", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                const Divider(height: 24),

                // Transfer Driver
                if (status == 'ASSIGNED')
                  ListTile(
                    leading: const Icon(Icons.swap_horiz_rounded, color: Colors.indigo),
                    title: const Text("Transfer Driver (cURL #1 / #3)"),
                    subtitle: const Text("Reassign task to available driver"),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showTransferDriverDialog(context, task);
                    },
                  ),

                // Update Locations
                ListTile(
                  leading: const Icon(Icons.edit_location_alt_rounded, color: Colors.teal),
                  title: const Text("Update Locations (Outer vs Campus)"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showUpdateLocationsDialog(context, task);
                  },
                ),

                // Verify Task (Unified option with Convert to Route toggle)
                ListTile(
                  leading: const Icon(Icons.verified_rounded, color: Color(0xFF10B981)),
                  title: const Text("Verify Task"),
                  subtitle: const Text("Approve task, set points & option to convert to route"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showUnifiedVerifyTaskModal(context, task);
                  },
                ),

                // Cancel Task (9)
                ListTile(
                  leading: const Icon(Icons.cancel_outlined, color: Colors.orange),
                  title: const Text("Cancel Task"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showConfirmActionModal(
                      context: context,
                      title: "Cancel Task?",
                      message: "Are you sure you want to cancel this driver task? This will set the task status to CANCELLED.",
                      confirmButtonText: "Yes, Cancel Task",
                      icon: Icons.cancel_outlined,
                      color: const Color(0xFFF97316),
                      onConfirm: () async {
                        final success = await ref.read(driverTaskStoreProvider).cancelTask(taskId, reason: "Cancelled by Admin");
                        if (context.mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Task cancelled")),
                          );
                        }
                      },
                    );
                  },
                ),

                // Delete Task
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  title: const Text("Delete Task"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showConfirmActionModal(
                      context: context,
                      title: "Delete Task?",
                      message: "Are you sure you want to permanently delete this task? This action cannot be undone.",
                      confirmButtonText: "Yes, Delete Task",
                      icon: Icons.delete_forever_rounded,
                      color: const Color(0xFFEF4444),
                      onConfirm: () async {
                        final success = await ref.read(driverTaskStoreProvider).deleteTask(taskId);
                        if (context.mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Task deleted")),
                          );
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);

    final taskStore = ref.watch(driverTaskStoreProvider);
    final tasks = taskStore.tasks;
    final availableDrivers = taskStore.availableDrivers;

    final List<Map<String, dynamic>> filteredTasks = tasks.where((t) {
      final status = getEffectiveTaskStatus(t);
      if (_selectedStatusFilter != 'ALL' && status != _selectedStatusFilter) return false;
      final q = _searchController.text.toLowerCase().trim();
      if (q.isNotEmpty) {
        final title = (t['title'] ?? '').toString().toLowerCase();
        final desc = (t['description'] ?? '').toString().toLowerCase();
        return title.contains(q) || desc.contains(q);
      }
      return true;
    }).toList();

      return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Driver Tasks",
          style: GoogleFonts.outfit(color: titleColor, fontWeight: FontWeight.w900, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.people_alt_rounded, color: primaryBlue),
            tooltip: "Driver Availability",
            onPressed: () => _showDriverAvailabilityModal(context),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: primaryBlue),
            onPressed: () {
              taskStore.fetchAllTasks(isRefresh: true);
              taskStore.fetchAvailableDrivers();
            },
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          backgroundColor: primaryBlue,
          elevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          label: const Text("Create Task", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
          onPressed: () => _showCreateTaskDialog(context),
        ),
      ),
      body: Column(
        children: [
          // Driver Availability Banner Card
          InkWell(
            onTap: () => _showDriverAvailabilityModal(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryBlue.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Drivers Status: ${availableDrivers.where((d) => (d['status'] ?? '').toString().toUpperCase() == 'AVAILABLE').length} Available",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: titleColor),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text("View All", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: primaryBlue)),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 18, color: primaryBlue),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Search driver tasks...",
                hintStyle: TextStyle(color: subColor, fontWeight: FontWeight.normal, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: subColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.cancel_rounded, color: subColor, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // Status Filter Horizontal Chips Row
          _buildFilterChipsRow(tasks, primaryBlue, titleColor, subColor, isDark),

          // Task List
          Expanded(
            child: taskStore.isLoading && tasks.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredTasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined, size: 48, color: subColor.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text(
                              "No driver tasks found",
                              style: TextStyle(color: subColor, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => taskStore.fetchAllTasks(isRefresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, index) {
                            final task = filteredTasks[index];
                            final dynamic taskId = task['id'];
                            final String status = getEffectiveTaskStatus(task);
                            final String title = task['title'] ?? 'Driver Task';
                            final String desc = task['description'] ?? '';
                            final String fromLoc = task['from_location'] ?? '';
                            final String toLoc = task['to_location'] ?? '';
                            final String inCampus = task['in_campus'] ?? '';
                            final String locName = task['location_name'] ?? 'Main Bunk';

                            final driverObj = task['driver'] ?? task['assigned_driver'];
                            final String driverName = driverObj is Map ? (driverObj['name'] ?? driverObj['user']?['name'] ?? 'Assigned Driver').toString() : (task['driver_id'] != null ? "Driver #${task['driver_id']}" : "Unassigned");

                            final vehicleObj = task['vehicle'];
                            final String vehicleNo = vehicleObj is Map ? (vehicleObj['vehicle_number'] ?? 'Vehicle 56').toString() : (task['vehicle_id'] != null ? "Vehicle #${task['vehicle_id']}" : "Vehicle 56");

                            final tt = task['task_type'] ?? task['taskType'];
                            final String taskType = tt is Map ? (tt['name'] ?? tt['category_name'] ?? '').toString() : '';
                            final taskTheme = getTaskThemeInfo(title, taskType);

                            return InkWell(
                              onTap: () {
                                if (taskId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DriverTaskDetailsPage(
                                        taskId: taskId,
                                        initialTaskData: task,
                                      ),
                                    ),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: status == 'OVERDUE'
                                        ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                                        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header Row: Icon + Title + Status Badge
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: taskTheme.bgTint,
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Icon(taskTheme.icon, color: taskTheme.color, size: 22),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: titleColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (desc.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  desc,
                                                  style: TextStyle(fontSize: 12, color: subColor),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildStatusBadge(status),
                                      ],
                                    ),
                                    const SizedBox(height: 14),

                                    // Location & Vehicle Details
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                inCampus.isNotEmpty ? Icons.location_city_rounded : Icons.location_on_rounded,
                                                size: 15,
                                                color: taskTheme.color,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  inCampus.isNotEmpty
                                                      ? "Campus: $inCampus"
                                                      : (fromLoc.isNotEmpty || toLoc.isNotEmpty ? "$fromLoc ➔ $toLoc" : locName),
                                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: titleColor),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(Icons.directions_bus_rounded, size: 15, color: subColor),
                                              const SizedBox(width: 6),
                                              Text(
                                                vehicleNo,
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subColor),
                                              ),
                                              const SizedBox(width: 16),
                                              Icon(Icons.person_rounded, size: 15, color: subColor),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  driverName,
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subColor),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
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

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
    Color text = const Color(0xFF3B82F6);

    switch (status) {
      case 'COMPLETED':
        bg = const Color(0xFF10B981).withValues(alpha: 0.12);
        text = const Color(0xFF10B981);
        break;
      case 'STARTED':
      case 'ON_TRIP':
      case 'IN_PROGRESS':
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        text = const Color(0xFFF59E0B);
        break;
      case 'OVERDUE':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
        text = const Color(0xFFEF4444);
        break;
      case 'VERIFIED':
        bg = const Color(0xFF8B5CF6).withValues(alpha: 0.12);
        text = const Color(0xFF8B5CF6);
        break;
      case 'CANCELLED':
        bg = const Color(0xFFEF4444).withValues(alpha: 0.12);
        text = const Color(0xFFEF4444);
        break;
      default:
        bg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
        text = const Color(0xFF3B82F6);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: text, letterSpacing: 0.3),
      ),
    );
  }

  Widget _buildFilterChipsRow(List<Map<String, dynamic>> allTasks, Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    final filters = ['ALL', 'ASSIGNED', 'STARTED', 'OVERDUE', 'COMPLETED', 'VERIFIED', 'CANCELLED'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedStatusFilter == f;
          int count = 0;
          if (f == 'ALL') {
            count = allTasks.length;
          } else {
            count = allTasks.where((t) => getEffectiveTaskStatus(t) == f).length;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              showCheckmark: false,
              label: Text("$f ($count)"),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : titleColor,
              ),
              selected: isSelected,
              selectedColor: primaryBlue,
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              side: BorderSide(
                color: isSelected ? primaryBlue : (isDark ? Colors.white10 : Colors.black12),
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedStatusFilter = f);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showDriverSearchPickerModal({
    required BuildContext context,
    required List<Map<String, dynamic>> availableDrivers,
    required int? selectedDriverId,
    required Function(int driverId) onSelect,
  }) {
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
            final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
            final primaryBlue = const Color(0xFF6366F1);

            final query = searchController.text.toLowerCase().trim();
            final filteredDrivers = availableDrivers.where((d) {
              if (query.isEmpty) return true;
              final name = (d['name'] ?? '').toString().toLowerCase();
              final phone = (d['phone'] ?? '').toString().toLowerCase();
              final status = (d['status'] ?? '').toString().toLowerCase();
              return name.contains(query) || phone.contains(query) || status.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.only(
                top: 16,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Select Driver",
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                            ),
                          ),
                          Text(
                            "Search and select available fleet driver",
                            style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.close_rounded, color: titleColor, size: 18),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  TextField(
                    controller: searchController,
                    onChanged: (_) => setPickerState(() {}),
                    style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Search driver by name or status...",
                      hintStyle: TextStyle(color: subColor, fontWeight: FontWeight.normal, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: primaryBlue),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.cancel_rounded, color: subColor, size: 18),
                              onPressed: () {
                                searchController.clear();
                                setPickerState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Drivers List
                  Expanded(
                    child: filteredDrivers.isEmpty
                        ? Center(
                            child: Text(
                              "No drivers found matching search",
                              style: TextStyle(color: subColor, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredDrivers.length,
                            itemBuilder: (context, index) {
                              final d = filteredDrivers[index];
                              final int driverId = d['id'];
                              final String name = d['name'] ?? "Driver #$driverId";
                              final String status = (d['status'] ?? 'AVAILABLE').toString().toUpperCase();
                              final bool isAvailable = status == 'AVAILABLE';
                              final bool isSelected = selectedDriverId == driverId;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primaryBlue.withValues(alpha: 0.12)
                                      : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? primaryBlue
                                        : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                                    width: isSelected ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Opacity(
                                  opacity: isAvailable ? 1.0 : 0.55,
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    child: InkWell(
                                      onTap: () {
                                        if (!isAvailable) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text("Driver '$name' is currently $status and cannot be assigned to tasks."),
                                              backgroundColor: Colors.red.shade700,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                          return;
                                        }
                                        onSelect(driverId);
                                        Navigator.pop(modalCtx);
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: isAvailable ? const Color(0x1F10B981) : const Color(0x1FF59E0B),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                isAvailable ? Icons.person_rounded : Icons.lock_rounded,
                                                color: isAvailable ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      color: titleColor,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    isAvailable
                                                        ? "ID: #$driverId ${d['phone'] != null ? '• ${d['phone']}' : ''}"
                                                        : "Currently Busy • Unavailable for assignment",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isAvailable ? subColor : Colors.red.shade400,
                                                      fontWeight: isAvailable ? FontWeight.w500 : FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            // Status Pill Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: isAvailable ? const Color(0x1F10B981) : const Color(0x1FF59E0B),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                isAvailable ? "AVAILABLE" : "🔒 $status",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: isAvailable ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ),
                                            if (isSelected) ...[
                                              const SizedBox(width: 10),
                                              Icon(Icons.check_circle_rounded, color: primaryBlue, size: 20),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
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
}
