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
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color messageColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final Color primaryBlue = const Color(0xFF6366F1);

    IconData icon = Icons.info_outline_rounded;
    Color alertColor = primaryBlue;

    if (widget.notification.type == 'SUCCESS') {
      icon = Icons.check_circle_rounded;
      alertColor = const Color(0xFF10B981);
    } else if (widget.notification.type == 'WARNING') {
      icon = Icons.warning_rounded;
      alertColor = Colors.orange;
    } else if (widget.notification.type == 'ERROR') {
      icon = Icons.error_rounded;
      alertColor = Colors.redAccent;
    }

    String timeAgo = _formatDateTime(widget.notification.createdAt);
    final bool isUnread = !widget.notification.isRead;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isUnread ? alertColor.withOpacity(0.35) : titleColor.withOpacity(0.06),
          width: isUnread ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isUnread 
                ? alertColor.withOpacity(0.06) 
                : Colors.black.withOpacity(isDark ? 0.05 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.isDashboard 
                ? () => setState(() => _isExpanded = !_isExpanded)
                : null,
            child: Container(
              // Accent bar on the left
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: isUnread ? alertColor : alertColor.withOpacity(0.2),
                    width: 5,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon with styled circle border
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: alertColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: alertColor, size: 20),
                      ),
                      const SizedBox(width: 14),
                      
                      // Message Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.notification.title,
                                    style: TextStyle(
                                      fontWeight: isUnread ? FontWeight.w900 : FontWeight.w700,
                                      fontSize: 14,
                                      color: titleColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    Text(
                                      timeAgo,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (isUnread) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: alertColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: alertColor.withOpacity(0.4),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            )
                                          ]
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              widget.notification.message,
                              style: TextStyle(
                                color: messageColor,
                                fontSize: 13,
                                fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                                height: 1.4,
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
                  if ((!widget.isDashboard || _isExpanded) && isUnread) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            context.read<NotificationProvider>().markAsRead(widget.notification.id);
                          },
                          icon: Icon(Icons.done_all_rounded, size: 14, color: alertColor),
                          label: Text(
                            "Mark as Seen",
                            style: TextStyle(
                              fontSize: 11, 
                              fontWeight: FontWeight.w800,
                              color: alertColor,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: alertColor.withOpacity(0.08),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 45) return "Just Now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return DateFormat('dd MMM').format(dt);
  }
}
