import re

with open('/Users/aswath/Documents/Tripzo/TMS/lib/screens/driver/driver_routes_screen.dart', 'r') as f:
    content = f.read()

# Replace the driver ID logic with a regex
content = re.sub(
    r'final driverStore = ref\.read\(driverStoreProvider\);\s*final profile = driverStore\.profile;\s*final driverId = profile\[\'id\'\];',
    r'final driverId = await UserStore.getUserId();',
    content
)

content = re.sub(
    r'final driverStore = ref\.read\(driverStoreProvider\);\s*final driver = driverStore\.driver;\s*final driverId = driver\[\'id\'\];',
    r'final driverId = await UserStore.getUserId();',
    content
)

# Fix the trailing braces issue (Line 1014 expected an executable)
# The file probably ends with something like `}\n}` when it shouldn't.
# We'll just split lines, strip empty ones, and see.
lines = content.split('\n')
while lines and not lines[-1].strip():
    lines.pop()

if lines and lines[-1].strip() == '}':
    if len(lines) > 1 and lines[-2].strip() == '}':
        # Remove the extra brace
        lines.pop()

with open('/Users/aswath/Documents/Tripzo/TMS/lib/screens/driver/driver_routes_screen.dart', 'w') as f:
    f.write('\n'.join(lines) + '\n')
