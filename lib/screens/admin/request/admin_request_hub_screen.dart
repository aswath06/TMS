import 'package:flutter/material.dart';
import 'package:tripzo/screens/admin/request/request_list_page.dart';
import 'package:tripzo/screens/admin/fuel/fuel_page.dart';
import 'package:tripzo/screens/admin/admin_allowance_screen.dart';
import 'dart:math' as math;

class AdminRequestHubScreen extends StatefulWidget {
  const AdminRequestHubScreen({super.key});

  @override
  State<AdminRequestHubScreen> createState() => _AdminRequestHubScreenState();
}

class _AdminRequestHubScreenState extends State<AdminRequestHubScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  late List<Map<String, dynamic>> _cardsData;
  bool _initialized = false;

  late AnimationController _swipeController;
  Animation<Offset>? _swipeAnimation;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _swipeController.addListener(() {
      if (_swipeAnimation != null) {
        setState(() {
          _dragOffset = _swipeAnimation!.value;
        });
      }
    });
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (!_initialized) {
      _initialized = true;
      final Color primaryBlue = const Color(0xFF6366F1);

      _cardsData = [
        {
          'id': 'mission',
          'title': "Missions",
          'description': "Track and manage transport missions in real-time.",
          'icon': Icons.explore_rounded,
          'color': primaryBlue,
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const RequestListPage()));
          },
        },
        {
          'id': 'routines',
          'title': "Daily Routines",
          'description': "Monitor campus bus routines and daily schedules.",
          'icon': Icons.directions_bus_rounded,
          'color': const Color(0xFF3B82F6),
          'onTap': () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bus Daily Routines screen coming soon')));
          },
        },
        {
          'id': 'fuels',
          'title': "Fuel Logs",
          'description': "Review fuel requests and vehicle consumption history.",
          'icon': Icons.local_gas_station_rounded,
          'color': const Color(0xFFF59E0B),
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const FuelPage()));
          },
        },
        {
          'id': 'allowance',
          'title': "Allowances",
          'description': "Approve driver allowances (DA/TA) for completed trips.",
          'icon': Icons.payments_rounded,
          'color': const Color(0xFF10B981),
          'onTap': () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAllowanceScreen()));
          },
        },
      ];
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (_swipeController.isAnimating) return;
    setState(() {
      _isDragging = true;
      _dragOffset = Offset.zero;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_swipeController.isAnimating) return;
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_swipeController.isAnimating) return;
    setState(() {
      _isDragging = false;
    });

    final velocity = details.velocity.pixelsPerSecond.dx;
    if (_dragOffset.dx.abs() > 120 || velocity.abs() > 800) {
      // Swipe out completely
      final targetX = _dragOffset.dx > 0 ? 500.0 : -500.0;
      final targetY = _dragOffset.dy + (velocity > 0 ? 100 : -100);
      
      _swipeAnimation = Tween<Offset>(begin: _dragOffset, end: Offset(targetX, targetY)).animate(
        CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
      );

      _swipeController.forward(from: 0).then((_) {
        // Animation finished, push to back
        setState(() {
          final item = _cardsData.removeAt(0);
          _cardsData.add(item);
          _dragOffset = Offset.zero;
          _swipeAnimation = null;
        });
        _swipeController.reset();
      });
    } else {
      // Snap back to center
      _swipeAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero).animate(
        CurvedAnimation(parent: _swipeController, curve: Curves.easeOutBack),
      );
      _swipeController.forward(from: 0).then((_) {
        setState(() {
          _dragOffset = Offset.zero;
          _swipeAnimation = null;
        });
        _swipeController.reset();
      });
    }
  }

  Widget _buildCardContent(Map<String, dynamic> cardData, bool isDark) {
    final Color itemColor = cardData['color'];

    return GestureDetector(
      onTap: cardData['onTap'],
      child: Container(
        height: 220,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: itemColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: itemColor.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: itemColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: itemColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(cardData['icon'], color: itemColor, size: 40),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cardData['title'],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    cardData['description'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStackedCards(bool isDark) {
    // Calculate a dynamic swipe progress (0.0 to 1.0) to drive background cards
    final double maxDrag = 150.0;
    double dragProgress = (_dragOffset.dx.abs() / maxDrag).clamp(0.0, 1.0);
    // If we are currently animating the swipe off screen, smoothly interpolate dragProgress up to 1.0
    if (_swipeController.isAnimating && _dragOffset.dx.abs() > 50) {
      dragProgress = math.max(dragProgress, _swipeController.value);
    }

    return SizedBox(
      height: 340,
      child: Stack(
        alignment: Alignment.topCenter,
        children: _cardsData.reversed.map((card) {
          int reversedIndex = _cardsData.indexOf(card);
          bool isFront = reversedIndex == 0;
          
          // Background cards smoothly move up and scale up based on the front card's drag progress!
          double effectiveIndex = reversedIndex.toDouble();
          if (!isFront) {
            effectiveIndex -= dragProgress;
          }

          final cardWidget = _buildCardContent(card, isDark);

          if (isFront) {
            // Front card follows the drag offset
            return Positioned(
              top: 0,
              left: 20 + _dragOffset.dx,
              right: 20 - _dragOffset.dx,
              child: Transform.translate(
                offset: Offset(0, _dragOffset.dy),
                child: Transform.rotate(
                  angle: _dragOffset.dx * 0.001, // Slight rotation while dragging
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: cardWidget,
                  ),
                ),
              ),
            );
          } else {
            // Background cards smoothly interpolate their state
            return Positioned(
              top: effectiveIndex * 35.0,
              left: 20,
              right: 20,
              child: Transform.scale(
                scale: 1.0 - (effectiveIndex * 0.06),
                alignment: Alignment.topCenter,
                child: Opacity(
                  opacity: (1.0 - (effectiveIndex * 0.15)).clamp(0.0, 1.0),
                  child: cardWidget,
                ),
              ),
            );
          }
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color primaryBlue, Color subColor, Color surface) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: "Search across requests...",
            hintStyle: TextStyle(
              color: subColor.withValues(alpha: 0.6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(Icons.search_rounded, color: primaryBlue, size: 22),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded, color: subColor, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.dashboard_rounded, color: primaryBlue, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          "Fleet Hub",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: titleColor,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryBlue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notifications_outlined, color: primaryBlue, size: 22),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "Manage missions, daily routines, fuels, and allowances.",
                  style: TextStyle(
                    color: subColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSearchBar(isDark, primaryBlue, subColor, surfaceColor),
              const SizedBox(height: 40),
              
              _buildStackedCards(isDark),
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
