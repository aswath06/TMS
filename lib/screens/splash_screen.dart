import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/routes.dart';
import '../store/user_store.dart';
import '../store/isdark.dart'; // Import Theme Store
import '../store/istamil.dart'; // Import Language Store
import '../utils/api_constants.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import '../providers/notification_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _zoomAnimation;
  late Animation<Color?> _bgColorAnimation;
  
  bool _isConnected = true;
  StreamSubscription? _connectivitySubscription;
  bool _hasCheckedConnectivity = false;

  // Location permission states
  bool _isLocationPermissionGranted = true;
  bool _isLocationServiceEnabled = true;

  final math.Random _random = math.Random();
  Offset? _randomLogoPos;
  late Animation<double> _textFadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Zoom happens from 0.4 (0.8s) to 0.75 (1.5s)
    _zoomAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.75, curve: Curves.easeInOutCubic),
      ),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.75, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // The single logo blip location
    final double angle = _random.nextDouble() * 2 * math.pi;
    final double distance = 60.0 + _random.nextDouble() * 100.0;
    _randomLogoPos = Offset(math.cos(angle) * distance, math.sin(angle) * distance);    // Load preferences first (Theme/Language) - no internet required
    _loadPreferences();

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final result = results.first;
      if (result != ConnectivityResult.none) {
        if (!_isConnected) {
          setState(() => _isConnected = true);
          _initiateStartupSequence();
        }
      } else {
        setState(() => _isConnected = false);
      }
    });

    // Initial check
    _checkInitialConnectivity();
  }



  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        ThemeStore.isDark = prefs.getBool('isDark') ?? false;
      });
    }
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final result = results.first;
    if (result == ConnectivityResult.none) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _hasCheckedConnectivity = true;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isConnected = true;
          _hasCheckedConnectivity = true;
        });
        _initiateStartupSequence();
      }
    }
  }

  /// Loads local settings and checks auth
  Future<void> _initiateStartupSequence() async {
    if (!_isConnected) return;

    final prefs = await SharedPreferences.getInstance();

    // 1. Check if it's the first time
    final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!hasSeenOnboarding) {
      // Delay for full animation
      await Future.delayed(const Duration(milliseconds: 2000));
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.getStarted);
      return;
    }

    // 2. Start the minimum display timer AND the API call in parallel
    final Future<bool> authCheck = _checkSession(prefs);
    await Future.delayed(const Duration(milliseconds: 2000));

    // 3. Wait for the API check to settle (it might already be done)
    final bool sessionValid = await authCheck;

    if (!mounted) return;

    // 4. Navigate based on result
    final String? role = await UserStore.getRole();
    final bool isPinEnabled = prefs.getBool('isPinEnabled') ?? false;

    if (!sessionValid || role == null) {
      // If session is invalid, clear and go to login
      await UserStore.clear();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    } else {
      // 4.5 Initialize Notifications
      if (mounted) {
        final notificationProvider = ref.read(notificationProviderFamily);
        UserStore.getToken().then((token) {
          if (token != null) {
            notificationProvider.initialize(token: token);
          }
        });
      }

      // On startup, we no longer block the user or require 'Always Allow' location permission.

      // Navigation to correct landing page
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
    }
  }

  /// Checks and requests location permission
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _isLocationServiceEnabled = false;
        });
      }
      return false;
    }

    permission = await Geolocator.checkPermission();
    
    // On many devices, we might want to request it once if denied
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission != LocationPermission.always) {
      if (mounted) {
        setState(() {
          _isLocationPermissionGranted = false;
          _isLocationServiceEnabled = true;
        });
      }
      return false;
    }

    if (mounted) {
      setState(() {
        _isLocationPermissionGranted = true;
        _isLocationServiceEnabled = true;
      });
    }
    return true;
  }

  /// Helper to check session locally
  Future<bool> _checkSession(SharedPreferences prefs) async {
    final String? token = await UserStore.getToken();
    final String? role = await UserStore.getRole();
    
    // If token and role exist, we consider the local session valid
    if (token != null && token.isNotEmpty && role != null && role.isNotEmpty) {
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Local theme variables
    final bool isDark = ThemeStore.isDark;
    final Size size = MediaQuery.of(context).size;
    final Color subTitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double val = _controller.value;
          
          final bool showLogo = val >= 0.2; // 0.4s onwards
          final bool isZooming = val >= 0.4; // 0.8s onwards
          
          double zoomProgress = 0.0;
          if (isZooming) {
             zoomProgress = _zoomAnimation.value; 
          }
          
          final double currentScale = showLogo ? (isZooming ? (0.444 + (1.0 - 0.444) * zoomProgress) : 0.444) : 0.0;
          final Offset currentOffset = showLogo ? (isZooming ? Offset.lerp(_randomLogoPos!, Offset.zero, zoomProgress)! : _randomLogoPos!) : Offset.zero;

          final double textOpacity = isZooming ? _textFadeAnimation.value : 0.0;

          final Color bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;

          return Container(
            color: bgColor,
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Radar Lottie
                if (!isZooming)
                  Lottie.asset(
                    'assets/a519d1ac-1171-11ee-b9e8-33c8e3fd28ec.json',
                    width: 400,
                    height: 400,
                    fit: BoxFit.contain,
                  ),
                  
                // The Logo (Blip -> Zooming)
                if (showLogo)
                  Transform.translate(
                    offset: currentOffset,
                    child: Transform.scale(
                      scale: currentScale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 180,
                            height: 180,
                            padding: const EdgeInsets.all(24), // Padding to make it look like a card
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF4F46E5).withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5).withOpacity(0.25),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/TripZo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          SizedBox(height: size.height * 0.04),
                          Opacity(
                            opacity: textOpacity,
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.montserrat(
                                  fontSize: 72,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: -1.5,
                                ),
                                children: [
                                  TextSpan(
                                    text: "Trip",
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const TextSpan(
                                    text: "Zo",
                                    style: TextStyle(color: Color(0xFF4F46E5)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Transport Management System text Always visible at the bottom
                Positioned(
                  bottom: 40,
                  child: Text(
                    LanguageStore.isTamil
                        ? "போக்குவரத்து மேலாண்மை அமைப்பு"
                        : "TRANSPORT MANAGEMENT SYSTEM",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: subTitleColor,
                      letterSpacing: LanguageStore.isTamil ? 1 : 4,
                    ),
                  ),
                ),

                // Error Overlays
                if (!_isConnected) _buildNoInternetUI(size, isDark, subTitleColor),
                if (_isConnected && (!_isLocationServiceEnabled || !_isLocationPermissionGranted))
                  _buildLocationPermissionUI(size, isDark, subTitleColor),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationPermissionUI(Size size, bool isDark, Color subTitleColor) {
    bool isTamil = LanguageStore.isTamil;
    
    return Container(
      color: (isDark ? const Color(0xFF0F172A) : Colors.white).withOpacity(0.95),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              !_isLocationServiceEnabled ? Icons.location_off_rounded : Icons.location_searching_rounded,
              size: 80,
              color: const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            !_isLocationServiceEnabled
                ? (isTamil ? "இருப்பிட சேவை முடக்கப்பட்டுள்ளது" : "Location Services Disabled")
                : (isTamil ? "இருப்பிட அனுமதி தேவை" : "Location Permission Required"),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              !_isLocationServiceEnabled
                  ? (isTamil
                      ? "தொடர உங்கள் மொபைலில் GPS சேவையை இயக்கவும்."
                      : "Please enable GPS services on your device to continue.")
                  : (isTamil
                      ? "ஓட்டுநர்களுக்கு பின்னணிக் கண்காணிப்புக்கு 'எப்போதும் அனுமதி' (Always Allow) தேவை. தயவுசெய்து அமைப்புகளில் மாற்றவும்."
                      : "Drivers require 'Always Allow' location permission for background tracking to ensure safe and accurate trips. Please update this in your settings."),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: subTitleColor,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () async {
              if (!_isLocationServiceEnabled) {
                await Geolocator.openLocationSettings();
              } else {
                await Geolocator.openAppSettings();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
            child: Text(
              isTamil ? "அமைப்புகளைத் திறக்க" : "Open Settings",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              _initiateStartupSequence();
            },
            child: Text(
              isTamil ? "மீண்டும் முயற்சிக்கவும்" : "Retry",
              style: TextStyle(
                color: const Color(0xFF4F46E5),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoInternetUI(Size size, bool isDark, Color subTitleColor) {
    return Container(
      color: (isDark ? const Color(0xFF0F172A) : Colors.white).withOpacity(0.9),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 80,
            color: const Color(0xFF4F46E5),
          ),
          const SizedBox(height: 24),
          Text(
             LanguageStore.isTamil 
              ? "இணைய இணைப்பு இல்லை"
              : "No Internet Connection",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              LanguageStore.isTamil
                  ? "தயவுசெய்து உங்கள் இணைய இணைப்பைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்."
                  : "You are not connected to the internet. Please check your connection and try again.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: subTitleColor,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              _checkInitialConnectivity();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              LanguageStore.isTamil ? "மீண்டும் முயற்சிக்கவும்" : "Retry",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoIcon(bool isSmall, bool isDark) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
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
      child: Image.asset(
        'assets/TripZo.png',
        width: isSmall ? 100 : 140,
        height: isSmall ? 100 : 140,
        fit: BoxFit.contain,
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

class ParticleData {
  final Offset target;
  final Color color;
  ParticleData(this.target, this.color);
}

class ParticleTextPainter extends CustomPainter {
  final double progress;
  final List<ParticleData> particles;

  ParticleTextPainter({
    required this.progress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;

    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(42);

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      
      final startX = (random.nextDouble() - 0.5) * size.width * 2.0 + size.width / 2;
      final startY = -size.height * 5.0 - random.nextDouble() * 500.0; 
      
      final delay = random.nextDouble() * 0.4; 
      final duration = 0.6; 
      
      double particleProgress = 0.0;
      if (progress > delay) {
         particleProgress = (progress - delay) / duration;
      }
      particleProgress = math.min(1.0, particleProgress);
      
      final curvedProgress = Curves.bounceOut.transform(particleProgress);
      
      final currentX = startX + (p.target.dx - startX) * curvedProgress;
      final currentY = startY + (p.target.dy - startY) * curvedProgress;
      
      paint.color = p.color.withOpacity(particleProgress); 
      
      canvas.drawCircle(Offset(currentX, currentY), 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticleTextPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.particles != particles;
  }
}
