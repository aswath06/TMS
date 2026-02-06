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
    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 10, bottom: 12),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
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
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF7C3AED)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? items[index].activeIcon : items[index].icon,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF94A3B8),
                      size: 24,
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      Text(
                        items[index].label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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

  List<_NavItem> _facultyItems() => [
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.assignment_outlined, Icons.assignment_rounded, 'Requests'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  List<_NavItem> _driverItems() => [
    _NavItem(Icons.grid_view_outlined, Icons.grid_view_rounded, 'Home'),
    _NavItem(Icons.alt_route_outlined, Icons.alt_route_rounded, 'Routes'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  _NavItem(this.icon, this.activeIcon, this.label);
}
