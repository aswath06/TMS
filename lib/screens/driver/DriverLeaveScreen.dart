import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tms/store/istamil.dart';

class DriverLeaveScreen extends StatefulWidget {
  const DriverLeaveScreen({super.key});

  @override
  State<DriverLeaveScreen> createState() => _DriverLeaveScreenState();
}

class _DriverLeaveScreenState extends State<DriverLeaveScreen> {
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _buildHeader(
                    isTamil ? "விடுப்பு போர்ட்டல்" : "Leave Portal",
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

                  const SizedBox(height: 36),

                  _buildHistoryHeader(
                    isTamil ? "விடுப்பு வரலாறு" : "Leave History",
                    titleColor,
                  ),
                  const SizedBox(height: 16),
                  _buildLeaveHistoryItem(
                    isTamil ? "ஆண்டு விடுப்பு" : "Annual Leave",
                    "Feb 12 - Feb 14",
                    isTamil ? "காத்திருப்பில்" : "Pending",
                    Colors.orangeAccent,
                    surfaceColor,
                    isDark,
                  ),
                  _buildLeaveHistoryItem(
                    isTamil ? "மருத்துவ விடுப்பு" : "Sick Leave",
                    "Jan 05 - Jan 06",
                    isTamil ? "அங்கீகரிக்கப்பட்டது" : "Approved",
                    Colors.teal.shade400,
                    surfaceColor,
                    isDark,
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
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
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
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
        color: primary.withOpacity(isDark ? 0.15 : 0.08),
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
      MaterialPageRoute(builder: (context) => const ApplyLeavePage()),
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
            color: primary.withOpacity(0.4),
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
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
          ),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_task_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  isTamil ? "விடுப்பு விண்ணப்பிக்க" : "APPLY NEW LEAVE",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
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

  Widget _buildHistoryHeader(String title, Color color) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      _buildSectionTitle(title, color),
      Icon(Icons.history_rounded, color: Colors.grey.withOpacity(0.5)),
    ],
  );

  Widget _buildLeaveHistoryItem(
    String type,
    String date,
    String status,
    Color statusColor,
    Color surface,
    bool isDark,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        Container(
          height: 45,
          width: 45,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
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
                type,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                date,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _calendarNavButton(IconData icon, VoidCallback onTap, Color primary) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: primary, size: 20),
        ),
      );

  Widget _buildSectionTitle(String title, Color color) => Text(
    title,
    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
  );
}

class ApplyLeavePage extends StatelessWidget {
  const ApplyLeavePage({super.key});
  @override
  Widget build(BuildContext context) {
    final bool isTamil = LanguageStore.isTamil;
    return Scaffold(
      appBar: AppBar(
        title: Text(isTamil ? "விடுப்பு விண்ணப்பம்" : "Request Leave"),
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          isTamil
              ? "புதிய விடுப்பு விண்ணப்பப் படிவம்"
              : "Form for new leave application",
        ),
      ),
    );
  }
}
