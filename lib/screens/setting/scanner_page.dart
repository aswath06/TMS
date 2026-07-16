import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/store/istamil.dart'; // Import Language Store
import 'package:tripzo/store/isdark.dart'; // Import Theme Store
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/utils/toast_utils.dart';
import 'package:tripzo/utils/api_error_parser.dart';


class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with SingleTickerProviderStateMixin {
  bool isProcessing = false;
  String? scannedSessionId;
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.unrestricted,
    returnImage: false,
    autoStart: true,
  );
  final TextEditingController _hoursController = TextEditingController(
    text: "24",
  );

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  void _onDetect(BarcodeCapture capture) {
    if (scannedSessionId != null || isProcessing) return;
    final barcode = capture.barcodes.first;
    if (barcode.rawValue != null) {
      setState(() => scannedSessionId = barcode.rawValue);
      cameraController.stop();
      _animationController.stop();
    }
  }

  Future<void> _approveLogin() async {
    setState(() => isProcessing = true);
    final bool isTamil = LanguageStore.isTamil;
    try {
      final token = await UserStore.getToken();
      final hours = int.tryParse(_hoursController.text) ?? 24;

      final response = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/auth/web-login-approve"),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode({"sessionId": scannedSessionId, "accessHours": hours}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          showTopToast(
            context,
            isTamil
                ? "உள்நுழைவு அங்கீகரிக்கப்பட்டது"
                : "Login Approved Successfully",
          );
          Navigator.pop(context);
        }
      } else {
        _handleError(
          isTamil
              ? ApiErrorParser.parse(response, fallback: "சர்வர் பிழை")
              : ApiErrorParser.parse(response, fallback: "Server Error"),
        );
      }
    } catch (e) {
      _handleError(
        isTamil
            ? "இணைப்பு தோல்வியடைந்தது"
            : "Connection failed. Check your internet.",
      );
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  void _handleError(String message) {
    showTopToast(context, message, isError: true);
    setState(() => scannedSessionId = null);
    cameraController.start();
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    cameraController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine Global States
    final bool isDark = ThemeStore.isDark;
    final bool isTamil = LanguageStore.isTamil;
    final Color primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: Colors.black, // Camera view is always black background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isTamil ? "ஸ்கேன் செய்க" : "SCAN QR",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            letterSpacing: 2,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          ValueListenableBuilder(
            valueListenable: cameraController,
            builder: (context, state, child) {
              return IconButton(
                icon: Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                  color: Colors.white,
                ),
                onPressed: () => cameraController.toggleTorch(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: cameraController, onDetect: _onDetect),
          _buildScannerOverlay(primaryBlue, isTamil),
          if (scannedSessionId != null)
            _buildApprovalPanel(isDark, isTamil, primaryBlue),
          if (isProcessing) _buildLoadingOverlay(primaryBlue),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay(Color primaryBlue, bool isTamil) {
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.7),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: SizedBox(
            width: 260,
            height: 260,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: primaryBlue.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    if (scannedSessionId == null)
                      Positioned(
                        top: _animationController.value * 240 + 10,
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: primaryBlue.withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                            gradient: LinearGradient(
                              colors: [
                                primaryBlue.withValues(alpha: 0),
                                primaryBlue,
                                primaryBlue.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.7,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryBlue.withValues(alpha: 0.3)),
              ),
              child: Text(
                isTamil
                    ? "சட்டத்தில் QR குறியீட்டை சீரமைக்கவும்"
                    : "Align QR Code within the frame",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalPanel(bool isDark, bool isTamil, Color primaryBlue) {
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
              blurRadius: 40,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isTamil ? "அனுமதி வழங்குக" : "Authorize Session",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _hoursController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: isTamil ? "கால அளவு (மணிநேரம்)" : "Duration (Hours)",
                labelStyle: TextStyle(color: subTitleColor),
                filled: true,
                fillColor: cardColor,
                prefixIcon: Icon(Icons.av_timer_rounded, color: primaryBlue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                suffixText: isTamil ? "மணி" : "HRS",
                suffixStyle: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      setState(() => scannedSessionId = null);
                      cameraController.start();
                      _animationController.repeat(reverse: true);
                    },
                    child: Text(
                      isTamil ? "ரத்து" : "CANCEL",
                      style: TextStyle(
                        color: subTitleColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _approveLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isTamil ? "அனுமதி" : "APPROVE",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(Color primaryBlue) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 3),
      ),
    );
  }
}
