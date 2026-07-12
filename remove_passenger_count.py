import os

file_path = '/Users/aswath/Documents/Tripzo/TMS/lib/screens/admin/request/daily_bus_run_details_page.dart'

with open(file_path, 'r') as f:
    content = f.read()

old_func = """  void _showStartEveningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
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

new_func = """  void _showStartEveningBottomSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    final TextEditingController odometerController = TextEditingController();
    
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
              Text("Direct start AN", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: titleColor)),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final int? odo = int.tryParse(odometerController.text);
                    if (odo != null) {
                      Navigator.pop(ctx);
                      _submitEveningStart(odo, 0); // Passenger count is not required for evening start
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

if old_func in content:
    content = content.replace(old_func, new_func)
    print("Replacement successful")
else:
    print("Old function not found!")

with open(file_path, 'w') as f:
    f.write(content)

