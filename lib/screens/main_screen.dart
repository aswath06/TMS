import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
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
  StreamSubscription<ServiceStatus>? _locationSubscription;
  bool _isGpsDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    
    // Initialize monitor for drivers
    if (widget.userRole.toLowerCase() == 'driver') {
      _startLocationMonitor();
    }
  }

  void _startLocationMonitor() {
    _locationSubscription = Geolocator.getServiceStatusStream().listen((status) {
      _evaluateGpsStatus(status);
    });
    
    // Initial check after build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isEnabled = await Geolocator.isLocationServiceEnabled();
      _evaluateGpsStatus(isEnabled ? ServiceStatus.enabled : ServiceStatus.disabled);
    });
  }

  Future<void> _evaluateGpsStatus(ServiceStatus status) async {
    if (!mounted) return;

    if (status == ServiceStatus.disabled) {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      
      if (isRunning && !_isGpsDialogOpen) {
        _showBlockingGpsDialog();
      }
    } else {
      if (_isGpsDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        _isGpsDialogOpen = false;
      }
    }
  }

  void _showBlockingGpsDialog() {
    _isGpsDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent back button
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: Colors.red),
              SizedBox(width: 12),
              Text("GPS REQUIRED", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.red)),
            ],
          ),
          content: const Text(
            "Live tracking is active. You MUST keep your location services (GPS) turned ON to continue using the app during a mission.",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Geolocator.openLocationSettings(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Open Location Settings", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _locationSubscription?.cancel();
    super.dispose();
  }

  List<Widget> _getScreens() {
    switch (widget.userRole.toLowerCase()) {
      case 'transport admin':
      case 'super admin':
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
