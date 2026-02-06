import 'package:flutter/material.dart';
import '../components/custom_bottom_bar.dart';
import 'profile_screen.dart';
import 'missions_screen.dart';
import 'dashboard_screen.dart';
import 'requests_screen.dart';

class MainScreen extends StatefulWidget {
  final String userRole;
  const MainScreen({super.key, required this.userRole});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  List<Widget> _getScreens() {
    final bool isFaculty = widget.userRole == 'faculty';

    if (isFaculty) {
      return [
        const DashboardScreen(),
        const MissionsScreen(),
        const RequestsScreen(),
        const ProfileScreen(),
      ];
    } else {
      return [
        const Center(child: Text("Driver Dashboard")),
        const Center(child: Text("Routes")),
        const Center(child: Text("Schedule")),
        const ProfileScreen(),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: bgColor,
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _getScreens()),
          Align(
            alignment: Alignment.bottomCenter,
            child: CustomBottomBar(
              currentIndex: _currentIndex,
              userRole: widget.userRole,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
