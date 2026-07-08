import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/screens/driver/apply_leave_page.dart';
import 'package:tripzo/screens/student/student_apply_leave_page.dart';
import 'package:tripzo/screens/driver/DriverAttendanceScreen.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/student_leave_store.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/components/common/structural_loading.dart';
import 'package:tripzo/utils/toast_utils.dart';

class DriverLeaveScreen extends ConsumerStatefulWidget {
  final String userRole;
  const DriverLeaveScreen({super.key, this.userRole = 'driver'});

  @override
  ConsumerState<DriverLeaveScreen> createState() => _DriverLeaveScreenState();
}

class _DriverLeaveScreenState extends ConsumerState<DriverLeaveScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.userRole == 'student') {
        useStudentLeaveStore.fetchLeaves();
      } else {
        useDriverStore.fetchLeaves();
        useDriverStore.fetchAttendance(isRefresh: true);
      }
    });
  }

  DateTime _focusedDay = DateTime.now();

  int _getDaysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
  int _getFirstDayOffset(int year, int month) =>
      DateTime(year, month, 1).weekday - 1;

  void _changeMonth(int offset) {
    setState(() {
      _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + offset);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isTamil = LanguageStore.isTamil;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          _buildBackgroundGlow(primaryBlue, isDark),
          SafeArea(
            child: Consumer(
builder: (context, ref, _) {
final store = ref.watch(driverStoreProvider);
                return RefreshIndicator(
                  onRefresh: () async {
                    if (widget.userRole == 'student') {
                      await useStudentLeaveStore.fetchLeaves();
                    } else {
                      await store.fetchLeaves();
                      await store.fetchAttendance(isRefresh: true);
                    }
                  },
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildHeader(
                          widget.userRole == 'driver' 
                              ? (isTamil ? "வருகை போர்ட்டல்" : "Attendance Portal")
                              : widget.userRole == 'student'
                                  ? (isTamil ? "போக்குவரத்து இருப்பு" : "Transport Availability")
                                  : (isTamil ? "விடுப்பு போர்ட்டல்" : "Leave Portal"),
                          titleColor,
                          screenWidth,
                        ),
                        const SizedBox(height: 32),

                        _buildAttractiveApplyButton(context, primaryBlue, isTamil),
                        const SizedBox(height: 40),

                        _buildSectionTitle(
                          isTamil ? "நாட்காட்டி பார்வை" : "Calendar Overview",
                          titleColor,
                        ),
                        const SizedBox(height: 18),
                        _buildFullCalendar(
                          surfaceColor,
                          isDark,
                          primaryBlue,
                          isTamil,
                        ),

                        if (widget.userRole != 'student') ...[
                          const SizedBox(height: 36),

                          _buildHistoryHeader(
                            isTamil ? "பயோமெட்ரிக் விவரங்கள்" : "Biometric Details",
                            titleColor,
                            icon: Icons.fingerprint_rounded,
                          ),
                          const SizedBox(height: 16),
                          _buildBiometricSection(store, surfaceColor, isDark, isTamil, primaryBlue),
                        ],

                        const SizedBox(height: 36),

                        _buildHistoryHeader(
                          widget.userRole == 'student'
                              ? (isTamil ? "வரலாறு" : "Availability History")
                              : (isTamil ? "விடுப்பு வரலாறு" : "Leave History"),
                          titleColor,
                          icon: Icons.history_rounded,
                        ),
                        const SizedBox(height: 16),
                        
                        if (widget.userRole == 'student')
                          ListenableBuilder(
                            listenable: useStudentLeaveStore,
                            builder: (context, _) {
                              if (useStudentLeaveStore.isLoadingLeaves && useStudentLeaveStore.leaves.isEmpty) {
                                return const StructuralLoading();
                              } else if (useStudentLeaveStore.leavesError != null) {
                                return _buildErrorState(useStudentLeaveStore.leavesError!, isTamil, isDark, onRetry: () => useStudentLeaveStore.fetchLeaves());
                              } else if (useStudentLeaveStore.leaves.isEmpty) {
                                return _buildEmptyHistory(isTamil, isDark);
                              }
                              return Column(
                                children: useStudentLeaveStore.leaves.map((leave) => Column(
                                  children: [
                                    _buildLeaveHistoryItem(leave, surfaceColor, isDark, isTamil),
                                    const SizedBox(height: 12),
                                  ],
                                )).toList(),
                              );
                            },
                          )
                        else ...[
                          if (store.isLoadingLeaves && store.leaves.isEmpty)
                            const StructuralLoading()
                          else if (store.leavesError != null)
                            _buildErrorState(store.leavesError!, isTamil, isDark)
                          else if (store.leaves.isEmpty)
                            _buildEmptyHistory(isTamil, isDark)
                          else
                            ...store.leaves.map((leave) => Column(
                              children: [
                                _buildLeaveHistoryItem(
                                  leave,
                                  surfaceColor,
                                  isDark,
                                  isTamil,
                                ),
                                const SizedBox(height: 12),
                              ],
                            )),
                        ],

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricSection(DriverStore store, Color surfaceColor, bool isDark, bool isTamil, Color primaryBlue) {
    if (store.isLoadingAttendance && store.attendance.isEmpty) {
      return const StructuralLoading();
    }
    
    if (store.attendance.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            isTamil ? "பயோமெட்ரிக் தரவு எதுவும் இல்லை" : "No biometric data found",
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
          ),
        ),
      );
    }

    final top5 = store.attendance.take(5).toList();

    return Column(
      children: [
        ...top5.map((data) {
          final String dateStr = data['date'] ?? "";
          String fnTime = data['fn_time'] ?? "--:--";
          String anTime = data['an_time'] ?? "--:--";

          try {
            if (fnTime != "--:--") fnTime = DateFormat("hh:mm a").format(DateFormat("HH:mm:ss").parse(fnTime));
            if (anTime != "--:--") anTime = DateFormat("hh:mm a").format(DateFormat("HH:mm:ss").parse(anTime));
          } catch (_) {}

          String displayDate = dateStr;
          try {
            final dt = DateTime.parse(dateStr);
            displayDate = DateFormat("dd-MM-yyyy 'and' EEEE").format(dt);
          } catch (_) {}

          Widget buildTimeDetail({required String label, required String time, required IconData icon}) {
            final isMissing = time == "--:--";
            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: isMissing ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isMissing ? Colors.grey.shade400 : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 16, color: primaryBlue),
                        const SizedBox(width: 8),
                        Text(
                          displayDate,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.fingerprint_rounded, size: 20, color: Colors.grey.shade400),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: buildTimeDetail(
                        label: "Forenoon", 
                        time: fnTime, 
                        icon: Icons.login_rounded,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    Expanded(
                      child: buildTimeDetail(
                        label: "Afternoon", 
                        time: anTime, 
                        icon: Icons.logout_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DriverAttendanceScreen()),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isTamil ? "அனைத்தையும் காண்க" : "View All",
                style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 16, color: primaryBlue),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyHistory(bool isTamil, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black12),
            const SizedBox(height: 12),
            Text(
              widget.userRole == 'student' 
                  ? (isTamil ? "வரலாறு எதுவும் இல்லை" : "No availability history found")
                  : (isTamil ? "வரலாறு எதுவும் இல்லை" : "No leave history found"),
              style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullCalendar(
    Color surface,
    bool isDark,
    Color primary,
    bool isTamil,
  ) {
    // This will now work because of the initialization in main.dart
    final monthTitle = DateFormat.yMMMM(
      isTamil ? 'ta' : 'en',
    ).format(_focusedDay);

    final daysInMonth = _getDaysInMonth(_focusedDay.year, _focusedDay.month);
    final firstDayOffset = _getFirstDayOffset(
      _focusedDay.year,
      _focusedDay.month,
    );
    final totalCells = daysInMonth + firstDayOffset;

    final List<String> weekDays = isTamil
        ? ['தி', 'செ', 'பு', 'வி', 'வெ', 'ச', 'ஞ']
        : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              Row(
                children: [
                  _calendarNavButton(
                    Icons.chevron_left,
                    () => _changeMonth(-1),
                    primary,
                  ),
                  const SizedBox(width: 8),
                  _calendarNavButton(
                    Icons.chevron_right,
                    () => _changeMonth(1),
                    primary,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays
                .map(
                  (d) => Text(
                    d,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              if (index < firstDayOffset) return const SizedBox.shrink();

              int day = index - firstDayOffset + 1;
              bool isToday =
                  day == DateTime.now().day &&
                  _focusedDay.month == DateTime.now().month &&
                  _focusedDay.year == DateTime.now().year;

              return Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isToday ? primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      "$day",
                      style: TextStyle(
                        color: isToday
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- REUSABLE WIDGETS ---

  Widget _buildBackgroundGlow(Color primary, bool isDark) => Positioned(
    top: -100,
    right: -100,
    child: Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary.withValues(alpha: isDark ? 0.15 : 0.08),
      ),
    ),
  );

  Widget _buildHeader(String title, Color titleColor, double width) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: width * 0.08,
          fontWeight: FontWeight.w900,
          color: titleColor,
          letterSpacing: -1.5,
        ),
      ),
      Container(
        height: 4,
        width: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ],
  );

  Widget _buildAttractiveApplyButton(
    BuildContext context,
    Color primary,
    bool isTamil,
  ) => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => widget.userRole == 'student' 
          ? const StudentApplyLeavePage() 
          : ApplyLeavePage(userRole: widget.userRole)),
    ),
    child: Container(
      width: double.infinity,
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, const Color(0xFF818CF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.userRole == 'student' ? Icons.directions_bus_rounded : Icons.add_task_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.userRole == 'student'
                      ? (isTamil ? "போக்குவரத்து இருப்பை மாற்று" : "UPDATE TRANSPORT AVAILABILITY")
                      : (isTamil ? "விடுப்பு விண்ணப்பிக்க" : "APPLY NEW LEAVE"),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildHistoryHeader(String title, Color color, {IconData icon = Icons.history_rounded}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      _buildSectionTitle(title, color),
      Icon(icon, color: Colors.grey.withValues(alpha: 0.5)),
    ],
  );

  Widget _buildLeaveHistoryItem(
    Map<String, dynamic> leave,
    Color surface,
    bool isDark,
    bool isTamil,
  ) {
    if (widget.userRole == 'student') {
      return _buildStudentLeaveHistoryItem(leave, surface, isDark, isTamil);
    }
    
    final int status = leave['status'] ?? 1;
    final String fromDate = _formatDateShort(leave['from_date']);
    final String toDate = _formatDateShort(leave['to_date']);
    
    String statusStr = "Pending";
    Color statusColor = Colors.orange;
    if (status == 2) {
      statusStr = "Approved";
      statusColor = Colors.teal.shade400;
    } else if (status == 3) {
      statusStr = "Rejected";
      statusColor = Colors.redAccent;
    }

    if (isTamil) {
      if (status == 1) {
        statusStr = "காத்திருப்பில்";
      } else if (status == 2) statusStr = "அங்கீகரிக்கப்பட்டது";
      else if (status == 3) statusStr = "நிராகரிக்கப்பட்டது";
    }

    final int typeInt = leave['leave_type'] ?? 1;
    final String typeStr = DriverStore.LEAVE_TYPE[typeInt] ?? (isTamil ? "விடுப்பு" : "Leave");

    return GestureDetector(
      onTap: () => _showLeaveDetailsPopup(context, leave, isTamil, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03)),
        ),
        child: Row(
          children: [
            Container(
              height: 45,
              width: 45,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                color: statusColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    typeStr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$fromDate - $toDate",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusStr,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveDetailsPopup(BuildContext context, Map<String, dynamic> leave, bool isTamil, bool isDark) {
    final status = leave['status'] ?? 1;
    final type = DriverStore.LEAVE_TYPE[leave['leave_type']] ?? "Leave";
    final driver = leave['driver'] ?? {};
    final routes = leave['routes_during_leave'] as List? ?? [];

    Color statusColor = Colors.orange;
    String statusStr = isTamil ? "காத்திருப்பில்" : "Pending";
    if (status == 2) {
      statusColor = Colors.teal;
      statusStr = isTamil ? "அங்கீகரிக்கப்பட்டது" : "Approved";
    } else if (status == 3) {
      statusColor = Colors.redAccent;
      statusStr = isTamil ? "நிராகரிக்கப்பட்டது" : "Rejected";
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          statusStr.toUpperCase(),
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    type,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${_formatDateLong(leave['from_date'])} - ${_formatDateLong(leave['to_date'])}",
                    style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  _popupInfoRow(isTamil ? "ஓட்டுநர்" : "Driver", driver['name'] ?? "Unknown", Icons.person_outline_rounded),
                  _popupInfoRow(isTamil ? "மின்னஞ்சல்" : "Email", driver['email'] ?? "No email", Icons.alternate_email_rounded),
                  _popupInfoRow(isTamil ? "மொத்த நாட்கள்" : "Total Days", "${leave['total_days']} ${isTamil ? 'நாட்கள்' : 'Days'}", Icons.date_range_rounded),
                  
                  const SizedBox(height: 20),
                  Text(
                    isTamil ? "விடுப்புக்கான காரணம்" : "Reason for Leave",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      leave['reason'] ?? (isTamil ? "விளக்கப்படவில்லை" : "No reason provided"),
                      style: const TextStyle(height: 1.5),
                    ),
                  ),

                  if (routes.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      isTamil ? "விடுமுறையின் போது திட்டமிடப்பட்ட பயணங்கள்" : "Routes Scheduled During Leave",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ...routes.map((r) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(r['routeName'] ?? "Unknown Route", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    )),
                  ],

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(isTamil ? "சரி" : "CLOSE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentLeaveHistoryItem(
    Map<String, dynamic> leave,
    Color surface,
    bool isDark,
    bool isTamil,
  ) {
    final String dateStr = _formatDateShort(leave['leave_date']);
    final String shiftType = leave['shift_type'] ?? "";
    final String leaveType = leave['leave_type'] ?? "Leave";
    final bool canRevoke = leave['can_revoke'] == true;

    return GestureDetector(
      onTap: () => _showStudentLeaveDetailsPopup(context, leave, isTamil, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03)),
        ),
        child: Row(
          children: [
            Container(
              height: 45,
              width: 45,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                color: Colors.blueAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leaveType,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$dateStr • $shiftType",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (canRevoke)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isTamil ? "ரத்து செய்" : "Cancel",
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showStudentLeaveDetailsPopup(BuildContext context, Map<String, dynamic> leave, bool isTamil, bool isDark) {
    final type = leave['leave_type'] ?? "Leave";
    final dateStr = _formatDateLong(leave['leave_date']);
    final shift = leave['shift_type'] ?? "";
    final reason = leave['reason'] ?? (isTamil ? "விளக்கப்படவில்லை" : "No reason provided");
    final bool canRevoke = leave['can_revoke'] == true;
    final int id = leave['id'];

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          (isTamil ? "மாணவர் விடுப்பு" : "Student Leave").toUpperCase(),
                          style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    type,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateStr,
                    style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  _popupInfoRow(isTamil ? "ஷிப்ட்" : "Shift", shift, Icons.access_time_rounded),
                  
                  const SizedBox(height: 20),
                  Text(
                    isTamil ? "விடுப்புக்கான காரணம்" : "Reason for Leave",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      reason,
                      style: const TextStyle(height: 1.5),
                    ),
                  ),

                  const SizedBox(height: 32),
                  if (canRevoke) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          final success = await useStudentLeaveStore.revokeLeave(id);
                          if (success) {
                            if (mounted) {
                              showTopToast(context, isTamil ? "ரத்து செய்யப்பட்டது" : "Leave Revoked Successfully");
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(isTamil ? "ரத்து செய்" : "CANCEL LEAVE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(isTamil ? "சரி" : "CLOSE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _popupInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6366F1).withValues(alpha: 0.7)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calendarNavButton(IconData icon, VoidCallback onTap, Color primary) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primary, size: 20),
        ),
      );

  Widget _buildSectionTitle(String title, Color color) => Text(
    title,
    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
  );

  String _formatDateShort(String? dateStr) {
    if (dateStr == null) return "...";
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM dd').format(dt);
    } catch (_) {
      return "...";
    }
  }

  String _formatDateLong(String? dateStr) {
    if (dateStr == null) return "...";
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM, yyyy').format(dt);
    } catch (_) {
      return "...";
    }
  }

  Widget _buildErrorState(String error, bool isTamil, bool isDark, {VoidCallback? onRetry}) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          ),
          TextButton(
            onPressed: onRetry ?? () => useDriverStore.fetchLeaves(),
            child: Text(isTamil ? "மீண்டும் முயற்சி" : "RETRY"),
          ),
        ],
      ),
    );
  }
}
