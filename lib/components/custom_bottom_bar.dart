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
    final bool isFaculty = userRole == 'faculty';
    final List<_NavItem> items = isFaculty ? _facultyItems() : _driverItems();

    const Color brandColor = Color(0xFF4F46E5);
    const Color grayText = Color(0xFF94A3B8);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.08),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? brandColor.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? items[index].activeIcon : items[index].icon,
                      color: isSelected ? brandColor : grayText,
                      size: 26,
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 10),
                      Text(
                        items[index].label,
                        style: const TextStyle(
                          color: brandColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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

  // --- Updated Faculty Items Order ---
  List<_NavItem> _facultyItems() => [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.explore_outlined, Icons.explore_rounded, 'Missions'),
    _NavItem(Icons.assignment_outlined, Icons.assignment_rounded, 'Requests'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  List<_NavItem> _driverItems() => [
    _NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Home'),
    _NavItem(Icons.alt_route_outlined, Icons.alt_route_rounded, 'Routes'),
    _NavItem(
      Icons.calendar_month_outlined,
      Icons.calendar_month_rounded,
      'Schedule',
    ),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  _NavItem(this.icon, this.activeIcon, this.label);
}
