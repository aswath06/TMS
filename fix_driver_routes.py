with open('/Users/aswath/Documents/Tripzo/TMS/lib/screens/driver/driver_routes_screen.dart', 'r') as f:
    content = f.read()

# We need to extract the widget string which starts from `  Widget _buildDailyBusRouteCard({` 
# up to the end of its block before `class _DriverRoutesScreenState`.
start_str = "  Widget _buildDailyBusRouteCard({"
end_str = "class _DriverRoutesScreenState extends ConsumerState<DriverRoutesScreen> with SingleTickerProviderStateMixin {"

idx1 = content.find(start_str)
idx2 = content.find(end_str)

if idx1 != -1 and idx2 != -1:
    # The function is between idx1 and idx2
    function_str = content[idx1:idx2]
    
    # We remove this function from the middle
    new_content = content[:idx1] + "}\n\n" + end_str + content[idx2 + len(end_str):]
    
    # We append the function before the final `}`
    # Find the last `}`
    last_brace_idx = new_content.rfind('}')
    
    final_content = new_content[:last_brace_idx] + function_str + "\n}\n"
    
    with open('/Users/aswath/Documents/Tripzo/TMS/lib/screens/driver/driver_routes_screen.dart', 'w') as f:
        f.write(final_content)
    print("Fixed position.")
else:
    print("Failed to find boundaries.")
