import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tripzo/utils/crypto_utils.dart';
import 'package:tripzo/store/driver_store.dart';

class VerifyMissionScreen extends StatefulWidget {
  final String requestId;
  final bool isStart;

  const VerifyMissionScreen({
    super.key,
    required this.requestId,
    this.isStart = true,
  });

  @override
  State<VerifyMissionScreen> createState() => _VerifyMissionScreenState();
}

class _VerifyMissionScreenState extends State<VerifyMissionScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isVerifying = false;
  late AnimationController _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _setupFocusNodes();
  }

  void _setupFocusNodes() {
    for (int i = 0; i < 6; i++) {
        _focusNodes[i].onKeyEvent = (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
            // If current field is empty and not the first field, move to previous
            if (_controllers[i].text.isEmpty && i > 0) {
              _focusNodes[i - 1].requestFocus();
              _controllers[i - 1].clear();
              return KeyEventResult.handled;
            } else if (_controllers[i].text.isNotEmpty) {
              // Just clearing the current field is handled by the default behavior,
              // but we can enforce it here to be sure.
              _controllers[i].clear();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        };
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyOtp(String otp) async {
    if (otp.length != 6) return;

    setState(() => _isVerifying = true);
    try {
      final result = await useDriverStore.verifyRouteOtp(
        routeId: int.tryParse(widget.requestId) ?? 0,
        otp: otp,
        isStart: widget.isStart,
      );

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw result['message'];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  String _getOtp() {
    return _controllers.map((c) => c.text).join();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isVerifying) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code != null) {
        final decrypted = CryptoUtils.decryptOTP(code);
        if (decrypted.length == 6 && int.tryParse(decrypted) != null) {
          setState(() {
            for (int i = 0; i < 6; i++) {
              _controllers[i].text = decrypted[i];
            }
          });
          _verifyOtp(decrypted);
          break;
        }
      }
    }
  }

  Widget _buildOtpBox(int index, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 50,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: _focusNodes[index].hasFocus 
            ? (isDark ? Colors.white.withOpacity(0.12) : Colors.white)
            : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focusNodes[index].hasFocus 
              ? const Color(0xFF6366F1) 
              : (isDark ? Colors.white12 : Colors.grey.shade300),
          width: 2.5,
        ),
        boxShadow: _focusNodes[index].hasFocus ? [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: Center(
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24, 
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w900, 
            color: _focusNodes[index].hasFocus ? const Color(0xFF6366F1) : (isDark ? Colors.white : Colors.black87)
          ),
          decoration: const InputDecoration(
            counterText: "",
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () {
            _controllers[index].selection = TextSelection(
              baseOffset: 0,
              extentOffset: _controllers[index].text.length,
            );
          },
          onChanged: (value) {
            if (value.isNotEmpty) {
              // Type-over logic: if multiple chars, take latest
              if (value.length > 1) {
                final last = value.substring(value.length - 1);
                _controllers[index].text = last;
                _controllers[index].selection = TextSelection.fromPosition(TextPosition(offset: 1));
              }
              
              if (index < 5) {
                _focusNodes[index + 1].requestFocus();
              } else {
                _focusNodes[index].unfocus();
                final otp = _getOtp();
                if (otp.length == 6) _verifyOtp(otp);
              }
            } else {
              // Handled by onKeyEvent primarily for backspace, 
              // but keeping it here for safety on some platforms.
              if (index > 0 && value.isEmpty) {
                // _focusNodes[index - 1].requestFocus(); // Removing to avoid double trigger with onKeyEvent
              }
            }
            setState(() {}); // Re-paint for focus/shadow
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.isStart ? "Verify Mission Start" : "Verify Mission Completion",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Premium Mesh Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark 
                    ? [const Color(0xFF0F172A), const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFEEF2FF), const Color(0xFFF8FAFC)],
                ),
              ),
            ),
          ),
          
          // Glowing Ambient Orbs
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [primaryBlue.withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Column(
                  children: [
                    // Scanner Section with Glassmorphism and Neon accents
                    Container(
                      height: 280,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: primaryBlue.withOpacity(0.2),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: Stack(
                          children: [
                            MobileScanner(onDetect: _onDetect),
                            // Scanning Area Frame
                            Center(
                              child: Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                                  borderRadius: BorderRadius.circular(35),
                                ),
                                child: Stack(
                                  children: [
                                    _buildCorner(0, 0, 90),
                                    _buildCorner(null, 0, 180),
                                    _buildCorner(0, null, 0),
                                    _buildCorner(null, null, 270),
                                    
                                    // Animated Scanning Line
                                    AnimatedBuilder(
                                      animation: _scannerController,
                                      builder: (context, child) {
                                        return Positioned(
                                          top: 210 * _scannerController.value,
                                          left: 10,
                                          right: 10,
                                          child: Container(
                                            height: 3,
                                            decoration: BoxDecoration(
                                              boxShadow: [
                                                BoxShadow(
                                                  color: primaryBlue,
                                                  blurRadius: 10,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  primaryBlue,
                                                  primaryBlue,
                                                  Colors.transparent
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Instructions Text
                    Column(
                      children: [
                        Text(
                          "Security Handshake",
                          style: TextStyle(
                            fontSize: 32, 
                            fontWeight: FontWeight.w900, 
                            color: textColor,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            "Scan QR or Enter the 6-digit code provided to securely validate your current mission status.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: subTextColor,
                              fontSize: 15,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 54),
                    
                    // OTP Input Section
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: FittedBox(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (i) => _buildOtpBox(i, isDark)),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Validation Button
                    SizedBox(
                      width: double.infinity,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 150),
                        scale: _isVerifying ? 0.98 : 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              colors: [primaryBlue, primaryBlue.withBlue(255)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withOpacity(0.4),
                                blurRadius: 25,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isVerifying ? null : () => _verifyOtp(_getOtp()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 22),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            child: _isVerifying
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                  )
                                : const Text(
                                    "VALIDATE HANDSHAKE",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Security Footer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_rounded, size: 16, color: primaryBlue.withOpacity(0.7)),
                          const SizedBox(width: 10),
                          Text(
                            "ENCRYPTED CHANNEL V2.0",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: subTextColor.withOpacity(0.8),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(double? top, double? right, double rotation) {
    return Positioned(
      top: top,
      right: right,
      left: top == null && right == null ? null : (right == null ? 0 : null),
      bottom: top == null && right == null ? 0 : (top == null ? 0 : null),
      child: Transform.rotate(
        angle: rotation * (3.14159 / 180),
        child: Container(
          width: 35,
          height: 35,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFF6366F1), width: 5),
              left: BorderSide(color: Color(0xFF6366F1), width: 5),
            ),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
          ),
        ),
      ),
    );
  }
}
