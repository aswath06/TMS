import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import '../../providers/notification_provider.dart';
import '../../components/notification_card.dart';

class NotificationListScreen extends ConsumerStatefulWidget {
  const NotificationListScreen({super.key});

  @override
  ConsumerState<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends ConsumerState<NotificationListScreen> {
  String _activeFilter = 'All'; // 'All', 'Unread', 'Alerts'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProviderFamily).fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, titleColor, primaryBlue),
                const SizedBox(height: 16),
                _buildFilterChips(primaryBlue, cardBgColor, titleColor, subColor),
                const SizedBox(height: 12),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final provider = ref.watch(notificationProviderFamily);
                      if (provider.isLoading && provider.notifications.isEmpty) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: primaryBlue,
                            strokeWidth: 3,
                          ),
                        );
                      }

                      final filteredList = provider.notifications.where((n) {
                        if (_activeFilter == 'Unread') {
                          return !n.isRead;
                        } else if (_activeFilter == 'Alerts') {
                          return n.type == 'ERROR' || n.type == 'WARNING';
                        }
                        return true;
                      }).toList();

                      if (filteredList.isEmpty) {
                        return _buildEmptyState(isDark, titleColor, subColor, primaryBlue);
                      }

                      return RefreshIndicator(
                        color: primaryBlue,
                        backgroundColor: cardBgColor,
                        onRefresh: () => provider.fetchNotifications(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            return NotificationCard(
                              notification: filteredList[index],
                              isDashboard: false,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color titleColor, Color primaryBlue) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: titleColor.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: titleColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "INBOX",
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900,
                      color: primaryBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Notifications",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Consumer(
            builder: (context, ref, _) {
              final provider = ref.watch(notificationProviderFamily);
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showMarkAllConfirmation(context, primaryBlue),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryBlue.withOpacity(0.2), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded, size: 16, color: primaryBlue),
                      const SizedBox(width: 8),
                      Text(
                        "Mark seen",
                        style: TextStyle(
                          color: primaryBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(Color primaryBlue, Color cardBg, Color titleColor, Color subColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: ['All', 'Unread', 'Alerts'].map((filter) {
          bool isActive = _activeFilter == filter;
          return Consumer(
            builder: (context, ref, _) {
              final provider = ref.watch(notificationProviderFamily);
              int count = 0;
              if (filter == 'All') {
                count = provider.notifications.length;
              } else if (filter == 'Unread') {
                count = provider.unreadCount;
              } else {
                count = provider.notifications.where((n) => n.type == 'ERROR' || n.type == 'WARNING').length;
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _activeFilter = filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive ? primaryBlue : cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isActive ? primaryBlue : titleColor.withOpacity(0.08),
                        width: 1.5,
                      ),
                      boxShadow: isActive ? [
                        BoxShadow(
                          color: primaryBlue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ] : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          filter,
                          style: TextStyle(
                            color: isActive ? Colors.white : subColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.white.withOpacity(0.25) : primaryBlue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "$count",
                              style: TextStyle(
                                color: isActive ? Colors.white : primaryBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  void _showMarkAllConfirmation(BuildContext context, Color primaryBlue) {
    final provider = ref.read(notificationProviderFamily);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Icon(Icons.mark_email_read_rounded, color: primaryBlue, size: 28),
            const SizedBox(width: 12),
            const Text("Mark all as read?", style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: const Text(
          "Are you sure you want to clear your notifications unread badges? This will mark all of them as seen.",
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              provider.markAllAsRead();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text("Confirm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color titleColor, Color subColor, Color primaryBlue) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(color: primaryBlue.withOpacity(0.1), width: 2),
              ),
              child: Icon(
                _activeFilter == 'Alerts' ? Icons.notification_important_rounded : Icons.notifications_none_rounded,
                size: 84,
                color: primaryBlue.withOpacity(0.35),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No ${_activeFilter.toLowerCase()} notifications",
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                _activeFilter == 'All'
                    ? "Your notifications inbox is completely empty. When you receive updates on routes or assignments, they will appear here."
                    : "No notifications fit the selected filter category.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundDecor(bool isDark) => Positioned.fill(
    child: Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: CircleAvatar(
            radius: 200,
            backgroundColor: const Color(0xFF6366F1).withOpacity(isDark ? 0.08 : 0.04),
          ),
        ),
        Positioned(
          bottom: -50,
          left: -100,
          child: CircleAvatar(
            radius: 150,
            backgroundColor: const Color(0xFFEC4899).withOpacity(isDark ? 0.06 : 0.03),
          ),
        ),
      ],
    ),
  );
}
