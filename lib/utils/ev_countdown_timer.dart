import 'dart:async';
import 'package:flutter/material.dart';

class EvCountdownTimer extends StatefulWidget {
  final String timestampStr;
  final int durationSeconds;
  final VoidCallback onExpire;

  const EvCountdownTimer({
    Key? key,
    required this.timestampStr,
    this.durationSeconds = 60,
    required this.onExpire,
  }) : super(key: key);

  @override
  State<EvCountdownTimer> createState() => _EvCountdownTimerState();
}

class _EvCountdownTimerState extends State<EvCountdownTimer> {
  Timer? _timer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _calculate();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculate());
  }

  void _calculate() {
    try {
      final startTime = DateTime.parse(widget.timestampStr).toLocal();
      final now = DateTime.now();
      final elapsed = now.difference(startTime).inSeconds;
      final remaining = widget.durationSeconds - elapsed;
      if (remaining <= 0) {
        _timer?.cancel();
        if (_remainingSeconds != 0) {
          if (mounted) setState(() => _remainingSeconds = 0);
          widget.onExpire();
        }
      } else {
        if (mounted) setState(() => _remainingSeconds = remaining);
      }
    } catch (_) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingSeconds <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer, color: Colors.orange, size: 14),
        const SizedBox(width: 4),
        Text(
          "00:${_remainingSeconds.toString().padLeft(2, '0')}",
          style: const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
