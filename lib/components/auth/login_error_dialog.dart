import 'package:flutter/material.dart';

class LoginErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color baseColor;
  final VoidCallback? onRetry;

  const LoginErrorDialog({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.baseColor,
    this.onRetry,
  });

  static void show(
    BuildContext context, {
    required String message,
    VoidCallback? onRetry,
  }) {
    String finalTitle = "Login Failed";
    String finalMessage = message;
    IconData finalIcon = Icons.error_outline_rounded;
    Color finalColor = const Color(0xFFEF4444); // Default Red

    if (message.toLowerCase().contains("network error")) {
      finalTitle = "Network Error";
      finalIcon = Icons.wifi_off_rounded;
      finalColor = const Color(0xFF6366F1); // Indigo
    } else if (message.toLowerCase().contains("another device")) {
      finalTitle = "Session Active";
      finalIcon = Icons.devices_other_rounded;
      finalColor = const Color(0xFFF59E0B); // Amber
    } else if (message.toLowerCase().contains("invalid") || message.toLowerCase().contains("unauthorized")) {
      finalTitle = "Access Denied";
      finalIcon = Icons.lock_person_rounded;
      finalColor = const Color(0xFFEF4444); // Red
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => LoginErrorDialog(
        title: finalTitle,
        message: finalMessage,
        icon: finalIcon,
        baseColor: finalColor,
        onRetry: onRetry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: baseColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: baseColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          if (onRetry != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onRetry!();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: baseColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(20),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Retry Now",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Dismiss",
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: baseColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(20),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Understood",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
