import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import '../utils/routes.dart';

class NotificationBell extends ConsumerStatefulWidget {
  final Color iconColor;
  final double size;

  const NotificationBell({
    super.key,
    required this.iconColor,
    this.size = 28,
  });

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
builder: (context, ref, _) {
final provider = ref.watch(notificationProviderFamily);
        final count = provider.unreadCount;
        
        if (count > 0 && _lastCount == 0) {
          _controller.forward();
        } else if (count == 0 && _lastCount > 0) {
          _controller.reverse();
        } else if (count > _lastCount) {
          // Pulse effect on increment
          _controller.forward(from: 0.5);
        }
        _lastCount = count;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.iconColor.withValues(alpha: 0.05),
              ),
              child: IconButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
                tooltip: 'Notifications',
                icon: Icon(
                  count > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                  color: widget.iconColor,
                  size: widget.size,
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                right: 4,
                top: 4,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFB91C1C)], // Red 500 to Red 700
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor == Colors.transparent 
                          ? Colors.white 
                          : Theme.of(context).cardColor, 
                        width: 1.5
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Center(
                      child: Text(
                        count > 9 ? '9+' : count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
