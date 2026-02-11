import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../utils/routes.dart';
import '../store/user_store.dart';
import '../store/isdark.dart'; // Import Theme Store
import '../store/istamil.dart'; // Import Language Store

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Trigger Auth and Preferences Check
    _initiateStartupSequence();
  }

  /// Loads local settings and checks auth
  Future<void> _initiateStartupSequence() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Sync Theme and Language before navigating
    setState(() {
      ThemeStore.isDark = prefs.getBool('isDark') ?? false;
      bool isTamil = prefs.getBool('isTamil') ?? false;
      LanguageStore.isTamil = isTamil;
    });

    // 2. Wait for animation to finish a bit
    await Future.delayed(const Duration(milliseconds: 2000));

    // 3. Auth Logic
    final String? token = await UserStore.getToken();
    final String? role = await UserStore.getRole();
    final bool isPinEnabled = prefs.getBool('isPinEnabled') ?? false;

    if (!mounted) return;

    if (token != null && role != null) {
      if (isPinEnabled) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.lockScreen,
          arguments: role,
        );
      } else {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.dashboard,
          arguments: role,
        );
      }
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Local theme variables
    final bool isDark = ThemeStore.isDark;
    final Size size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 360;

    // Dynamic Colors
    final Color bgColorStart = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFFFFFFF);
    final Color bgColorEnd = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF1F5F9);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgColorStart, bgColorEnd],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Decorative circles change opacity based on theme
            Positioned(
              top: -size.height * 0.05,
              right: -size.width * 0.1,
              child: _buildDecorativeCircle(
                size.width * 0.6,
                const Color(0xFF6366F1).withOpacity(isDark ? 0.08 : 0.04),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.05,
              left: -size.width * 0.1,
              child: _buildDecorativeCircle(
                size.width * 0.4,
                const Color(0xFF4F46E5).withOpacity(isDark ? 0.06 : 0.03),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildLogoIcon(isSmallScreen, isDark),
                          SizedBox(height: size.height * 0.04),
                          Text(
                            "TMS",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 48 : 60,
                              fontWeight: FontWeight.w900,
                              color: titleColor,
                              letterSpacing: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            LanguageStore.isTamil
                                ? "போக்குவரத்து மேலாண்மை அமைப்பு"
                                : "TRANSPORT MANAGEMENT SYSTEM",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 12,
                              fontWeight: FontWeight.w700,
                              color: subTitleColor,
                              letterSpacing: LanguageStore.isTamil ? 1 : 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              bottom: 40,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  "V 1.0.0",
                  style: TextStyle(
                    color: subTitleColor.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoIcon(bool isSmall, bool isDark) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 24 : 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(isDark ? 0.3 : 0.12),
            blurRadius: 40,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
        ).createShader(bounds),
        child: Icon(
          Icons.local_shipping_rounded,
          size: isSmall ? 64 : 84,
          color: Colors.white, // Colors.white is needed for ShaderMask to work
        ),
      ),
    );
  }

  Widget _buildDecorativeCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
