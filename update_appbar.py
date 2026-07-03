file_path = "/Users/aswath/Documents/Tripzo/TMS/lib/screens/driver/driver_routes_screen.dart"
with open(file_path, "r") as f:
    content = f.read()

old_appbar = """      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: _isSearching"""

new_appbar = """      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        title: _isSearching"""

content = content.replace(old_appbar, new_appbar)

with open(file_path, "w") as f:
    f.write(content)
