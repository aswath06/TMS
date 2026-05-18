import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:tripzo/store/admin_allowance_store.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/screens/faculty/missions/mission_details_screen.dart';
import 'package:shimmer/shimmer.dart';

import 'package:tripzo/store/user_store.dart';

class AdminAllowanceScreen extends StatefulWidget {
  const AdminAllowanceScreen({super.key});

  @override
  State<AdminAllowanceScreen> createState() => _AdminAllowanceScreenState();
}

class _AdminAllowanceScreenState extends State<AdminAllowanceScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  int? _tempSelectedDriverId;
  DateTime? _tempSelectedDate;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      adminAllowanceStore.fetchDriversForFilter();
      adminAllowanceStore.fetchAllowances(isRefresh: true);
      adminAllowanceStore.fetchPendingAllowanceCreations();
      _loadUserRole();
    });
  }

  void _loadUserRole() async {
    final role = await UserStore.getRole();
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      if (!adminAllowanceStore.isLoadingAllowances && !adminAllowanceStore.isFetchingMoreAllowances && adminAllowanceStore.hasMoreAllowances) {
        adminAllowanceStore.fetchMoreAllowances();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    adminAllowanceStore.setFilters(search: query);
  }

  void _showFilterModal(BuildContext context) {
    _tempSelectedDriverId = null;
    _tempSelectedDate = null;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
            final Color surface = isDark ? const Color(0xFF1E293B) : Colors.white;
            final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final bool isTamil = LanguageStore.isTamil;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isTamil ? "வடிகட்டி" : "Filter Allowances",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor),
                    ),
                    const SizedBox(height: 24),

                    // Driver Dropdown
                    Text(
                      isTamil ? "ஓட்டுநரைத் தேர்ந்தெடுக்கவும்" : "Select Driver",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: titleColor.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 8),
                    Consumer<AdminAllowanceStore>(
                      builder: (context, store, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              hint: Text(isTamil ? "அனைத்து ஓட்டுநர்களும்" : "All Drivers"),
                              value: _tempSelectedDriverId,
                              dropdownColor: surface,
                              style: TextStyle(color: titleColor, fontSize: 16),
                              items: [
                                DropdownMenuItem(
                                  value: -1,
                                  child: Text(isTamil ? "அனைத்து ஓட்டுநர்களும்" : "All Drivers"),
                                ),
                                ...store.driversList.map((driver) {
                                  return DropdownMenuItem<int>(
                                    value: driver['id'],
                                    child: Text(driver['user']?['name'] ?? "Unknown"),
                                  );
                                }).toList(),
                              ],
                              onChanged: (val) {
                                setModalState(() {
                                  _tempSelectedDriverId = val;
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Date Picker
                    Text(
                      isTamil ? "தேதியைத் தேர்ந்தெடுக்கவும்" : "Select Date",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: titleColor.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _tempSelectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (pickedDate != null) {
                          setModalState(() {
                            _tempSelectedDate = pickedDate;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _tempSelectedDate == null
                                  ? (isTamil ? "எந்த தேதியும் இல்லை" : "Any Date")
                                  : DateFormat('yyyy-MM-dd').format(_tempSelectedDate!),
                              style: TextStyle(color: titleColor, fontSize: 16),
                            ),
                            const Icon(Icons.calendar_today_rounded, color: Colors.grey, size: 20),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              adminAllowanceStore.setFilters(driverId: -1, date: "clear");
                              Navigator.pop(ctx);
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              isTamil ? "அழிக்க" : "Clear All",
                              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              adminAllowanceStore.setFilters(
                                driverId: _tempSelectedDriverId,
                                date: _tempSelectedDate != null ? DateFormat('yyyy-MM-dd').format(_tempSelectedDate!) : null,
                              );
                              Navigator.pop(ctx);
                            },
                            child: Text(
                              isTamil ? "விண்ணப்பிக்கவும்" : "Apply",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color primaryBlue = const Color(0xFF6366F1);
    final bool isTamil = LanguageStore.isTamil;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isTamil ? "அனைத்து படிகள்" : "All Allowances",
          style: TextStyle(fontWeight: FontWeight.w900, color: titleColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: primaryBlue),
            onPressed: () => _showFilterModal(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(color: titleColor),
                decoration: InputDecoration(
                  hintText: isTamil ? "தேடுக..." : "Search allowances...",
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          Expanded(
            child: Consumer<AdminAllowanceStore>(
              builder: (context, store, _) {
                if (store.isLoadingAllowances && store.allowances.isEmpty) {
                  return _buildSkeletonLoading(isDark);
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      store.fetchAllowances(isRefresh: true),
                      store.fetchPendingAllowanceCreations(),
                    ]);
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      if (store.pendingCreations.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _buildPendingCreationsSection(
                            store.pendingCreations,
                            isDark,
                            isTamil,
                            primaryBlue,
                          ),
                        ),
                      if (store.allowances.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: _buildEmptyState(isTamil, isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return _buildAllowanceCard(store.allowances[index], isDark, isTamil, primaryBlue, titleColor, index);
                              },
                              childCount: store.allowances.length,
                            ),
                          ),
                        ),
                      if (store.isFetchingMoreAllowances)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isTamil, Color subColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.payments_outlined, size: 64, color: subColor.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            isTamil ? "எந்த படிகளும் கிடைக்கவில்லை" : "No allowances found",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: subColor),
          ),
          const SizedBox(height: 8),
          Text(
            isTamil ? "பட்டியல் காலியாக உள்ளது" : "Try adjusting your filters",
            style: TextStyle(fontSize: 14, color: subColor.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading(bool isDark) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllowanceCard(Map<String, dynamic> item, bool isDark, bool isTamil, Color primaryBlue, Color titleColor, int index) {
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final String amount = item['amount']?.toString() ?? '0.00';
    final String status = item['payment_status'] ?? 'UNKNOWN';
    final String dateStr = item['createdAt'] ?? '';
    final String allowanceReason = item['reason'] ?? '';
    final String paymentMode = item['payment_mode'] ?? 'N/A';

    final driverInfo = item['driver'];
    final userInfo = driverInfo?['user'];
    final driverName = userInfo?['name'] ?? 'Unknown Driver';

    final tripInstance = item['tripInstance'];
    final routeRequest = tripInstance?['routeRequest'];
    final String routeName = routeRequest != null ? (routeRequest['route_name'] ?? 'Unknown Route') : 'N/A';

    final creatorInfo = item['createdBy'];
    final String createdBy = creatorInfo?['name'] ?? 'Unknown Admin';

    String formattedDate = '';
    if (dateStr.isNotEmpty) {
      try {
        final parsedDate = DateTime.parse(dateStr).toLocal();
        formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(parsedDate);
      } catch (e) {
        formattedDate = dateStr;
      }
    }

    final List<dynamic>? typeItems = item['typeItems'];
    List<String> typesList = [];
    if (typeItems != null && typeItems.isNotEmpty) {
      for (var typeItem in typeItems) {
        final allowanceType = typeItem['allowanceType'];
        if (allowanceType != null && allowanceType['name'] != null) {
          typesList.add(allowanceType['name'].toString());
        }
      }
    }

    if (typesList.isEmpty) {
      final dynamic allowanceTypeRaw = item['allowance_type'];
      if (allowanceTypeRaw is String && allowanceTypeRaw.isNotEmpty) {
        typesList = allowanceTypeRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } else if (allowanceTypeRaw is List) {
        typesList = allowanceTypeRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
    }

    final String? endedAtStr = tripInstance?['ended_at'];
    String formattedEndedAt = '';
    if (endedAtStr != null && endedAtStr.isNotEmpty) {
      try {
        final parsedDate = DateTime.parse(endedAtStr).toLocal();
        formattedEndedAt = DateFormat('MMM dd, yyyy • hh:mm a').format(parsedDate);
      } catch (_) {}
    }

    Color statusColor;
    IconData statusIcon;
    switch (status.toUpperCase()) {
      case 'SEEN':
      case 'RECEIVED':
        statusColor = const Color(0xFF10B981); // Emerald
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'ASSIGNED':
      case 'PENDING':
        statusColor = const Color(0xFFF59E0B); // Amber
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'RECHECK_REQUESTED':
        statusColor = Colors.red;
        statusIcon = Icons.report_problem_rounded;
        break;
      default:
        statusColor = primaryBlue;
        statusIcon = Icons.info_rounded;
    }

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 100).clamp(0, 500)),
      curve: Curves.easeOutQuart,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "₹$amount",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: primaryBlue,
                    ),
                  ),
                ],
              ),
              if (typesList.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: typesList.map((type) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryBlue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primaryBlue.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Icon(Icons.person_rounded, size: 16, color: subColor),
                  const SizedBox(width: 6),
                  Text(
                    driverName,
                    style: TextStyle(fontSize: 14, color: titleColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: subColor),
                  const SizedBox(width: 6),
                  Text(
                    formattedDate,
                    style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (formattedEndedAt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.timer_off_outlined, size: 14, color: subColor),
                    const SizedBox(width: 6),
                    Text(
                      "${isTamil ? 'முடிந்த நேரம்' : 'Ended'}: $formattedEndedAt",
                      style: TextStyle(fontSize: 12, color: subColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 12),
              Text(
                routeName,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: titleColor),
              ),
              if (allowanceReason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_rounded, size: 16, color: subColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        allowanceReason,
                        style: TextStyle(fontSize: 13, color: titleColor.withOpacity(0.8), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.payment_rounded, size: 16, color: subColor),
                  const SizedBox(width: 6),
                  Text(
                    "${isTamil ? 'பணம் செலுத்தும் முறை' : 'Mode'}: $paymentMode",
                    style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (routeRequest != null && routeRequest['id'] != null)
                    GestureDetector(
                      onTap: () {
                        // Navigate to Mission Details
                        String timeStr = "TBD";
                        if (routeRequest['legs'] != null && routeRequest['legs'].isNotEmpty) {
                          final firstLeg = routeRequest['legs'][0];
                          if (firstLeg['planned_start_at'] != null) {
                            try {
                              final dt = DateTime.parse(firstLeg['planned_start_at']).toLocal();
                              timeStr = DateFormat('hh:mm a').format(dt);
                            } catch (_) {}
                          }
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MissionDetailsScreen(
                              missionTitle: routeName,
                              time: timeStr,
                              driverName: driverName,
                              driverPhone: "",
                              vehicleInfo: "Assigned Vehicle",
                              capacity: "0",
                              pathType: routeRequest['trip_type'] ?? "ONE_WAY",
                              status: routeRequest['status'] ?? "UNKNOWN",
                              statusColor: primaryBlue,
                              requestId: routeRequest['id'].toString(),
                              creatorName: createdBy,
                              rawStatus: 8,
                              stops: const [],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isTamil ? 'விவரம்' : 'Details',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingCreationsSection(
    List<Map<String, dynamic>> items,
    bool isDark,
    bool isTamil,
    Color primaryColor,
  ) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(
                Icons.pending_actions_outlined,
                color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isTamil ? "படி உருவாக்க வேண்டியவை" : "Pending Allowance Creation",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706)).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${items.length}",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 142,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              
              // Extract fields safely
              final routeRequest = item['routeRequest'] ?? {};
              final routeName = routeRequest['route_name'] ?? (isTamil ? 'தெரியவில்லை' : 'Unknown');
              
              String driverName = isTamil ? 'தெரியவில்லை' : 'Unknown';
              String vehicleNumber = isTamil ? 'தெரியவில்லை' : 'Unknown';
              
              final tripLegs = item['tripLegs'] as List<dynamic>?;
              if (tripLegs != null && tripLegs.isNotEmpty) {
                final assignments = tripLegs[0]['assignments'] as List<dynamic>?;
                if (assignments != null && assignments.isNotEmpty) {
                  final driver = assignments[0]['driver'];
                  if (driver != null) {
                    driverName = driver['user']?['name'] ?? driverName;
                  }
                  final vehicle = assignments[0]['vehicle'];
                  if (vehicle != null) {
                    vehicleNumber = vehicle['vehicle_number'] ?? vehicleNumber;
                  }
                }
              }

              // Extract actual end trip time
              final endedAtStr = item['ended_at'];
              String formattedEndTime = isTamil ? 'தெரியவில்லை' : 'Unknown';
              if (endedAtStr != null) {
                try {
                  final endedAt = DateTime.parse(endedAtStr).toLocal();
                  formattedEndTime = DateFormat('dd MMM yyyy, hh:mm a').format(endedAt);
                } catch (_) {}
              }

              return GestureDetector(
                onTap: () {
                  String timeStr = "TBD";
                  if (tripLegs != null && tripLegs.isNotEmpty) {
                    final firstLeg = tripLegs[0];
                    if (firstLeg['planned_start_at'] != null) {
                      try {
                        final dt = DateTime.parse(firstLeg['planned_start_at']).toLocal();
                        timeStr = DateFormat('hh:mm a').format(dt);
                      } catch (_) {}
                    }
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MissionDetailsScreen(
                        missionTitle: routeName,
                        time: timeStr,
                        driverName: driverName,
                        driverPhone: "",
                        vehicleInfo: vehicleNumber,
                        capacity: "0",
                        pathType: routeRequest['trip_type'] ?? "ONE_WAY",
                        status: item['status'] ?? "UNKNOWN",
                        statusColor: Colors.orange,
                        requestId: routeRequest['id']?.toString() ?? "",
                        creatorName: "Transport Department",
                        rawStatus: 8,
                        stops: const [],
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 280,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706)).withOpacity(0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              routeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: titleColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isTamil ? "நிலுவையில்" : "Pending",
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: subColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "${isTamil ? 'ஓட்டுநர்' : 'Driver'}: $driverName",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: subColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.directions_bus_outlined, size: 14, color: subColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "${isTamil ? 'வாகனம்' : 'Vehicle'}: $vehicleNumber",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: subColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: subColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              formattedEndTime,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: subColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
