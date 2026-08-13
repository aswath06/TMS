import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripzo/store/providers.dart';

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
      ref.read(driverStoreProvider).fetchProfile();
      ref.read(vehicleStoreProvider).fetchVehicles();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateTaskDialog(BuildContext context) {
    final driverStore = ref.read(driverStoreProvider);
    final vehicleStore = ref.read(vehicleStoreProvider);
    final taskStore = ref.read(driverTaskStoreProvider);

    final titleController = TextEditingController();
    final descController = TextEditingController();
    final locationController = TextEditingController(text: "Main Bunk");
    final latController = TextEditingController(text: "11.0168");
    final lonController = TextEditingController(text: "76.9558");
    final durationController = TextEditingController(text: "60");
    final remarksController = TextEditingController();

    int? selectedDriverId;
    int? selectedVehicleId;
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

            return Container(
              padding: EdgeInsets.only(
                top: 24,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Create Driver Task",
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: "Task Title",
                        hintText: "e.g. Vehicle Cleaning",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: "Description",
                        hintText: "e.g. Clean interior and exterior",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: locationController,
                            decoration: const InputDecoration(
                              labelText: "Location Name",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: durationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Duration (mins)",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remarksController,
                      decoration: const InputDecoration(
                        labelText: "Remarks",
                        hintText: "e.g. Priority task",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          if (titleController.text.trim().isEmpty) return;

                          final body = {
                            "driver_id": selectedDriverId ?? 241,
                            "vehicle_id": selectedVehicleId ?? 56,
                            "task_type_id": selectedTaskTypeId ?? 1,
                            "title": titleController.text.trim(),
                            "description": descController.text.trim(),
                            "location_name": locationController.text.trim(),
                            "latitude": double.tryParse(latController.text) ?? 11.0168,
                            "longitude": double.tryParse(lonController.text) ?? 76.9558,
                            "starts_at": selectedDateTime.toUtc().toIso8601String(),
                            "duration_minutes": int.tryParse(durationController.text) ?? 60,
                            "remarks": remarksController.text.trim(),
                          };

                          final success = await ref.read(driverTaskStoreProvider).createTask(body);
                          if (mounted && success) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Task created successfully!")),
                            );
                          }
                        },
                        child: const Text(
                          "Create Task",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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

  void _showTaskActionDialog(BuildContext context, Map<String, dynamic> task) {
    final taskId = task['id'];
    final status = (task['status'] ?? 'ASSIGNED').toString().toUpperCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final remarksController = TextEditingController();
    final reasonController = TextEditingController();
    final pointsController = TextEditingController(text: "30");

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            task['title'] ?? "Manage Task",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Current Status: $status", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
              const SizedBox(height: 16),
              if (status == 'COMPLETED' || status == 'ASSIGNED') ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.verified_rounded, color: Colors.white),
                  label: const Text("Verify Task (Auto 30 Points & Convert)"),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final success = await ref.read(driverTaskStoreProvider).updateTask(taskId, {
                      "status": "VERIFIED",
                      "convert_to_route": true,
                    });
                    if (mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Task verified and converted to route!")),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                  label: const Text("Direct Verify (With Remarks)"),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final success = await ref.read(driverTaskStoreProvider).verifyTask(taskId, remarks: "Verified by Admin");
                    if (mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Task verified successfully!")),
                      );
                    }
                  },
                ),
              ],
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.cancel_outlined, color: Colors.white),
                label: const Text("Cancel Task"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final success = await ref.read(driverTaskStoreProvider).cancelTask(taskId, reason: "Cancelled by Admin");
                  if (mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Task cancelled")),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                label: const Text("Delete Task"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final success = await ref.read(driverTaskStoreProvider).deleteTask(taskId);
                  if (mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Task deleted")),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskStore = ref.watch(driverTaskStoreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final primaryBlue = const Color(0xFF6366F1);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final query = _searchController.text.toLowerCase().trim();
    List<Map<String, dynamic>> filteredTasks = taskStore.tasks.where((t) {
      if (_selectedStatusFilter != 'ALL') {
        final st = (t['status'] ?? '').toString().toUpperCase();
        if (st != _selectedStatusFilter) return false;
      }
      if (query.isNotEmpty) {
        final title = (t['title'] ?? '').toString().toLowerCase();
        final desc = (t['description'] ?? '').toString().toLowerCase();
        return title.contains(query) || desc.contains(query);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          "Driver Tasks Management",
          style: GoogleFonts.outfit(color: titleColor, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: primaryBlue),
            onPressed: () => ref.read(driverTaskStoreProvider).fetchAllTasks(isRefresh: true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("New Task", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showCreateTaskDialog(context),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: "Search tasks...",
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: taskStore.isLoading && filteredTasks.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredTasks.isEmpty
                    ? Center(
                        child: Text(
                          "No driver tasks found",
                          style: TextStyle(color: subColor, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref.read(driverTaskStoreProvider).fetchAllTasks(isRefresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, index) {
                            final task = filteredTasks[index];
                            final status = (task['status'] ?? 'ASSIGNED').toString().toUpperCase();

                            Color statusColor = primaryBlue;
                            if (status == 'VERIFIED' || status == 'COMPLETED') {
                              statusColor = const Color(0xFF10B981);
                            } else if (status == 'STARTED' || status == 'IN_PROGRESS') {
                              statusColor = const Color(0xFF3B82F6);
                            } else if (status == 'CANCELLED') {
                              statusColor = const Color(0xFFEF4444);
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withValues(alpha: 0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
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
                                        child: Text(
                                          task['title'] ?? 'Driver Task',
                                          style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: titleColor,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (task['description'] != null && task['description'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      task['description'].toString(),
                                      style: TextStyle(color: subColor, fontSize: 13),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.location_on_rounded, size: 16, color: primaryBlue),
                                          const SizedBox(width: 4),
                                          Text(
                                            task['location_name'] ?? 'Main Bunk',
                                            style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.more_vert_rounded),
                                        onPressed: () => _showTaskActionDialog(context, task),
                                      ),
                                    ],
                                  ),
                                ],
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
}
