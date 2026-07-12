import os

file_path = '/Users/aswath/Documents/Tripzo/TMS/lib/screens/admin/request/daily_bus_run_details_page.dart'

with open(file_path, 'r') as f:
    content = f.read()

# 1. Update passenger count default
old_sheet = """  void _showEndMorningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    final TextEditingController odometerController = TextEditingController();
    final TextEditingController passengerController = TextEditingController();"""

new_sheet = """  void _showEndMorningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    final TextEditingController odometerController = TextEditingController();
    final String campusInCount = _run['campus_in_count']?.toString() ?? '0';
    final TextEditingController passengerController = TextEditingController(text: campusInCount);"""

content = content.replace(old_sheet, new_sheet)

# 2. Update showConfirmAttendance condition
old_cond = """    final bool oldConfirmAttendanceCondition = isAssignedFaculty && 
        (assignedFacultyUserId == 421 || true) &&
        isPresent && 
        !isAttendanceConfirmed && 
        !_localAttendanceConfirmed;"""

new_cond = """    final bool oldConfirmAttendanceCondition = (isSuperOrTransportAdmin || (isAssignedFaculty && isPresent)) && 
        !isAttendanceConfirmed && 
        !_localAttendanceConfirmed;"""

content = content.replace(old_cond, new_cond)

with open(file_path, 'w') as f:
    f.write(content)

print("Done")
