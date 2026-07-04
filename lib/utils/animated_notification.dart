import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tripzo/utils/routes.dart';

class AnimatedInAppNotification extends StatefulWidget {
  final String title;
  final String message;
  final String type;
  final VoidCallback onDismiss;

  const AnimatedInAppNotification({
    super.key,
    required this.title,
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<AnimatedInAppNotification> createState() => _AnimatedInAppNotificationState();
}

class _AnimatedInAppNotificationState extends State<AnimatedInAppNotification> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    _controller.forward();

    _autoDismissTimer = Timer(const Duration(seconds: 4), () {
      _dismiss();
    });
  }

  void _dismiss() async {
    if (mounted) {
      await _controller.reverse();
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;

    IconData icon = Icons.notifications_active_rounded;
    Color themeColor = const Color(0xFF6366F1);

    if (widget.type == 'SUCCESS') {
      icon = Icons.check_circle_rounded;
      themeColor = const Color(0xFF10B981);
    } else if (widget.type == 'WARNING') {
      icon = Icons.warning_rounded;
      themeColor = Colors.orange;
    } else if (widget.type == 'ERROR') {
      icon = Icons.error_rounded;
      themeColor = Colors.redAccent;
    }

    return SlideTransition(
      position: _offsetAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta! < -10) {
              _dismiss();
            }
          },
          child: Container(
            width: screenWidth - 32,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: themeColor.withValues(alpha: 0.35),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Animated Glowing Icon Container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: themeColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: themeColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Text Fields
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Tiny Close Indicator
                GestureDetector(
                  onTap: _dismiss,
                  child: Icon(
                    Icons.close_rounded,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showPremiumInAppNotification({
  required String title,
  required String message,
  String type = 'INFO',
}) {
  final context = AppRoutes.navigatorKey.currentContext;
  if (context == null) return;

  OverlayEntry? overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: AnimatedInAppNotification(
          title: title,
          message: message,
          type: type,
          onDismiss: () {
            overlayEntry?.remove();
          },
        ),
      ),
    ),
  );

  Overlay.of(context).insert(overlayEntry);
}
