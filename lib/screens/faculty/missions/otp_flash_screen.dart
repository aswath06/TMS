import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tripzo/utils/crypto_utils.dart';
import 'package:flutter/services.dart';

class OtpFlashScreen extends StatefulWidget {
  final String otp;
  final String title;
  final String? qrDataPayload;

  const OtpFlashScreen({
    super.key,
    required this.otp,
    required this.title,
    this.qrDataPayload,
  });

  @override
  State<OtpFlashScreen> createState() => _OtpFlashScreenState();
}

class _OtpFlashScreenState extends State<OtpFlashScreen> with SingleTickerProviderStateMixin {
  int _secondsLeft = 30;
  late Timer _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    HapticFeedback.heavyImpact();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer.cancel();
        if (mounted) Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Robustly determine raw OTP for display and encrypted data for QR
    final String rawOtp;
    String qrData;
    
    if (RegExp(r'^\d{6}$').hasMatch(widget.otp)) {
      // Input is raw numeric string
      rawOtp = widget.otp;
      qrData = CryptoUtils.encryptOTP(widget.otp);
    } else {
      // Input is likely encrypted hex string
      qrData = widget.otp;
      final decrypted = CryptoUtils.decryptOTP(widget.otp);
      // If decryption fails to produce 6 digits, it might return the hex, 
      // so we should handle that gracefully in the UI.
      rawOtp = decrypted;
    }

    if (widget.qrDataPayload != null) {
      qrData = widget.qrDataPayload!;
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Premium Color Palette & Design Tokens
    final Color glassColor = isDark 
        ? const Color(0xFF0F172A).withValues(alpha: 0.7) 
        : const Color(0xFFF8FAFC).withValues(alpha: 0.7);
    final Color cardBg = isDark 
        ? const Color(0xFF1E293B).withValues(alpha: 0.9) 
        : Colors.white.withValues(alpha: 0.95);
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? Colors.white54 : const Color(0xFF64748B);
    final Color accentColor = const Color(0xFF6366F1); // Indigo-500
    final Color primaryBlue = const Color(0xFF4F46E5); // Indigo-600

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Ultra-Glassy Immersive Backdrop
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                color: glassColor,
              ),
            ),
          ),

          // 2. Centered Popup with Premium Card
          Center(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutBack,
              tween: Tween(begin: 0.7, end: 1.0),
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: ((scale - 0.7) / 0.3).clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Container(
                width: MediaQuery.of(context).size.width * 0.88,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
                      blurRadius: 50,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Accent Bar
                    Container(
                      height: 6,
                      width: 60,
                      margin: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
                      child: Column(
                        children: [
                          // Header area
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  widget.title.toUpperCase(),
                                  style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(Icons.close_rounded, color: subTextColor, size: 18),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Secure Verification",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // QR Code Container with Pulse Effect
                          ScaleTransition(
                            scale: Tween(begin: 1.0, end: 1.05).animate(
                              CurvedAnimation(
                                parent: _pulseController,
                                curve: Curves.easeInOut,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(36),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.3),
                                    blurRadius: 35,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: MediaQuery.of(context).size.width * 0.42,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Color(0xFF1E293B),
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          Text(
                            "DRIVERS SCAN CODE",
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // OTP Display in a box below QR
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              rawOtp,
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                                letterSpacing: 8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Countdown & Status Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                // Circular Timer
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: CircularProgressIndicator(
                                        value: _secondsLeft / 30,
                                        strokeWidth: 5,
                                        strokeCap: StrokeCap.round,
                                        backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                      ),
                                    ),
                                    Text(
                                      "$_secondsLeft",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _secondsLeft > 10 ? "OTP IS ACTIVE" : "EXPIRING SOON",
                                        style: TextStyle(
                                          color: _secondsLeft > 10 ? Colors.green : Colors.orange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      Text(
                                        "Expires in $_secondsLeft seconds",
                                        style: TextStyle(
                                          color: subTextColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.shield_rounded, color: Colors.green, size: 18),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                          // Security Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_outline_rounded, color: subTextColor, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                "END-TO-END ENCRYPTED",
                                style: TextStyle(
                                  color: subTextColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
