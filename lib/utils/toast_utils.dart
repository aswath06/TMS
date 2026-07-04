import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tripzo/utils/routes.dart';

OverlayEntry? _activeToastEntry;
Timer? _toastTimer;

/// Global function to show a custom top-level toast notification.
void showTopToast(BuildContext context, String message, {bool isError = false}) {
  String displayMessage = message;
  bool displayIsError = isError;

  try {
    final startIndex = message.indexOf('{');
    final endIndex = message.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      final jsonStr = message.substring(startIndex, endIndex + 1);
      final json = jsonDecode(jsonStr);
      if (json is Map) {
        if (json.containsKey('message')) {
          displayMessage = json['message'].toString();
        }
        if (json.containsKey('success')) {
          displayIsError = json['success'] == false;
        }
      }
    }
  } catch (_) {}

  final bool isDark = Theme.of(context).brightness == Brightness.dark;

  final Color bgColor = displayIsError
      ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2))
      : (isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5));

  final Color textColor = displayIsError
      ? (isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B))
      : (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46));

  final IconData icon = displayIsError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;
  final Color iconColor = displayIsError
      ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
      : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669));

  // Cancel any existing active toast to prevent overlapping
  if (_activeToastEntry != null) {
    _toastTimer?.cancel();
    if (_activeToastEntry!.mounted) {
      _activeToastEntry!.remove();
    }
    _activeToastEntry = null;
  }

  final overlayState = AppRoutes.navigatorKey.currentState?.overlay ?? Overlay.of(context);

  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
      child: _TopToastWidget(
        message: displayMessage,
        bgColor: bgColor,
        textColor: textColor,
        icon: icon,
        iconColor: iconColor,
        onDismiss: () {
          if (overlayEntry.mounted) {
            overlayEntry.remove();
          }
          if (_activeToastEntry == overlayEntry) {
            _activeToastEntry = null;
          }
        },
      ),
    ),
  );

  _activeToastEntry = overlayEntry;
  overlayState.insert(overlayEntry);
}

/// A custom ScaffoldMessenger that intercepts standard showSnackBar calls
/// and redirects them to show as top toasts.
class CustomScaffoldMessenger extends ScaffoldMessenger {
  const CustomScaffoldMessenger({
    super.key,
    required super.child,
  });

  @override
  ScaffoldMessengerState createState() => _CustomScaffoldMessengerState();
}

class _CustomScaffoldMessengerState extends ScaffoldMessengerState {
  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    final String message = _extractTextFromWidget(snackBar.content);

    final lowerMsg = message.toLowerCase();
    final isErrorText = lowerMsg.contains('fail') || 
                        lowerMsg.contains('error') || 
                        lowerMsg.contains('not defined') ||
                        lowerMsg.contains('invalid') ||
                        lowerMsg.contains('unauthorized') ||
                        lowerMsg.contains('exception') ||
                        lowerMsg.contains('warning');

    // Determine if the SnackBar was intended as an error/warning by checking colors or text
    final isError = isErrorText ||
        snackBar.backgroundColor == Colors.red ||
        snackBar.backgroundColor == Colors.redAccent ||
        snackBar.backgroundColor == Colors.orange ||
        snackBar.backgroundColor == Colors.orangeAccent ||
        snackBar.backgroundColor == const Color(0xFFDC2626) ||
        snackBar.backgroundColor == const Color(0xFF7F1D1D) ||
        snackBar.backgroundColor == Colors.red[800] ||
        snackBar.backgroundColor == Colors.red[900];

    // Show using our top toast system
    showTopToast(context, message, isError: isError);

    // Return a valid ScaffoldFeatureController by calling super with an invisible SnackBar
    return super.showSnackBar(
      const SnackBar(
        content: SizedBox.shrink(),
        duration: Duration.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
  }

  /// Helper to safely traverse the SnackBar child widget tree and extract readable text.
  String _extractTextFromWidget(Widget widget) {
    if (widget is Text) {
      return widget.data ?? '';
    }
    if (widget is Center && widget.child != null) {
      return _extractTextFromWidget(widget.child!);
    }
    if (widget is Padding && widget.child != null) {
      return _extractTextFromWidget(widget.child!);
    }
    if (widget is Container && widget.child != null) {
      return _extractTextFromWidget(widget.child!);
    }
    if (widget is Expanded) {
      return _extractTextFromWidget(widget.child);
    }
    if (widget is Row) {
      return widget.children.map(_extractTextFromWidget).where((s) => s.isNotEmpty).join(' ').trim();
    }
    if (widget is Column) {
      return widget.children.map(_extractTextFromWidget).where((s) => s.isNotEmpty).join(' ').trim();
    }
    // Fallback search inside general widget fields
    return '';
  }
}

class _TopToastWidget extends StatefulWidget {
  final String message;
  final Color bgColor;
  final Color textColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onDismiss;

  const _TopToastWidget({
    required this.message,
    required this.bgColor,
    required this.textColor,
    required this.icon,
    required this.iconColor,
    required this.onDismiss,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
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

    _toastTimer = Timer(const Duration(seconds: 4), () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (mounted) {
      _controller.reverse().then((_) {
        widget.onDismiss();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss, // Tap to dismiss instantly
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: widget.bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.iconColor.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: widget.iconColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: widget.textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
