import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:intl/intl.dart';
import 'package:tripzo/screens/faculty/missions/mission_details_screen.dart';
import 'package:shimmer/shimmer.dart';

class DriverAllowanceScreen extends StatefulWidget {
  const DriverAllowanceScreen({super.key});

  @override
  State<DriverAllowanceScreen> createState() => _DriverAllowanceScreenState();
}

class _DriverAllowanceScreenState extends State<DriverAllowanceScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      useDriverStore.fetchAllowances(isRefresh: true);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      if (!useDriverStore.isLoadingAllowances && !useDriverStore.isFetchingMoreAllowances && useDriverStore.hasMoreAllowances) {
        useDriverStore.fetchMoreAllowances();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showRecheckModal(BuildContext context, int allowanceId) {
    final TextEditingController reasonController = TextEditingController();
    final bool isTamil = LanguageStore.isTamil;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
        final Color surface = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.report_problem_rounded, color: Colors.red),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isTamil ? "மறுபரிசீலனை கோரிக்கை" : "Request Recheck",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  style: TextStyle(color: titleColor),
                  decoration: InputDecoration(
                    hintText: isTamil ? "காரணத்தை உள்ளிடவும்..." : "Enter remarks for recheck...",
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      if (reasonController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(isTamil ? "காரணத்தை உள்ளிடுவது கட்டாயம்" : "Remarks cannot be empty")),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      
                      // Show loading dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );
                      
                      final res = await useDriverStore.requestAllowanceRecheck(allowanceId, reasonController.text.trim());
                      
                      if (mounted) {
                        Navigator.pop(context); // Close loading dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res['message'] ?? (res['success'] ? "Success" : "Failed"))),
                        );
                      }
                    },
                    child: Text(
                      isTamil ? "சமர்ப்பி" : "Submit",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleConfirm(BuildContext context, int allowanceId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    
    final res = await useDriverStore.markAllowanceSeen(allowanceId);
    
    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      final isTamil = LanguageStore.isTamil;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? (res['success'] ? "Success" : "Failed"))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTamil = LanguageStore.isTamil;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isTamil ? "படிகள்" : "Allowances",
          style: TextStyle(fontWeight: FontWeight.w900, color: titleColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<DriverStore>(
        builder: (context, store, _) {
          if (store.isLoadingAllowances && store.allowances.isEmpty) {
            return _buildSkeletonLoading(isDark);
          }

          return RefreshIndicator(
            onRefresh: () => store.fetchAllowances(isRefresh: true),
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(
                  child: SizedBox(height: 10),
                ),
                if (store.allowances.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(isTamil, isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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
                const SliverToBoxAdapter(child: SizedBox(height: 40)), // Bottom padding
              ],
            ),
          );
        },
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
            isTamil ? "படிகள் எதுவும் இல்லை" : "No allowances found",
            style: TextStyle(color: subColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoading(bool isDark) {
    final Color baseColor = isDark ? const Color(0xFF1E293B) : Colors.grey[300]!;
    final Color highlightColor = isDark ? const Color(0xFF334155) : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(20),
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllowanceCard(Map<String, dynamic> allowance, bool isDark, bool isTamil, Color primaryBlue, Color titleColor, int index) {
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    
    final tripInstance = allowance['tripInstance'];
    final routeRequest = tripInstance?['routeRequest'];
    final routeName = routeRequest?['route_name'] ?? tripInstance?['trip_number'] ?? "Unknown Route";
    final amount = allowance['amount'] ?? "0.00";
    final String status = allowance['payment_status'] ?? "UNKNOWN";
    final createdBy = allowance['createdBy']?['name'] ?? "Admin";
    final allowanceReason = allowance['reason'] ?? "";
    final allowanceId = allowance['id'] as int;

    final String dateStr = allowance['createdAt'] ?? "";
    String formattedDate = "";
    if (dateStr.isNotEmpty) {
      final date = DateTime.tryParse(dateStr)?.toLocal();
      if (date != null) {
        formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(date);
      }
    }

    Color statusColor = Colors.grey;
    String statusStr = status;
    
    if (status == 'ASSIGNED') {
      statusColor = Colors.orange;
      statusStr = isTamil ? "ஒதுக்கப்பட்டது" : "ASSIGNED";
    } else if (status == 'SEEN' || status == 'COMPLETED') {
      statusColor = Colors.green;
      statusStr = isTamil ? "பார்க்கப்பட்டது" : status;
    } else if (status == 'RECHECK_REQUESTED') {
      statusColor = Colors.redAccent;
      statusStr = isTamil ? "மறுபரிசீலனை" : "RECHECK REQUESTED";
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (index * 100).clamp(0, 1000)),
      curve: Curves.easeOutCubic,
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
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusStr,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
              Text(
                "₹$amount",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primaryBlue),
              ),
            ],
          ),
          if (formattedDate.isNotEmpty) ...[
            const SizedBox(height: 12),
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
          ],
          const SizedBox(height: 12),
          Text(
            routeName,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: titleColor),
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
              Icon(Icons.person_pin_circle_rounded, size: 16, color: subColor),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w600, fontFamily: 'Inter'), // Assuming default font, else standard
                    children: [
                      TextSpan(text: "${isTamil ? 'உருவாக்கியவர்' : 'Created by'}: "),
                      TextSpan(
                        text: createdBy,
                        style: TextStyle(color: titleColor, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (routeRequest != null && routeRequest['id'] != null)
                GestureDetector(
                  onTap: () {
                    // Navigate to Mission Details
                    String timeStr = "TBD";
                    if (routeRequest['legs'] != null && routeRequest['legs'].isNotEmpty) {
                      final firstLeg = routeRequest['legs'][0];
                      timeStr = firstLeg['planned_start_at'] ?? "TBD";
                      if (timeStr != "TBD") {
                        timeStr = DateFormat('hh:mm a').format(DateTime.parse(timeStr).toLocal());
                      }
                    }
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MissionDetailsScreen(
                          missionTitle: routeName,
                          time: timeStr,
                          driverName: "Driver",
                          driverPhone: "",
                          vehicleInfo: "Assigned Vehicle",
                          capacity: "0",
                          pathType: routeRequest['trip_type'] ?? "ONE_WAY",
                          status: routeRequest['status'] ?? "UNKNOWN",
                          statusColor: primaryBlue,
                          requestId: routeRequest['id'].toString(),
                          rawStatus: 8,
                          stops: const [],
                        ),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isTamil ? "விவரங்களைக் காண்" : "View Details",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: primaryBlue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 12, color: primaryBlue),
                    ],
                  ),
                ),
            ],
          ),
          
          if (status == 'ASSIGNED') ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      foregroundColor: Colors.red,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showRecheckModal(context, allowanceId),
                    child: Text(
                      isTamil ? "மறுபரிசீலனை" : "Recheck",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _handleConfirm(context, allowanceId),
                    child: Text(
                      isTamil ? "உறுதி செய்" : "Confirm",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            )
          ]
        ],
      ),
    ));
  }
}
