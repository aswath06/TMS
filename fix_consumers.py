import os
import re

def fix_consumer_generic(filepath):
    if not os.path.exists(filepath): return
    with open(filepath, 'r') as f:
        content = f.read()

    # Consumer<Store> -> Consumer
    content = re.sub(r'Consumer<[A-Za-z0-9_]+>\s*\(', r'Consumer(', content)
    
    # We also need to fix `WidgetRef ref` where it complains about undefined getters.
    # In reward_points_history_screen, ref.watch(driverStoreProvider) needs to be assigned.
    # Actually, if we just replace Consumer with ConsumerWidget it would be much cleaner.
    
    with open(filepath, 'w') as f:
        f.write(content)

fix_consumer_generic('lib/screens/notification/notification_list_screen.dart')

