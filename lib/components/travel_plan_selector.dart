import 'package:flutter/material.dart';

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
  final Function(DateTime) onEndDateChanged;

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
            "Start",
            startDate,
            onStartDateChanged,
          ),
        ),
        if (travelType == 'Multi Day') ...[
          const SizedBox(width: 8),
          Expanded(
            child: _dateTile(
              context,
              "End",
              endDate,
              onEndDateChanged,
            ),
          ),
        ],
      ],
    );
  }

  Widget _dateTile(
    BuildContext context,
    String label,
    DateTime? date,
    Function(DateTime) onPicked,
  ) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month, size: 16, color: primaryBlue),
            const SizedBox(width: 8),
            Text(
              date == null ? label : "${date.day}/${date.month}",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
