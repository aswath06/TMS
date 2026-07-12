import os

file_path = '/Users/aswath/Documents/Tripzo/TMS/lib/screens/admin/request/daily_bus_run_details_page.dart'

with open(file_path, 'r') as f:
    content = f.read()

# 1. Update ARRIVED_CAMPUS logic
old_logic = """        if (showConfirmAttendance) {
          bottomBar = Row(
            children: [
              Expanded(
                child: _buildBottomButton(
                  "Confirm Attendance",
                  Icons.check_circle_rounded,
                  Colors.green,
                  isDark,
                  _isLoadingAction ? null : _showConfirmAttendancePopup,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBottomButton("Direct end (FN)", Icons.stop_circle_rounded, primaryBlue, isDark, _isLoadingAction ? null : () => _showEndMorningBottomSheet(primaryBlue, titleColor, subColor, isDark)),
              ),
            ],
          );
        } else {"""

new_logic = """        if (showConfirmAttendance) {
          bottomBar = _buildDualBottomButtonColumn(
            "Confirm Attendance", Icons.check_circle_rounded, Colors.green, _isLoadingAction ? null : _showConfirmAttendancePopup,
            "Direct end (FN)", Icons.stop_circle_rounded, primaryBlue, _isLoadingAction ? null : () => _showEndMorningBottomSheet(primaryBlue, titleColor, subColor, isDark),
            isDark
          );
        } else {"""

content = content.replace(old_logic, new_logic)

# 2. Add _buildDualBottomButtonColumn helper
old_helper = """  Widget _buildBottomButton(String text, IconData icon, Color primaryBlue, bool isDark, VoidCallback? onPressed) {"""

new_helper = """  Widget _buildDualBottomButtonColumn(
    String text1, IconData icon1, Color color1, VoidCallback? onPressed1,
    String text2, IconData icon2, Color color2, VoidCallback? onPressed2,
    bool isDark
  ) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInnerButton(text1, icon1, color1, onPressed1),
          const SizedBox(height: 12),
          _buildInnerButton(text2, icon2, color2, onPressed2),
        ],
      ),
    );
  }

  Widget _buildInnerButton(String text, IconData icon, Color primaryBlue, VoidCallback? onPressed) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (onPressed != null)
            BoxShadow(
              color: primaryBlue.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoadingAction
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    text,
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBottomButton(String text, IconData icon, Color primaryBlue, bool isDark, VoidCallback? onPressed) {"""

content = content.replace(old_helper, new_helper)

with open(file_path, 'w') as f:
    f.write(content)

print("Done")
