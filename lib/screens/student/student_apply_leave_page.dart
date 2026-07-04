import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tripzo/store/student_leave_store.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/utils/toast_utils.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';

class StudentApplyLeavePage extends StatefulWidget {
  const StudentApplyLeavePage({super.key});

  @override
  State<StudentApplyLeavePage> createState() => _StudentApplyLeavePageState();
}

class _StudentApplyLeavePageState extends State<StudentApplyLeavePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedShift;
  String? _selectedLeaveType;

  final List<String> shifts = ['MORNING', 'EVENING', 'BOTH'];
  final List<String> leaveTypes = ['Sick Leave', 'General leave'];

  final Color primaryBlue = const Color(0xFF6366F1);

  Future<void> _pickDate() async {
    final DateTime? picked = await CustomDateTimePicker.show(
      context,
      initialDate: _selectedDate ?? DateTime.now(),
      minDate: DateTime.now(),
      showTime: false,
      accent: primaryBlue,
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        useStudentLeaveStore.resetLeavesError();
      });
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
                        isTamil ? "தேதி" : "Leave Date",
                        titleColor,
                      ),
                      const SizedBox(height: 16),
                      _buildDateSelector(cardColor, titleColor, isTamil),

                      const SizedBox(height: 32),
                      _buildSectionTitle(
                        isTamil ? "ஷிப்ட் வகை" : "Shift Type",
                        titleColor,
                      ),
                      const SizedBox(height: 16),
                      _buildShiftChips(cardColor, titleColor, isTamil),

                      const SizedBox(height: 32),
                      _buildSectionTitle(
                        isTamil ? "விடுப்பு வகை" : "Leave Type",
                        titleColor,
                      ),
                      const SizedBox(height: 16),
                      _buildLeaveTypeDropdown(cardColor, titleColor, isTamil),

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
                        listenable: useStudentLeaveStore,
                        builder: (context, child) {
                          if (useStudentLeaveStore.leavesError == null) {
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
                                    useStudentLeaveStore.leavesError!,
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

  Widget _buildDateSelector(Color card, Color txt, bool isTamil) {
    return GestureDetector(
      onTap: _pickDate,
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: primaryBlue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month_rounded, size: 20, color: primaryBlue),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  _selectedDate == null
                      ? (isTamil ? "தேதியைத் தேர்ந்தெடுக்கவும்" : "Select Date")
                      : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: txt,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShiftChips(Color card, Color txt, bool isTamil) {
    return Container(
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
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: shifts.map((shift) {
          final isSelected = _selectedShift == shift;
          return ChoiceChip(
            label: Text(
              shift,
              style: TextStyle(
                color: isSelected ? Colors.white : txt,
                fontWeight: FontWeight.bold,
              ),
            ),
            selected: isSelected,
            selectedColor: primaryBlue,
            backgroundColor: primaryBlue.withValues(alpha: 0.05),
            onSelected: (bool selected) {
              setState(() {
                if (selected) {
                  _selectedShift = shift;
                } else {
                  _selectedShift = null;
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLeaveTypeDropdown(Color card, Color txt, bool isTamil) {
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
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
          items: leaveTypes.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedLeaveType == type
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
                      type,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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

  Widget _buildSubmitButton(bool isTamil) {
    return ListenableBuilder(
      listenable: useStudentLeaveStore,
      builder: (context, child) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: useStudentLeaveStore.isApplying
                ? null
                : () async {
                    if (_formKey.currentState!.validate() &&
                        _selectedDate != null &&
                        _selectedShift != null &&
                        _selectedLeaveType != null) {

                      final success = await useStudentLeaveStore.createLeave(
                        date: DateFormat('yyyy-MM-dd').format(_selectedDate!),
                        shiftType: _selectedShift!,
                        leaveType: _selectedLeaveType!,
                        reason: _reasonController.text,
                      );

                      if (!context.mounted) return;

                      if (success) {
                        showTopToast(
                          context,
                          isTamil
                              ? "விண்ணப்பம் வெற்றிகரமாக சமர்ப்பிக்கப்பட்டது"
                              : "Application Submitted Successfully",
                        );
                        Navigator.pop(context);
                      } else {
                        showTopToast(
                          context,
                          useStudentLeaveStore.leavesError ??
                              (isTamil
                                  ? "பிழை ஏற்பட்டது"
                                  : "An error occurred"),
                          isError: true,
                        );
                      }
                    } else {
                      showTopToast(
                        context,
                        isTamil
                            ? "அனைத்து விவரங்களையும் பூர்த்தி செய்யவும்"
                            : "Please fill all details",
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
            child: useStudentLeaveStore.isApplying
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
