import os

file_path = '/Users/aswath/Documents/Tripzo/TMS/lib/screens/admin/request/daily_bus_run_details_page.dart'

with open(file_path, 'r') as f:
    content = f.read()

old_block = """      } else if (s == 'FN_COMPLETED') {
        bottomBar = _buildBottomButton("Direct start AN", Icons.play_circle_fill_rounded, primaryBlue, isDark, _isLoadingAction ? null : () => _showStartEveningBottomSheet(primaryBlue, titleColor, subColor, isDark));
      } else if (s == 'DEPARTED_CAMPUS') {"""

new_block = """      } else if (s == 'FN_COMPLETED') {
        if (showConfirmAttendance) {
          bottomBar = _buildDualBottomButtonColumn(
            "Confirm Attendance", Icons.check_circle_rounded, Colors.green, _isLoadingAction ? null : _showConfirmAttendancePopup,
            "Direct start AN", Icons.play_circle_fill_rounded, primaryBlue, _isLoadingAction ? null : () => _showStartEveningBottomSheet(primaryBlue, titleColor, subColor, isDark),
            isDark
          );
        } else {
          bottomBar = _buildBottomButton("Direct start AN", Icons.play_circle_fill_rounded, primaryBlue, isDark, _isLoadingAction ? null : () => _showStartEveningBottomSheet(primaryBlue, titleColor, subColor, isDark));
        }
      } else if (s == 'DEPARTED_CAMPUS') {"""

content = content.replace(old_block, new_block)

with open(file_path, 'w') as f:
    f.write(content)

print("Done")
