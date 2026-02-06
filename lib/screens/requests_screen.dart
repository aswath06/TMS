import 'package:flutter/material.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Requests")),
      body: const Center(
        child: Icon(Icons.paste_rounded, size: 100, color: Colors.grey),
      ),
    );
  }
}
