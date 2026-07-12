import os

file_path = '/Users/aswath/Documents/Tripzo/TMS/lib/screens/admin/request/daily_bus_run_details_page.dart'

with open(file_path, 'r') as f:
    content = f.read()

old_logic = """  void _showDirectGatePassPopup(Color primaryBlue, Color titleColor, Color subColor, bool isDark, {String defaultType = 'FN'}) {
    String autoOtp = '';
    final assignments = _run['assignment'] as List? ?? [];
    if (assignments.isNotEmpty) {
      final firstV = assignments.firstWhere((a) => a['vehicle']?['vehicle_otp'] != null, orElse: () => null);
      if (firstV != null) {
        autoOtp = firstV['vehicle']['vehicle_otp']?.toString() ?? '';
      }
    }"""

new_logic = """  void _showDirectGatePassPopup(Color primaryBlue, Color titleColor, Color subColor, bool isDark, {String defaultType = 'FN'}) {
    String autoOtp = '';
    final assignments = _run['assignment'] as List? ?? [];
    if (assignments.isNotEmpty) {
      final String targetShift = defaultType == 'AN' ? 'EVENING' : 'MORNING';
      final firstV = assignments.firstWhere((a) => a['shift_code'] == targetShift && a['vehicle']?['vehicle_otp'] != null, orElse: () => null);
      if (firstV != null) {
        autoOtp = firstV['vehicle']['vehicle_otp']?.toString() ?? '';
      }
    }"""

content = content.replace(old_logic, new_logic)

with open(file_path, 'w') as f:
    f.write(content)

print("Done")
