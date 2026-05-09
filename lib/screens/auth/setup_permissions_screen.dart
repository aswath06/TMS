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

class _SetupPermissionsScreenState extends State<SetupPermissionsScreen> with WidgetsBindingObserver {
  bool _isInternetOk = false;
  bool _isLocationOk = false;
  bool _isNotificationOk = false;
  bool _isLocationAlways = false;
  bool _isBatteryOk = false;
  bool _isProcessing = false;

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAll();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
       _checkInternet(results.first);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  @override
  void dispose() {
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
                    Text(
                      isTamil ? "தேவையான அனுமதிகள்" : "Required Access",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isTamil 
                        ? "தடையற்ற சேவையைப் பெற பின்வரும் அனுமதிகளை வழங்கவும்."
                        : "Please ensure all requirements below are met for a seamless experience.",
                      style: TextStyle(fontSize: 16, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(height: 40),
                    
                    _buildRequirementCard(
                      title: isTamil ? "இணைய இணைப்பு" : "Internet Connection",
                      subtitle: isTamil ? "சேவையகத்துடன் இணைக்கத் தேவை" : "Required to sync with TripZo servers",
                      icon: Icons.wifi_rounded,
                      isOk: _isInternetOk,
                      onTap: () => _checkAll(),
                      isDark: isDark,
                    ),
                    
                    _buildRequirementCard(
                      title: isTamil ? "அறிவிப்பு அனுமதி" : "Notification Access",
                      subtitle: isTamil ? "உடனடி அறிவிப்புகளைப் பெறத் தேவை" : "Required to receive live mission updates",
                      icon: Icons.notifications_active_rounded,
                      isOk: _isNotificationOk,
                      onTap: _requestNotification,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: (_isInternetOk && _isNotificationOk) ? _completeOnboarding : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isProcessing 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isTamil ? "தொடரவும்" : "PROCEED TO LOGIN",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2, color: Colors.white),
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
