import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  final String title;
  const DashboardScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: const Center(child: Text("Welcome to your Dashboard")),
    );
  }
}
