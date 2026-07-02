import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/utils/toast_utils.dart';

class FacultyScanOtpScreen extends StatefulWidget {
  final int runId;
  final String otpType;
  const FacultyScanOtpScreen({super.key, required this.runId, required this.otpType});

  @override
  State<FacultyScanOtpScreen> createState() => _FacultyScanOtpScreenState();
}

class _FacultyScanOtpScreenState extends State<FacultyScanOtpScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController cameraController = MobileScannerController();
  late AnimationController _laserController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _triggerLongVibration() async {
    try {
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.vibrate();
    } catch (_) {}
  }

  Future<void> _verifyOtp(String otp) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    await _triggerLongVibration();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      ),
    );

    try {
      final token = await UserStore.getToken();
      if (!mounted) return;
      if (token == null) {
        Navigator.pop(context);
        _showSnackBar("Session expired. Please log in again.", Colors.red);
        return;
      }

      final url = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/${widget.runId}/verify-boarding-otp";
      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode({
          "otp_code": otp,
        }),
      );

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading dialog

      final isSuccess = response.statusCode == 200;
      String message = isSuccess ? "Attendance marked successfully." : "Verification failed.";
      
      try {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['message'] != null && data['message'].toString().trim().isNotEmpty) {
          message = data['message'].toString();
        } else if (data['error'] != null && data['error'].toString().trim().isNotEmpty) {
          message = data['error'].toString();
        }
      } catch (_) {}

      if (isSuccess) {
        _showSnackBar(message, Colors.green);
        Navigator.pop(context, true);
      } else {
        _showSnackBar(message, Colors.red);
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showSnackBar("Connection error: $e", Colors.red);
      setState(() => _isProcessing = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcode = capture.barcodes.first;
    if (barcode.rawValue != null) {
      final String code = barcode.rawValue!.trim();
      _verifyOtp(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF070A13) : const Color(0xFFEDF2F7);
    const Color primaryBlue = Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: cameraController,
              onDetect: _onDetect,
            ),
          ),
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.7),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: primaryBlue.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withValues(alpha: 0.1),
                    blurRadius: 25,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _laserController,
                    builder: (context, child) {
                      return Positioned(
                        top: 250 * _laserController.value,
                        left: 16,
                        right: 16,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                primaryBlue,
                                Colors.cyanAccent,
                                primaryBlue,
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 1.5,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  ..._buildCorners(primaryBlue),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        "SCAN BOARDING QR",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: GestureDetector(
                      onTap: () => cameraController.toggleTorch(),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: ValueListenableBuilder(
                          valueListenable: cameraController,
                          builder: (context, state, child) {
                            final isOn = state.torchState == TorchState.on;
                            return Icon(
                              isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              color: isOn ? Colors.yellowAccent : Colors.white,
                              size: 18,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Text(
                        "Align the student's boarding QR code inside the frame scanner to verify arrival.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withValues(alpha: 0.35),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      cameraController.stop();
                      if (!mounted) return;
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FacultyEnterOtpScreen(
                            runId: widget.runId,
                            otpType: widget.otpType,
                          ),
                        ),
                      );
                      if (result == true) {
                        if (!context.mounted) return;
                        Navigator.pop(context, true);
                      } else {
                        cameraController.start();
                      }
                    },
                    icon: const Icon(Icons.keyboard_rounded, color: Colors.white, size: 20),
                    label: const Text(
                      "ENTER OTP CODE",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners(Color color) {
    const double size = 20;
    const double thickness = 3.5;
    return [
      Positioned(
        top: 8,
        left: 8,
        child: Container(width: size, height: thickness, color: color),
      ),
      Positioned(
        top: 8,
        left: 8,
        child: Container(width: thickness, height: size, color: color),
      ),
      Positioned(
        top: 8,
        right: 8,
        child: Container(width: size, height: thickness, color: color),
      ),
      Positioned(
        top: 8,
        right: 8,
        child: Container(width: thickness, height: size, color: color),
      ),
      Positioned(
        bottom: 8,
        left: 8,
        child: Container(width: size, height: thickness, color: color),
      ),
      Positioned(
        bottom: 8,
        left: 8,
        child: Container(width: thickness, height: size, color: color),
      ),
      Positioned(
        bottom: 8,
        right: 8,
        child: Container(width: size, height: thickness, color: color),
      ),
      Positioned(
        bottom: 8,
        right: 8,
        child: Container(width: thickness, height: size, color: color),
      ),
    ];
  }
}

class FacultyEnterOtpScreen extends StatefulWidget {
  final int runId;
  final String otpType;
  const FacultyEnterOtpScreen({super.key, required this.runId, required this.otpType});

  @override
  State<FacultyEnterOtpScreen> createState() => _FacultyEnterOtpScreenState();
}

class ShakeCurve extends Curve {
  const ShakeCurve();
  @override
  double transformInternal(double t) {
    return math.sin(t * 3 * math.pi * 2);
  }
}

class _FacultyEnterOtpScreenState extends State<FacultyEnterOtpScreen> with TickerProviderStateMixin {
  String _otp = "";
  bool _isProcessing = false;
  bool _isError = false;
  bool _isSuccess = false;

  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  late AnimationController _shakeController;
  late AnimationController _mergeController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _mergeAnimation;

  @override
  void initState() {
    super.initState();
    
    for (int i = 0; i < 6; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_controllers[i].text.isEmpty && i > 0) {
              _focusNodes[i - 1].requestFocus();
              _controllers[i - 1].clear();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
      ));
      
      _controllers[i].addListener(() => _onTextChanged(i));
      
      // Auto-select text on focus
      _focusNodes[i].addListener(() {
        if (mounted && _focusNodes[i].hasFocus) {
          setState(() {}); // Redraw to update active box highlight
          _controllers[i].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controllers[i].text.length,
          );
        } else if (mounted) {
          setState(() {}); // Redraw to clear highlight on blur
        }
      });
    }

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: const ShakeCurve()),
    );

    _mergeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _mergeAnimation = CurvedAnimation(parent: _mergeController, curve: Curves.easeInOutQuad);

    // Auto focus first box
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (int i = 0; i < 6; i++) {
      _controllers[i].dispose();
      _focusNodes[i].dispose();
    }
    _shakeController.dispose();
    _mergeController.dispose();
    super.dispose();
  }

  void _onTextChanged(int index) {
    if (_isProcessing || _isSuccess) return;

    final text = _controllers[index].text;
    if (text.length > 1) {
      _controllers[index].text = text.substring(text.length - 1);
      _controllers[index].selection = TextSelection.fromPosition(
        TextPosition(offset: _controllers[index].text.length),
      );
      return;
    }

    // Update global OTP state
    String otp = "";
    for (int i = 0; i < 6; i++) {
      otp += _controllers[i].text;
    }
    setState(() {
      _otp = otp;
    });

    if (text.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else if (otp.length == 6) {
        _submitOtp();
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _submitOtp() async {
    if (_isProcessing || _isSuccess) return;
    setState(() {
      _isProcessing = true;
      _isError = false;
    });

    // Unfocus all fields to dismiss keyboard
    for (var node in _focusNodes) {
      node.unfocus();
    }

    try {
      final token = await UserStore.getToken();
      if (!mounted) return;
      if (token == null) {
        _showSnackBar("Session expired. Please log in again.", Colors.red);
        if (context.mounted) {
          showTopToast(context, "Session expired. Please log in again.", isError: true);
        }
        setState(() => _isProcessing = false);
        _focusNodes[0].requestFocus();
        return;
      }

      final url = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/${widget.runId}/verify-boarding-otp";
      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode({
          "otp_code": _otp,
        }),
      );

      if (!mounted) return;

      final isSuccess = response.statusCode == 200;
      
      String message = isSuccess ? "Attendance marked successfully" : "Invalid OTP check the QR code";
      try {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['message'] != null && data['message'].toString().trim().isNotEmpty) {
          message = data['message'].toString();
        } else if (data['error'] != null && data['error'].toString().trim().isNotEmpty) {
          message = data['error'].toString();
        }
      } catch (_) {}

      if (isSuccess) {
        setState(() {
          _isSuccess = true;
        });
        
        // Vibrate to signal success
        HapticFeedback.mediumImpact();
        
        // Trigger the beautiful merge animation
        await _mergeController.forward();
        
        if (mounted) {
          _showSnackBar(message, Colors.green);
          if (context.mounted) {
            showTopToast(context, message);
          }
        }
        await Future.delayed(const Duration(milliseconds: 1200));
        
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _isError = true;
          _isProcessing = false;
        });
        _showSnackBar(message, Colors.red);
        if (context.mounted) {
          showTopToast(context, message, isError: true);
        }
        
        // Shake animation
        await _shakeController.forward(from: 0.0);
        await Future.delayed(const Duration(milliseconds: 200));
        
        if (mounted) {
          setState(() {
            _otp = "";
            for (var controller in _controllers) {
              controller.clear();
            }
            _isError = false;
          });
          _focusNodes[0].requestFocus();
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("Connection error: $e", Colors.red);
      if (context.mounted) {
        showTopToast(context, "Connection error: $e", isError: true);
      }
      setState(() {
        _otp = "";
        for (var controller in _controllers) {
          controller.clear();
        }
        _isProcessing = false;
        _isError = false;
      });
      _focusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    const Color primaryBlue = Color(0xFF6366F1);

    final bgGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFFEEF2F6), Color(0xFFF8FAFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          "OTP Entry",
          style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: Stack(
            children: [
              GestureDetector(
                onTap: () {
                  if (!_isProcessing && !_isSuccess) {
                    bool focused = false;
                    for (int i = 0; i < 6; i++) {
                      if (_focusNodes[i].hasFocus) {
                        focused = true;
                        break;
                      }
                    }
                    if (!focused) {
                      for (int i = 0; i < 6; i++) {
                        if (_controllers[i].text.isEmpty) {
                          _focusNodes[i].requestFocus();
                          return;
                        }
                      }
                      _focusNodes[5].requestFocus();
                    }
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        "Enter Verification Code",
                        style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          "We've sent a 6-digit code to verify your identity",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: subColor.withValues(alpha: 0.85),
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  primaryBlue.withValues(alpha: isDark ? 0.16 : 0.08),
                                  primaryBlue.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.85,
                              maxHeight: 250,
                            ),
                            child: Lottie.asset(
                              'assets/bus.json',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Passcode Container Area
                      _buildPasscodeBoxes(textColor, primaryBlue, isDark),
                      
                      const SizedBox(height: 16),
                      Text(
                        "${_otp.length}/6 digits entered",
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: subColor),
                      ),
                      
                      const SizedBox(height: 60),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield_rounded, color: primaryBlue, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Secured with Tripzo Fleet Gateway",
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: subColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isProcessing)
                Positioned.fill(
                  child: Container(
                    color: (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)).withValues(alpha: 0.7),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const CircularProgressIndicator(color: primaryBlue),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasscodeBoxes(Color textColor, Color primaryBlue, bool isDark) {
    return SizedBox(
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Row of 6 individual boxes that slide together and blend to green
          AnimatedBuilder(
            animation: Listenable.merge([_shakeAnimation, _mergeAnimation]),
            builder: (context, child) {
              final double shakeOffset = _shakeAnimation.value * 12.0;
              final double mergeVal = _mergeAnimation.value;

              return Transform.translate(
                offset: Offset(shakeOffset, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    final bool isCurrent = _focusNodes[index].hasFocus;
                    
                    // Center the 6 boxes into one single box in the center (item index relative to center offset is (index - 2.5) * (48.0 + 12.0))
                    final double translationX = -(index - 2.5) * (48.0 + 12.0) * mergeVal;
                    
                    Color bgCol = isDark ? const Color(0xFF1E293B) : Colors.white;
                    Color borderCol = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200;
                    
                    if (_isError) {
                      borderCol = Colors.red;
                      bgCol = Colors.red.withValues(alpha: 0.05);
                    } else if (_isSuccess) {
                      borderCol = Colors.green;
                      bgCol = Colors.green.withValues(alpha: 0.05);
                    } else if (isCurrent) {
                      borderCol = primaryBlue;
                    }

                    // Lerp background and border colors towards green during merge
                    final Color finalBgCol = Color.lerp(bgCol, Colors.green.withValues(alpha: 0.05), mergeVal)!;
                    final Color finalBorderCol = Color.lerp(borderCol, Colors.green, mergeVal)!;

                    return Transform.translate(
                      offset: Offset(translationX, 0),
                      child: Container(
                        width: 48,
                        height: 64,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: finalBgCol,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: finalBorderCol,
                            width: (_isSuccess || isCurrent || _isError) ? 2.0 : 1.0,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: primaryBlue.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    spreadRadius: 1.5,
                                  ),
                                ]
                              : null,
                        ),
                        child: Opacity(
                          opacity: (1.0 - mergeVal).clamp(0.0, 1.0),
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            showCursor: false,
                            enabled: !_isProcessing && !_isSuccess && (mergeVal == 0.0),
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              counterText: "",
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
          
          // Glowing Tick checkmark in a single box that scales up in the center on success
          AnimatedBuilder(
            animation: _mergeAnimation,
            builder: (context, child) {
              final double mergeVal = _mergeAnimation.value;
              if (mergeVal == 0.0) return const SizedBox.shrink();
              
              return Opacity(
                opacity: mergeVal.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: mergeVal,
                  child: Container(
                    width: 48,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.15),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.green,
                      size: 32,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
