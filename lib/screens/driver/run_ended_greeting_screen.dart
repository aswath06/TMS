import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:audioplayers/audioplayers.dart';

class RunEndedGreetingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const RunEndedGreetingScreen({Key? key, required this.onComplete}) : super(key: key);

  @override
  _RunEndedGreetingScreenState createState() => _RunEndedGreetingScreenState();
}

class _RunEndedGreetingScreenState extends State<RunEndedGreetingScreen> {
  final String _fullText = "Trip Ended Successfully!\n\nThanks for the safe ride. The journey was wonderful and we enjoyed the ride.\n\nபயணம் வெற்றிகரமாக முடிந்தது!\n\nபாதுகாப்பான பயணத்திற்கு நன்றி. பயணம் அற்புதமாக இருந்தது, நாங்கள் பயணத்தை ரசித்தோம்.";
  String _displayedText = "";
  int _currentIndex = 0;
  Timer? _timer;
  bool _isCompleting = false;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
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
    // Delay typing slightly to let the tick animation play first
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (_currentIndex < _fullText.length) {
          setState(() {
            _displayedText += _fullText[_currentIndex];
            _currentIndex++;
          });
        } else {
          _timer?.cancel();
          // Wait a few seconds after typing finishes before calling onComplete automatically
          Future.delayed(const Duration(seconds: 4), () {
            _triggerComplete();
          });
        }
      });
    });
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Professional sleek dark slate
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Lottie.asset(
                  'assets/Tick.json',
                  width: 200,
                  height: 200,
                  repeat: false,
                ),
                const SizedBox(height: 30),
                Text(
                  _displayedText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),
                AnimatedOpacity(
                  opacity: _currentIndex >= _fullText.length ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: ElevatedButton(
                    onPressed: _triggerComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1), // Indigo accent color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      elevation: 4,
                    ),
                    child: const Text(
                      "Continue",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
    );
  }
}
