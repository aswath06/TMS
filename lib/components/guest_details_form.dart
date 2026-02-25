import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';

class GuestDetailsForm extends StatelessWidget {
  final List<TextEditingController> nameControllers;
  final List<TextEditingController> phoneControllers;
  final List<String> countryCodes;
  final int passengerCount;
  final Color cardColor;
  final Color titleColor;
  final Color primaryBlue;
  final Color bgColor;
  final VoidCallback onAddGuest;
  final Function(int) onRemoveGuest;
  final Function() onBulkUpload;

  const GuestDetailsForm({
    super.key,
    required this.nameControllers,
    required this.phoneControllers,
    required this.countryCodes,
    required this.passengerCount,
    required this.cardColor,
    required this.titleColor,
    required this.primaryBlue,
    required this.bgColor,
    required this.onAddGuest,
    required this.onRemoveGuest,
    required this.onBulkUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle("Guest Details"),
            if (passengerCount > 5)
              TextButton.icon(
                onPressed: onBulkUpload,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(
                  "Bulk Upload",
                  style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else if (nameControllers.length < passengerCount)
              TextButton.icon(
                onPressed: onAddGuest,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text(
                  "Add Guest",
                  style: TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...nameControllers.asMap().entries.map((entry) {
          int idx = entry.key;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: titleColor.withOpacity(0.05),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _inputField(
                        "Guest ${idx + 1} Name",
                        Icons.person_outline,
                        cardColor,
                        titleColor,
                        controller: nameControllers[idx],
                        isName: true,
                      ),
                    ),
                    if (idx > 0)
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: () => onRemoveGuest(idx),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: bgColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      CountryCodePicker(
                        onChanged: (country) =>
                            countryCodes[idx] = country.dialCode!,
                        initialSelection: 'IN',
                        favorite: const ['+91', 'US'],
                        textStyle: TextStyle(
                          color: titleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        showFlagMain: true,
                        flagWidth: 20,
                        padding: EdgeInsets.zero,
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.grey.withOpacity(0.3),
                      ),
                      Expanded(
                        child: _inputField(
                          "Phone Number",
                          Icons.phone_android_outlined,
                          Colors.transparent,
                          titleColor,
                          controller: phoneControllers[idx],
                          isPhone: true,
                          noMargin: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
      ],
    );
  }

  Widget _inputField(
    String hint,
    IconData icon,
    Color color,
    Color textColor, {
    int max = 1,
    TextEditingController? controller,
    bool isPhone = false,
    bool isName = false,
    bool noMargin = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: noMargin ? 0 : 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: max,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        inputFormatters: [
          if (isPhone) FilteringTextInputFormatter.digitsOnly,
          if (isName) FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
        ],
        validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: textColor.withOpacity(0.4), fontSize: 13),
          prefixIcon: Icon(icon, size: 16, color: primaryBlue.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 12,
          ),
        ),
      ),
    );
  }
}
