import re

file_path = '/Users/aswath/Documents/Tripzo/TMS/lib/screens/admin/request/daily_routines_page.dart'

with open(file_path, 'r') as f:
    content = f.read()

content = re.sub(
    r"(String _selectedFilter = 'ALL';\n\s*String _selectedDateFilter = 'ALL';)",
    r"\1\n  bool _isListView = false;",
    content
)

with open(file_path, 'w') as f:
    f.write(content)

