import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class CustomDateTimePicker {
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDate,
    DateTime? minDate,
    DateTime? maxDate,
    bool showTime = true,
    Color? accent,
    Color? cardColor,
    Color? titleColor,
    Color? subTitleColor,
  }) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryBlue = accent ?? const Color(0xFF6366F1);
    final Color cColor = cardColor ?? (isDark ? const Color(0xFF0F172A).withOpacity(0.8) : Colors.white.withOpacity(0.8));
    final Color tColor = titleColor ?? (isDark ? Colors.white : const Color(0xFF0F172A));
    final Color sTitleColor = subTitleColor ?? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomDateTimePickerSheet(
        initialDate: initialDate,
        minDate: minDate,
        maxDate: maxDate,
        showTime: showTime,
        accent: primaryBlue,
        cardColor: cColor,
        titleColor: tColor,
        subTitleColor: sTitleColor,
      ),
    );
  }
}

class CustomDateTimePickerSheet extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime? minDate;
  final DateTime? maxDate;
  final bool showTime;
  final Color accent;
  final Color cardColor;
  final Color titleColor;
  final Color subTitleColor;

  const CustomDateTimePickerSheet({
    super.key,
    this.initialDate,
    this.minDate,
    this.maxDate,
    required this.showTime,
    required this.accent,
    required this.cardColor,
    required this.titleColor,
    required this.subTitleColor,
  });

  @override
  State<CustomDateTimePickerSheet> createState() => _CustomDateTimePickerSheetState();
}

class _CustomDateTimePickerSheetState extends State<CustomDateTimePickerSheet>
    with SingleTickerProviderStateMixin {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  late int _selectedHour;
  late int _selectedMinute;
  late bool _isAM;

  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final init = widget.initialDate ?? now;

    _selectedDay = DateTime(init.year, init.month, init.day);
    _focusedMonth = DateTime(init.year, init.month);

    final int h24 = init.hour;
    _isAM = h24 < 12;
    _selectedHour = h24 == 0 ? 12 : h24 > 12 ? h24 - 12 : h24;
    _selectedMinute = init.minute;

    _hourCtrl = FixedExtentScrollController(initialItem: _selectedHour - 1);
    _minuteCtrl = FixedExtentScrollController(initialItem: _selectedMinute);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  DateTime _buildResult() {
    if (!widget.showTime) {
      return _selectedDay;
    }
    int h24 = _selectedHour;
    if (_isAM) {
      if (h24 == 12) h24 = 0;
    } else {
      if (h24 != 12) h24 += 12;
    }
    return DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      h24,
      _selectedMinute,
    );
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
  int _firstWeekday(int year, int month) => DateTime(year, month, 1).weekday % 7;

  bool _isBeforeMin(DateTime day) {
    final min = widget.minDate ?? DateTime(1900);
    final minDay = DateTime(min.year, min.month, min.day);
    return day.isBefore(minDay);
  }

  bool _isAfterMax(DateTime day) {
    if (widget.maxDate == null) return false;
    final max = widget.maxDate!;
    final maxDay = DateTime(max.year, max.month, max.day);
    return day.isAfter(maxDay);
  }

  bool get _isValid {
    final res = _buildResult();
    if (widget.minDate != null && res.isBefore(widget.minDate!)) return false;
    if (widget.maxDate != null && res.isAfter(widget.maxDate!)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);

    return ScaleTransition(
      scale: _scaleAnim,
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            decoration: BoxDecoration(
              color: widget.cardColor,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 10)),
              ],
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: widget.subTitleColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: widget.accent.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(Icons.event_note_rounded, color: widget.accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.showTime ? "Select Schedule" : "Choose Date",
                            style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: widget.titleColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCalendar(),
                  if (widget.showTime) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Divider(height: 1, color: dividerColor),
                    ),
                    _buildTimePicker(isDark),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(height: 1, color: dividerColor),
                  ),
                  _buildActions(),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final daysCount = _daysInMonth(year, month);
    final startWeekday = _firstWeekday(year, month);
    final monthLabel = DateFormat('MMMM yyyy').format(_focusedMonth);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navBtn(Icons.arrow_back_ios_new_rounded, () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1))),
              Text(monthLabel, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: widget.titleColor)),
              _navBtn(Icons.arrow_forward_ios_rounded, () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'].map((d) => Expanded(child: Center(child: Text(d, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: widget.subTitleColor.withOpacity(0.5), letterSpacing: 0.5))))).toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: startWeekday + daysCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
            itemBuilder: (_, index) {
              if (index < startWeekday) return const SizedBox.shrink();
              final day = index - startWeekday + 1;
              final date = DateTime(year, month, day);
              final isToday = date == today;
              final isSelected = date == _selectedDay;
              final disabled = _isBeforeMin(date) || _isAfterMax(date);
              
              return GestureDetector(
                onTap: disabled ? null : () => setState(() => _selectedDay = date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    gradient: isSelected ? LinearGradient(colors: [widget.accent, widget.accent.withBlue(255)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                    color: isSelected ? null : (isToday ? widget.accent.withOpacity(0.12) : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: isToday && !isSelected ? Border.all(color: widget.accent.withOpacity(0.3), width: 1.5) : null,
                    boxShadow: isSelected ? [BoxShadow(color: widget.accent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
                  ),
                  child: Center(
                    child: Text('$day', style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: disabled ? widget.subTitleColor.withOpacity(0.2) : (isSelected ? Colors.white : (isToday ? widget.accent : widget.titleColor)))),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: widget.accent.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 16, color: widget.accent),
      ),
    );
  }

  Widget _buildTimePicker(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 18, color: widget.accent.withOpacity(0.6)),
              const SizedBox(width: 8),
              Text("Set Time", style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700, color: widget.titleColor)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isValid 
                        ? [widget.accent.withOpacity(0.15), widget.accent.withOpacity(0.05)]
                        : [Colors.red.withOpacity(0.15), Colors.red.withOpacity(0.05)]
                  ), 
                  borderRadius: BorderRadius.circular(10), 
                  border: Border.all(color: _isValid ? widget.accent.withOpacity(0.1) : Colors.red.withOpacity(0.3))
                ), 
                child: Text(
                  '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')} ${_isAM ? 'AM' : 'PM'}', 
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, 
                    fontWeight: FontWeight.w800, 
                    color: _isValid ? widget.accent : Colors.red, 
                    letterSpacing: 0.5
                  )
                )
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              children: [
                Expanded(child: _wheelSpinner(count: 12, controller: _hourCtrl, labelBuilder: (i) => '${i + 1}'.padLeft(2, '0'), onChanged: (i) => setState(() => _selectedHour = i + 1), isDark: isDark)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(":", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: widget.accent.withOpacity(0.3)))),
                Expanded(child: _wheelSpinner(count: 60, controller: _minuteCtrl, labelBuilder: (i) => '$i'.padLeft(2, '0'), onChanged: (i) => setState(() => _selectedMinute = i), isDark: isDark)),
                const SizedBox(width: 16),
                _buildAmPmToggle(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wheelSpinner({required int count, required FixedExtentScrollController controller, required String Function(int) labelBuilder, required ValueChanged<int> onChanged, required bool isDark}) {
    return Stack(
      children: [
        Center(child: Container(height: 44, decoration: BoxDecoration(color: widget.accent.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: widget.accent.withOpacity(0.15), width: 1)))),
        ListWheelScrollView.useDelegate(
          controller: controller, itemExtent: 44, perspective: 0.006, diameterRatio: 1.4, physics: const FixedExtentScrollPhysics(), onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(childCount: count, builder: (_, index) {
            final isSelected = controller.hasClients && controller.selectedItem == index;
            return Center(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 200), style: GoogleFonts.plusJakartaSans(fontSize: isSelected ? 22 : 16, fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500, color: isSelected ? widget.accent : widget.subTitleColor.withOpacity(0.4)), child: Text(labelBuilder(index))));
          }),
        ),
      ],
    );
  }

  Widget _buildAmPmToggle(bool isDark) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [_amPmChip('AM', _isAM, isDark), const SizedBox(height: 10), _amPmChip('PM', !_isAM, isDark)]);
  }

  Widget _amPmChip(String label, bool active, bool isDark) {
    return GestureDetector(
      onTap: () { if (!active) setState(() => _isAM = label == 'AM'); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic, width: 60, height: 48,
        decoration: BoxDecoration(
          gradient: active ? LinearGradient(colors: [widget.accent, widget.accent.withBlue(255)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          color: active ? null : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: active ? [BoxShadow(color: widget.accent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Center(child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: active ? Colors.white : widget.subTitleColor, letterSpacing: 0.5))),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Expanded(child: TextButton(onPressed: () => Navigator.pop(context), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: widget.subTitleColor.withOpacity(0.15)))), child: Text("Dismiss", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: widget.subTitleColor.withOpacity(0.7), fontSize: 15)))),
          const SizedBox(width: 16),
          Expanded(child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: widget.accent.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6))]),
            child: ElevatedButton(
              onPressed: () {
                if (!_isValid) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Selected time is out of allowed range"),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, _buildResult());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isValid ? widget.accent : widget.accent.withOpacity(0.3), 
                foregroundColor: Colors.white, 
                padding: const EdgeInsets.symmetric(vertical: 18), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), 
                elevation: 0
              ),
              child: Text("Confirm", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5))
            ),
          )),
        ],
      ),
    );
  }
}
