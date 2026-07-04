import 'package:flutter/material.dart';
import 'package:tripzo/screens/admin/request/request_list_page.dart';
import 'package:tripzo/screens/admin/request/daily_routines_page.dart';
import 'package:tripzo/screens/admin/fuel/fuel_page.dart';
import 'package:tripzo/screens/admin/admin_allowance_screen.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/store/ui_config.dart';

class AdminRequestHubScreen extends ConsumerStatefulWidget {
  const AdminRequestHubScreen({super.key});

  @override
  ConsumerState<AdminRequestHubScreen> createState() => _AdminRequestHubScreenState();
}

class _AdminRequestHubScreenState extends ConsumerState<AdminRequestHubScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _activeVehicleFilter = 'Total'; // 'Total', 'Student', 'Faculty'

  late List<Map<String, dynamic>> _cardsData;
  bool _initialized = false;

  late AnimationController _swipeController;
  late AnimationController _reEntryController;
  Animation<Offset>? _swipeAnimation;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fleetMonitorStoreProvider).fetchFleetData();
      ref.read(driverStoreProvider).fetchPendingFuelEntries();
      ref.read(adminAllowanceStoreProvider).fetchPendingAllowanceCreations();
      UIConfig().load();
    });
    _swipeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _swipeController.addListener(() {
      if (_swipeAnimation != null) {
        setState(() {
          _dragOffset = _swipeAnimation!.value;
        });
      }
    });

    _reEntryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _reEntryController.addListener(() {
      setState(() {});
    });

    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) return;

    // Find the first card matching the search query
    int matchIndex = _cardsData.indexWhere((card) {
      final title = card['title'].toString().toLowerCase();
      final desc = card['description'].toString().toLowerCase();
      return title.contains(query) || desc.contains(query);
    });

    // If we found a match and it's not already at the front, move it to the front
    if (matchIndex > 0) {
      setState(() {
        final item = _cardsData.removeAt(matchIndex);
        _cardsData.insert(0, item);
      });
    }
  }

  @override
  void dispose() {
    _swipeController.dispose();
    _reEntryController.dispose();
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
            Navigator.push(context, MaterialPageRoute(builder: (context) => const DailyRoutinesListPage()));
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
      
      // Dynamic duration based on velocity for smoother fast swipes
      int durationMs = 300;
      if (velocity.abs() > 100) {
        final distanceRemaining = 500.0 - _dragOffset.dx.abs();
        durationMs = (distanceRemaining / velocity.abs() * 1000).toInt().clamp(100, 350);
      }
      _swipeController.duration = Duration(milliseconds: durationMs);

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
        
        // Trigger the smooth re-entry animation for the card added to the back
        _reEntryController.duration = Duration(milliseconds: durationMs + 100); // Match re-entry speed
        _reEntryController.forward(from: 0);
      });
    } else {
      // Snap back to center
      _swipeController.duration = const Duration(milliseconds: 300);
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

  Widget _buildCountBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        "$count $label",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCardContent(Map<String, dynamic> cardData, bool isDark, double cardHeight) {
    final Color itemColor = cardData['color'];
    final String id = cardData['id'];

    Widget? extraWidget;
    if (id == 'mission' || id == 'routines') {
      final fleetStore = ref.watch(fleetMonitorStoreProvider);
      extraWidget = Row(
        children: [
          _buildCountBadge("Running", fleetStore.outsideCount, const Color(0xFF10B981)),
          const SizedBox(width: 8),
          _buildCountBadge("Ready to start", fleetStore.insideCount, const Color(0xFF3B82F6)),
        ],
      );
    } else if (id == 'fuels') {
      final driverStore = ref.watch(driverStoreProvider);
      extraWidget = _buildCountBadge("Fuel Pendings", driverStore.pendingFuelEntries.length, const Color(0xFFF59E0B));
    } else if (id == 'allowance') {
      final allowanceStore = ref.watch(adminAllowanceStoreProvider);
      extraWidget = _buildCountBadge("Allowance Count", allowanceStore.pendingCreations.length, const Color(0xFF8B5CF6));
    }

    return GestureDetector(
      onTap: cardData['onTap'],
      child: Container(
        height: cardHeight,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
              child: Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cardData['title'],
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cardData['description'],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          height: 1.4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 2,
                      ),
                      if (extraWidget != null) ...[
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: extraWidget,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStackedCards(bool isDark) {
    final double screenHeight = MediaQuery.of(context).size.height;
    // Decrease card size slightly and make it responsive
    final double cardHeight = (screenHeight * 0.18).clamp(160.0, 190.0);
    final double stackHeight = cardHeight + 110.0;

    // Calculate a dynamic swipe progress (0.0 to 1.0) to drive background cards
    final double maxDrag = 150.0;
    double dragProgress = (_dragOffset.dx.abs() / maxDrag).clamp(0.0, 1.0);
    // If we are currently animating the swipe off screen, smoothly interpolate dragProgress up to 1.0
    if (_swipeController.isAnimating && _dragOffset.dx.abs() > 50) {
      dragProgress = math.max(dragProgress, _swipeController.value);
    }

    return SizedBox(
      height: stackHeight,
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

          final cardWidget = _buildCardContent(card, isDark, cardHeight);

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
            double topPos = effectiveIndex * 35.0;
            double effectiveOpacity = (1.0 - (effectiveIndex * 0.15)).clamp(0.0, 1.0);
            double effectiveScale = 1.0 - (effectiveIndex * 0.06);

            // Animate re-entry if this is the card just added to the back
            if (reversedIndex == _cardsData.length - 1 && _reEntryController.isAnimating) {
              final entryProgress = Curves.easeOutCubic.transform(_reEntryController.value);
              effectiveOpacity *= entryProgress;
              topPos += 30.0 * (1.0 - entryProgress);
              effectiveScale *= (0.95 + 0.05 * entryProgress);
            }

            return Positioned(
              top: topPos,
              left: 20,
              right: 20,
              child: Transform.scale(
                scale: effectiveScale,
                alignment: Alignment.topCenter,
                child: Opacity(
                  opacity: effectiveOpacity,
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
              
              ListenableBuilder(
                listenable: UIConfig(),
                builder: (context, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UIConfig().isUIEnhancementEnabled
                          ? _buildStackedCards(isDark)
                          : _buildAlternativeCards(isDark, primaryBlue),
                      
                      if (UIConfig().isUIEnhancementEnabled) ...[
                        const SizedBox(height: 24),
                        _buildDynamicCardDetails(isDark, primaryBlue),
                      ],
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlternativeCards(bool isDark, Color primaryBlue) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              _buildAlternativeCardItem(_cardsData[0], isDark, 0),
              const SizedBox(width: 15),
              _buildAlternativeCardItem(_cardsData[1], isDark, 1),
              const SizedBox(width: 15),
              _buildAlternativeCardItem(_cardsData[2], isDark, 2),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildAlternativeCardItem(_cardsData[3], isDark, 3),
              const SizedBox(width: 15),
              Expanded(child: const SizedBox()),
              const SizedBox(width: 15),
              Expanded(child: const SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativeCardItem(Map<String, dynamic> cardData, bool isDark, int index) {
    final Color itemColor = cardData['color'];
    final Color surface = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Expanded(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 400 + (index * 150)),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: InkWell(
          onTap: cardData['onTap'],
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: itemColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(cardData['icon'], color: itemColor, size: 32),
                ),
                const SizedBox(height: 14),
                Text(
                  cardData['title'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicCardDetails(bool isDark, Color primaryBlue) {
    if (_cardsData.isEmpty) return const SizedBox.shrink();
    
    final String activeId = _cardsData.first['id'];
    
    return TweenAnimationBuilder<double>(
      key: ValueKey(activeId),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 15 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Consumer(
        builder: (context, ref, _) {
          switch (activeId) {
            case 'mission':
              return _buildMissionStats(isDark, primaryBlue);
            case 'routines':
              return _buildRoutineStats(isDark, primaryBlue);
            case 'fuels':
              return _buildFuelStats(isDark, primaryBlue);
            case 'allowance':
              return _buildAllowanceStats(isDark, primaryBlue);
            default:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget _buildPaginatedStats(List<Widget> tiles, bool isDark) {
    List<Widget> pages = [];
    for (int i = 0; i < tiles.length; i += 2) {
      pages.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: tiles[i]),
            if (i + 1 < tiles.length) const SizedBox(width: 16),
            if (i + 1 < tiles.length) Expanded(child: tiles[i + 1])
            else Expanded(child: const SizedBox()),
          ],
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: PageView(
        physics: const BouncingScrollPhysics(),
        children: pages.map((page) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: page,
        )).toList(),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color, bool isDark) {
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark, {bool hasPagination = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          if (hasPagination)
            Row(
              children: [
                Icon(Icons.swipe_left_rounded, size: 16, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                const SizedBox(width: 4),
                Text("Swipe", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[400], fontWeight: FontWeight.bold)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMissionStats(bool isDark, Color primaryBlue) {
    final tiles = [
      _buildStatTile("Completed", "142", Icons.check_circle_rounded, const Color(0xFF10B981), isDark),
      _buildStatTile("Pending", "12", Icons.pending_actions_rounded, const Color(0xFFF59E0B), isDark),
      _buildStatTile("Ready to Start", "5", Icons.play_circle_fill_rounded, primaryBlue, isDark),
      _buildStatTile("Outcampus", "3", Icons.exit_to_app_rounded, const Color(0xFFEF4444), isDark),
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Mission Statistics", isDark, hasPagination: true),
        const SizedBox(height: 8),
        _buildPaginatedStats(tiles, isDark),
      ],
    );
  }

  Widget _buildRoutineStats(bool isDark, Color primaryBlue) {
    final tiles = [
      _buildStatTile("Total Bus", "45", Icons.directions_bus_rounded, primaryBlue, isDark),
      _buildStatTile("Running", "4", Icons.speed_rounded, const Color(0xFFEF4444), isDark),
      _buildStatTile("In Service", "42", Icons.build_circle_rounded, const Color(0xFF10B981), isDark),
    ];

    // Dummy Vehicles Data (with student and faculty stats mapped)
    final List<Map<String, String>> vehicles = List.generate(5, (index) => {
      "veh": "TN36Z123$index",
      "fn": "${50 + index * 5}",
      "an": "${45 + index * 5}",
      "fac_fn": "${10 + index * 2}",
      "fac_an": "${8 + index * 2}"
    });

    int totalFn = 0;
    int totalAn = 0;
    int totalFacFn = 0;
    int totalFacAn = 0;
    for (var v in vehicles) {
      totalFn += int.parse(v['fn']!);
      totalAn += int.parse(v['an']!);
      totalFacFn += int.parse(v['fac_fn']!);
      totalFacAn += int.parse(v['fac_an']!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Daily Bus Routines", isDark, hasPagination: true),
        const SizedBox(height: 8),
        _buildPaginatedStats(tiles, isDark),
        const SizedBox(height: 16),
        
        // Student Sessions Section
        _buildSectionHeader("Student Sessions", isDark),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildSessionSummaryCard(
                  "Total", "${totalFn + totalAn}", Icons.groups_rounded, primaryBlue, isDark
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSessionSummaryCard(
                  "FN", "$totalFn", Icons.wb_sunny_rounded, const Color(0xFF10B981), isDark
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSessionSummaryCard(
                  "AN", "$totalAn", Icons.nights_stay_rounded, const Color(0xFFF59E0B), isDark
                ),
              ),
            ],
          ),
        ),

        // Faculty Sessions Section (Matches student session cards format exactly)
        _buildSectionHeader("Faculty Sessions", isDark),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildSessionSummaryCard(
                  "Total", "${totalFacFn + totalFacAn}", Icons.groups_rounded, primaryBlue, isDark
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSessionSummaryCard(
                  "FN", "$totalFacFn", Icons.wb_sunny_rounded, const Color(0xFF10B981), isDark
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSessionSummaryCard(
                  "AN", "$totalFacAn", Icons.nights_stay_rounded, const Color(0xFFF59E0B), isDark
                ),
              ),
            ],
          ),
        ),
        
        // Vehicle Assignment Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            children: [
              // Vehicle List Header with Role Filter Toggle
              Row(
                children: [
                  Text("Vehicle Assignment", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : Colors.black)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildRoleFilterSegment("Total", isDark, primaryBlue),
                        _buildRoleFilterSegment("Student", isDark, primaryBlue),
                        _buildRoleFilterSegment("Faculty", isDark, primaryBlue),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Vehicle List Cards (dynamic badges based on role selection filter)
              ...vehicles.map((v) {
                String fnCount = "";
                String anCount = "";
                if (_activeVehicleFilter == 'Student') {
                  fnCount = v['fn']!;
                  anCount = v['an']!;
                } else if (_activeVehicleFilter == 'Faculty') {
                  fnCount = v['fac_fn']!;
                  anCount = v['fac_an']!;
                } else {
                  fnCount = "${int.parse(v['fn']!) + int.parse(v['fac_fn']!)}";
                  anCount = "${int.parse(v['an']!) + int.parse(v['fac_an']!)}";
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.directions_bus_filled_rounded, size: 20, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v['veh']!, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                            const SizedBox(height: 4),
                            Text("Active Route", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.grey[500] : Colors.grey[500])),
                          ],
                        ),
                      ),
                      _buildSessionBadge("FN", fnCount, const Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      _buildSessionBadge("AN", anCount, const Color(0xFFF59E0B)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionSummaryCard(String title, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 2),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildSessionBadge(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$label ", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          Text(count, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildRoleFilterSegment(String role, bool isDark, Color primaryBlue) {
    final bool isSelected = _activeVehicleFilter == role;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeVehicleFilter = role;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? primaryBlue : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected && !isDark
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))]
              : [],
        ),
        child: Text(
          role,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isSelected
                ? (isDark ? Colors.white : primaryBlue)
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  Widget _buildFuelStats(bool isDark, Color primaryBlue) {
    final tiles = [
      _buildStatTile("Fuel Count", "128", Icons.local_gas_station_rounded, const Color(0xFFF59E0B), isDark),
      _buildStatTile("Total Liters", "4,520 L", Icons.water_drop_rounded, primaryBlue, isDark),
      _buildStatTile("Total Amount", "₹4,25,000", Icons.currency_rupee_rounded, const Color(0xFF10B981), isDark),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Fuel Overview", isDark, hasPagination: true),
        const SizedBox(height: 8),
        _buildPaginatedStats(tiles, isDark),
      ],
    );
  }

  Widget _buildAllowanceStats(bool isDark, Color primaryBlue) {
    final tiles = [
      _buildStatTile("Allowances", "85", Icons.payments_rounded, primaryBlue, isDark),
      _buildStatTile("Total Amount", "₹12,400", Icons.account_balance_wallet_rounded, const Color(0xFF10B981), isDark),
      _buildStatTile("Pending", "12", Icons.pending_rounded, const Color(0xFFF59E0B), isDark),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Allowance Overview", isDark, hasPagination: true),
        const SizedBox(height: 8),
        _buildPaginatedStats(tiles, isDark),
      ],
    );
  }
}
