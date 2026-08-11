import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';

class SecurityGateSuccessScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final bool isGateOut;

  const SecurityGateSuccessScreen({
    Key? key,
    required this.onComplete,
    required this.isGateOut,
  }) : super(key: key);

  @override
  _SecurityGateSuccessScreenState createState() => _SecurityGateSuccessScreenState();
}

class _SecurityGateSuccessScreenState extends State<SecurityGateSuccessScreen> {
  late final String _fullText;
  String _displayedText = "";
  int _currentIndex = 0;
  Timer? _timer;
  bool _isCompleting = false;
  bool _showButton = false;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _fullText = widget.isGateOut 
        ? "Gate Out Done!\n\nVehicle is authorized to leave the campus."
        : "Gate In Done!\n\nVehicle has successfully returned to the campus.";

    _audioPlayer = AudioPlayer();
    _playAudio();
    _startTypingEffect();
  }

  Future<void> _playAudio() async {
    try {
      await _audioPlayer.play(AssetSource('songs/hornsound.mp3'));
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  void _startTypingEffect() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _timer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
        if (_currentIndex < _fullText.length) {
          setState(() {
            _displayedText += _fullText[_currentIndex];
            _currentIndex++;
          });
        } else {
          _timer?.cancel();
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) {
              setState(() {
                _showButton = true;
              });
            }
          });
          
          Future.delayed(const Duration(seconds: 5), () {
            _triggerComplete();
          });
        }
      });
    });
  }

  void _triggerComplete() {
    if (mounted && !_isCompleting) {
      _isCompleting = true;
      Navigator.of(context).pop();
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Premium Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF000000)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          
          // Subtle Glowing Orbs
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 100, spreadRadius: 50)
                ]
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.2), blurRadius: 100, spreadRadius: 50)
                ]
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Lottie Animation with Glow
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                )
                              ],
                            ),
                          ),
                          Lottie.asset(
                            'assets/Tick.json',
                            width: 200,
                            height: 200,
                            repeat: false,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // Animated Typing Text
                      Container(
                        constraints: const BoxConstraints(minHeight: 120),
                        alignment: Alignment.topCenter,
                        child: Text(
                          _displayedText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            height: 1.5,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      const SizedBox(height: 50),
                      
                      // Continue Button
                      AnimatedOpacity(
                        opacity: _showButton ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 800),
                        child: AnimatedSlide(
                          offset: _showButton ? Offset.zero : const Offset(0, 0.5),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutBack,
                          child: InkWell(
                            onTap: _triggerComplete,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Text(
                                "Continue",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
