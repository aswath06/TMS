import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/utils/task_icon_helper.dart';

class DriverTaskDetailsPage extends ConsumerStatefulWidget {
  final dynamic taskId;
  final Map<String, dynamic>? initialTaskData;

  const DriverTaskDetailsPage({
    super.key,
    required this.taskId,
    this.initialTaskData,
  });

  @override
  ConsumerState<DriverTaskDetailsPage> createState() => _DriverTaskDetailsPageState();
}

class _DriverTaskDetailsPageState extends ConsumerState<DriverTaskDetailsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _taskDetails;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _taskDetails = widget.initialTaskData;
    _fetchDetails();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(driverTaskStoreProvider).fetchAvailableDrivers();
    });
  }

  Future<void> _fetchDetails({bool isRefresh = false}) async {
    if (!isRefresh && _taskDetails == null) {
      setState(() => _isLoading = true);
    }
    try {
      final res = await ref.read(driverTaskStoreProvider).getTaskById(widget.taskId);
      if (mounted) {
        setState(() {
          if (res != null) {
            _taskDetails = res;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
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

  /// Admin Task Action Dialog (Manage Task options)
  void _showTaskActionDialog() {
    final task = _taskDetails ?? widget.initialTaskData ?? {};
    final taskId = widget.taskId;
    final status = getEffectiveTaskStatus(task);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgSurface = isDark ? const Color(0xFF1E293B) : Colors.white;
        final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Container(
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: bgSurface,
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
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['title'] ?? "Task Options",
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Manage and configure task details",
                            style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildModalStatusChip(status),
                  ],
                ),
                const SizedBox(height: 20),

                // Transfer Driver (Only for ASSIGNED / PLANNED)
                if (status == 'ASSIGNED' || status == 'PLANNED')
                  _buildActionTile(
                    context: context,
                    title: "Transfer Driver",
                    subtitle: "Reassign task to an available driver",
                    icon: Icons.swap_horiz_rounded,
                    iconColor: const Color(0xFF6366F1),
                    iconBgTint: const Color(0x1F6366F1),
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showTransferDriverDialog(task);
                    },
                  ),

                // Update Locations
                _buildActionTile(
                  context: context,
                  title: "Update Locations",
                  subtitle: "Switch between Outer & In-Campus locations",
                  icon: Icons.edit_location_alt_rounded,
                  iconColor: const Color(0xFF14B8A6),
                  iconBgTint: const Color(0x1F14B8A6),
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showUpdateLocationsDialog(task);
                  },
                ),

                // Verify Task (Unified Option with Convert to Route Toggle)
                _buildActionTile(
                  context: context,
                  title: "Verify Task",
                  subtitle: "Approve task, set points & option to convert to route",
                  icon: Icons.verified_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBgTint: const Color(0x1F10B981),
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showUnifiedVerifyTaskModal(context, task, onSuccess: () => _fetchDetails(isRefresh: true));
                  },
                ),

                // Cancel Task
                _buildActionTile(
                  context: context,
                  title: "Cancel Task",
                  subtitle: "Cancel task and log cancellation reason",
                  icon: Icons.cancel_outlined,
                  iconColor: const Color(0xFFF97316),
                  iconBgTint: const Color(0x1FF97316),
                  isDark: isDark,
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
                        if (mounted && success) {
                          _fetchDetails(isRefresh: true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Task cancelled")),
                            );
                          }
                        }
                      },
                    );
                  },
                ),

                // Delete Task
                _buildActionTile(
                  context: context,
                  title: "Delete Task",
                  subtitle: "Permanently delete task from system",
                  icon: Icons.delete_outline_rounded,
                  iconColor: const Color(0xFFEF4444),
                  iconBgTint: const Color(0x1FEF4444),
                  isDark: isDark,
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
                        if (mounted && success) {
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Task deleted")),
                            );
                          }
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

  Widget _buildModalStatusChip(String status) {
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

  Widget _buildActionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgTint,
    required VoidCallback onTap,
    bool isDark = false,
  }) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBgTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: subColor.withValues(alpha: 0.5), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Update Location Fields Bottom Sheet
  void _showUpdateLocationsDialog(Map<String, dynamic> task) {
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
                            if (mounted && success) {
                              Navigator.pop(ctx);
                              _fetchDetails(isRefresh: true);
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

  /// Transfer Driver Bottom Sheet
  void _showTransferDriverDialog(Map<String, dynamic> task) {
    final taskId = task['id'];
    final availableDrivers = ref.read(driverTaskStoreProvider).availableDrivers;
    int? selectedDriverId = availableDrivers.isNotEmpty ? availableDrivers.first['id'] : task['driver_id'];

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
                            if (mounted && success) {
                              Navigator.pop(ctx);
                              _fetchDetails(isRefresh: true);
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

  /// Unified Verify Task Bottom Sheet Modal (Combines Verify, Points, and Convert to Route)
  void _showUnifiedVerifyTaskModal(BuildContext context, Map<String, dynamic> task, {VoidCallback? onSuccess}) {
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
                                onSuccess?.call();
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

  void _showStartOdometerDialog() {
    final task = _taskDetails ?? widget.initialTaskData ?? {};
    final vehicleObj = task['vehicle'];
    num vehicleOdo = 0;
    if (vehicleObj is Map) {
      vehicleOdo = num.tryParse((vehicleObj['odometer'] ?? vehicleObj['current_odometer'] ?? vehicleObj['last_odometer'] ?? 0).toString()) ?? 0;
    } else if (task['vehicle_odometer'] != null) {
      vehicleOdo = num.tryParse(task['vehicle_odometer'].toString()) ?? 0;
    }

    final odoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgSurface = isDark ? const Color(0xFF1E293B) : Colors.white;
        final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: bgSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  "Start Task Information",
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Please enter the starting details before continuing.",
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: TextField(
                    controller: odoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: titleColor),
                    decoration: InputDecoration(
                      hintText: "Start Odometer",
                      hintStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Icon(Icons.speed_rounded, color: Color(0xFF6366F1), size: 22),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 48),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          "Close",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () async {
                          final odoVal = num.tryParse(odoController.text.trim());
                          if (odoVal == null || odoVal <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please enter a valid Start Odometer reading."),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (vehicleOdo > 0 && odoVal < vehicleOdo) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Start odometer ($odoVal km) cannot be less than vehicle's current odometer ($vehicleOdo km)."),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          final success = await ref.read(driverTaskStoreProvider).startTask(
                            widget.taskId,
                            startOdometer: odoVal,
                          );
                          if (mounted && success) {
                            _fetchDetails(isRefresh: true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Task started with Start Odometer: $odoVal km!"),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          "SUBMIT",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCompleteOdometerDialog() {
    final task = _taskDetails ?? widget.initialTaskData ?? {};
    num startOdo = 0;
    final startOdoRaw = task['start_odometer'] ?? task['startOdometer'];
    if (startOdoRaw != null) {
      startOdo = num.tryParse(startOdoRaw.toString()) ?? 0;
    }

    final vehicleObj = task['vehicle'];
    num vehicleOdo = 0;
    if (vehicleObj is Map) {
      vehicleOdo = num.tryParse((vehicleObj['odometer'] ?? vehicleObj['current_odometer'] ?? vehicleObj['last_odometer'] ?? 0).toString()) ?? 0;
    } else if (task['vehicle_odometer'] != null) {
      vehicleOdo = num.tryParse(task['vehicle_odometer'].toString()) ?? 0;
    }

    final odoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgSurface = isDark ? const Color(0xFF1E293B) : Colors.white;
        final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: bgSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  "Complete Task Information",
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Please enter the ending details before completing.",
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: TextField(
                    controller: odoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: titleColor),
                    decoration: InputDecoration(
                      hintText: "End Odometer",
                      hintStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Icon(Icons.speed_rounded, color: Color(0xFF10B981), size: 22),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 48),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          "Close",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () async {
                          final odoVal = num.tryParse(odoController.text.trim());
                          if (odoVal == null || odoVal <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please enter a valid End Odometer reading."),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (startOdo > 0 && odoVal < startOdo) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("End odometer ($odoVal km) cannot be less than start odometer ($startOdo km)."),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (vehicleOdo > 0 && odoVal < vehicleOdo) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("End odometer ($odoVal km) cannot be less than vehicle's current odometer ($vehicleOdo km)."),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          final success = await ref.read(driverTaskStoreProvider).completeTask(
                            widget.taskId,
                            endOdometer: odoVal,
                          );
                          if (mounted && success) {
                            _fetchDetails(isRefresh: true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Task completed with End Odometer: $odoVal km!"),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          "SUBMIT",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openInMaps(double lat, double lng) async {
    final uri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isTamil = LanguageStore.isTamil;

    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);

    final task = _taskDetails ?? {};
    final String status = getEffectiveTaskStatus(task);
    final String taskNo = task['task_number'] ?? (widget.taskId != null ? "DT-${widget.taskId}" : "DT-TASK");
    final String title = task['title'] ?? (isTamil ? 'ஓட்டுநர் பணி' : 'Driver Task');
    final String description = task['description'] ?? 'No description provided.';
    final String location = (task['location_name'] ?? task['location'] ?? task['place_name'] ?? task['address'] ?? task['site'] ?? 'Main Bunk').toString();
    final String fromLoc = (task['from_location'] ?? task['start_location'] ?? task['pickup_location'] ?? task['from'] ?? task['pickup'] ?? task['source_location'] ?? task['source'] ?? task['route_from'] ?? '').toString();
    final String toLoc = (task['to_location'] ?? task['end_location'] ?? task['destination_location'] ?? task['destination'] ?? task['to'] ?? task['drop_location'] ?? task['drop'] ?? task['route_to'] ?? '').toString();
    final String inCampus = (task['in_campus'] ?? task['campus_location'] ?? task['campus_site'] ?? task['site_name'] ?? task['campus_name'] ?? task['hub_name'] ?? '').toString();

    String startLocationDisplay = fromLoc.isNotEmpty ? fromLoc : location;
    String endLocationDisplay = toLoc.isNotEmpty ? toLoc : description;
    if (inCampus.isNotEmpty) {
      startLocationDisplay = "🏢 In-Campus: $inCampus";
    }
    final String remarks = task['remarks'] ?? 'None';
    final String duration = "${task['duration_minutes'] ?? 60} mins";
    
    final tt = task['task_type'] ?? task['taskType'] ?? task['category'] ?? task['category_name'] ?? task['task_category'];
    String taskType = 'General Task';
    if (tt is Map) {
      taskType = (tt['name'] ?? tt['category_name'] ?? tt['title'] ?? 'General Task').toString();
    } else if (tt != null && tt.toString().isNotEmpty) {
      taskType = tt.toString();
    }

    final v = task['vehicle'];
    final String vehicleNo = v is Map ? (v['vehicle_number'] ?? 'Vehicle 56').toString() : (task['vehicle_id'] != null ? "Vehicle #${task['vehicle_id']}" : (v != null ? "Vehicle #$v" : "Vehicle 56"));

    final ab = task['assigned_by'] ?? task['assignedBy'];
    final String assignedBy = ab is Map ? (ab['name'] ?? 'Admin').toString() : (ab != null ? "Admin #$ab" : 'Admin');

    final double? lat = task['latitude'] != null ? double.tryParse(task['latitude'].toString()) : null;
    final double? lng = task['longitude'] != null ? double.tryParse(task['longitude'].toString()) : null;

    num? startOdo;
    final rawStartOdo = task['start_odometer'] ?? task['start_odo'] ?? task['odometer_start'] ?? task['initial_odometer'] ?? task['start_odometer_reading'] ?? (v is Map ? (v['start_odometer'] ?? v['odometer']) : null);
    if (rawStartOdo != null) {
      startOdo = num.tryParse(rawStartOdo.toString());
    }

    num? endOdo;
    final rawEndOdo = task['end_odometer'] ?? task['end_odo'] ?? task['odometer_end'] ?? task['final_odometer'] ?? task['end_odometer_reading'] ?? (v is Map ? v['end_odometer'] : null);
    if (rawEndOdo != null) {
      endOdo = num.tryParse(rawEndOdo.toString());
    }

    num? distanceKm;
    if (startOdo != null && endOdo != null && endOdo >= startOdo) {
      final diff = endOdo - startOdo;
      distanceKm = num.tryParse(diff.toStringAsFixed(2)) ?? diff;
    }

    final String startsAtStr = task['starts_at'] ?? '';
    String startTimeText = "TBD";
    DateTime? startDateTime;
    if (startsAtStr.isNotEmpty) {
      try {
        startDateTime = DateTime.parse(startsAtStr).toLocal();
        startTimeText = DateFormat('hh:mm a, dd MMM yyyy').format(startDateTime);
      } catch (_) {}
    }

    bool canStart = true;
    String startTimeMessage = "";
    if (startDateTime != null && (status == 'ASSIGNED' || status == 'PLANNED')) {
      final now = DateTime.now();
      if (now.isBefore(startDateTime)) {
        canStart = false;
        startTimeMessage = "Starts at ${DateFormat('hh:mm a').format(startDateTime)}";
      }
    }

    Color statusColor = primaryBlue;
    if (status == 'STARTED' || status == 'IN_PROGRESS') {
      statusColor = const Color(0xFF10B981);
    } else if (status == 'COMPLETED' || status == 'VERIFIED') {
      statusColor = Colors.grey;
    } else if (status == 'CANCELLED' || status == 'OVERDUE') {
      statusColor = const Color(0xFFEF4444);
    }

    final taskTheme = getTaskThemeInfo(title, taskType, "$description $location");

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isTamil ? "பணி விவரங்கள்" : "Task Details",
          style: GoogleFonts.outfit(color: titleColor, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Color(0xFF6366F1)),
            tooltip: "Manage Task Options",
            onPressed: _showTaskActionDialog,
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: primaryBlue),
            onPressed: () => _fetchDetails(isRefresh: true),
          ),
        ],
      ),
      body: _isLoading && _taskDetails == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _fetchDetails(isRefresh: true),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Hero Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.08),
                            blurRadius: 20,
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: taskTheme.bgTint,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(taskTheme.icon, color: taskTheme.color, size: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: GoogleFonts.outfit(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: titleColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      taskType,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: taskTheme.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Stat Grid (2x2)
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatTile(
                            icon: Icons.access_time_filled_rounded,
                            label: "START TIME",
                            value: startTimeText,
                            cardColor: cardColor,
                            titleColor: titleColor,
                            subColor: subColor,
                            accentColor: primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatTile(
                            icon: Icons.timer_rounded,
                            label: "DURATION",
                            value: duration,
                            cardColor: cardColor,
                            titleColor: titleColor,
                            subColor: subColor,
                            accentColor: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatTile(
                            icon: Icons.directions_bus_rounded,
                            label: "VEHICLE",
                            value: vehicleNo,
                            cardColor: cardColor,
                            titleColor: titleColor,
                            subColor: subColor,
                            accentColor: const Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatTile(
                            icon: Icons.admin_panel_settings_rounded,
                            label: "ASSIGNED BY",
                            value: assignedBy,
                            cardColor: cardColor,
                            titleColor: titleColor,
                            subColor: subColor,
                            accentColor: const Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Location & Route Flow Card (In-Campus vs Outer Route Start & End)
                    Builder(
                      builder: (context) {
                        final bool isInCampus = inCampus.isNotEmpty || (fromLoc.isEmpty && toLoc.isEmpty);

                        if (isInCampus) {
                          final String campusLocName = inCampus.isNotEmpty ? inCampus : location;
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                              ),
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
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF6366F1),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "IN-CAMPUS LOCATION",
                                              style: GoogleFonts.outfit(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF6366F1),
                                                letterSpacing: 0.5,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (lat != null && lng != null)
                                      InkWell(
                                        onTap: () => _openInMaps(lat, lng),
                                        child: Row(
                                          children: [
                                            Icon(Icons.map_rounded, size: 16, color: primaryBlue),
                                            const SizedBox(width: 4),
                                            Text(
                                              "Open Map",
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryBlue),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(getLocationOrGoalIcon(campusLocName, isStart: true), color: const Color(0xFF6366F1), size: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "CAMPUS SITE / HUB",
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subColor),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            campusLocName,
                                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: titleColor),
                                          ),
                                          if (lat != null && lng != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              "GPS: $lat, $lng",
                                              style: TextStyle(fontSize: 12, color: subColor),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }

                        final String startLoc = fromLoc.isNotEmpty ? fromLoc : (location.isNotEmpty ? location : "Start Location");
                        final String endLoc = toLoc.isNotEmpty ? toLoc : (fromLoc.isNotEmpty ? "Destination Location" : (location.isNotEmpty ? location : "Destination Location"));

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      "LOCATION & ROUTE FLOW",
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: titleColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (lat != null && lng != null)
                                    InkWell(
                                      onTap: () => _openInMaps(lat, lng),
                                      child: Row(
                                        children: [
                                          Icon(Icons.map_rounded, size: 16, color: primaryBlue),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Open Map",
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryBlue),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Start Location Pin
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(getLocationOrGoalIcon(startLoc, isStart: true), color: Colors.white, size: 16),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "START LOCATION",
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subColor),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          startLoc,
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: titleColor),
                                        ),
                                        if (lat != null && lng != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            "GPS: $lat, $lng",
                                            style: TextStyle(fontSize: 12, color: subColor),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 15, top: 6, bottom: 6),
                                child: Container(
                                  width: 2,
                                  height: 24,
                                  color: primaryBlue.withValues(alpha: 0.3),
                                ),
                              ),
                              // End Location Pin
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(getLocationOrGoalIcon(endLoc, isStart: false), color: Colors.white, size: 16),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "END LOCATION / DESTINATION",
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subColor),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          endLoc,
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: titleColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Odometer & Distance Readings Card (Always Displayed)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0x1F10B981),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.speed_rounded, color: Color(0xFF10B981), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "VEHICLE ODOMETER READINGS",
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: titleColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (distanceKm != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0x1F10B981),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "$distanceKm KM",
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.play_circle_fill_rounded, size: 14, color: Color(0xFF10B981)),
                                          const SizedBox(width: 6),
                                          Text("START ODOMETER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subColor)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        startOdo != null ? "$startOdo km" : "Not Recorded",
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: startOdo != null ? titleColor : subColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.stop_circle_rounded, size: 14, color: Color(0xFFEF4444)),
                                          const SizedBox(width: 6),
                                          Text("END ODOMETER", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subColor)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        endOdo != null ? "$endOdo km" : "Not Recorded",
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: endOdo != null ? titleColor : subColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (distanceKm != null) ...[
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("TOTAL DISTANCE COVERED", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: subColor)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "$distanceKm KM",
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Admin Instructions & Remarks Card (Only shown if remarks exist)
                    if (remarks.isNotEmpty && remarks.toLowerCase() != 'none') ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "ADMIN REMARKS & NOTES",
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              remarks,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: titleColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Admin Management Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.settings_suggest_rounded, color: Color(0xFF6366F1)),
                        label: const Text("Manage Task Options", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _showTaskActionDialog,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bottom Action Button
                    if (status == 'ASSIGNED' || status == 'PLANNED') ...[
                      if (canStart)
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                            label: const Text("Start Task", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _showStartOdometerDialog,
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.lock_clock_rounded, color: Colors.grey, size: 22),
                            label: Text(
                              startTimeMessage.isNotEmpty ? startTimeMessage : "Upcoming Task",
                              style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.withValues(alpha: 0.15),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Task starts at $startTimeText. You can start when the time arrives."),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            },
                          ),
                        ),
                    ] else if (status == 'STARTED' || status == 'IN_PROGRESS') ...[
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                          label: const Text("Complete Task", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _showCompleteOdometerDialog,
                        ),
                      ),
                    ] else if (status == 'VERIFIED') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.verified_rounded, color: Color(0xFF10B981)),
                            SizedBox(width: 8),
                            Text(
                              "Task Completed & Verified",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ),
                    ] else if (status == 'COMPLETED') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                            SizedBox(width: 8),
                            Text(
                              "Task Completed",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.cancel_rounded, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              "Task Cancelled",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color cardColor,
    required Color titleColor,
    required Color subColor,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subColor)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
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
