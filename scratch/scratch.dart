import 'package:flutter/material.dart';

class DummyScratch extends StatefulWidget {
  const DummyScratch({super.key});

  @override
  State<DummyScratch> createState() => _DummyScratchState();
}

class _DummyScratchState extends State<DummyScratch> {
  final Map<String, dynamic> _run = {'id': 1, 'service_date': '2026-07-16'};

  void _refreshDetails() {}

  void _showBusChangeRequestModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const SizedBox.shrink(); // Replaced missing _BusChangeRequestModal
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
