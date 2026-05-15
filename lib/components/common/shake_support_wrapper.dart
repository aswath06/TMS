import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shake/shake.dart';
import 'package:tripzo/utils/routes.dart';

class ShakeSupportWrapper extends StatefulWidget {
  final Widget child;
  const ShakeSupportWrapper({super.key, required this.child});

  @override
  State<ShakeSupportWrapper> createState() => _ShakeSupportWrapperState();
}

class _ShakeSupportWrapperState extends State<ShakeSupportWrapper> {
  ShakeDetector? detector;
  bool _isModalShowing = false;

  void _handleShake() {
    debugPrint("📱 [ShakeSupportWrapper] SHAKE DETECTED");
    if (!_isModalShowing && mounted) {
      _showSupportModal();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        detector = ShakeDetector.autoStart(
          onPhoneShake: (event) {
            _handleShake();
          },
          shakeThresholdGravity: 2.1,
        );
      }
    });
  }

  @override
  void dispose() {
    detector?.stopListening();
    super.dispose();
  }

  void _showSupportModal() {
    final navContext = AppRoutes.navigatorKey.currentContext;
    if (navContext == null) {
      debugPrint("⚠️ [ShakeSupportWrapper] Navigator context is null");
      _isModalShowing = false;
      return;
    }
    _isModalShowing = true;
    showModalBottomSheet(
      context: navContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SupportModalSheet(),
    ).then((_) => _isModalShowing = false);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class SupportModalSheet extends StatefulWidget {
  const SupportModalSheet({super.key});

  @override
  State<SupportModalSheet> createState() => _SupportModalSheetState();
}

class _SupportModalSheetState extends State<SupportModalSheet> {
  final TextEditingController _msgController = TextEditingController();

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: subTitleColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.support_agent_rounded, color: primaryBlue, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                "Support",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "How can we help you? Describe your issue below and our team will get back to you.",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: subTitleColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _msgController,
              maxLines: 5,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
              decoration: InputDecoration(
                hintText: "Type your message here...",
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: subTitleColor.withValues(alpha: 0.4),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: () {
                if (_msgController.text.trim().isNotEmpty) {
                   Navigator.pop(context);
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("Support request sent successfully!")),
                   );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              child: Text(
                "Submit Request",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
