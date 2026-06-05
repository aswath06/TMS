import os
import re

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Fix createState
    content = re.sub(r'State<([a-zA-Z0-9_]+)>\s+createState\(\)', r'ConsumerState<\1> createState()', content)
    
    # Fix Consumer with 1 argument (which is wrong in riverpod)
    # E.g. Consumer<VehicleStore>( builder: (context, store, child) => ... )
    # Should become: Consumer( builder: (context, ref, child) { final store = ref.watch(vehicleStoreProvider); return ... } )
    # This is too complex for regex, so I will just change `Consumer<([a-zA-Z0-9_]+)>` to `Consumer` 
    # But wait! If we do that, the builder still has `(context, store, child)`.
    # Let's just manually fix the few files that have `Consumer<` or use `ConsumerWidget` instead!
    
    with open(filepath, 'w') as f:
        f.write(content)

def main():
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                fix_file(os.path.join(root, file))

if __name__ == '__main__':
    main()
