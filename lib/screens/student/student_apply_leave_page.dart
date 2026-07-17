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

  DateTime? _fromDate;
  DateTime? _toDate;
  String? _selectedShift; // Single day
  String? _fromShift; // Multi day
  String? _toShift; // Multi day
  String? _selectedLeaveType = 'General leave';

  final List<String> shifts = ['MORNING', 'EVENING', 'BOTH'];
  final List<String> halfShifts = ['MORNING', 'EVENING'];
  final List<String> leaveTypes = ['Sick Leave', 'General leave'];

  final Color primaryBlue = const Color(0xFF6366F1);

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime? picked = await CustomDateTimePicker.show(
      context,
      initialDate: _fromDate ?? today,
      minDate: today,
      showTime: false,
      accent: primaryBlue,
    );

    if (picked != null && mounted) {
      setState(() {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
          _toDate = _fromDate;
        }
        useStudentLeaveStore.resetLeavesError();
      });
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime? picked = await CustomDateTimePicker.show(
      context,
      initialDate: _toDate ?? (_fromDate ?? today),
      minDate: _fromDate ?? today,
      showTime: false,
      accent: primaryBlue,
    );

    if (picked != null && mounted) {
      setState(() {
        _toDate = picked;
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
                        isTamil ? "தேதி" : "Availability Date",
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

                      ListenableBuilder(
                        listenable: useStudentLeaveStore,
                        builder: (context, child) {
                          if (useStudentLeaveStore.leavesError == null) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            margin: const EdgeInsets.only(top: 24),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.redAccent.withValues(alpha: 0.1), Colors.redAccent.withValues(alpha: 0.02)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    useStudentLeaveStore.leavesError!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 32),
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
    return Row(
      children: [
        Expanded(child: _buildSingleDateSelector(card, txt, isTamil, true)),
        const SizedBox(width: 16),
        Expanded(child: _buildSingleDateSelector(card, txt, isTamil, false)),
      ],
    );
  }

  Widget _buildSingleDateSelector(Color card, Color txt, bool isTamil, bool isFrom) {
    final date = isFrom ? _fromDate : _toDate;
    final label = isFrom ? (isTamil ? "முதல்" : "From") : (isTamil ? "வரை" : "To");

    return GestureDetector(
      onTap: isFrom ? _pickFromDate : _pickToDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryBlue.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: primaryBlue.withValues(alpha: 0.1), width: 1.5),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: txt.withValues(alpha: 0.6), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: primaryBlue),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    date == null ? "--/--/----" : DateFormat('dd MMM yyyy').format(date),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: txt),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftChips(Color card, Color txt, bool isTamil) {
    final isMultiDay = _fromDate != null && _toDate != null && !_fromDate!.isAtSameMomentAs(_toDate!);

    if (!isMultiDay) {
      return _buildShiftRow(card, txt, isTamil, shifts, _selectedShift, (s) => setState(() => _selectedShift = s), null);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildShiftRow(card, txt, isTamil, halfShifts, _fromShift, (s) => setState(() => _fromShift = s), isTamil ? "முதல் ஷிப்ட்" : "From Shift"),
        const SizedBox(height: 16),
        _buildShiftRow(card, txt, isTamil, halfShifts, _toShift, (s) => setState(() => _toShift = s), isTamil ? "வரை ஷிப்ட்" : "To Shift"),
      ],
    );
  }

  Widget _buildShiftRow(Color card, Color txt, bool isTamil, List<String> options, String? currentValue, Function(String) onSelect, String? label) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: txt.withValues(alpha: 0.7))),
            const SizedBox(height: 12),
          ],
          Row(
            children: options.map((shift) {
              final isSelected = currentValue == shift;
              IconData iconData;
              if (shift == 'MORNING') iconData = Icons.wb_sunny_rounded;
              else if (shift == 'EVENING') iconData = Icons.nights_stay_rounded;
              else iconData = Icons.timelapse_rounded;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(shift),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryBlue : primaryBlue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryBlue.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          iconData,
                          color: isSelected ? Colors.white : primaryBlue.withValues(alpha: 0.6),
                          size: 22,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          shift,
                          style: TextStyle(
                            color: isSelected ? Colors.white : txt.withValues(alpha: 0.7),
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
                isTamil ? "போக்குவரத்து இருப்பு" : "Transport Availability",
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
                    final isMultiDay = _fromDate != null && _toDate != null && !_fromDate!.isAtSameMomentAs(_toDate!);
                    final isValidSingle = !isMultiDay && _fromDate != null && _toDate != null && _selectedShift != null;
                    final isValidMulti = isMultiDay && _fromShift != null && _toShift != null;

                    if (_formKey.currentState!.validate() && (isValidSingle || isValidMulti)) {

                      final success = await useStudentLeaveStore.createLeave(
                        fromDate: DateFormat('yyyy-MM-dd').format(_fromDate!),
                        toDate: DateFormat('yyyy-MM-dd').format(_toDate!),
                        shiftType: isMultiDay ? null : _selectedShift,
                        fromShiftType: isMultiDay ? _fromShift : null,
                        toShiftType: isMultiDay ? _toShift : null,
                        reason: 'Availability update',
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
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: useStudentLeaveStore.isApplying
                      ? [Colors.grey, Colors.grey]
                      : [primaryBlue, const Color(0xFF818CF8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: useStudentLeaveStore.isApplying
                    ? []
                    : [
                        BoxShadow(
                          color: primaryBlue.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Center(
                child: useStudentLeaveStore.isApplying
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        isTamil ? "விண்ணப்பிக்கவும்" : "SUBMIT APPLICATION",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
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
