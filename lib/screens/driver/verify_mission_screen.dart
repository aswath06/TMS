import 'dart:ui';
import 'package:flutter/material.dart';
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

class _VerifyMissionScreenState extends State<VerifyMissionScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isVerifying = false;

  @override
  void dispose() {
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
    return Container(
      width: 45,
      height: 55,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focusNodes[index].hasFocus 
              ? const Color(0xFF6366F1) 
              : (isDark ? Colors.white12 : Colors.grey.shade300),
          width: 2,
        ),
        boxShadow: _focusNodes[index].hasFocus ? [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF6366F1)),
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.isNotEmpty) {
            if (index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else {
              _focusNodes[index].unfocus();
              final otp = _getOtp();
              if (otp.length == 6) _verifyOtp(otp);
            }
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
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
          // Background Gradient
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryBlue.withOpacity(0.05),
              ),
            ),
          ),
          
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
              child: Column(
                children: [
                  // Scanner section with premium frame
                  Container(
                    height: 280,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      color: Colors.black,
                      boxShadow: [
                        BoxShadow(
                          color: primaryBlue.withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: Stack(
                        children: [
                          MobileScanner(onDetect: _onDetect),
                          // Scanning Area indicator
                          Center(
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Stack(
                                children: [
                                  // Corner accents
                                  _buildCorner(0, 0, 90),
                                  _buildCorner(null, 0, 180),
                                  _buildCorner(0, null, 0),
                                  _buildCorner(null, null, 270),
                                ],
                              ),
                            ),
                          ),
                          // Scanning Line Animation placeholder
                          Positioned(
                            top: 40,
                            left: 40,
                            right: 40,
                            bottom: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    primaryBlue.withOpacity(0.1),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Text instructions
                  Text(
                    "Security Verification",
                    style: TextStyle(
                      fontSize: 26, 
                      fontWeight: FontWeight.w900, 
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "Scan the QR code generated by the Faculty or enter the 6-digit code manually.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 14,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // OTP Boxes with updated premium design
                  FittedBox(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (i) => _buildOtpBox(i, isDark)),
                    ),
                  ),
                  
                  const SizedBox(height: 54),
                  
                  // Button
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: primaryBlue.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isVerifying ? null : () => _verifyOtp(_getOtp()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          elevation: 0,
                        ),
                        child: _isVerifying
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                              )
                            : const Text(
                                "CONFIRM & VALIDATE",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Bottom security note
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 14, color: subTextColor),
                      const SizedBox(width: 8),
                      Text(
                        "SECURE HANDSHAKE PROTOCOL",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: subTextColor,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
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
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFF6366F1), width: 4),
              left: BorderSide(color: Color(0xFF6366F1), width: 4),
            ),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(10)),
          ),
        ),
      ),
    );
  }
}
