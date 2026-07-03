with open('/Users/aswath/Documents/Tripzo/TMS/lib/screens/driver/driver_routes_screen.dart', 'r') as f:
    content = f.read()

# We know where it starts: `  Widget _buildDailyBusRouteCard({`
start_idx = content.find("  Widget _buildDailyBusRouteCard({")
if start_idx != -1:
    # Find where the function ends. It ends just before `class _DriverRoutesScreenState` starts? No, wait.
    # Actually, if it replaced `}\n` after `createState() => _DriverRoutesScreenState();`,
    # then it was put directly in `DriverRoutesScreen`.
    # It ends at the next `class _DriverRoutesScreenState` or similar? 
    # Let's just use python to extract everything from `Widget _buildDailyBusRouteCard` up to the end of its block.
    # To be safer, since we appended it after `createState() => _DriverRoutesScreenState();\n`, let's just 
    # split by `class _DriverRoutesScreenState extends ConsumerState<DriverRoutesScreen> with SingleTickerProviderStateMixin {`
    
    parts = content.split("class _DriverRoutesScreenState extends ConsumerState<DriverRoutesScreen> with SingleTickerProviderStateMixin {")
    if len(parts) == 2:
        part1 = parts[0]
        part2 = parts[1]
        
        # In part1, it should look like:
        # class DriverRoutesScreen ... {
        #   ...
        #   ConsumerState<DriverRoutesScreen> createState() => _DriverRoutesScreenState();
        # 
        #   Widget _buildDailyBusRouteCard(...) { ... }
        # } // this closing brace was missing? Wait, if I replaced `}\n`, I replaced the closing brace of `DriverRoutesScreen`.
        
        # Let's fix this properly. I'll download the original file state using git checkout, then redo the replacement correctly.
