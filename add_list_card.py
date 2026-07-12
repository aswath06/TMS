import os

file_path = '/Users/aswath/Documents/Tripzo/TMS/lib/screens/admin/request/daily_routines_page.dart'

with open(file_path, 'r') as f:
    content = f.read()

# 1. Update the list builder to use _buildListCard
old_builder = """                                final run = runs[index];
                                return _buildRoutineCard(context, run, cardColor, titleColor, subColor, primaryBlue);
                              },"""

new_builder = """                                final run = runs[index];
                                return _isListView 
                                    ? _buildListCard(context, run, cardColor, titleColor, subColor, primaryBlue)
                                    : _buildRoutineCard(context, run, cardColor, titleColor, subColor, primaryBlue);
                              },"""

content = content.replace(old_builder, new_builder)

# 2. Add _buildListCard function
old_routine_card = """  Widget _buildRoutineCard("""

new_list_card = """  Widget _buildListCard(
    BuildContext context,
    Map<String, dynamic> run,
    Color cardColor,
    Color titleColor,
    Color subColor,
    Color primaryBlue,
  ) {
    final String runName = run['run_name'] ?? 'Bus Run';
    final String status = run['status'] ?? 'PENDING';
    
    final bool isMorningConfirmed = run['is_morning_attendance_confirmed'] == true ||
        run['is_morning_attendance_confirmed']?.toString() == 'true' ||
        run['morning_attendance_confirmed'] == true ||
        run['morning_attendance_confirmed']?.toString() == 'true';

    final bool isEveningConfirmed = run['is_evening_attendance_confirmed'] == true ||
        run['is_evening_attendance_confirmed']?.toString() == 'true' ||
        run['evening_attendance_confirmed'] == true ||
        run['evening_attendance_confirmed']?.toString() == 'true';
    
    final assignments = run['assignment'] as List? ?? [];
    String vehicleNo = "No Vehicle";
    if (assignments.isNotEmpty) {
      final vNumbers = assignments.map((a) => a['vehicle']?['vehicle_number']).whereType<String>().toSet();
      if (vNumbers.isNotEmpty) vehicleNo = vNumbers.join(", ");
    }
    
    String busNumber = "BUS NO -";
    if (assignments.isNotEmpty) {
      final bNumbers = assignments.map((a) => a['vehicle']?['bus_number']).whereType<String>().toSet();
      if (bNumbers.isNotEmpty) busNumber = "BUS NO ${bNumbers.join(", ")}";
    }

    return GestureDetector(
      onTap: () async {
        if (context.mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DailyBusRunDetailsPage(runData: run),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.directions_bus_rounded, color: primaryBlue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          vehicleNo,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: titleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        busNumber,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (isMorningConfirmed)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.green, size: 10),
                              SizedBox(width: 4),
                              Text("FN Confirmed", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      if (isEveningConfirmed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.green, size: 10),
                              SizedBox(width: 4),
                              Text("AN Confirmed", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineCard("""

content = content.replace(old_routine_card, new_list_card)

with open(file_path, 'w') as f:
    f.write(content)

print("Done")
