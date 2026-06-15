import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tripzo/utils/crypto_utils.dart';

class StudentAttendanceScannerScreen extends StatefulWidget {
  const StudentAttendanceScannerScreen({super.key});

  @override
  State<StudentAttendanceScannerScreen> createState() => _StudentAttendanceScannerScreenState();
}

class _StudentAttendanceScannerScreenState extends State<StudentAttendanceScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController cameraController = MobileScannerController();
  bool _isScanned = false;
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2, milliseconds: 500),
    );
    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    )..addListener(() {
        setState(() {});
      });
    _laserController.repeat(reverse: true);
  }

  @override
  void dispose() {
    cameraController.dispose();
    _laserController.dispose();
    super.dispose();
  }

  void _processScannedData(String code) {
    if (!mounted) return;
    
    debugPrint("[STUDENT QR SCANNER] Raw Code Scanned: '$code'");

    String? extractedOtp;

    try {
      dynamic data;
      try {
        data = jsonDecode(code);
      } catch (_) {
        // Not JSON, assume raw OTP
      }

      if (data is Map<String, dynamic> && data['otp'] != null) {
        // Extract and decrypt OTP if it's JSON
        final String encryptedOtp = data['otp'].toString();
        extractedOtp = CryptoUtils.decryptOTP(encryptedOtp);
      } else {
        // Raw code fallback
        extractedOtp = code;
      }
    } catch (e) {
      debugPrint("[STUDENT QR SCANNER] Error parsing code: $e");
      extractedOtp = code; // Fallback to raw string if decryption fails
    }
    
    // Ensure it's 6 digits (basic validation)
    if (extractedOtp != null && extractedOtp.length > 6) {
        extractedOtp = extractedOtp.substring(0, 6);
    }
    
    debugPrint("[STUDENT QR SCANNER] Extracted OTP: '$extractedOtp'");

    // Return the extracted OTP directly to the OtpAttendanceScreen
    Navigator.pop(context, extractedOtp);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    const Color activeAccentColor = Color(0xFF6366F1); // Indigo

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070A13) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeAccentColor.withOpacity(0.1),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 12.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: isDark ? Colors.white : Colors.black87,
                        onPressed: () => Navigator.pop(context),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: activeAccentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: activeAccentColor.withOpacity(0.2), width: 1.5),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded, 
                          color: activeAccentColor, 
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Bus Verification",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "STUDENT ATTENDANCE SCANNER",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: activeAccentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Text(
                    "Scan the official QR code displayed inside the bus to instantly log your attendance.",
                    style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Scanner Frame
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: activeAccentColor.withOpacity(0.15),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: activeAccentColor.withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Stack(
                        children: [
                          MobileScanner(
                            controller: cameraController,
                            onDetect: (capture) {
                              if (_isScanned) return;
                              
                              final List<Barcode> barcodes = capture.barcodes;
                              for (final barcode in barcodes) {
                                if (!_isScanned && barcode.rawValue != null) {
                                  setState(() => _isScanned = true);
                                  _processScannedData(barcode.rawValue!);
                                  break;
                                }
                              }
                            },
                          ),
                          
                          ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              Colors.black.withOpacity(0.5),
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
                                    width: 240,
                                    height: 240,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          if (!_isScanned)
                            Positioned(
                              top: MediaQuery.of(context).size.height * 0.5 * _laserAnimation.value,
                              left: MediaQuery.of(context).size.width / 2 - 144, // 144 is 240/2 + margins
                              child: Container(
                                width: 240,
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      activeAccentColor.withOpacity(0.01),
                                      activeAccentColor,
                                      activeAccentColor.withOpacity(0.01),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: activeAccentColor.withOpacity(0.8),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
