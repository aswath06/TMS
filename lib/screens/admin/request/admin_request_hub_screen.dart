import 'package:flutter/material.dart';
import 'package:tripzo/screens/admin/request/request_list_page.dart';
import 'package:tripzo/screens/admin/fuel/fuel_page.dart';
import 'package:tripzo/screens/admin/admin_allowance_screen.dart';

class AdminRequestHubScreen extends StatefulWidget {
  const AdminRequestHubScreen({super.key});

  @override
  State<AdminRequestHubScreen> createState() => _AdminRequestHubScreenState();
}

class _AdminRequestHubScreenState extends State<AdminRequestHubScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _swipeCounter = 0; 

  late List<Map<String, dynamic>> _cardsData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    if (_swipeCounter == 0) {
      _cardsData = [
        {
          'id': 'mission',
          'title': "Missions",
          'description': "Track and manage transport missions in real-time.",
          'icon': Icons.explore_rounded,
          'gradient': const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          'shadowColor': const Color(0xFF6366F1),
          'onTap': () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RequestListPage()),
            );
          },
        },
        {
          'id': 'routines',
          'title': "Daily Routines",
          'description': "Monitor campus bus routines and daily schedules.",
          'icon': Icons.directions_bus_rounded,
          'gradient': const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          'shadowColor': const Color(0xFF3B82F6),
          'onTap': () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bus Daily Routines screen coming soon')),
            );
          },
        },
        {
          'id': 'fuels',
          'title': "Fuel Logs",
          'description': "Review fuel requests and vehicle consumption history.",
          'icon': Icons.local_gas_station_rounded,
          'gradient': const LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          'shadowColor': const Color(0xFFF59E0B),
          'onTap': () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FuelPage()),
            );
          },
        },
        {
          'id': 'allowance',
          'title': "Allowances",
          'description': "Approve driver allowances (DA/TA) for completed trips.",
          'icon': Icons.payments_rounded,
          'gradient': const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          'shadowColor': const Color(0xFF10B981),
          'onTap': () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AdminAllowanceScreen()),
            );
          },
        },
      ];
    }
  }

  void _onDismissed(DismissDirection direction) {
    setState(() {
      _swipeCounter++;
      final item = _cardsData.removeAt(0);
      _cardsData.add(item);
    });
  }

  Widget _buildCardContent(Map<String, dynamic> cardData, bool isDark) {
    return GestureDetector(
      onTap: cardData['onTap'],
      child: Container(
        width: MediaQuery.of(context).size.width - 48,
        height: 240,
        decoration: BoxDecoration(
          gradient: cardData['gradient'],
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: cardData['shadowColor'].withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              // Giant background watermark icon
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  cardData['icon'],
                  size: 160,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              // Glassmorphism overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(cardData['icon'], color: Colors.white, size: 36),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Row(
                            children: [
                              Text(
                                "Open",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 10),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cardData['title'],
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1.0,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cardData['description'],
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStackedCards(bool isDark) {
    return SizedBox(
      height: 280,
      child: Stack(
        alignment: Alignment.topCenter,
        children: List.generate(_cardsData.length, (index) {
          int reversedIndex = _cardsData.length - 1 - index;
          final card = _cardsData[reversedIndex];
          bool isFront = reversedIndex == 0;
          
          final cardWidget = _buildCardContent(card, isDark);

          if (isFront) {
            return Positioned(
              top: 0,
              child: Dismissible(
                key: ValueKey('${card['id']}_$_swipeCounter'),
                direction: DismissDirection.horizontal,
                onDismissed: _onDismissed,
                child: cardWidget,
              ),
            );
          } else {
            return AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              top: reversedIndex * 30.0, // Push down to peek out from the bottom
              child: AnimatedScale(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                scale: 1.0 - (reversedIndex * 0.05), // Make them narrower
                alignment: Alignment.topCenter, // Scale from top so they don't shift up
                child: Opacity(
                  opacity: 1.0 - (reversedIndex * 0.15),
                  child: cardWidget,
                ),
              ),
            );
          }
        }),
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
              
              // The Stacked Swipe Cards (Redesigned)
              _buildStackedCards(isDark),
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
