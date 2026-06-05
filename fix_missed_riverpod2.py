import os
import re

# We will just traverse ALL dart files in lib/screens and lib/components
files_to_fix = []
for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            files_to_fix.append(os.path.join(root, file))

provider_map = {
    'NotificationProvider': 'notificationProviderFamily',
    'AdminAllowanceStore': 'adminAllowanceStoreProvider',
    'DriverStore': 'driverStoreProvider',
    'RequestStore': 'requestStoreProvider',
    'VehicleStore': 'vehicleStoreProvider',
    'DashboardStore': 'dashboardStoreProvider'
}

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
        
    original = content
    
    for store, provider in provider_map.items():
        # Handle Provider.of<Store>(context, listen: false) with multiline
        # pattern: Provider\.of<Store>\s*\([^)]+\)
        content = re.sub(
            r'Provider\.of<' + store + r'>\s*\([^)]+\)',
            'ref.read(' + provider + ')',
            content
        )
        
        # Handle Consumer<Store>(builder: (context, store_var, child) {
        # using non-greedy match for anything up to { or =>
        # Actually it's safer to just replace Consumer<Store> with Consumer and then let developer fix the variables, but wait!
        # If we replace Consumer<Store>(builder: (context, store, child) { 
        # with Consumer(builder: (context, ref, child) { final store = ref.watch(provider);
        
        pattern = r'Consumer<' + store + r'>\(\s*builder:\s*\([^,]+,\s*([^,]+),\s*([^)]+)\)\s*\{'
        def replacer(match):
            store_var = match.group(1).strip()
            child_var = match.group(2).strip()
            return 'Consumer(\nbuilder: (context, ref, ' + child_var + ') {\nfinal ' + store_var + ' = ref.watch(' + provider + ');'
        
        content = re.sub(pattern, replacer, content)

    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)

for filepath in files_to_fix:
    fix_file(filepath)
    
print("Finished fixing missed riverpod conversions globally")
