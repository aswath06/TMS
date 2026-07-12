import os

file_path = '/Users/aswath/Documents/Tripzo/TMS/lib/screens/admin/request/daily_bus_run_details_page.dart'

with open(file_path, 'r') as f:
    content = f.read()

# 1. Add passenger_count to _showEndMorningBottomSheet
old_sheet = """  void _showEndMorningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    final TextEditingController odometerController = TextEditingController();
    bool allowanceNeeded = false;"""

new_sheet = """  void _showEndMorningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    final TextEditingController odometerController = TextEditingController();
    final TextEditingController passengerController = TextEditingController();
    bool allowanceNeeded = false;"""

content = content.replace(old_sheet, new_sheet)

old_field = """                    // Odometer Field
                    TextField(
                      controller: odometerController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: "End Odometer Reading",
                        labelStyle: TextStyle(color: subColor),
                        hintText: "Enter odometer value",
                        prefixIcon: Icon(Icons.speed_rounded, color: primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryBlue, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),"""

new_field = """                    // Odometer Field
                    TextField(
                      controller: odometerController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: "End Odometer Reading",
                        labelStyle: TextStyle(color: subColor),
                        hintText: "Enter odometer value",
                        prefixIcon: Icon(Icons.speed_rounded, color: primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryBlue, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passengerController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: "Passenger Count",
                        labelStyle: TextStyle(color: subColor),
                        hintText: "Enter passenger count",
                        prefixIcon: Icon(Icons.people_alt_rounded, color: primaryBlue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: primaryBlue, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),"""

content = content.replace(old_field, new_field)

old_submit = """                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final String oStr = odometerController.text.trim();
                          if (oStr.isEmpty) {
                            _showSnackBar("Please fill in odometer details", Colors.orange);
                            return;
                          }
                          final int? odometerVal = int.tryParse(oStr);
                          if (odometerVal == null) {
                            _showSnackBar("Invalid numeric values", Colors.orange);
                            return;
                          }
                          Navigator.pop(context);
                          _submitMorningOdometer(odometerVal, null, allowanceNeeded);
                        },"""

new_submit = """                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final String oStr = odometerController.text.trim();
                          if (oStr.isEmpty) {
                            _showSnackBar("Please fill in odometer details", Colors.orange);
                            return;
                          }
                          final int? odometerVal = int.tryParse(oStr);
                          final int? paxVal = int.tryParse(passengerController.text.trim());
                          if (odometerVal == null) {
                            _showSnackBar("Invalid numeric values", Colors.orange);
                            return;
                          }
                          if (passengerController.text.trim().isNotEmpty && paxVal == null) {
                            _showSnackBar("Invalid passenger count", Colors.orange);
                            return;
                          }
                          Navigator.pop(context);
                          _submitMorningOdometer(odometerVal, paxVal, allowanceNeeded);
                        },"""

content = content.replace(old_submit, new_submit)

# 2. Add showConfirmAttendance conditionally to ARRIVED_CAMPUS for isSuperOrTransportAdmin
old_bottom_bar = """      } else if (s == 'ARRIVED_CAMPUS') {
        bottomBar = _buildBottomButton("Direct end button (FN)", Icons.stop_circle_rounded, primaryBlue, isDark, _isLoadingAction ? null : () => _showEndMorningBottomSheet(primaryBlue, titleColor, subColor, isDark));
      } else if (s == 'FN_COMPLETED') {"""

new_bottom_bar = """      } else if (s == 'ARRIVED_CAMPUS') {
        if (showConfirmAttendance) {
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
        } else {
          bottomBar = _buildBottomButton("Direct end button (FN)", Icons.stop_circle_rounded, primaryBlue, isDark, _isLoadingAction ? null : () => _showEndMorningBottomSheet(primaryBlue, titleColor, subColor, isDark));
        }
      } else if (s == 'FN_COMPLETED') {"""

content = content.replace(old_bottom_bar, new_bottom_bar)

with open(file_path, 'w') as f:
    f.write(content)

print("Done")
