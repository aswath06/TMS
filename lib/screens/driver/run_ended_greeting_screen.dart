import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';

class RunEndedGreetingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final double distance;
  final int points;

  const RunEndedGreetingScreen({
    Key? key,
    required this.onComplete,
    required this.distance,
    required this.points,
  }) : super(key: key);

  @override
  _RunEndedGreetingScreenState createState() => _RunEndedGreetingScreenState();
}

class _RunEndedGreetingScreenState extends State<RunEndedGreetingScreen> {
  final String _fullText = "Trip Completed Successfully!";
  String _displayedText = "";
  int _currentIndex = 0;
  Timer? _timer;
  bool _isCompleting = false;
  late AudioPlayer _audioPlayer;

  // Animation variables
  bool _showCoins = false;
  bool _startCounting = false;
  bool _showCard = false;
  final Random _random = Random();
  final int _coinCount = 20;

  // State to manage individual coin delays
  List<bool> _coinSpawned = [];

  @override
  void initState() {
    super.initState();
    _coinSpawned = List.generate(_coinCount, (index) => false);
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
      _timer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
        if (_currentIndex < _fullText.length) {
          setState(() {
            _displayedText += _fullText[_currentIndex];
            _currentIndex++;
          });
        } else {
          _timer?.cancel();
          // Trigger animation after typing
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _showCard = true;
                _showCoins = true;
              });
              _triggerCoinsStream();
              
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted) {
                  setState(() {
                    _startCounting = true;
                  });
                }
              });

              Future.delayed(const Duration(seconds: 5), () {
                _triggerComplete();
              });
            }
          });
        }
      });
    });
  }

  void _triggerCoinsStream() async {
    for (int i = 0; i < _coinCount; i++) {
      if (!mounted) break;
      await Future.delayed(Duration(milliseconds: 20 + _random.nextInt(30)));
      if (mounted) {
        setState(() {
          _coinSpawned[i] = true;
        });
      }
    }
  }

  void _triggerComplete() {
    if (mounted && !_isCompleting) {
      _isCompleting = true;
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
    final size = MediaQuery.of(context).size;
    final walletTopPos = size.height * 0.45;
    final walletLeftPos = size.width / 2;

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
                // blur radius using ImageFilter in a BackdropFilter is preferred, but simple BoxShadow works
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
                        constraints: const BoxConstraints(minHeight: 70),
                        alignment: Alignment.center,
                        child: Text(
                          _displayedText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
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
                      
                      const SizedBox(height: 30),
                      
                      // Glassmorphic Stats Card
                      AnimatedSlide(
                        offset: _showCard ? Offset.zero : const Offset(0, 0.5),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: _showCard ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 600),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    )
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.route_rounded, color: Colors.white70, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          "Distance: ${widget.distance.toStringAsFixed(1)} km",
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      child: Divider(color: Colors.white12, height: 1),
                                    ),
                                    const Text(
                                      "REWARD EARNED",
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.monetization_on_rounded,
                                            color: Colors.amber,
                                            size: 32,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        TweenAnimationBuilder<int>(
                                          tween: IntTween(begin: 0, end: _startCounting ? widget.points : 0),
                                          duration: const Duration(milliseconds: 2000),
                                          curve: Curves.easeOutExpo,
                                          builder: (context, value, child) {
                                            return Text(
                                              "+$value",
                                              style: const TextStyle(
                                                color: Colors.amber,
                                                fontSize: 48,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -1,
                                                shadows: [
                                                  Shadow(
                                                    color: Colors.amberAccent,
                                                    blurRadius: 20,
                                                  )
                                                ]
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        const Padding(
                                          padding: EdgeInsets.only(top: 12),
                                          child: Text(
                                            "pts",
                                            style: TextStyle(
                                              color: Colors.amber,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 50),
                      
                      // Continue Button
                      AnimatedOpacity(
                        opacity: _showCard ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 800),
                        child: AnimatedSlide(
                          offset: _showCard ? Offset.zero : const Offset(0, 0.5),
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
                                "Continue to Dashboard",
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
          
          // Enhanced Flying Coins
          if (_showCoins)
            ...List.generate(_coinCount, (index) {
              if (!_coinSpawned[index]) return const SizedBox();

              final double startX = size.width / 2 + (_random.nextDouble() * 200 - 100);
              final double startY = size.height + 50;
              
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 1000 + (_random.nextInt(500))),
                curve: Curves.easeInCirc,
                builder: (context, value, child) {
                  final double currentX = startX + (walletLeftPos - startX) * value;
                  final double currentY = startY + (walletTopPos - startY) * value;
                  
                  // Add a nice spiral/arch effect
                  final double arch = sin(value * pi) * (80 + _random.nextDouble() * 40); 
                  final double finalX = currentX + arch * (index % 2 == 0 ? 1 : -1);

                  return Positioned(
                    left: finalX - 20,
                    top: currentY - 20,
                    child: Transform.scale(
                      scale: 1.2 - (value * 0.7),
                      child: Transform.rotate(
                        angle: value * pi * 4 * (index % 2 == 0 ? 1 : -1),
                        child: Opacity(
                          opacity: value > 0.8 ? (1.0 - value) * 5 : 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.6),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                )
                              ]
                            ),
                            child: const Icon(
                              Icons.monetization_on,
                              color: Color(0xFFFFD700),
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
        ],
      ),
    );
  }
}
