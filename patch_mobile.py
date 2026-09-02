import re

with open('lib/screens/faculty/missions/mission_details_screen.dart', 'r') as f:
    content = f.read()

old_code = """                                          // 1. Proof mandatory
                                          if (e['proof'] == null) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Image proof is mandatory for all allowances (${type['name'] ?? type['type_name']})"), backgroundColor: Colors.red));
                                            hasValidationError = true;
                                            break;
                                          }
                                          // 2. Date mandatory for Food if > 3 cards"""

new_code = """                                          // 1. Proof mandatory
                                          if (e['proof'] == null || (e['proof'] as List).isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Image proof is mandatory for all allowances (${type['name'] ?? type['type_name']})"), backgroundColor: Colors.red));
                                            hasValidationError = true;
                                            break;
                                          }
                                          // 1.5 Meal mandatory for Food
                                          if (isFood) {
                                            final mealsList = e['meals'] as List<String>?;
                                            if (mealsList == null || mealsList.isEmpty) {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a meal (Breakfast/Lunch/Dinner) for Food Allowance"), backgroundColor: Colors.red));
                                              hasValidationError = true;
                                              break;
                                            }
                                          }
                                          // 2. Date mandatory for Food if > 3 cards"""

if old_code in content:
    content = content.replace(old_code, new_code)
    with open('lib/screens/faculty/missions/mission_details_screen.dart', 'w') as f:
        f.write(content)
    print("Successfully patched mobile meal validation")
else:
    print("Could not find old_code")
