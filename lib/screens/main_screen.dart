import 'package:flutter/material.dart';
import 'package:tripzo/screens/admin/admin_dashboard_screen.dart';
import 'package:tripzo/screens/admin/AdminProfileScreen.dart';
import 'package:tripzo/screens/admin/request/request_list_page.dart';
import 'package:tripzo/screens/admin/vechiles/vechile_page.dart'; // Ensure path is correct
import 'package:tripzo/screens/admin/admin_driver_screen.dart';
// Driver Screens
import 'package:tripzo/screens/driver/DriverLeaveScreen.dart';
import 'package:tripzo/screens/driver/DriverProfileScreen.dart';
import 'package:tripzo/screens/driver/driver_duties_screen.dart';
import 'package:tripzo/screens/driver/driver_routes_screen.dart';
// Faculty/Admin Screens
import 'faculty/profile_screen.dart';
import 'faculty/missions_screen.dart';
import 'faculty/dashboard_screen.dart';
import 'faculty/requests_screen.dart';

import '../components/custom_bottom_bar.dart';

class MainScreen extends StatefulWidget {
  final String userRole;
  const MainScreen({super.key, required this.userRole});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
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
    switch (widget.userRole.toLowerCase()) {
      case 'transport admin':
        return [
          const AdminDashboardScreen(),
          const RequestListPage(),
          const VehiclePage(),
          const AdminDriverScreen(),
          const AdminProfileScreen(),
        ];
      case 'faculty':
        return [
          const DashboardScreen(),
          const MissionsScreen(),
          const RequestsScreen(),
          const ProfileScreen(),
        ];
      case 'driver':
      default:  
        return [
          const DriverDutiesScreen(),
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
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: const NeverScrollableScrollPhysics(),
            children: _getScreens(),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: CustomBottomBar(
              currentIndex: _currentIndex,
              userRole: widget.userRole,
              onTap: (index) {
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutQuart,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
