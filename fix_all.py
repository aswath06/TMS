with open('/Users/aswath/Documents/Tripzo/TMS/lib/screens/driver/driver_routes_screen.dart', 'r') as f:
    lines = f.readlines()

# 1. Add missing import for AssignmentDetailsScreen if not present
import_stmt = "import 'package:tripzo/screens/driver/assignment_details_screen.dart';\n"
if import_stmt not in lines:
    lines.insert(12, import_stmt)

# 2. Fix the missing colors in `_buildDailyBusRoutesList`
for i, line in enumerate(lines):
    if 'Widget _buildDailyBusRoutesList() {' in line:
        insert_idx = i + 3
        colors = """    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
"""
        lines.insert(insert_idx, colors)
        break

# 3. Fix DriverStore `profile` to `driver` (DriverStore usually has `driver` instead of `profile`)
for i, line in enumerate(lines):
    if 'final profile = driverStore.profile;' in line:
        lines[i] = line.replace('driverStore.profile', 'driverStore.driver')

# 4. Remove the extra closing brace causing `Expected a method, getter, setter or operator declaration`
# Let's just find the last two lines, they should be `}`
while lines[-1].strip() == '':
    lines.pop()

# If it ends with two `}` but the class only needs one, we might have an extra.
# Let's count the braces. A simpler way is just use a regex or check the last lines.
if lines[-1].strip() == '}' and lines[-2].strip() == '}':
    lines.pop()

with open('/Users/aswath/Documents/Tripzo/TMS/lib/screens/driver/driver_routes_screen.dart', 'w') as f:
    f.writelines(lines)
print("Applied fixes.")
