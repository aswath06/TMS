import 'package:flutter/material.dart';

class PassengerSelector extends StatelessWidget {
  final Color cardColor;
  final Color titleColor;
  final int passengerCount;
  final String selectedVehicleType;
  final Function(int) onCountChanged;
  final Function(String) onVehicleTypeChanged;

  const PassengerSelector({
    super.key,
    required this.cardColor,
    required this.titleColor,
    required this.passengerCount,
    required this.selectedVehicleType,
    required this.onCountChanged,
    required this.onVehicleTypeChanged,
  });

  String _getAutoVehicleType(int count) {
    if (count <= 4) return "Mini";
    if (count <= 7) return "SUV";
    if (count <= 20) return "Mini Bus";
    return "Bus";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 65,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<int>(
                value: passengerCount,
                dropdownColor: cardColor,
                menuMaxHeight: 400,
                icon: const Icon(
                  Icons.group_rounded,
                  size: 18,
                  color: Colors.grey,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: "Passengers",
                  labelStyle: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                items: List.generate(60, (i) => i + 1)
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          "$e",
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    onCountChanged(v);
                    onVehicleTypeChanged(_getAutoVehicleType(v));
                  }
                },
              ),
            ),
          ),
          Container(
            width: 1,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 15),
            color: Colors.grey.withOpacity(0.2),
          ),
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Suggested Vehicle",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      selectedVehicleType.contains('Bus')
                          ? Icons.directions_bus_rounded
                          : Icons.directions_car_filled_rounded,
                      size: 16,
                      color: titleColor.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      selectedVehicleType,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
