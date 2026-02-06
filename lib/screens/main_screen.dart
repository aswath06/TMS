import 'package:flutter/material.dart';
import '../components/custom_bottom_bar.dart';

class MainScreen extends StatefulWidget {
  final String userRole;
  const MainScreen({super.key, required this.userRole});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  Widget _buildBody(bool isFaculty) {
    // 4 screens for each role
    final List<Widget> facultyScreens = [
      const Center(child: Text("Faculty Home")),
      const Center(child: Text("Requests")),
      const Center(child: Text("History")),
      const Center(child: Text("Profile")),
    ];

    final List<Widget> driverScreens = [
      const Center(child: Text("Driver Home")),
      const Center(child: Text("Routes")),
      const Center(child: Text("Schedule")),
      const Center(child: Text("Profile")),
    ];

    return isFaculty
        ? facultyScreens[_currentIndex]
        : driverScreens[_currentIndex];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF1F5F9,
      ), // Matching your Login background
      body: _buildBody(widget.userRole == 'faculty'),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: _currentIndex,
        userRole: widget.userRole,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
