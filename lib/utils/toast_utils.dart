import 'package:flutter/material.dart';

void showTopToast(BuildContext context, String message, {bool isError = false}) {
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  
  final Color bgColor = isError 
      ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2))
      : (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5));
      
  final Color textColor = isError 
      ? (isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B))
      : (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46));
      
  final IconData icon = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;
  final Color iconColor = isError 
      ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
      : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669));

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: iconColor.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height - 150,
        left: 20,
        right: 20,
      ),
      duration: const Duration(seconds: 4),
      dismissDirection: DismissDirection.up,
    ),
  );
}
