import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/utils/toast_utils.dart';

class SplitVehicleScreen extends StatefulWidget {
  final int runId;

  const SplitVehicleScreen({super.key, required this.runId});

  @override
  State<SplitVehicleScreen> createState() => _SplitVehicleScreenState();
}

class _SplitVehicleScreenState extends State<SplitVehicleScreen> {
  final TextEditingController _startOdometerController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _startOdometerController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _submitSplit() async {
    if (_startOdometerController.text.trim().isEmpty) {
      showTopToast(context, "Please enter start odometer reading", isError: true);
      return;
    }

    if (_placeController.text.trim().isEmpty) {
      showTopToast(context, "Please enter place", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final String? token = await UserStore.getToken();
      if (token == null) {
        if (mounted) showTopToast(context, "Session expired", isError: true);
        return;
      }

      final String url =
          "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/${widget.runId}/resume-evening-trip";

      final Map<String, dynamic> body = {
        "startOdometer": int.tryParse(_startOdometerController.text.trim()) ?? 0,
        "place": _placeController.text.trim(),
      };

      debugPrint("---- [SPLIT VEHICLE: SUBMIT] ----\nPATCH $url\nBody: ${json.encode(body)}\n----------------------------");

      final response = await http.patch(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(body),
      );

      debugPrint("---- [SPLIT VEHICLE: SUBMIT RESPONSE ${response.statusCode}] ----\n${response.body}\n----------------------------");

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          showTopToast(context, "Vehicle split and resumed successfully!");
          Navigator.pop(context, true);
        }
      } else if (response.statusCode == 401) {
        await UserStore.forceLogout();
      } else {
        final resBody = json.decode(response.body);
        if (mounted) {
          showTopToast(
            context,
            resBody['message'] ?? "Failed to split vehicle",
            isError: true,
          );
        }
      }
    } catch (e) {
      debugPrint("Error submitting split vehicle: $e");
      if (mounted) showTopToast(context, "Connection failed", isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const Color primaryBlue = Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Split Vehicle",
          style: GoogleFonts.outfit(
            color: titleColor,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryBlue.withValues(alpha: 0.08),
                    primaryBlue.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: primaryBlue.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.call_split_rounded,
                      color: primaryBlue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Split Bus Route",
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Enter details to resume evening trip from a split point",
                          style: TextStyle(
                            fontSize: 13,
                            color: subColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Row(
              children: [
                const Icon(Icons.speed_rounded, size: 18, color: primaryBlue),
                const SizedBox(width: 8),
                Text(
                  "Start Odometer",
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _startOdometerController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: "Enter start odometer reading",
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : Colors.black38,
                  fontWeight: FontWeight.normal,
                ),
                prefixIcon: Icon(Icons.speed_rounded,
                    color: primaryBlue.withValues(alpha: 0.6), size: 20),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: primaryBlue.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.place_rounded, size: 18, color: primaryBlue),
                const SizedBox(width: 8),
                Text(
                  "Place Name",
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _placeController,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: "Enter place name",
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : Colors.black38,
                  fontWeight: FontWeight.normal,
                ),
                prefixIcon: Icon(Icons.place_rounded,
                    color: primaryBlue.withValues(alpha: 0.6), size: 20),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: primaryBlue.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
              ),
            ),

            const SizedBox(height: 36),
            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitSplit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  disabledBackgroundColor:
                      primaryBlue.withValues(alpha: 0.4),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.call_split_rounded, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            "Submit Split",
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
