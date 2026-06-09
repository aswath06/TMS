import re

with open("lib/screens/admin/request/request_list_page.dart", "r") as f:
    content = f.read()

# Rename classes
content = content.replace("RequestListPage", "MissionsScreen")

# Remove back button
back_button_pattern = r"""\s*GestureDetector\(\s*onTap: \(\) => Navigator\.pop\(context\),\s*child: Padding\(\s*padding: const EdgeInsets\.only\(right: 8\.0\),\s*child: Icon\(\s*Icons\.arrow_back_ios_new_rounded,\s*color: titleColor,\s*size: 24,\s*\),\s*\),\s*\),"""
content = re.sub(back_button_pattern, "", content)

# Adjust pathType to show Faculty View or actual travel type instead of "Admin View"
content = content.replace('pathType: "Admin View"', 'pathType: mission[\'travelType\'] ?? "One-Way"')

with open("lib/screens/faculty/missions_screen.dart", "w") as f:
    f.write(content)

print("Done modifying missions_screen.dart")
