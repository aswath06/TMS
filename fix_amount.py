import re

with open('lib/screens/faculty/missions/mission_details_screen.dart', 'r') as f:
    content = f.read()

old_code = """                                          // 0. Amount mandatory
                                          if ((e['amount'] as TextEditingController).text.trim().isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Amount is mandatory for all allowances (${type['name'] ?? type['type_name']})"), backgroundColor: Colors.red));
                                            hasValidationError = true;
                                            break;
                                          }
                                          // 1. Proof mandatory"""

new_code = """                                          // 0. Amount mandatory
                                          if ((e['amount'] as TextEditingController).text.trim().isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Amount is mandatory for all allowances (${type['name'] ?? type['type_name']})"), backgroundColor: Colors.red));
                                            hasValidationError = true;
                                            break;
                                          }
                                          // 0.5 Amount Limit Check
                                          final masterAmountStr = type['amount']?.toString() ?? "0";
                                          final masterAmount = double.tryParse(masterAmountStr) ?? 0.0;
                                          final enteredAmount = double.tryParse((e['amount'] as TextEditingController).text.trim()) ?? 0.0;
                                          if (masterAmount > 0 && enteredAmount > masterAmount) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Amount for ${type['name'] ?? type['type_name']} cannot exceed ₹$masterAmount"), backgroundColor: Colors.red));
                                            hasValidationError = true;
                                            break;
                                          }
                                          // 1. Proof mandatory"""

if old_code in content:
    content = content.replace(old_code, new_code)
    with open('lib/screens/faculty/missions/mission_details_screen.dart', 'w') as f:
        f.write(content)
    print("Successfully patched amount validation")
else:
    print("Could not find old_code")
