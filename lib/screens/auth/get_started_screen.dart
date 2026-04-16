import 'package:flutter/material.dart';
import '../../utils/routes.dart';
import '../../store/user_store.dart';
import '../../store/isdark.dart';
import '../../store/istamil.dart';

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  late AnimationController _animationController;

  final List<Map<String, String>> _onboardingData = [
    {
      "title": "Smart Fleet Management",
      "subtitle": "Streamline vehicle requests and management for your entire organization.",
      "title_tn": "புத்திசாலித்தனமான போக்குவரத்து",
      "subtitle_tn": "உங்கள் நிறுவனத்திற்கான வாகன கோரிக்கைகளை எளிதாக நிர்வகிக்கவும்.",
      "icon": "🚚",
    },
    {
      "title": "Live Driver Tracking",
      "subtitle": "Real-time visibility into driver locations and active mission status.",
      "title_tn": "நேரடி கண்காணிப்பு",
      "subtitle_tn": "ஓட்டுநர்களின் இருப்பிடத்தை நேரலையில் கவனித்து பயண நிலையை அறியவும்.",
      "icon": "📍",
    },
    {
      "title": "Mission Coordination",
      "subtitle": "Secure mission starts and ends with encrypted OTP and QR code handshakes.",
      "title_tn": "பயண ஒருங்கிணைப்பு",
      "subtitle_tn": "OTP மற்றும் QR குறியீடுகள் மூலம் பாதுகாப்பான பயணத் தொடக்கம் மற்றும் முடிவு.",
      "icon": "🛡️",
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeStore.isDark;
    final bool isTamil = LanguageStore.isTamil;
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Stack(
        children: [
          // Background accents
          Positioned(
            top: -100,
            right: -100,
            child: _buildBlurCircle(300, const Color(0xFF6366F1).withOpacity(0.1)),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _buildBlurCircle(250, const Color(0xFF4F46E5).withOpacity(0.12)),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Logo section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Image.asset('assets/TripZo.png', height: 40),
                      const SizedBox(width: 12),
                      Text(
                        "TripZo",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (value) => setState(() => _currentPage = value),
                    itemCount: _onboardingData.length,
                    itemBuilder: (context, index) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Icon/Illustration placeholder
                              Container(
                                width: size.width * 0.7,
                                height: size.width * 0.7,
                                constraints: const BoxConstraints(maxWidth: 300, maxHeight: 300),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withOpacity(0.05),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.1), width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    _onboardingData[index]["icon"]!,
                                    style: const TextStyle(fontSize: 100),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 48),
                              FadeTransition(
                                opacity: _animationController,
                                child: Text(
                                  isTamil ? _onboardingData[index]["title_tn"]! : _onboardingData[index]["title"]!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : Colors.black,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isTamil ? _onboardingData[index]["subtitle_tn"]! : _onboardingData[index]["subtitle"]!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Controls
                Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    children: [
                      // Dots Indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _onboardingData.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index ? const Color(0xFF6366F1) : const Color(0xFF6366F1).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      // Buttons
                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_currentPage == _onboardingData.length - 1) {
                              Navigator.pushReplacementNamed(context, AppRoutes.setupPermissions);
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 8,
                            shadowColor: const Color(0xFF6366F1).withOpacity(0.5),
                          ),
                          child: Text(
                            _currentPage == _onboardingData.length - 1
                                ? (isTamil ? "தொடங்கவும்" : "GET STARTED")
                                : (isTamil ? "அடுத்து" : "NEXT"),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.setupPermissions),
                        child: Text(
                          isTamil ? "தவிர்க்க" : "SKIP",
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black45,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
