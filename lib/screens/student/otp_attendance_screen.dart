import 'package:flutter/material.dart';
import 'package:tripzo/screens/student/student_attendance_scanner_screen.dart';

class OtpAttendanceScreen extends StatefulWidget {
  const OtpAttendanceScreen({super.key});

  @override
  State<OtpAttendanceScreen> createState() => _OtpAttendanceScreenState();
}

class _OtpAttendanceScreenState extends State<OtpAttendanceScreen> {
  String _otpCode = "";
  final int _maxLen = 6;

  void _onKeyPress(String value) {
    if (_otpCode.length < _maxLen) {
      setState(() {
        _otpCode += value;
      });
      // Auto-submit if we hit 6 digits
      if (_otpCode.length == _maxLen) {
        Future.delayed(const Duration(milliseconds: 200), _onSubmit);
      }
    }
  }

  void _onBackspace() {
    if (_otpCode.isNotEmpty) {
      setState(() {
        _otpCode = _otpCode.substring(0, _otpCode.length - 1);
      });
    }
  }

  void _onSubmit() {
    if (_otpCode.length == _maxLen) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Text("Submitting OTP: $_otpCode"),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.all(20),
        ),
      );
    }
  }

  Future<void> _openScanner() async {
    final String? scannedOtp = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StudentAttendanceScannerScreen(),
      ),
    );

    if (scannedOtp != null && scannedOtp.isNotEmpty) {
      setState(() {
        _otpCode = scannedOtp.length > _maxLen ? scannedOtp.substring(0, _maxLen) : scannedOtp;
      });
      if (_otpCode.length == _maxLen) {
        _onSubmit();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color primaryBlue = const Color(0xFF6366F1);
    
    // Calculate size dynamically
    final double screenHeight = MediaQuery.of(context).size.height;
    final double keypadHeight = screenHeight * 0.45;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: titleColor),
        title: Text(
          "Enter Attendance Code",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: titleColor,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // OTP Display
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(_maxLen, (index) {
                        final bool hasValue = index < _otpCode.length;
                        final String digit = hasValue ? _otpCode[index] : "";
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          width: hasValue ? 50 : 42,
                          height: hasValue ? 62 : 52,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: hasValue ? primaryBlue : (isDark ? Colors.white24 : Colors.black12),
                              width: hasValue ? 2 : 1,
                            ),
                            boxShadow: hasValue
                                ? [
                                    BoxShadow(
                                      color: primaryBlue.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    )
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              digit,
                              style: TextStyle(
                                fontSize: hasValue ? 28 : 24,
                                fontWeight: FontWeight.w900,
                                color: titleColor,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            
            // Interactive Numpad Area
            Container(
              height: keypadHeight,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _AnimatedNumpadButton(text: "1", color: titleColor, isDark: isDark, onTap: () => _onKeyPress("1")),
                      _AnimatedNumpadButton(text: "2", color: titleColor, isDark: isDark, onTap: () => _onKeyPress("2")),
                      _AnimatedNumpadButton(text: "3", color: titleColor, isDark: isDark, onTap: () => _onKeyPress("3")),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _AnimatedNumpadButton(text: "4", color: titleColor, isDark: isDark, onTap: () => _onKeyPress("4")),
                      _AnimatedNumpadButton(text: "5", color: titleColor, isDark: isDark, onTap: () => _onKeyPress("5")),
                      _AnimatedNumpadButton(text: "6", color: titleColor, isDark: isDark, onTap: () => _onKeyPress("6")),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _AnimatedNumpadButton(text: "7", color: titleColor, isDark: isDark, onTap: () => _onKeyPress("7")),
                      _AnimatedNumpadButton(text: "8", color: titleColor, isDark: isDark, onTap: () => _onKeyPress("8")),
                      _AnimatedNumpadButton(text: "9", color: titleColor, isDark: isDark, onTap: () => _onKeyPress("9")),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Scan QR Option 
                      _AnimatedNumpadButton(
                        text: "QR",
                        icon: Icons.qr_code_scanner_rounded,
                        color: titleColor,
                        isDark: isDark,
                        onTap: _openScanner,
                      ),
                      _AnimatedNumpadButton(text: "0", color: titleColor, isDark: isDark, onTap: () => _onKeyPress("0")),
                      _AnimatedNumpadButton(
                        text: "DEL",
                        icon: Icons.backspace_rounded,
                        color: titleColor,
                        isDark: isDark,
                        onTap: _onBackspace,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Animated Numpad Button
class _AnimatedNumpadButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _AnimatedNumpadButton({
    required this.text,
    this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_AnimatedNumpadButton> createState() => _AnimatedNumpadButtonState();
}

class _AnimatedNumpadButtonState extends State<_AnimatedNumpadButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) {
      _controller.reverse();
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAction = widget.icon != null;
    
    // Size dynamically based on screen width
    final double screenWidth = MediaQuery.of(context).size.width;
    final double buttonSize = screenWidth * 0.20; // 20% of screen width

    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isAction ? (widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.05)) : Colors.transparent,
            boxShadow: isAction ? [] : [
              BoxShadow(
                color: widget.isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: Center(
            child: widget.icon != null
                ? Icon(widget.icon, color: widget.color, size: buttonSize * 0.4)
                : Text(
                    widget.text,
                    style: TextStyle(
                      fontSize: buttonSize * 0.45,
                      fontWeight: FontWeight.w600,
                      color: widget.color,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
