import os
import re

files_to_fix = [
    'lib/screens/auth/login_screen.dart',
    'lib/components/notification_bell.dart',
    'lib/screens/admin/admin_allowance_screen.dart',
    'lib/screens/admin/admin_driver_screen.dart',
    'lib/screens/driver/DriverLeaveScreen.dart',
    'lib/screens/driver/DriverProfileScreen.dart',
    'lib/screens/driver/driver_duties_screen.dart',
    'lib/screens/admin/add_driver_page.dart',
    'lib/screens/admin/request/view_all_leaves_page.dart',
    'lib/screens/driver/driver_allowance_screen.dart',
]

provider_map = {
    'NotificationProvider': 'notificationProviderFamily',
    'AdminAllowanceStore': 'adminAllowanceStoreProvider',
    'DriverStore': 'driverStoreProvider',
    'RequestStore': 'requestStoreProvider',
}

def fix_file(filepath):
    if not os.path.exists(filepath):
        print(f"Not found: {filepath}")
        return
        
    with open(filepath, 'r') as f:
        content = f.read()
        
    for store, provider in provider_map.items():
        # Handle Provider.of<Store>(context, listen: false) and similar
        # We need to be careful with newlines, sometimes context is on next line
        content = re.sub(
            r'Provider\.of<' + store + r'>\s*\([^,]+(?:,\s*listen\s*:\s*false)?\)',
            'ref.read(' + provider + ')',
            content
        )
        
        # Handle Consumer<Store>(builder: (context, store_var, child)) {
        pattern = r'Consumer<' + store + r'>\(\s*builder:\s*\([^,]+,\s*([^,]+),\s*([^\)]+)\)\s*\{'
        def replacer(match):
            store_var = match.group(1)
            child_var = match.group(2)
            return 'Consumer(\nbuilder: (context, ref, ' + child_var + ') {\nfinal ' + store_var + ' = ref.watch(' + provider + ');'
        
        content = re.sub(pattern, replacer, content)

    with open(filepath, 'w') as f:
        f.write(content)

for filepath in files_to_fix:
    fix_file(filepath)
    
print("Finished fixing missed riverpod conversions")
