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

  // Placeholder Screens
  Widget _buildBody(bool isFaculty) {
    if (isFaculty) {
      return [
        const Center(child: Text("Faculty Home")),
        const Center(child: Text("My Requests (Clipboard)")),
        const Center(child: Text("Faculty Profile")),
      ][_currentIndex];
    } else {
      return [
        const Center(child: Text("Driver Home")),
        const Center(child: Text("Routes Map")),
        const Center(child: Text("Driver Profile")),
      ][_currentIndex];
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isFaculty = widget.userRole == 'faculty';

    return Scaffold(
      body: _buildBody(isFaculty),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: _currentIndex,
        userRole: widget.userRole,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
