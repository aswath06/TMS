import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';

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

  Future<DateTime?> _pickDateTime(
    BuildContext context,
    DateTime? current, {
    DateTime? minDate,
  }) async {
    return CustomDateTimePicker.show(
      context,
      initialDate: current,
      minDate: minDate,
      accent: primaryBlue,
      cardColor: cardColor,
      titleColor: titleColor,
      subTitleColor: subTitleColor,
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
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: hasValue ? titleColor : titleColor.withOpacity(0.35),
              ),
            ),
            const SizedBox(height: 3),
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
