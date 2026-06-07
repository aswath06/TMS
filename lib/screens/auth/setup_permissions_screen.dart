import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/routes.dart';
import '../../store/isdark.dart';
import '../../store/istamil.dart';

class SetupPermissionsScreen extends StatefulWidget {
  const SetupPermissionsScreen({super.key});

  @override
  State<SetupPermissionsScreen> createState() => _SetupPermissionsScreenState();
}

class _SetupPermissionsScreenState extends State<SetupPermissionsScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isInternetOk = false;
  bool _isLocationOk = false;
  bool _isNotificationOk = false;
  bool _isLocationAlways = false;
  bool _isBatteryOk = false;
  bool _isProcessing = false;

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  late AnimationController _animationController;
  late Animation<Offset> _headerSlide;
  late Animation<double> _headerFade;
  late Animation<Offset> _card1Slide;
  late Animation<Offset> _card2Slide;
  late Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAll();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
       _checkInternet(results.first);
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _headerSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)),
    );
    _headerFade = CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.5, curve: Curves.easeIn));

    _card1Slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic)),
    );

    _card2Slide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic)),
    );

    _buttonFade = CurvedAnimation(parent: _animationController, curve: const Interval(0.6, 1.0, curve: Curves.easeIn));

    _animationController.forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _checkAll() async {
    final connectivity = await Connectivity().checkConnectivity();
    await _checkInternet(connectivity.first);
    await _checkPermissions();
  }

  Future<void> _checkInternet(ConnectivityResult result) async {
    setState(() => _isInternetOk = result != ConnectivityResult.none);
  }

  Future<void> _checkPermissions() async {
    final locationStatus = await Permission.location.status;
    final locationAlwaysStatus = await Permission.locationAlways.status;
    final notificationStatus = await Permission.notification.status;
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;

    setState(() {
      _isLocationOk = locationStatus.isGranted;
      _isLocationAlways = locationAlwaysStatus.isGranted;
      _isNotificationOk = notificationStatus.isGranted;
      _isBatteryOk = batteryStatus.isGranted;
    });
  }

  Future<void> _requestLocation() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      await Permission.locationAlways.request();
    }
    _checkPermissions();
  }


  Future<void> _requestNotification() async {
    await Permission.notification.request();
    _checkPermissions();
  }

  Future<void> _requestBatteryExemption() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    _checkPermissions();
  }

  Future<void> _completeOnboarding() async {
    if (!_isInternetOk) return;
    
    setState(() => _isProcessing = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeStore.isDark;
    final bool isTamil = LanguageStore.isTamil;
    final Color primaryColor = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isTamil ? "அமைப்புகள்" : "App Setup", style: const TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SlideTransition(
                      position: _headerSlide,
                      child: FadeTransition(
                        opacity: _headerFade,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTamil ? "தேவையான அனுமதிகள்" : "System Preparation",
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isTamil 
                                ? "தடையற்ற சேவையைப் பெற பின்வரும் அனுமதிகளை வழங்கவும்."
                                : "Please grant the following access to ensure real-time tracking and seamless communication.",
                              style: TextStyle(fontSize: 16, color: isDark ? Colors.white60 : Colors.black54, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    SlideTransition(
                      position: _card1Slide,
                      child: FadeTransition(
                        opacity: _headerFade,
                        child: _buildRequirementCard(
                          title: isTamil ? "இணைய இணைப்பு" : "Internet Connection",
                          subtitle: isTamil ? "சேவையகத்துடன் இணைக்கத் தேவை" : "Required to sync with TripZo servers",
                          icon: Icons.wifi_rounded,
                          isOk: _isInternetOk,
                          onTap: () => _checkAll(),
                          isDark: isDark,
                        ),
                      ),
                    ),
                    
                    SlideTransition(
                      position: _card2Slide,
                      child: FadeTransition(
                        opacity: _headerFade,
                        child: _buildRequirementCard(
                          title: isTamil ? "அறிவிப்பு அனுமதி" : "Notification Access",
                          subtitle: isTamil ? "உடனடி அறிவிப்புகளைப் பெறத் தேவை" : "Required to receive live mission updates",
                          icon: Icons.notifications_active_rounded,
                          isOk: _isNotificationOk,
                          onTap: _requestNotification,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            FadeTransition(
              opacity: _buttonFade,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: (_isInternetOk && _isNotificationOk) 
                      ? const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                    color: (_isInternetOk && _isNotificationOk) ? null : (isDark ? Colors.grey[800] : Colors.grey[300]),
                    boxShadow: (_isInternetOk && _isNotificationOk) ? [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ] : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: (_isInternetOk && _isNotificationOk && !_isProcessing) ? _completeOnboarding : null,
                      child: Center(
                        child: _isProcessing 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isTamil ? "தொடரவும்" : "PROCEED TO LOGIN",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900, 
                                    fontSize: 16, 
                                    letterSpacing: 1.5, 
                                    color: (_isInternetOk && _isNotificationOk) ? Colors.white : (isDark ? Colors.white54 : Colors.black38),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded, 
                                  color: (_isInternetOk && _isNotificationOk) ? Colors.white : (isDark ? Colors.white54 : Colors.black38),
                                ),
                              ],
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isOk,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final Color successColor = const Color(0xFF10B981);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOk ? successColor.withOpacity(0.5) : (isDark ? Colors.white10 : Colors.black12),
            width: 2,
          ),
          boxShadow: [
            if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOk ? successColor.withOpacity(0.1) : (isDark ? Colors.white10 : Colors.grey.shade100),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isOk ? successColor : (isDark ? Colors.white30 : Colors.grey), size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54)),
                ],
              ),
            ),
            Icon(
              isOk ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
              color: isOk ? successColor : (isDark ? Colors.white24 : Colors.grey.shade300),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
