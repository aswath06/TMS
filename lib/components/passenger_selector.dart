import 'package:flutter/material.dart';

class PassengerSelector extends StatelessWidget {
  final Color cardColor;
  final Color titleColor;
  final int passengerCount;
  final String selectedCountryCode;
  final Function(int) onCountChanged;
  final Function(String) onCountryCodeChanged;

  const PassengerSelector({
    super.key,
    required this.cardColor,
    required this.titleColor,
    required this.passengerCount,
    required this.selectedCountryCode,
    required this.onCountChanged,
    required this.onCountryCodeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Count Dropdown
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButtonFormField<int>(
                value: passengerCount,
                dropdownColor: cardColor,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: "Count",
                  labelStyle: TextStyle(fontSize: 12),
                ),
                items: List.generate(10, (i) => i + 1)
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text("$e", style: TextStyle(color: titleColor)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => onCountChanged(v!),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Country Code & Phone
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  DropdownButton<String>(
                    value: selectedCountryCode,
                    underline: const SizedBox(),
                    dropdownColor: cardColor,
                    items: ["+91", "+1", "+44"]
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => onCountryCodeChanged(v!),
                  ),
                  const VerticalDivider(width: 20),
                  const Expanded(
                    child: TextField(
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: "Phone Number",
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 13),
                      ),
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
