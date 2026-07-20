import 'package:flutter/material.dart';

class CustomBottomBar extends StatelessWidget {
  final int currentIndex;
  final String userRole;
  final Function(int) onTap;

  const CustomBottomBar({
    super.key,
    required this.currentIndex,
    required this.userRole,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine which items to show based on the role
    final List<_NavItem> items = _getNavItems();

    const Color brandColor = Color(0xFF4F46E5);
    const Color grayText = Color(0xFF94A3B8);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final double systemBottom = MediaQuery.of(context).padding.bottom;
    final double finalBottom = systemBottom > 0 ? systemBottom + 8 : 24;

    return Container(
      padding: EdgeInsets.fromLTRB(
        items.length > 4 ? 12 : 20,
        0,
        items.length > 4 ? 12 : 20,
        finalBottom,
      ),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(items.length, (index) {
            final bool isSelected = currentIndex == index;
            return GestureDetector(
              onTap: () => onTap(index),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.fastOutSlowIn,
                padding: EdgeInsets.symmetric(
                  horizontal: items.length > 4 ? 12 : 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? brandColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? items[index].activeIcon : items[index].icon,
                      color: isSelected ? brandColor : grayText,
                      size: items.length > 4 ? 24 : 26,
                    ),
                    if (isSelected) ...[
                      SizedBox(width: items.length > 4 ? 6 : 10),
                      Text(
                        items[index].label,
                        style: TextStyle(
                          color: brandColor,
                          fontWeight: FontWeight.bold,
                          fontSize: items.length > 4 ? 12 : 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  List<_NavItem> _getNavItems() {
    switch (userRole.toLowerCase()) {
      case 'transport admin':
      case 'super admin':
        return [
          _NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Home'),
          _NavItem(
            Icons.assignment_outlined,
            Icons.assignment_rounded,
            'Requests',
          ),
          _NavItem(
            Icons.local_shipping_outlined,
            Icons.local_shipping_rounded,
            'Vehicle',
          ),
          _NavItem(
            Icons.people_outline_rounded,
            Icons.people_rounded,
            'Driver',
          ),
          _NavItem(
            Icons.forum_outlined,
            Icons.forum_rounded,
            'Chat',
          ),
        ];
      case 'faculty':
      case 'non teaching':
      case 'intern':
        return [
          _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
          _NavItem(Icons.explore_outlined, Icons.explore_rounded, 'Missions'),
          _NavItem(
            Icons.directions_bus_outlined,
            Icons.directions_bus_rounded,
            'Bus',
          ),
          _NavItem(
            Icons.event_busy_outlined,
            Icons.event_busy_rounded,
            'Leave',
          ),
          _NavItem(
            Icons.forum_outlined,
            Icons.forum_rounded,
            'Chat',
          ),
        ];
      case 'security':
        return [
          _NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Dashboard'),
          _NavItem(
            Icons.directions_car_outlined,
            Icons.directions_car_rounded,
            'Car',
          ),
          _NavItem(
            Icons.directions_bus_outlined,
            Icons.directions_bus_rounded,
            'Bus',
          ),
          _NavItem(
            Icons.forum_outlined,
            Icons.forum_rounded,
            'Chat',
          ),
        ];
      case 'student':
        return [
          _NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Dashboard'),
          _NavItem(Icons.directions_bus_outlined, Icons.directions_bus_rounded, 'Bus'),
          _NavItem(Icons.event_busy_outlined, Icons.event_busy_rounded, 'Leave'),
          _NavItem(Icons.forum_outlined, Icons.forum_rounded, 'Chat'),
        ];
      case 'driver':
      default:
        return [
          _NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Home'),
          _NavItem(Icons.alt_route_outlined, Icons.alt_route_rounded, 'Routes'),
          _NavItem(
            Icons.calendar_month_outlined,
            Icons.calendar_month_rounded,
            'Schedule',
          ),
          _NavItem(
            Icons.forum_outlined,
            Icons.forum_rounded,
            'Chat',
          ),
        ];
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  _NavItem(this.icon, this.activeIcon, this.label);
}
