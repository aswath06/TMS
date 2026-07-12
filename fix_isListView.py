import os

file_path = '/Users/aswath/Documents/Tripzo/TMS/lib/screens/admin/request/daily_routines_page.dart'

with open(file_path, 'r') as f:
    content = f.read()

old_state = """  String _selectedFilter = 'ALL';
  String _selectedDateFilter = 'ALL';
  
  bool _isLoading = false;"""

new_state = """  String _selectedFilter = 'ALL';
  String _selectedDateFilter = 'ALL';
  bool _isListView = false;
  
  bool _isLoading = false;"""

if old_state in content:
    content = content.replace(old_state, new_state)
    print("Success")
else:
    print("Failed")

with open(file_path, 'w') as f:
    f.write(content)

