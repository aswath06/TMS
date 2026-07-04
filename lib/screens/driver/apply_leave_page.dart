import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/utils/toast_utils.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';

class ApplyLeavePage extends StatefulWidget {
  final String userRole;
  const ApplyLeavePage({super.key, this.userRole = 'driver'});

  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedLeaveType; // null until types load

  final Color primaryBlue = const Color(0xFF6366F1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure profile is loaded for ID
      if (DriverStore().profileData.value == null) {
        DriverStore().fetchProfile();
      }
      // Fetch dynamic leave types
      useDriverStore.fetchLeaveTypes().then((_) {
        if (mounted && useDriverStore.leaveTypes.isNotEmpty && _selectedLeaveType == null) {
          setState(() {
            _selectedLeaveType = useDriverStore.leaveTypes.first['id'] as int;
          });
        }
      });
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
    final DateTime initialDate = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? (_startDate?.add(const Duration(days: 1)) ?? DateTime.now()));

    final DateTime? picked = await CustomDateTimePicker.show(
      context,
      initialDate: initialDate,
      minDate: isStart ? DateTime.now() : (_startDate ?? DateTime.now()),
      showTime: true,
      accent: primaryBlue,
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
        useDriverStore.resetLeavesError();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTamil = LanguageStore.isTamil;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isStudent = widget.userRole.toLowerCase() == 'student';

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

                      _buildDateSelectionArea(
                        cardColor,
                        titleColor,
                        subTitleColor,
                        isTamil,
                      ),

                      if (!isStudent) ...[
                        const SizedBox(height: 32),
                        _buildSectionTitle(
                          isTamil ? "விடுப்பு வகை" : "Leave Type",
                          titleColor,
                        ),
                        const SizedBox(height: 16),
                        _buildLeaveTypeSelector(cardColor, titleColor, isTamil),
                      ],

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

                      const SizedBox(height: 32),

                      ListenableBuilder(
                        listenable: useDriverStore,
                        builder: (context, child) {
                          if (useDriverStore.leavesError == null) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    useDriverStore.leavesError!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

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

        if (_startDate != null && _endDate != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Divider(
                    color: primaryBlue.withValues(alpha: 0.2),
                    thickness: 1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryBlue.withValues(alpha: 0.3)),
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
                    color: primaryBlue.withValues(alpha: 0.2),
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
              color: Colors.black.withValues(alpha: 0.02),
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
        color: primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
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

  Widget _buildHeader(BuildContext context, Color titleColor, bool isTamil) {
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
                      isTamil ? "நிர்வாகம்" : "ADMINISTRATION",
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
                isTamil ? "விடுப்பு விண்ணப்பம்" : "Apply Leave",
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
            Icons.edit_calendar_outlined,
            color: titleColor.withValues(alpha: 0.6),
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
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
            overflow: TextOverflow.ellipsis,
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
          hintStyle: TextStyle(color: t.withValues(alpha: 0.4), fontSize: 13),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.1),
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

  Widget _buildLeaveTypeSelector(Color card, Color txt, bool isTamil) {
    return ListenableBuilder(
      listenable: useDriverStore,
      builder: (context, _) {
        // Loading skeleton
        if (useDriverStore.isLoadingLeaveTypes) {
          return Container(
            height: 60,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                ),
              ),
            ),
          );
        }

        final types = useDriverStore.leaveTypes;
        if (types.isEmpty) {
          return Container(
            height: 60,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              isTamil ? 'வகைகள் கிடைக்கவில்லை' : 'No leave types available',
              style: TextStyle(color: txt.withValues(alpha: 0.4), fontSize: 14),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedLeaveType,
              isExpanded: true,
              borderRadius: BorderRadius.circular(16),
              icon: Container(
                margin: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: primaryBlue,
                ),
              ),
              hint: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.event_note_rounded,
                      size: 18,
                      color: primaryBlue,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      isTamil ? 'வகையைத் தேர்ந்தெடுக்கவும்' : 'Select leave type',
                      style: TextStyle(
                        color: txt.withValues(alpha: 0.4),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              style: TextStyle(
                color: txt,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              dropdownColor: card,
              onChanged: (val) {
                if (val != null) setState(() => _selectedLeaveType = val);
              },
              items: types.map((type) {
                final int typeId = type['id'] as int;
                final String label = type['name'] ?? type['code'] ?? '';
                return DropdownMenuItem<int>(
                  value: typeId,
                  child: Row(
                    children: [
                      Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _selectedLeaveType == typeId
                              ? primaryBlue.withValues(alpha: 0.15)
                              : primaryBlue.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.event_note_rounded,
                          size: 18,
                          color: primaryBlue,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: txt,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmitButton(bool isTamil) {
    final bool isStudent = widget.userRole.toLowerCase() == 'student';
    return ListenableBuilder(
      listenable: useDriverStore,
      builder: (context, child) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: useDriverStore.isLoadingLeaves
                ? null
                : () async {
                     if (_formKey.currentState!.validate() &&
                        _startDate != null &&
                        _endDate != null &&
                        (isStudent || _selectedLeaveType != null)) {

                      if (!_endDate!.isAfter(_startDate!)) {
                        showTopToast(
                          context,
                          isTamil
                              ? "முடிவுத் தேதி தொடக்கத் தேதிக்கு பிறகு இருக்க வேண்டும்"
                              : "End date must be after start date",
                          isError: true,
                        );
                        return;
                      }

                      // Build ISO datetime strings matching the API format:
                      // "2026-04-16T10:00:00"
                      String pad(int n) => n.toString().padLeft(2, '0');
                      final String fromDate =
                          "${DateFormat('yyyy-MM-dd').format(_startDate!)}T"
                          "${pad(_startDate!.hour)}:${pad(_startDate!.minute)}:00";
                      final String toDate =
                          "${DateFormat('yyyy-MM-dd').format(_endDate!)}T"
                          "${pad(_endDate!.hour)}:${pad(_endDate!.minute)}:00";

                      final success = await useDriverStore.createLeave(
                        fromDate: fromDate,
                        toDate: toDate,
                        leaveType: isStudent ? 1 : _selectedLeaveType!,
                        reason: _reasonController.text,
                      );

                      if (!context.mounted) return;

                      if (success) {
                        Navigator.pop(context);
                        showTopToast(
                          context,
                          isTamil
                              ? "விண்ணப்பம் வெற்றிகரமாக சமர்ப்பிக்கப்பட்டது"
                              : "Application Submitted Successfully",
                        );
                      } else {
                        showTopToast(
                          context,
                          useDriverStore.leavesError ??
                              (isTamil
                                  ? "பிழை ஏற்பட்டது"
                                  : "An error occurred"),
                          isError: true,
                        );
                      }
                    } else if (_startDate == null || _endDate == null) {
                      showTopToast(
                        context,
                        isTamil
                            ? "தேதியைத் தேர்ந்தெடுக்கவும்"
                            : "Please select dates-time",
                        isError: true,
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
            child: useDriverStore.isLoadingLeaves
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
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
      },
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
              backgroundColor: primaryBlue.withValues(alpha: isDark ? 0.1 : 0.05),
            ),
          ),
          Positioned(
            bottom: 0,
            left: -50,
            child: CircleAvatar(
              radius: 120,
              backgroundColor: const Color(
                0xFFEC4899,
              ).withValues(alpha: isDark ? 0.08 : 0.04),
            ),
          ),
        ],
      ),
    );
  }
}
