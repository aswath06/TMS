import os

file_path = '/Users/aswath/Documents/Tripzo/TMS/lib/screens/admin/request/daily_routines_page.dart'

with open(file_path, 'r') as f:
    content = f.read()

old_logic = """    final assignments = run['assignment'] as List? ?? [];
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

    return GestureDetector("""

new_logic = """    final assignments = run['assignment'] as List? ?? [];
    
    List<Widget> vehicleWidgets = [];
    if (assignments.isEmpty) {
      vehicleWidgets.add(
        Text(
          "No Vehicle Assigned",
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: titleColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else {
      final Map<int, Map<String, dynamic>> uniqueVehicles = {};
      for (var a in assignments) {
        if (a['vehicle'] != null && a['vehicle']['id'] != null) {
          uniqueVehicles[a['vehicle']['id']] = a['vehicle'];
        }
      }
      
      for (var v in uniqueVehicles.values) {
        String vNo = v['vehicle_number'] ?? "Unknown";
        String bNo = v['bus_number'] != null ? "(BUS NO ${v['bus_number']})" : "";
        
        vehicleWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              "$vNo $bNo".trim(),
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: titleColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }
    }

    return GestureDetector("""

content = content.replace(old_logic, new_logic)

old_ui = """                  Row(
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
                  ),"""

new_ui = """                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: vehicleWidgets,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(status),
                    ],
                  ),"""

content = content.replace(old_ui, new_ui)

with open(file_path, 'w') as f:
    f.write(content)

print("Done")
