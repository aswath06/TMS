import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:intl/intl.dart';

class DriverAttendanceScreen extends ConsumerStatefulWidget {
  const DriverAttendanceScreen({super.key});

  @override
  ConsumerState<DriverAttendanceScreen> createState() => _DriverAttendanceScreenState();
}

class _DriverAttendanceScreenState extends ConsumerState<DriverAttendanceScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(driverStoreProvider).fetchMoreAttendance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTamil = LanguageStore.isTamil;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final store = ref.watch(driverStoreProvider);
    final attendance = store.attendance;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isTamil ? "பயோமெட்ரிக் விவரங்கள்" : "Biometric Details",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: store.isLoadingAttendance && attendance.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await store.fetchAttendance(isRefresh: true);
              },
              child: attendance.isEmpty
                  ? Center(
                      child: Text(
                        isTamil ? "எந்த தரவும் இல்லை" : "No biometric data found",
                        style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: attendance.length + (store.hasMoreAttendance ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == attendance.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final data = attendance[index];
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
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
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
                              const SizedBox(height: 16),
                              Container(height: 1, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                              const SizedBox(height: 16),
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
                      },
                    ),
            ),
    );
  }
}
