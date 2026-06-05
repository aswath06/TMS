import os
import re

def fix_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # If the file does NOT have ConsumerStatefulWidget, we should revert ConsumerState<X> to State<X>
    if 'ConsumerStatefulWidget' not in content:
        content = re.sub(r'ConsumerState<([a-zA-Z0-9_]+)>\s+createState\(\)', r'State<\1> createState()', content)
        content = re.sub(r'extends\s+ConsumerState<([a-zA-Z0-9_]+)>', r'extends State<\1>', content)
    
    with open(filepath, 'w') as f:
        f.write(content)

def main():
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                fix_file(os.path.join(root, file))

if __name__ == '__main__':
    main()
