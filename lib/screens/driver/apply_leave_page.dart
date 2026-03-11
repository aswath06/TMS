import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tms/store/driver_store.dart';
import 'package:tms/store/istamil.dart';
import 'package:tms/store/request_store.dart';
import 'package:tms/store/user_store.dart';

class ApplyLeavePage extends StatefulWidget {
  const ApplyLeavePage({super.key});

  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  final Color primaryBlue = const Color(0xFF6366F1);
  
  @override
  void initState() {
    super.initState();
    // Ensure profile is loaded for ID
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (DriverStore().profileData.value == null) {
        DriverStore().fetchProfile();
      }
    });
  }

  // --- Helper: Calculate Days Difference ---
  String _getDaysDifference(bool isTamil) {
    if (_startDate == null || _endDate == null) return "";

    final difference = _endDate!.difference(_startDate!).inDays;
    // We add 1 to include the partial/starting day in the count
    final totalDays = difference < 0 ? 0 : difference + 1;

    if (isTamil) {
      return "$totalDays நாட்கள்";
    }
    return "$totalDays ${totalDays == 1 ? 'Day' : 'Days'}";
  }

  Future<void> _pickDateTime(BuildContext context, bool isStart) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: ColorScheme.light(primary: primaryBlue)),
        child: child!,
      ),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          final fullDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          if (isStart) {
            _startDate = fullDateTime;
          } else {
            _endDate = fullDateTime;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTamil = LanguageStore.isTamil;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, titleColor, isTamil),
                      const SizedBox(height: 32),

                      _buildSectionTitle(
                        isTamil ? "கால அளவு" : "Leave Duration",
                        titleColor,
                      ),
                      const SizedBox(height: 16),

                      // --- Date Selection Area ---
                      _buildDateSelectionArea(
                        cardColor,
                        titleColor,
                        subTitleColor,
                        isTamil,
                      ),

                      const SizedBox(height: 32),

                      _buildSectionTitle(
                        isTamil ? "காரணம்" : "Reason for Leave",
                        titleColor,
                      ),
                      const SizedBox(height: 16),
                      _inputField(
                        isTamil
                            ? "இங்கே விவரிக்கவும்..."
                            : "Describe your reason here...",
                        Icons.notes_rounded,
                        cardColor,
                        titleColor,
                        max: 4,
                        controller: _reasonController,
                        isTamil: isTamil,
                      ),

                      const SizedBox(height: 40),
                      _buildSubmitButton(isTamil),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectionArea(
    Color card,
    Color txt,
    Color sub,
    bool isTamil,
  ) {
    return Column(
      children: [
        _splitDateTile(
          isTamil ? "தொடக்கம்" : "From Date",
          _startDate,
          () => _pickDateTime(context, true),
          card,
          txt,
          sub,
        ),

        // --- Duration Indicator ---
        if (_startDate != null && _endDate != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Divider(
                    color: primaryBlue.withOpacity(0.2),
                    thickness: 1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryBlue.withOpacity(0.3)),
                  ),
                  child: Text(
                    _getDaysDifference(isTamil),
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: primaryBlue.withOpacity(0.2),
                    thickness: 1,
                  ),
                ),
              ],
            ),
          )
        else
          const SizedBox(height: 12),

        _splitDateTile(
          isTamil ? "முடிவு" : "To Date",
          _endDate,
          () => _pickDateTime(context, false),
          card,
          txt,
          sub,
        ),
      ],
    );
  }

  Widget _splitDateTile(
    String label,
    DateTime? dateTime,
    VoidCallback onTap,
    Color card,
    Color txt,
    Color sub,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: sub,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Date Container
                Expanded(
                  flex: 2,
                  child: _dateTimeBox(
                    Icons.calendar_month_rounded,
                    dateTime == null
                        ? (LanguageStore.isTamil ? "தேதி" : "Date")
                        : DateFormat('dd MMM, yyyy').format(dateTime),
                    txt,
                  ),
                ),
                const SizedBox(width: 10),
                // Time Container
                Expanded(
                  flex: 1,
                  child: _dateTimeBox(
                    Icons.access_time_rounded,
                    dateTime == null
                        ? (LanguageStore.isTamil ? "நேரம்" : "Time")
                        : DateFormat('hh:mm a').format(dateTime),
                    txt,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateTimeBox(IconData icon, String value, Color txt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryBlue.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: primaryBlue),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: txt,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- Reuse Standard Components ---

  Widget _buildHeader(BuildContext context, Color titleColor, bool isTamil) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
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
                Text(
                  isTamil ? "நிர்வாகம்" : "ADMINISTRATION",
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isTamil ? "விடுப்பு விண்ணப்பம்" : "Apply Leave",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: titleColor.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.edit_calendar_outlined,
            color: titleColor.withOpacity(0.6),
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color titleColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
      ],
    );
  }

  Widget _inputField(
    String h,
    IconData i,
    Color c,
    Color t, {
    int max = 1,
    TextEditingController? controller,
    required bool isTamil,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: max,
        style: TextStyle(color: t, fontSize: 14, fontWeight: FontWeight.w600),
        validator: (value) => (value == null || value.isEmpty)
            ? (isTamil ? "தேவை" : "Required")
            : null,
        decoration: InputDecoration(
          hintText: h,
          hintStyle: TextStyle(color: t.withOpacity(0.4), fontSize: 13),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(i, size: 18, color: primaryBlue),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 20,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool isTamil) {
    return Consumer<RequestStore>(
      builder: (context, store, child) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: store.isLoadingLeaves ? null : () async {
              if (_formKey.currentState!.validate() &&
                  _startDate != null &&
                  _endDate != null) {
                
                final String fromDate = DateFormat('yyyy-MM-dd').format(_startDate!);
                final String toDate = DateFormat('yyyy-MM-dd').format(_endDate!);
                final String startTime = DateFormat('HH:mm').format(_startDate!);
                final String endTime = DateFormat('HH:mm').format(_endDate!);

                // Get current user ID from DriverStore profile data
                final profile = DriverStore().profileData.value;
                final int driverId = profile?['id'] ?? 0;

                final success = await store.createLeave(
                  driverId: driverId,
                  fromDate: fromDate,
                  toDate: toDate,
                  startTime: startTime,
                  endTime: endTime,
                  leaveType: 4, // Default to 'Other' for driver self-apply, or add picker
                  reason: _reasonController.text,
                );

                if (success && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isTamil ? "விண்ணப்பம் வெற்றிகரமாக சமர்ப்பிக்கப்பட்டது" : "Application Submitted Successfully")),
                  );
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(store.leavesErrorMessage ?? (isTamil ? "பிழை ஏற்பட்டது" : "An error occurred"))),
                  );
                }
              } else if (_startDate == null || _endDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isTamil ? "தேதியைத் தேர்ந்தெடுக்கவும்" : "Please select dates-time")),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: store.isLoadingLeaves 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(
                  isTamil ? "விண்ணப்பிக்கவும்" : "SUBMIT APPLICATION",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
          ),
        );
      }
    );
  }

  Widget _buildBackgroundDecor(bool isDark) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: primaryBlue.withOpacity(isDark ? 0.1 : 0.05),
            ),
          ),
          Positioned(
            bottom: 0,
            left: -50,
            child: CircleAvatar(
              radius: 120,
              backgroundColor: const Color(
                0xFFEC4899,
              ).withOpacity(isDark ? 0.08 : 0.04),
            ),
          ),
        ],
      ),
    );
  }
}
