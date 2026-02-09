import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/routes.dart';

class LockScreen extends StatefulWidget {
  final String role; // Passed from Splash to redirect after PIN success
  const LockScreen({super.key, required this.role});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String enteredPin = "";
  String? storedPin;
  bool isError = false;

  @override
  void initState() {
    super.initState();
    _getStoredPin();
  }

  Future<void> _getStoredPin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      storedPin = prefs.getString('userPin');
    });
  }

  void _handleKeyPress(String value) {
    if (enteredPin.length < 4) {
      setState(() {
        enteredPin += value;
        isError = false;
      });
    }

    if (enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _verifyPin() async {
    if (enteredPin == storedPin) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.dashboard,
        arguments: widget.role,
      );
    } else {
      setState(() {
        isError = true;
        enteredPin = ""; // Reset on error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(Icons.lock_person_rounded, size: 64, color: primaryBlue),
            const SizedBox(height: 24),
            const Text(
              "Enter App PIN",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isError
                  ? "Incorrect PIN. Try again."
                  : "Please enter your 4-digit security code",
              style: TextStyle(color: isError ? Colors.red : Colors.grey),
            ),
            const SizedBox(height: 40),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < enteredPin.length
                        ? primaryBlue
                        : Colors.grey.shade300,
                  ),
                );
              }),
            ),
            const Spacer(),
            _buildNumPad(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildNumPad() {
    return Column(
      children: [
        for (var row in [
          ["1", "2", "3"],
          ["4", "5", "6"],
          ["7", "8", "9"],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((val) => _numButton(val)).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 80), // Empty space
            _numButton("0"),
            _numButton("backspace", isIcon: true),
          ],
        ),
      ],
    );
  }

  Widget _numButton(String val, {bool isIcon = false}) {
    return Container(
      margin: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () {
          if (isIcon) {
            if (enteredPin.isNotEmpty) {
              setState(
                () =>
                    enteredPin = enteredPin.substring(0, enteredPin.length - 1),
              );
            }
          } else {
            _handleKeyPress(val);
          }
        },
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          child: isIcon
              ? const Icon(Icons.backspace_outlined, size: 28)
              : Text(
                  val,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
