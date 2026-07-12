import os

file_path = '/Users/aswath/Documents/Tripzo/TMS/lib/screens/admin/request/daily_routines_page.dart'

with open(file_path, 'r') as f:
    content = f.read()

old_str = "final Map<String, bool> _loadingRuns = {};"
new_str = "final Map<String, bool> _loadingRuns = {};\n  bool _isListView = false;"

content = content.replace(old_str, new_str)

with open(file_path, 'w') as f:
    f.write(content)
