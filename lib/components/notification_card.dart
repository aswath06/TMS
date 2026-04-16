import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationCard extends StatefulWidget {
  final NotificationModel notification;
  final bool isDashboard;

  const NotificationCard({
    super.key,
    required this.notification,
    this.isDashboard = false,
  });

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color primaryBlue = const Color(0xFF6366F1);

    IconData icon = Icons.info_outline_rounded;
    Color color = primaryBlue;

    if (widget.notification.type == 'SUCCESS') {
      icon = Icons.check_circle_rounded;
      color = Colors.green.shade400;
    } else if (widget.notification.type == 'WARNING') {
      icon = Icons.warning_amber_rounded;
      color = Colors.orange;
    } else if (widget.notification.type == 'ERROR') {
      icon = Icons.error_outline_rounded;
      color = Colors.redAccent;
    }

    String timeAgo = _formatDateTime(widget.notification.createdAt);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: widget.notification.isRead 
              ? color.withOpacity(0.05) 
              : color.withOpacity(0.2),
          width: widget.notification.isRead ? 1 : 2,
        ),
        boxShadow: [
          if (!widget.notification.isRead)
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: widget.isDashboard 
              ? () => setState(() => _isExpanded = !_isExpanded)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.notification.title,
                                  style: TextStyle(
                                    fontWeight: widget.notification.isRead 
                                        ? FontWeight.w700 
                                        : FontWeight.w900,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.notification.message,
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: 13,
                            ),
                            maxLines: (widget.isDashboard && !_isExpanded) ? 1 : null,
                            overflow: (widget.isDashboard && !_isExpanded) 
                                ? TextOverflow.ellipsis 
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if ((!widget.isDashboard || _isExpanded) && !widget.notification.isRead) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          context.read<NotificationProvider>().markAsRead(widget.notification.id);
                        },
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text(
                          "Mark as Seen",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: color,
                          backgroundColor: color.withOpacity(0.08),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return "Just Now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return DateFormat('dd MMM').format(dt);
  }
}
