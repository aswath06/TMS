import 'package:flutter/material.dart';
import 'package:tms/screens/driver/DriverLeaveScreen.dart';
import 'package:tms/screens/driver/DriverProfileScreen.dart';
import 'package:tms/screens/driver/driver_duties_screen.dart';
import 'package:tms/screens/driver/driver_routes_screen.dart';
import '../components/custom_bottom_bar.dart';
import 'faculty/profile_screen.dart';
import 'faculty/missions_screen.dart';
import 'faculty/dashboard_screen.dart';
import 'faculty/requests_screen.dart' hide MissionsScreen;

class MainScreen extends StatefulWidget {
  final String userRole;
  const MainScreen({super.key, required this.userRole});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  // PageController handles the sliding animation
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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
        const DriverDutiesScreen(), // Updated from placeholder
        const DriverRoutesScreen(),
        const DriverLeaveScreen(),
        const DriverProfileScreen(),
      ];
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
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
          // Replaced IndexedStack with PageView for smooth transitions
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics:
                const NeverScrollableScrollPhysics(), // Disable swiping to keep Nav Bar in sync
            children: _getScreens(),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: CustomBottomBar(
              currentIndex: _currentIndex,
              userRole: widget.userRole,
              onTap: (index) {
                // Trigger the sliding animation
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutQuart, // Smooth, professional curve
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
