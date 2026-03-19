import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDateTimePicker {
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDate,
    DateTime? minDate,
    bool showTime = true,
    Color? accent,
    Color? cardColor,
    Color? titleColor,
    Color? subTitleColor,
  }) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryBlue = accent ?? const Color(0xFF6366F1);
    final Color cColor = cardColor ?? (isDark ? const Color(0xFF1E293B) : Colors.white);
    final Color tColor = titleColor ?? (isDark ? Colors.white : const Color(0xFF0F172A));
    final Color sTitleColor = subTitleColor ?? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomDateTimePickerSheet(
        initialDate: initialDate,
        minDate: minDate,
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
  final bool showTime;
  final Color accent;
  final Color cardColor;
  final Color titleColor;
  final Color subTitleColor;

  const CustomDateTimePickerSheet({
    super.key,
    this.initialDate,
    this.minDate,
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
      duration: const Duration(milliseconds: 350),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);

    return ScaleTransition(
      scale: _scaleAnim,
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: widget.cardColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 30, offset: const Offset(0, -6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: widget.subTitleColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Icon(Icons.event_rounded, color: widget.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    widget.showTime ? "Pick Date & Time" : "Pick Date",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: widget.titleColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: dividerColor),
            _buildCalendar(),
            if (widget.showTime) ...[
              Divider(height: 1, color: dividerColor),
              _buildTimePicker(isDark),
            ],
            Divider(height: 1, color: dividerColor),
            _buildActions(),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navBtn(Icons.chevron_left_rounded, () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1))),
              Text(monthLabel, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: widget.titleColor)),
              _navBtn(Icons.chevron_right_rounded, () => setState(() => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) => SizedBox(width: 36, child: Center(child: Text(d, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.subTitleColor.withOpacity(0.6)))))).toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: startWeekday + daysCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
            itemBuilder: (_, index) {
              if (index < startWeekday) return const SizedBox.shrink();
              final day = index - startWeekday + 1;
              final date = DateTime(year, month, day);
              final isToday = date == today;
              final isSelected = date == _selectedDay;
              final disabled = _isBeforeMin(date);
              return GestureDetector(
                onTap: disabled ? null : () => setState(() => _selectedDay = date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? widget.accent : (isToday ? widget.accent.withOpacity(0.12) : Colors.transparent),
                    borderRadius: BorderRadius.circular(10),
                    border: isToday && !isSelected ? Border.all(color: widget.accent.withOpacity(0.4), width: 1.5) : null,
                  ),
                  child: Center(
                    child: Text('$day', style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: disabled ? widget.subTitleColor.withOpacity(0.25) : (isSelected ? Colors.white : (isToday ? widget.accent : widget.titleColor)))),
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
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: widget.accent.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: widget.accent),
      ),
    );
  }

  Widget _buildTimePicker(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 16, color: widget.accent),
              const SizedBox(width: 6),
              Text("Select Time", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.titleColor)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: widget.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')} ${_isAM ? 'AM' : 'PM'}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: widget.accent, letterSpacing: 0.5))),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 110,
            child: Row(
              children: [
                Expanded(child: _wheelSpinner(count: 12, controller: _hourCtrl, labelBuilder: (i) => '${i + 1}'.padLeft(2, '0'), onChanged: (i) => setState(() => _selectedHour = i + 1), isDark: isDark)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Text(":", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: widget.accent))),
                Expanded(child: _wheelSpinner(count: 60, controller: _minuteCtrl, labelBuilder: (i) => '$i'.padLeft(2, '0'), onChanged: (i) => setState(() => _selectedMinute = i), isDark: isDark)),
                const SizedBox(width: 12),
                _buildAmPmToggle(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wheelSpinner({required int count, required FixedExtentScrollController controller, required String Function(int) labelBuilder, required ValueChanged<int> onChanged, required bool isDark}) {
    return Container(
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03), borderRadius: BorderRadius.circular(14)),
      child: Stack(
        children: [
          Center(child: Container(height: 38, decoration: BoxDecoration(color: widget.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: widget.accent.withOpacity(0.2), width: 1)))),
          ListWheelScrollView.useDelegate(
            controller: controller, itemExtent: 38, perspective: 0.005, diameterRatio: 1.5, physics: const FixedExtentScrollPhysics(), onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(childCount: count, builder: (_, index) {
              final isSelected = controller.hasClients && controller.selectedItem == index;
              return Center(child: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 200), style: TextStyle(fontSize: isSelected ? 20 : 15, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500, color: isSelected ? widget.accent : widget.subTitleColor.withOpacity(0.5)), child: Text(labelBuilder(index))));
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAmPmToggle(bool isDark) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [_amPmChip('AM', _isAM, isDark), const SizedBox(height: 8), _amPmChip('PM', !_isAM, isDark)]);
  }

  Widget _amPmChip(String label, bool active, bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _isAM = label == 'AM'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), width: 52, height: 44,
        decoration: BoxDecoration(color: active ? widget.accent : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)), borderRadius: BorderRadius.circular(12), border: active ? null : Border.all(color: widget.subTitleColor.withOpacity(0.15), width: 1), boxShadow: active ? [BoxShadow(color: widget.accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))] : null),
        child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: active ? Colors.white : widget.subTitleColor, letterSpacing: 0.5))),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Expanded(child: TextButton(onPressed: () => Navigator.pop(context), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: widget.subTitleColor.withOpacity(0.2)))), child: Text("Cancel", style: TextStyle(fontWeight: FontWeight.w700, color: widget.subTitleColor, fontSize: 14)))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context, _buildResult()), style: ElevatedButton.styleFrom(backgroundColor: widget.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0), child: const Text("Confirm", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)))),
        ],
      ),
    );
  }
}
