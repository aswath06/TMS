import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/routes.dart';
import '../store/user_store.dart'; // Import your UserStore

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

    // Trigger Auth Check instead of a simple Timer
    _initiateAuthCheck();
  }

  /// Checks if the user is already logged in
  Future<void> _initiateAuthCheck() async {
    // Wait for the animation to feel natural (minimum 2.5 seconds)
    await Future.delayed(const Duration(milliseconds: 2500));

    final String? token = await UserStore.getToken();
    final String? role = await UserStore.getRole();

    if (mounted) {
      if (token != null && role != null) {
        // DIRECT ACCESS: User is authenticated
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.dashboard,
          arguments: role,
        );
      } else {
        // REQUIRE LOGIN: No token found
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 360;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -size.height * 0.05,
              right: -size.width * 0.1,
              child: _buildDecorativeCircle(
                size.width * 0.6,
                const Color(0xFF6366F1).withOpacity(0.04),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.05,
              left: -size.width * 0.1,
              child: _buildDecorativeCircle(
                size.width * 0.4,
                const Color(0xFF4F46E5).withOpacity(0.03),
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
                          _buildLogoIcon(isSmallScreen),
                          SizedBox(height: size.height * 0.04),
                          Text(
                            "TMS",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 48 : 60,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              letterSpacing: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "TRANSPORT MANAGEMENT SYSTEM",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                              letterSpacing: 4,
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
                    color: const Color(0xFF94A3B8).withOpacity(0.5),
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

  Widget _buildLogoIcon(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 24 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.12),
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
          color: Colors.white,
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
