import os
import re

STORES = {
    'VehicleStore': 'vehicleStoreProvider',
    'RequestStore': 'requestStoreProvider',
    'DriverStore': 'driverStoreProvider',
    'DashboardStore': 'dashboardStoreProvider',
    'ThemeStore': 'themeStoreProvider',
    'LanguageStore': 'languageStoreProvider',
    'AdminAllowanceStore': 'adminAllowanceStoreProvider',
    'NotificationProvider': 'notificationProviderFamily',
}

def migrate_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    if "package:provider/provider.dart" not in content:
        return

    content = content.replace("import 'package:provider/provider.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:tripzo/store/providers.dart';")

    content = re.sub(r'\bStatelessWidget\b', 'ConsumerWidget', content)
    content = re.sub(r'\bStatefulWidget\b', 'ConsumerStatefulWidget', content)
    content = re.sub(r'extends\s+State<', 'extends ConsumerState<', content)

    blocks = content.split('class ')
    new_blocks = [blocks[0]]
    for block in blocks[1:]:
        if 'extends ConsumerWidget' in block:
            block = re.sub(r'Widget\s+build\(\s*BuildContext\s+context\s*\)', r'Widget build(BuildContext context, WidgetRef ref)', block)
        new_blocks.append(block)
    content = 'class '.join(new_blocks)

    for store, provider in STORES.items():
        content = re.sub(rf'context\.watch<{store}>\(\)', rf'ref.watch({provider})', content)
        content = re.sub(rf'context\.read<{store}>\(\)', rf'ref.read({provider})', content)
        content = re.sub(rf'Provider\.of<{store}>\(\s*context\s*,\s*listen\s*:\s*false\s*\)', rf'ref.read({provider})', content)
        content = re.sub(rf'Provider\.of<{store}>\(\s*context\s*\)', rf'ref.watch({provider})', content)

    with open(filepath, 'w') as f:
        f.write(content)

def main():
    files = [
        "lib/screens/faculty/requests_screen.dart",
        "lib/screens/faculty/dashboard_screen.dart",
        "lib/screens/faculty/missions/mission_details_screen.dart",
        "lib/screens/faculty/missions/mission_history_screen.dart",
        "lib/screens/faculty/missions_screen.dart",
        "lib/screens/security/security_dashboard_screen.dart",
        "lib/screens/auth/login_screen.dart",
        "lib/screens/driver/DriverLeaveScreen.dart",
        "lib/screens/driver/driver_duties_screen.dart",
        "lib/screens/driver/driver_routes_screen.dart",
        "lib/screens/driver/reward_points_history_screen.dart",
        "lib/screens/driver/completed_routes_screen.dart",
        "lib/screens/driver/maintenance/accident_page.dart",
        "lib/screens/driver/maintenance/service_page.dart",
        "lib/screens/driver/driver_allowance_screen.dart",
        "lib/screens/driver/DriverProfileScreen.dart",
        "lib/screens/notification/notification_list_screen.dart",
        "lib/screens/admin/admin_driver_detail_screen.dart",
        "lib/screens/admin/add_driver_page.dart",
        "lib/screens/admin/vechiles/add_vehicle_page.dart",
        "lib/screens/admin/admin_dashboard_screen.dart",
        "lib/screens/admin/request/view_all_leaves_page.dart",
        "lib/screens/admin/request/request_list_page.dart",
        "lib/screens/admin/request/request_detail_screen.dart",
        "lib/screens/admin/request/admin_finalize_request_screen.dart",
        "lib/screens/admin/admin_driver_screen.dart",
        "lib/screens/admin/admin_allowance_screen.dart",
        "lib/screens/setting/settings_page.dart",
        "lib/screens/splash_screen.dart",
        "lib/components/notification_card.dart",
        "lib/components/leave_card.dart",
        "lib/components/notification_bell.dart"
    ]
    for f in files:
        if os.path.exists(f):
            migrate_file(f)

if __name__ == '__main__':
    main()
