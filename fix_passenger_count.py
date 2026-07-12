import os

file_path = '/Users/aswath/Documents/Tripzo/TMS/lib/screens/admin/request/daily_bus_run_details_page.dart'

with open(file_path, 'r') as f:
    content = f.read()

# 1. Update passenger count display in _showEndMorningBottomSheet
old_field = """                    const SizedBox(height: 16),
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

new_field = """                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people_alt_rounded, color: primaryBlue, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "Passenger Count",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            campusInCount,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),"""

content = content.replace(old_field, new_field)

# 2. Update submit logic to use campusInCount instead of passengerController
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
                          final int? paxVal = int.tryParse(campusInCount);
                          if (odometerVal == null) {
                            _showSnackBar("Invalid numeric values", Colors.orange);
                            return;
                          }
                          Navigator.pop(context);
                          _submitMorningOdometer(odometerVal, paxVal, allowanceNeeded);
                        },"""

content = content.replace(old_submit, new_submit)

# Remove the controller initialization to avoid unused variable warning
old_controller = """  void _showEndMorningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    final TextEditingController odometerController = TextEditingController();
    final String campusInCount = _run['campus_in_count']?.toString() ?? '0';
    final TextEditingController passengerController = TextEditingController(text: campusInCount);
    bool allowanceNeeded = false;"""

new_controller = """  void _showEndMorningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    final TextEditingController odometerController = TextEditingController();
    final String campusInCount = _run['campus_in_count']?.toString() ?? '0';
    bool allowanceNeeded = false;"""

content = content.replace(old_controller, new_controller)

with open(file_path, 'w') as f:
    f.write(content)

print("Done")
