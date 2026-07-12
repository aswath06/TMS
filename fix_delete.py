import os

# 1. Update frontend URL
frontend_file = '/Users/aswath/Documents/Tripzo/TMS/lib/screens/admin/request/daily_bus_run_details_page.dart'
with open(frontend_file, 'r') as f:
    f_content = f.read()

old_url = "final url = Uri.parse('${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/${_run['id']}');"
new_url = "final url = Uri.parse('${ApiConstants.baseUrl}/daily-bus/delete-runs/${_run['id']}');"
f_content = f_content.replace(old_url, new_url)

with open(frontend_file, 'w') as f:
    f.write(f_content)

# 2. Update backend roles
backend_file = '/Users/aswath/Documents/Tripzo/Transport_Management_Backend/routes/dailyBusRuns.routes.js'
with open(backend_file, 'r') as f:
    b_content = f.read()

old_route = """router.delete(
  "/delete-runs/:id",
  auth,
  role("Transport Admin"),
  controller.deleteDailyBusRun,
);"""

new_route = """router.delete(
  "/delete-runs/:id",
  auth,
  role("Super Admin", "Transport Admin"),
  controller.deleteDailyBusRun,
);"""

b_content = b_content.replace(old_route, new_route)

with open(backend_file, 'w') as f:
    f.write(b_content)

print("Done")
