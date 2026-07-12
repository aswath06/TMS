import os

file_path = '/Users/aswath/Documents/Tripzo/TMS/lib/screens/admin/request/daily_bus_run_details_page.dart'

with open(file_path, 'r') as f:
    content = f.read()

# 1. Update _showStartEveningBottomSheet
old_start = """  void _showStartEveningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    final TextEditingController odometerController = TextEditingController();
    final TextEditingController passengerController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Direct start AN", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor)),
              const SizedBox(height: 16),
              TextField(
                controller: odometerController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: titleColor),
                decoration: InputDecoration(
                  labelText: "Start Odometer",
                  labelStyle: TextStyle(color: subColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passengerController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: titleColor),
                decoration: InputDecoration(
                  labelText: "Passenger Count",
                  labelStyle: TextStyle(color: subColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final int? odo = int.tryParse(odometerController.text);
                    final int? pax = int.tryParse(passengerController.text);
                    if (odo != null && pax != null) {
                      Navigator.pop(ctx);
                      _submitEveningStart(odo, pax);
                    } else {
                      _showSnackBar("Invalid inputs", Colors.red);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text("Start Evening Run", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }"""

new_start = """  void _showStartEveningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    final TextEditingController odometerController = TextEditingController();
    final String campusOutCount = _run['campus_out_count']?.toString() ?? '0';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Direct start AN",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Submit details to start the evening run.",
                style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: odometerController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: "Start Odometer Reading",
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
                      campusOutCount,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final int? odo = int.tryParse(odometerController.text);
                    final int? pax = int.tryParse(campusOutCount);
                    if (odo != null) {
                      Navigator.pop(ctx);
                      _submitEveningStart(odo, pax ?? 0);
                    } else {
                      _showSnackBar("Invalid odometer reading", Colors.orange);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text("Start Evening Run", style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }"""

content = content.replace(old_start, new_start)

# 2. Update _showEndEveningBottomSheet
old_end = """  void _showEndEveningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    final TextEditingController odometerController = TextEditingController();
    bool allowanceNeeded = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Direct end AN", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor)),
                const SizedBox(height: 16),
                TextField(
                  controller: odometerController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: titleColor),
                  decoration: InputDecoration(
                    labelText: "End Odometer",
                    labelStyle: TextStyle(color: subColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text("Allowance Needed?", style: TextStyle(color: titleColor, fontWeight: FontWeight.bold)),
                  value: allowanceNeeded,
                  activeColor: primaryBlue,
                  onChanged: (val) {
                    setModalState(() {
                      allowanceNeeded = val;
                    });
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final int? odo = int.tryParse(odometerController.text);
                      if (odo != null) {
                        Navigator.pop(ctx);
                        _submitEveningOdometer(odo, allowanceNeeded);
                      } else {
                        _showSnackBar("Invalid odometer", Colors.red);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text("End Evening Run", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }"""

new_end = """  void _showEndEveningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    final TextEditingController odometerController = TextEditingController();
    bool allowanceNeeded = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Direct end AN", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: titleColor)),
                const SizedBox(height: 6),
                Text(
                  "Submit final shift details for evening routine.",
                  style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Allowance Needed",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: titleColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Select if driver allowance is needed",
                          style: TextStyle(fontSize: 10, color: subColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setModalState(() => allowanceNeeded = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: allowanceNeeded ? const Color(0xFF10B981) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "Yes",
                              style: TextStyle(
                                color: allowanceNeeded ? Colors.white : subColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setModalState(() => allowanceNeeded = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: !allowanceNeeded ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "No",
                              style: TextStyle(
                                color: !allowanceNeeded ? Colors.white : subColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final int? odo = int.tryParse(odometerController.text);
                      if (odo != null) {
                        Navigator.pop(ctx);
                        _submitEveningOdometer(odo, allowanceNeeded);
                      } else {
                        _showSnackBar("Invalid numeric values", Colors.orange);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text("Submit End Details", style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }"""

content = content.replace(old_end, new_end)

with open(file_path, 'w') as f:
    f.write(content)

print("Done")
