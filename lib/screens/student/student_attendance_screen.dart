import 'package:flutter/material.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class DayRecord {
  final DateTime date;
  final String fnStatus; // "Present", "Absent", "Leave"
  final String anStatus;
  final String? fnBusNo;
  final String? anBusNo;

  DayRecord({required this.date, required this.fnStatus, required this.anStatus, this.fnBusNo, this.anBusNo});
}

class StudentAttendanceScreen extends StatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  State<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  bool _isLoading = false;
  String _selectedFilter = "All"; // All, Present, Absent, Leave
  DateTime? _selectedDate; // The date picked by the user
  
  // Stats
  final double _attendancePercentage = 88.0;
  final int _presentCount = 22;
  final int _absentCount = 3;
  final int _leaveCount = 5; 

  // Mock list of past days
  final List<DayRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _generateMockData();
    _fetchAttendanceData();
  }
  
  void _generateMockData() {
    final now = DateTime.now();
    for (int i = 0; i < 14; i++) {
      final date = now.subtract(Duration(days: i));
      String fn = "Present";
      String an = "Present";
      
      if (date.weekday == 6 || date.weekday == 7) {
         fn = "Leave"; 
         an = "Leave";
      } else if (date.day % 3 == 0) {
         fn = "Present";
         an = "Absent";
      } else if (date.day % 5 == 0) {
         fn = "Absent";
         an = "Absent";
      }
      
      String? fnBus = "Bus 12";
      String? anBus = "Bus 14";
      
      _records.add(DayRecord(date: date, fnStatus: fn, anStatus: an, fnBusNo: fnBus, anBusNo: anBus));
    }
  }

  Future<void> _fetchAttendanceData() async {
    setState(() { _isLoading = true; });
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() { 
        _isLoading = false; 
      });
    }
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

    List<DayRecord> filteredRecords = _records.where((record) {
      bool statusMatch = _selectedFilter == "All" || record.fnStatus == _selectedFilter || record.anStatus == _selectedFilter;
      bool dateMatch = _selectedDate == null || 
          (record.date.year == _selectedDate!.year && 
           record.date.month == _selectedDate!.month && 
           record.date.day == _selectedDate!.day);
      return statusMatch && dateMatch;
    }).toList();

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
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : RefreshIndicator(
              onRefresh: _fetchAttendanceData,
              child: ListView(
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
                        _buildStatCard("${_attendancePercentage.toInt()}%", "Attendance", const Color(0xFF10B981), surfaceColor),
                        const SizedBox(width: 12),
                        _buildStatCard("$_presentCount", "Present", primaryBlue, surfaceColor),
                        const SizedBox(width: 12),
                        _buildStatCard("$_absentCount", "Absent", const Color(0xFFF43F5E), surfaceColor),
                        const SizedBox(width: 12),
                        _buildStatCard("$_leaveCount", "Leave", const Color(0xFFF59E0B), surfaceColor),
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
                  if (filteredRecords.isEmpty)
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
                        children: filteredRecords
                            .map((record) => _buildDaySection(record, surfaceColor, titleColor, subColor))
                            .toList(),
                      ),
                    ),
                ],
              ),
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

  Widget _buildDaySection(DayRecord record, Color surface, Color titleColor, Color subColor) {
    final dateStr = DateFormat('dd MMM yyyy').format(record.date);

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
          if (_selectedFilter == "All" || record.fnStatus == _selectedFilter) ...[
            _buildRecordCard("Forenoon Session", record.fnStatus, record.fnBusNo, surface, titleColor, subColor),
            const SizedBox(height: 10),
          ],
          if (_selectedFilter == "All" || record.anStatus == _selectedFilter)
            _buildRecordCard("Afternoon Session", record.anStatus, record.anBusNo, surface, titleColor, subColor),
        ],
      ),
    );
  }

  Widget _buildRecordCard(String title, String status, String? busNo, Color surface, Color titleColor, Color subColor) {
    Color statusColor;
    if (status == "Present") {
      statusColor = const Color(0xFF10B981);
    } else if (status == "Absent") {
      statusColor = const Color(0xFFEF4444);
    } else {
      statusColor = const Color(0xFFF59E0B);
    }
    
    final statusBgColor = statusColor.withOpacity(0.1);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.access_time_rounded, color: statusColor, size: 20),
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
                if (busNo != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.directions_bus_rounded, size: 14, color: subColor),
                      const SizedBox(width: 4),
                      Text(
                        busNo,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: subColor,
                          fontWeight: FontWeight.w500,
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
