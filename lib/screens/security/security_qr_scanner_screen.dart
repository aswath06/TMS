import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/utils/crypto_utils.dart';
import 'package:tripzo/store/user_store.dart';

class SecurityQrScannerScreen extends StatefulWidget {
  const SecurityQrScannerScreen({super.key});

  @override
  State<SecurityQrScannerScreen> createState() => _SecurityQrScannerScreenState();
}

class _SecurityQrScannerScreenState extends State<SecurityQrScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController cameraController = MobileScannerController();
  bool _isScanned = false;
  bool _isProcessing = false;
  bool _isSuccessState = false;
  String _selectedMode = 'Routes';

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

  Future<void> _processScannedData(String code) async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
      _isSuccessState = false;
    });

    debugPrint("\n==================================================");
    debugPrint("[QR SCANNER] Raw Code Scanned: '$code'");
    debugPrint("==================================================");

    try {
      if (_selectedMode == 'Bus') {
        String otpCode = code;
        try {
          final data = jsonDecode(code);
          if (data is Map<String, dynamic> && data['otp'] != null) {
            otpCode = CryptoUtils.decryptOTP(data['otp'].toString());
          }
        } catch (_) {}

        final now = DateTime.now();
        final serviceDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        
        final timeInMinutes = now.hour * 60 + now.minute;
        String type = "FN";
        if (timeInMinutes >= 120 && timeInMinutes <= 660) {
          type = "FN";
        } else if (timeInMinutes >= 690 && timeInMinutes <= 1080) {
          type = "AN";
        }

        final body = {
          "otp_code": otpCode,
          "service_date": serviceDate,
          "type": type
        };

        final token = await UserStore.getToken();
        final url = "https://18x50gz9-8055.inc1.devtunnels.ms/daily-bus/daily-bus-runs/operations/verify-campus-in-otp";

        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': token ?? '',
            'Content-Type': 'application/json'
          },
          body: jsonEncode(body),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = jsonDecode(response.body);
          
          bool isSuccess = true;
          String errorMessage = "Verification failed";
          
          if (responseData == false) {
            isSuccess = false;
          } else if (responseData is Map) {
            if (responseData['status'] == false || responseData['success'] == false || responseData['response'] == false) {
              isSuccess = false;
            }
            if (responseData['message'] != null) {
              errorMessage = responseData['message'];
            }
          }
          
          if (!isSuccess) {
            throw errorMessage;
          }

          if (!mounted) return;
          setState(() {
            _isSuccessState = true;
            _isProcessing = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Bus verified successfully!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          final error = jsonDecode(response.body);
          throw error['message'] ?? "Action failed (${response.statusCode})";
        }
        return;
      }

      dynamic data;
      try {
        data = jsonDecode(code);
      } catch (_) {
        debugPrint("[QR SCANNER] Warning: Scanned code is not a valid JSON string!");
      }

      int? tripId;
      String? action;
      String? encryptedOtp;

      if (data is Map<String, dynamic>) {
        tripId = data['trip_instance_id'] != null ? int.tryParse(data['trip_instance_id'].toString()) : null;
        action = data['otp_type']?.toString();
        encryptedOtp = data['otp']?.toString();
      }

      // Safe Fallback for Raw OTP Scan Codes
      if (tripId == null || action == null || encryptedOtp == null) {
        debugPrint("[QR SCANNER] Raw string fallback triggered. Defaulting to tripId=175 and action=START.");
        tripId = 175;
        action = "START";
        encryptedOtp = code;
      }

      // Decrypt OTP (turning the encrypted hex back to 6-digit numeric OTP)
      final decryptedOtp = CryptoUtils.decryptOTP(encryptedOtp.toString());
      debugPrint("[QR SCANNER] Encrypted OTP: '$encryptedOtp'");
      debugPrint("[QR SCANNER] Decrypted OTP: '$decryptedOtp'");

      final token = await UserStore.getToken();
      final url = ApiConstants.tripAction(tripId);
      final body = {
        "action": action,
        "mode": "OTP",
        "otp": decryptedOtp,
      };

      // Construct and Print the exact CURL representation for development convenience
      final curlHeaders = "-H 'Authorization: TMS $token' -H 'Content-Type: application/json'";
      final curlBody = "-d '${jsonEncode(body)}'";
      final curlCommand = "curl --location --request POST '$url' \\\n$curlHeaders \\\n$curlBody";
      
      debugPrint("\n--- [QR SCANNER] SENDING CURL ---");
      debugPrint(curlCommand);
      debugPrint("---------------------------------\n");

      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode(body),
      );

      debugPrint("\n--- [QR SCANNER] RESPONSE RECEIVED ---");
      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Body: ${response.body}");
      debugPrint("--------------------------------------\n");

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        setState(() {
          _isSuccessState = true;
          _isProcessing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$action successfully registered!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        final error = jsonDecode(response.body);
        throw error['message'] ?? "Action failed (${response.statusCode})";
      }
    } catch (e) {
      debugPrint("[QR SCANNER] Error during verification: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        // Wait a bit before allowing another scan
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _isScanned = false;
            _isSuccessState = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Aesthetic Accent Colors
    const Color neonIndigo = Color(0xFF6366F1);
    const Color neonAmber = Color(0xFFF59E0B);
    const Color neonGreen = Color(0xFF10B981);
    
    Color activeAccentColor = neonIndigo;
    String statusMessage = "ALIGN VEHICLE QR WITHIN FRAME";
    
    if (_isProcessing) {
      activeAccentColor = neonAmber;
      statusMessage = "VERIFYING SECURE KEY...";
    } else if (_isSuccessState) {
      activeAccentColor = neonGreen;
      statusMessage = "SECURE PASS GRANTED";
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070A13) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Elegant Abstract Gradient Background
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeAccentColor.withValues(alpha: 0.1),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Top Custom High-End Glass Header Card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 12.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: activeAccentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: activeAccentColor.withValues(alpha: 0.2), width: 1.5),
                          ),
                          child: Icon(
                            _isSuccessState 
                                ? Icons.verified_user_rounded 
                                : (_isProcessing ? Icons.sync_rounded : Icons.qr_code_scanner_rounded), 
                            color: activeAccentColor, 
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Gate Verification",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "SECURITY SCAN SYSTEM",
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
                      "Scan the official driver QR code displayed on the vehicle dashboard to register gateway clearance.",
                      style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Mode Toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: activeAccentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: activeAccentColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedMode = 'Routes'),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _selectedMode == 'Routes' ? activeAccentColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Routes',
                                  style: TextStyle(
                                    color: _selectedMode == 'Routes' ? Colors.white : activeAccentColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedMode = 'Bus'),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _selectedMode == 'Bus' ? activeAccentColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Bus',
                                  style: TextStyle(
                                    color: _selectedMode == 'Bus' ? Colors.white : activeAccentColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Immersive Glass Scanner Frame (Fixed Height for scrolling layout)
                  Container(
                    height: 420,
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: activeAccentColor.withValues(alpha: _isProcessing ? 0.4 : 0.15),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: activeAccentColor.withValues(alpha: 0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Stack(
                        children: [
                          // Live camera preview layer
                          MobileScanner(
                            controller: cameraController,
                            onDetect: (capture) {
                              if (_isScanned || _isProcessing) return;
                              
                              final List<Barcode> barcodes = capture.barcodes;
                              for (final barcode in barcodes) {
                                if (!_isScanned && barcode.rawValue != null) {
                                  setState(() => _isScanned = true);
                                  final String code = barcode.rawValue!;
                                  debugPrint('QR Barcode found! $code');
                                  _processScannedData(code);
                                  break;
                                }
                              }
                            },
                          ),
                          
                          // Darkening Scanner Mask overlay to emphasize viewport
                          ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.5),
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
                          
                          // Premium Animated Laser Scanner Line
                          if (!_isScanned && !_isProcessing)
                            Positioned(
                              top: 420 * _laserAnimation.value,
                              left: MediaQuery.of(context).size.width / 2 - 144,
                              child: Container(
                                width: 240,
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      activeAccentColor.withValues(alpha: 0.01),
                                      activeAccentColor,
                                      activeAccentColor.withValues(alpha: 0.01),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: activeAccentColor.withValues(alpha: 0.8),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                          // Sci-Fi Target corners custom painted frame
                          Center(
                            child: CustomPaint(
                              size: const Size(240, 240),
                              painter: ScannerOverlayPainter(color: activeAccentColor),
                            ),
                          ),
                          
                          // Verifying secure badge spinner
                          if (_isProcessing)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.6),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(
                                        color: neonAmber,
                                        strokeWidth: 3,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        "PROCESSING GATEWAY KEY",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.5,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                    ),
                  ),
                ),
                
                // Footer Status Message and Branding
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  child: Column(
                    children: [
                      // Status light badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: activeAccentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: activeAccentColor.withValues(alpha: 0.2), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: activeAccentColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: activeAccentColor.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              statusMessage,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "TRIPZO NETWORK V1.2.0 SECURE CORE",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  final Color color;
  ScannerOverlayPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    double len = 30.0; // corner bracket length

    // Top Left Corner
    path.moveTo(0, len);
    path.lineTo(0, 0);
    path.lineTo(len, 0);

    // Top Right Corner
    path.moveTo(size.width - len, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, len);

    // Bottom Left Corner
    path.moveTo(0, size.height - len);
    path.lineTo(0, size.height);
    path.lineTo(len, size.height);

    // Bottom Right Corner
    path.moveTo(size.width - len, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, size.height - len);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
