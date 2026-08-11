import 'package:flutter/material.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shimmer/shimmer.dart';
import 'package:tripzo/store/student_leave_store.dart';

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  String _selectedFilter = "All"; // All, Present, Absent, Leave
  DateTime? _selectedDate; // The date picked by the user
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLogs();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (useStudentLeaveStore.attendanceLogsHasMore && !useStudentLeaveStore.isFetchingMoreLogs) {
        useStudentLeaveStore.fetchAttendanceLogs(
          isLoadMore: true,
          filterDate: _selectedDate,
          statusFilter: _selectedFilter,
        );
      }
    }
  }

  void _fetchLogs() {
    useStudentLeaveStore.fetchAttendanceLogs(
      isLoadMore: false,
      filterDate: _selectedDate,
      statusFilter: _selectedFilter,
    );
  }

  Future<void> _pickDate() async {
    final picked = await CustomDateTimePicker.show(
      context,
      initialDate: _selectedDate ?? DateTime.now(),
      maxDate: DateTime.now(),
      showTime: false,
      accent: const Color(0xFF6366F1),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchLogs();
    }
  }

  void _showFilterSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 32),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Filter by Status",
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: subColor),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Filter List
                  Column(
                    children: [
                      _buildFilterChip("All", setModalState, isDark),
                      const SizedBox(height: 12),
                      _buildFilterChip("Present", setModalState, isDark),
                      const SizedBox(height: 12),
                      _buildFilterChip("Absent", setModalState, isDark),
                      const SizedBox(height: 12),
                      _buildFilterChip("Leave", setModalState, isDark),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String filter, StateSetter setModalState, bool isDark) {
    final isSelected = _selectedFilter == filter;
    final primaryBlue = const Color(0xFF6366F1);
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bgColor = isSelected ? primaryBlue.withOpacity(0.08) : surface;
    final borderColor = isSelected ? primaryBlue : (isDark ? Colors.white12 : Colors.black.withOpacity(0.05));
    final textColor = isSelected ? primaryBlue : (isDark ? Colors.white : const Color(0xFF0F172A));

    return InkWell(
      onTap: () {
        setModalState(() { _selectedFilter = filter; }); 
        setState(() { _selectedFilter = filter; }); 
        Navigator.pop(context);
        _fetchLogs();
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          filter,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryBlue = const Color(0xFF6366F1);

    // Calculate metrics
    final totalMapped = useStudentLeaveStore.dashboardTotalMappedDays;
    final absentCount = useStudentLeaveStore.dashboardAbsentCount;
    final leaveCount = useStudentLeaveStore.dashboardLeaveCount;
    final presentCount = totalMapped - absentCount - leaveCount;
    final attendancePercentage = totalMapped > 0 ? (presentCount / totalMapped) * 100 : 0.0;

    String formatMetric(double val) {
      if (val == val.toInt()) return val.toInt().toString();
      return val.toString();
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "My Attendance",
          style: GoogleFonts.outfit(
            color: titleColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: IconThemeData(color: titleColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: useStudentLeaveStore,
        builder: (context, _) {
          Map<String, List<dynamic>> groupedLogs = {};
          for (var log in useStudentLeaveStore.attendanceLogs) {
            String dateStr = DateFormat('dd MMM yyyy').format(DateTime.parse(log['date']));
            if (!groupedLogs.containsKey(dateStr)) {
              groupedLogs[dateStr] = [];
            }
            groupedLogs[dateStr]!.add(log);
          }

          return useStudentLeaveStore.isLoadingMetrics 
              ? _buildShimmerLoading(isDark, surfaceColor, bgColor)
              : RefreshIndicator(
                  onRefresh: () async => _fetchLogs(),
                  child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 16),
                  // Stats Row - Horizontal Scrollable
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildStatCard("${attendancePercentage.toStringAsFixed(0)}%", "Attendance", const Color(0xFF10B981), surfaceColor),
                        const SizedBox(width: 12),
                        _buildStatCard(formatMetric(presentCount), "Present", primaryBlue, surfaceColor),
                        const SizedBox(width: 12),
                        _buildStatCard(formatMetric(absentCount), "Absent", const Color(0xFFF43F5E), surfaceColor),
                        const SizedBox(width: 12),
                        _buildStatCard(formatMetric(leaveCount), "Leave", const Color(0xFFF59E0B), surfaceColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Active Filter Indicator
                  if (_selectedFilter != "All" || _selectedDate != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
                      child: Row(
                        children: [
                          Text(
                            "Filtering by: ",
                            style: GoogleFonts.outfit(color: subColor, fontSize: 14),
                          ),
                          if (_selectedFilter != "All")
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _selectedFilter,
                                style: GoogleFonts.outfit(
                                  color: primaryBlue, 
                                  fontSize: 12, 
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                          if (_selectedDate != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                DateFormat('dd MMM').format(_selectedDate!),
                                style: GoogleFonts.outfit(
                                  color: primaryBlue, 
                                  fontSize: 12, 
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setState(() {
                              _selectedFilter = "All";
                              _selectedDate = null;
                            }),
                            child: Text("Clear", style: GoogleFonts.outfit(fontSize: 13)),
                          )
                        ],
                      ),
                    ),

                  // Daily Attendance List
                  if (groupedLogs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          "No records found.",
                          style: GoogleFonts.outfit(color: subColor),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          ...groupedLogs.entries.map((entry) => _buildDaySection(entry.key, entry.value, surfaceColor, titleColor, subColor)),
                          if (useStudentLeaveStore.isFetchingMoreLogs)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 24),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );
        },
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark, Color surfaceColor, Color bgColor) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(4, (index) => Container(
                width: 110,
                height: 90,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              )),
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: List.generate(4, (index) => Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 20, color: surfaceColor),
                    const SizedBox(height: 12),
                    Container(
                      height: 85,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 85,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ],
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color valueColor, Color surfaceColor) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDaySection(String dateStr, List<dynamic> logs, Color surface, Color titleColor, Color subColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 12),
          ...logs.map((log) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildRecordCard(log['session'], log['status'], log['bus_number'], log['run_name'], surface, titleColor, subColor),
              )),
        ],
      ),
    );
  }

  Widget _buildRecordCard(String title, String status, String? busNo, String? runName, Color surface, Color titleColor, Color subColor) {
    Color statusColor;
    if (status == "Present") {
      statusColor = const Color(0xFF10B981);
    } else if (status == "Absent") {
      statusColor = const Color(0xFFEF4444);
    } else {
      statusColor = const Color(0xFFF59E0B);
    }
    
    final statusBgColor = statusColor.withOpacity(0.1);
    final iconColor = const Color(0xFF6366F1); // Indigo
    final iconBgColor = iconColor.withOpacity(0.1);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.access_time_rounded, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                if (busNo != null || runName != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.directions_bus_rounded, size: 14, color: subColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "${busNo ?? 'Not Assigned'} • ${runName ?? ''}",
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: subColor,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
