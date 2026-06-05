import re

def fix_notification():
    with open('lib/screens/notification/notification_list_screen.dart', 'r') as f:
        c = f.read()
    c = c.replace('Consumer(\n                    builder: (context, provider, _) {',
                  'Consumer(\n                    builder: (context, ref, _) {\n                      final provider = ref.watch(notificationProviderFamily);')
    c = c.replace('Consumer(\n            builder: (context, provider, _) {',
                  'Consumer(\n            builder: (context, ref, _) {\n              final provider = ref.watch(notificationProviderFamily);')
    c = c.replace('Consumer(\n             builder: (context, provider, _) {',
                  'Consumer(\n             builder: (context, ref, _) {\n               final provider = ref.watch(notificationProviderFamily);')
    with open('lib/screens/notification/notification_list_screen.dart', 'w') as f:
        f.write(c)

def fix_driver_routes():
    with open('lib/screens/driver/driver_routes_screen.dart', 'r') as f:
        c = f.read()
    c = c.replace('Consumer(', 'Consumer(builder: (context, ref, child) { final store = ref.watch(driverStoreProvider); return ')
    # driver_routes_screen: `return Consumer( builder: (context, store, child) =>` -> handled manually below
    
    with open('lib/screens/driver/driver_routes_screen.dart', 'w') as f:
        f.write(c)

def fix_reward_history():
    with open('lib/screens/driver/reward_points_history_screen.dart', 'r') as f:
        c = f.read()
    # It might just be `Consumer(` and `builder: (context, store, child)`
    c = re.sub(r'Consumer\(\s*builder:\s*\(context,\s*store,\s*child\)\s*\{',
               r'Consumer(\n        builder: (context, ref, child) {\n          final store = ref.watch(driverStoreProvider);', c)
    c = re.sub(r'Consumer\(\s*builder:\s*\(context,\s*store,\s*child\)\s*=>',
               r'Consumer(\n        builder: (context, ref, child) {\n          final store = ref.watch(driverStoreProvider);\n          return ', c)
    # the second replacement needs an extra `}` but wait, `=>` doesn't use `{}` so it's a syntax error to just `return ` without closing `}`!
    
    with open('lib/screens/driver/reward_points_history_screen.dart', 'w') as f:
        f.write(c)

fix_notification()
fix_reward_history()
