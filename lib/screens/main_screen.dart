import 'package:flutter/material.dart';
import '../components/custom_bottom_bar.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final String userRole;
  const MainScreen({super.key, required this.userRole});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Modern way: Define screens as a getter or helper method
  List<Widget> _getScreens() {
    bool isFaculty = widget.userRole == 'faculty';

    if (isFaculty) {
      return [
        const Center(child: Text("Faculty Home")),
        const Center(child: Text("Requests")),
        const Center(child: Text("History")),
        const ProfileScreen(),
      ];
    } else {
      return [
        const Center(child: Text("Driver Home")),
        const Center(child: Text("Routes")),
        const Center(child: Text("Schedule")),
        const ProfileScreen(),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      // Use IndexedStack to keep the state of pages alive when switching
      body: SafeArea(
        child: IndexedStack(index: _currentIndex, children: _getScreens()),
      ),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: _currentIndex,
        userRole: widget.userRole,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
