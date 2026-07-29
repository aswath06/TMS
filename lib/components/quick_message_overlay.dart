import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripzo/utils/routes.dart';
import 'package:tripzo/screens/chat/chat_detail_screen.dart';
import 'package:lottie/lottie.dart';

class QuickMessageOverlay extends StatefulWidget {
  final Widget child;

  const QuickMessageOverlay({super.key, required this.child});

  @override
  State<QuickMessageOverlay> createState() => _QuickMessageOverlayState();
}

class _QuickMessageOverlayState extends State<QuickMessageOverlay> {
  bool _showOverlay = false;
  Map<String, dynamic>? _quickData;
  Timer? _pollingTimer;
  int _countdown = 10;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _checkQuickMessage();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_showOverlay) {
        _checkQuickMessage();
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkQuickMessage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('quick_message');
      
      if (jsonStr != null) {
        final Map<String, dynamic> data = json.decode(jsonStr);
        final String messageId = data['id'];
        
        final List<String> acknowledged = prefs.getStringList('acknowledged_emergencies') ?? [];
        
        if (!acknowledged.contains(messageId)) {
          if (mounted && !_showOverlay) {
            setState(() {
              _quickData = data;
              _showOverlay = true;
              _countdown = 10;
            });
            _startCountdown();
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking quick message: $e");
    }
  }
  
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _acknowledgeMessage() async {
    if (_quickData == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final String messageId = _quickData!['id'];
      
      List<String> acknowledged = prefs.getStringList('acknowledged_emergencies') ?? [];
      if (!acknowledged.contains(messageId)) {
        acknowledged.add(messageId);
        await prefs.setStringList('acknowledged_emergencies', acknowledged);
      }
      
      if (mounted) {
        setState(() {
          _showOverlay = false;
        });
        await Future.delayed(const Duration(milliseconds: 300)); // wait for fade out
      }
    } catch (e) {
      debugPrint("Error acknowledging quick message: $e");
    }
  }
  
  void _navigateToChat() {
    if (_quickData == null) return;
    final groupName = _quickData!['groupName'] ?? "Group";
    final groupAvatar = _quickData!['groupAvatar'] ?? "";
    
    _acknowledgeMessage().then((_) {
      if (ChatDetailScreen.activeChatName == groupName) {
        return; // User is already in this chat
      }
      AppRoutes.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            name: groupName,
            avatarUrl: groupAvatar,
            isGroup: true,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_quickData != null)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_showOverlay,
              child: AnimatedOpacity(
                opacity: _showOverlay ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: SafeArea(
                    child: Center(
                      child: AnimatedScale(
                        scale: _showOverlay ? 1.0 : 0.8,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        child: GestureDetector(
                          onTap: _navigateToChat,
                          child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF818CF8).withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                        border: Border.all(color: const Color(0xFF818CF8), width: 2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Lottie.asset(
                            'assets/info.json',
                            width: 100,
                            height: 100,
                            repeat: true,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "QUICK MESSAGE",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.black87,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "From: ${_quickData!['sender']} in ${_quickData!['groupName'] ?? 'a group'}",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.grey.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_quickData!['subject'] != null && _quickData!['subject'].toString().isNotEmpty)
                            Text(
                              _quickData!['subject'],
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.black87,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF818CF8).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _quickData!['message'],
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _countdown == 0 ? () { _acknowledgeMessage(); } : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF818CF8),
                                disabledBackgroundColor: Colors.grey.shade300,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _countdown > 0 ? "Close in ${_countdown}s" : "Close",
                                style: GoogleFonts.plusJakartaSans(
                                  color: _countdown > 0 ? Colors.grey.shade600 : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Tap anywhere to view in chat",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
      ],
    );
  }
}
