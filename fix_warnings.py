file_path = "/Users/aswath/Documents/Tripzo/TMS/lib/screens/driver/driver_routes_screen.dart"
with open(file_path, "r") as f:
    content = f.read()

# Fix unused tripStatuses and tripStatus
old_status_code = """    final dynamic rawStatusValue = mission['status'];
    final tripStatuses = mission['trip_instance_statuses'] as List?;
    final String? tripStatus = (tripStatuses != null && tripStatuses.isNotEmpty) ? tripStatuses[0]['status']?.toString().toUpperCase() : null;"""

new_status_code = """    final dynamic rawStatusValue = mission['status'];"""

content = content.replace(old_status_code, new_status_code)

with open(file_path, "w") as f:
    f.write(content)
