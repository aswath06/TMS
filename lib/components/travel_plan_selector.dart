import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TravelPlanSelector extends StatelessWidget {
  final String travelType;
  final DateTime? startDate;
  final DateTime? endDate;
  final Color primaryBlue;
  final Color cardColor;
  final Color titleColor;
  final Color subTitleColor;
  final Function(String) onTypeChanged;
  final Function(DateTime) onStartDateChanged;
  final Function(DateTime?) onEndDateChanged;

  const TravelPlanSelector({
    super.key,
    required this.travelType,
    required this.startDate,
    required this.endDate,
    required this.primaryBlue,
    required this.cardColor,
    required this.titleColor,
    required this.subTitleColor,
    required this.onTypeChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
  });

  // ─────────────────────────────────────────────────────────
  //  Opens a premium bottom sheet with inline calendar + time
  // ─────────────────────────────────────────────────────────
  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime? current, {
    DateTime? minDate,
  }) async {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DateTimePickerSheet(
        initialDate: current,
        minDate: minDate,
        accent: primaryBlue,
        cardColor: cardColor,
        titleColor: titleColor,
        subTitleColor: subTitleColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTypeSelector(),
        const SizedBox(height: 12),
        _buildDateRow(context),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: ['One Way', 'Two Way', 'Multi Day'].map((type) {
          bool sel = travelType == type;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTypeChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    type,
                    style: TextStyle(
                      color: sel ? Colors.white : subTitleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _dateTile(
            context,
            label: "Start Date & Time",
            date: startDate,
            onPicked: (dt) {
              if (dt != null) onStartDateChanged(dt);
            },
          ),
        ),
        if (travelType == 'Multi Day') ...[
          const SizedBox(width: 8),
          Expanded(
            child: _dateTile(
              context,
              label: "End Date & Time",
              date: endDate,
              onPicked: onEndDateChanged,
              minDate: startDate,
            ),
          ),
        ],
      ],
    );
  }

  Widget _dateTile(
    BuildContext context, {
    required String label,
    required DateTime? date,
    required Function(DateTime?) onPicked,
    DateTime? minDate,
  }) {
    final bool hasValue = date != null;
    final String dateStr =
        hasValue ? DateFormat('MMM dd, yyyy').format(date!) : 'Select Date';
    final String timeStr =
        hasValue ? DateFormat('hh:mm a').format(date!) : 'Select Time';

    return GestureDetector(
      onTap: () async {
        final merged = await _pickDateTime(context, date, minDate: minDate);
        onPicked(merged);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color:
                hasValue ? primaryBlue.withOpacity(0.35) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    size: 14, color: primaryBlue),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: primaryBlue.withOpacity(0.8),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Date
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: hasValue ? titleColor : titleColor.withOpacity(0.35),
              ),
            ),
            const SizedBox(height: 3),
            // Time
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: hasValue
                      ? primaryBlue.withOpacity(0.7)
                      : titleColor.withOpacity(0.25),
                ),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasValue
                        ? primaryBlue.withOpacity(0.9)
                        : titleColor.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PREMIUM DATE + TIME PICKER BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════

class _DateTimePickerSheet extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime? minDate;
  final Color accent;
  final Color cardColor;
  final Color titleColor;
  final Color subTitleColor;

  const _DateTimePickerSheet({
    this.initialDate,
    this.minDate,
    required this.accent,
    required this.cardColor,
    required this.titleColor,
    required this.subTitleColor,
  });

  @override
  State<_DateTimePickerSheet> createState() => _DateTimePickerSheetState();
}

class _DateTimePickerSheetState extends State<_DateTimePickerSheet>
    with SingleTickerProviderStateMixin {
  late DateTime _focusedMonth;
  late DateTime _selectedDay;
  late int _selectedHour; // 1–12
  late int _selectedMinute; // 0–59
  late bool _isAM;

  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  // Scroll controllers for spinners
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final init = widget.initialDate ?? now;

    _selectedDay = DateTime(init.year, init.month, init.day);
    _focusedMonth = DateTime(init.year, init.month);

    // Convert 24h → 12h
    final int h24 = widget.initialDate?.hour ?? 9;
    _isAM = h24 < 12;
    _selectedHour = h24 == 0
        ? 12
        : h24 > 12
            ? h24 - 12
            : h24;
    _selectedMinute = widget.initialDate?.minute ?? 0;

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

  // Convert selections to 24-hour DateTime
  DateTime _buildResult() {
    int h24 = _selectedHour;
    if (_isAM) {
      if (h24 == 12) h24 = 0; // 12 AM = 0
    } else {
      if (h24 != 12) h24 += 12; // PM: add 12 except for 12 PM
    }
    return DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      h24,
      _selectedMinute,
    );
  }

  // ────────── CALENDAR HELPERS ──────────
  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
  int _firstWeekday(int year, int month) =>
      DateTime(year, month, 1).weekday % 7; // Sun = 0

  bool _isBeforeMin(DateTime day) {
    final min = widget.minDate ?? DateTime.now();
    final minDay = DateTime(min.year, min.month, min.day);
    return day.isBefore(minDay);
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month - 1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + 1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final dividerColor =
        isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);

    return ScaleTransition(
      scale: _scaleAnim,
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 30,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.subTitleColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Title row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Icon(Icons.event_rounded, color: widget.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Pick Date & Time",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: widget.titleColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: dividerColor),

            // ── Calendar ──
            _buildCalendar(isDark),

            Divider(height: 1, color: dividerColor),

            // ── Time Picker ──
            _buildTimePicker(isDark),

            Divider(height: 1, color: dividerColor),

            // ── Confirm / Cancel ──
            _buildActions(isDark),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  // ═════════════════════ CALENDAR GRID ═════════════════════
  Widget _buildCalendar(bool isDark) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final daysCount = _daysInMonth(year, month);
    final startWeekday = _firstWeekday(year, month);
    final monthLabel = DateFormat('MMMM yyyy').format(_focusedMonth);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // Month nav
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navBtn(Icons.chevron_left_rounded, _prevMonth),
              Text(
                monthLabel,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: widget.titleColor,
                ),
              ),
              _navBtn(Icons.chevron_right_rounded, _nextMonth),
            ],
          ),
          const SizedBox(height: 12),

          // Day-of-week header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (d) => SizedBox(
                    width: 36,
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.subTitleColor.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),

          // Day grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: startWeekday + daysCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (_, index) {
              if (index < startWeekday) return const SizedBox.shrink();

              final day = index - startWeekday + 1;
              final date = DateTime(year, month, day);
              final isToday = date == today;
              final isSelected = date == _selectedDay;
              final disabled = _isBeforeMin(date);

              return GestureDetector(
                onTap: disabled
                    ? null
                    : () => setState(() => _selectedDay = date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? widget.accent
                        : isToday
                            ? widget.accent.withOpacity(0.12)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isToday && !isSelected
                        ? Border.all(
                            color: widget.accent.withOpacity(0.4),
                            width: 1.5,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: disabled
                            ? widget.subTitleColor.withOpacity(0.25)
                            : isSelected
                                ? Colors.white
                                : isToday
                                    ? widget.accent
                                    : widget.titleColor,
                      ),
                    ),
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
        decoration: BoxDecoration(
          color: widget.accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: widget.accent),
      ),
    );
  }

  // ═════════════════════ TIME PICKER ═════════════════════
  Widget _buildTimePicker(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        children: [
          // Time header
          Row(
            children: [
              Icon(Icons.access_time_rounded,
                  size: 16, color: widget.accent),
              const SizedBox(width: 6),
              Text(
                "Select Time",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: widget.titleColor,
                ),
              ),
              const Spacer(),
              // Live preview of selected time
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')} ${_isAM ? 'AM' : 'PM'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: widget.accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Spinners row: Hour : Minute  AM/PM
          SizedBox(
            height: 130,
            child: Row(
              children: [
                // Hour spinner
                Expanded(child: _wheelSpinner(
                  count: 12,
                  controller: _hourCtrl,
                  labelBuilder: (i) => '${i + 1}'.padLeft(2, '0'),
                  onChanged: (i) => setState(() => _selectedHour = i + 1),
                  isDark: isDark,
                )),

                // Colon separator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    ":",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: widget.accent,
                    ),
                  ),
                ),

                // Minute spinner
                Expanded(child: _wheelSpinner(
                  count: 60,
                  controller: _minuteCtrl,
                  labelBuilder: (i) => '$i'.padLeft(2, '0'),
                  onChanged: (i) => setState(() => _selectedMinute = i),
                  isDark: isDark,
                )),

                const SizedBox(width: 12),

                // AM / PM toggle
                _buildAmPmToggle(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wheelSpinner({
    required int count,
    required FixedExtentScrollController controller,
    required String Function(int) labelBuilder,
    required ValueChanged<int> onChanged,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          // Center highlight band
          Center(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: widget.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.accent.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 38,
            perspective: 0.005,
            diameterRatio: 1.5,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: count,
              builder: (_, index) {
                final isSelected =
                    controller.hasClients && controller.selectedItem == index;
                return Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: isSelected ? 20 : 15,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected
                          ? widget.accent
                          : widget.subTitleColor.withOpacity(0.5),
                    ),
                    child: Text(labelBuilder(index)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmPmToggle(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _amPmChip('AM', _isAM, isDark),
        const SizedBox(height: 8),
        _amPmChip('PM', !_isAM, isDark),
      ],
    );
  }

  Widget _amPmChip(String label, bool active, bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _isAM = label == 'AM'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 44,
        decoration: BoxDecoration(
          color: active
              ? widget.accent
              : isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: active
              ? null
              : Border.all(
                  color: widget.subTitleColor.withOpacity(0.15),
                  width: 1,
                ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: widget.accent.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : widget.subTitleColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────── BOTTOM ACTIONS ───────────────
  Widget _buildActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          // Cancel
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: widget.subTitleColor.withOpacity(0.2),
                  ),
                ),
              ),
              child: Text(
                "Cancel",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: widget.subTitleColor,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Confirm
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _buildResult()),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_rounded,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    "Confirm",
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
