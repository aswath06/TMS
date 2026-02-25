import 'dart:async';
import 'package:flutter/material.dart';

/// Animated dots widget used as a loading placeholder in profile info cards.
class TypingText extends StatefulWidget {
  final TextStyle style;
  const TypingText({super.key, required this.style});

  @override
  State<TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<TypingText> {
  String _dots = "";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (mounted) {
        setState(() => _dots = _dots.length >= 3 ? "" : "$_dots.");
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(_dots, style: widget.style);
}
