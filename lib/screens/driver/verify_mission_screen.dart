import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tripzo/utils/crypto_utils.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  bool _scanStarted = true;

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
      final String? token = await UserStore.getToken();
      
      // Encrypt the OTP before sending
      final encryptedOtp = CryptoUtils.encryptOTP(otp);
      
      final url = widget.isStart 
          ? "${ApiConstants.baseUrl}/request/start-route"
          : "${ApiConstants.baseUrl}/request/complete-route-otp";
      
      final response = await http.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode({
          "route_id": int.tryParse(widget.requestId) ?? 0,
          "otp": encryptedOtp,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? "Mission ${widget.isStart ? 'Started' : 'Completed'} Successfully"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw data['message'] ?? "Verification failed";
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
            _scanStarted = false;
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.isStart ? "Verify Start" : "Verify Arrival"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Scanner section
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    children: [
                      MobileScanner(onDetect: _onDetect),
                      Center(
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                "Verification Required",
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.w900, 
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Scan the Faculty QR code or enter the digit code manually to proceed.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              
              // OTP Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) => _buildOtpBox(i, isDark)),
              ),
              
              const SizedBox(height: 60),
              
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : () => _verifyOtp(_getOtp()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                        : const Text(
                            "VERIFY & PROCEED",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
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
}
