import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/routes.dart';

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
      HapticFeedback.mediumImpact();
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.dashboard,
        arguments: widget.role,
      );
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        isError = true;
        enteredPin = ""; // Reset on error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryBlue = const Color(0xFF6366F1); // Elegant premium indigo
    
    // Adaptive color system
    final Color bgColor = isDark ? const Color(0xFF0F172A) : Colors.white; // Slate 900 vs White
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final Color dotUnselectedColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Lock Icon with premium glowing effect in dark mode
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? primaryBlue.withValues(alpha: 0.1) : primaryBlue.withValues(alpha: 0.05),
              ),
              child: Icon(Icons.lock_person_rounded, size: 68, color: primaryBlue),
            ),
            const SizedBox(height: 24),
            Text(
              "Enter App PIN",
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.w900, 
                color: textColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isError
                  ? "Incorrect PIN. Try again."
                  : "Please enter your 4-digit security code",
              style: TextStyle(
                color: isError ? Colors.redAccent : subTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            
            // PIN dots with smooth animations and glows
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final bool isFilled = index < enteredPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? primaryBlue : dotUnselectedColor,
                    border: Border.all(
                      color: isFilled ? primaryBlue : (isDark ? Colors.white12 : Colors.black12),
                      width: 1.5,
                    ),
                    boxShadow: isFilled ? [
                      BoxShadow(
                        color: primaryBlue.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ] : [],
                  ),
                );
              }),
            ),
            const Spacer(),
            _buildNumPad(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildNumPad(BuildContext context) {
    return Column(
      children: [
        for (var row in [
          ["1", "2", "3"],
          ["4", "5", "6"],
          ["7", "8", "9"],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((val) => _numButton(context, val)).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 100), // Perfect column spacer (width 76 + margin 24)
            _numButton(context, "0"),
            _numButton(context, "backspace", isIcon: true),
          ],
        ),
      ],
    );
  }

  Widget _numButton(BuildContext context, String val, {bool isIcon = false}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color buttonBg = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9); // Slate 100 vs dark glass
    final Color activeSplashColor = const Color(0xFF6366F1).withValues(alpha: 0.2);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: buttonBg,
        shape: BoxShape.circle,
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: InkWell(
        onTap: () {
          if (isIcon) {
            if (enteredPin.isNotEmpty) {
              setState(
                () => enteredPin = enteredPin.substring(0, enteredPin.length - 1),
              );
              HapticFeedback.lightImpact();
            }
          } else {
            _handleKeyPress(val);
            HapticFeedback.lightImpact();
          }
        },
        borderRadius: BorderRadius.circular(50),
        splashColor: activeSplashColor,
        highlightColor: activeSplashColor,
        child: Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          child: isIcon
              ? Icon(Icons.backspace_outlined, size: 24, color: textColor)
              : Text(
                  val,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
        ),
      ),
    );
  }
}
