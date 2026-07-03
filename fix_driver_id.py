with open('/Users/aswath/Documents/Tripzo/TMS/lib/screens/driver/driver_routes_screen.dart', 'r') as f:
    lines = f.readlines()

import_stmt = "import 'package:tripzo/store/user_store.dart';\n"
if import_stmt not in lines:
    lines.insert(13, import_stmt)

# Let's replace the onTap logic for finding the driverId
content = "".join(lines)

old_logic = """        final driverStore = ref.read(driverStoreProvider);
        final driver = driverStore.driver;
        final driverId = driver['id'];"""

new_logic = """        final driverId = await UserStore.getUserId();"""

if old_logic in content:
    content = content.replace(old_logic, new_logic)
else:
    # try the profile one just in case the previous script failed
    old_logic2 = """        final driverStore = ref.read(driverStoreProvider);
        final profile = driverStore.profile;
        final driverId = profile['id'];"""
    if old_logic2 in content:
        content = content.replace(old_logic2, new_logic)

with open('/Users/aswath/Documents/Tripzo/TMS/lib/screens/driver/driver_routes_screen.dart', 'w') as f:
    f.write(content)
print("Fixed driver ID logic.")
