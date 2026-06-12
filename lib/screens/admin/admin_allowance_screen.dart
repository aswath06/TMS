import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:tripzo/store/admin_allowance_store.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/screens/faculty/missions/mission_details_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/toast_utils.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';

class AdminAllowanceScreen extends ConsumerStatefulWidget {
  const AdminAllowanceScreen({super.key});

  @override
  ConsumerState<AdminAllowanceScreen> createState() => _AdminAllowanceScreenState();
}

class _AdminAllowanceScreenState extends ConsumerState<AdminAllowanceScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  int? _tempSelectedDriverId;
  DateTime? _tempSelectedDate;
  String? _userRole;
  bool _showPendingTab = false;

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
                    Consumer(
builder: (context, ref, child) {
final store = ref.watch(adminAllowanceStoreProvider);
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
                        final pickedDate = await CustomDateTimePicker.show(
                          context,
                          initialDate: _tempSelectedDate ?? DateTime.now(),
                          showTime: false,
                          accent: const Color(0xFF6366F1),
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

  void _showAllowanceReportSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
    DateTime selectedDate = DateTime.now();
    DateTime fromDate = DateTime.now().subtract(const Duration(days: 7));
    DateTime toDate = DateTime.now();
    bool isRangeReport = true;
    String selectedFormat = 'pdf';
    bool downloading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.file_download_outlined, color: primaryBlue, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Download Allowance Report",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: titleColor,
                              ),
                            ),
                            Text(
                              "Select date range and format to generate",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: subColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Segmented Toggle
                  Container(
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => isRangeReport = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isRangeReport ? primaryBlue : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "From - To Date",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isRangeReport
                                      ? Colors.white
                                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => isRangeReport = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: !isRangeReport ? primaryBlue : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "Date-wise",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: !isRangeReport
                                      ? Colors.white
                                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Date pickers
                  if (!isRangeReport) ...[
                    Text(
                      "REPORT DATE",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: subColor.withOpacity(0.6),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final picked = await CustomDateTimePicker.show(
                          context,
                          initialDate: selectedDate,
                          showTime: false,
                          accent: primaryBlue,
                        );
                        if (picked != null) setModalState(() => selectedDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 18, color: primaryBlue),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('MMMM dd, yyyy').format(selectedDate),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.keyboard_arrow_down_rounded, color: subColor, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "FROM DATE",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: subColor.withOpacity(0.6),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await CustomDateTimePicker.show(
                                    context,
                                    initialDate: fromDate,
                                    showTime: false,
                                    accent: primaryBlue,
                                  );
                                  if (picked != null) setModalState(() => fromDate = picked);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.event_available_rounded, size: 18, color: primaryBlue),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          DateFormat('dd MMM yyyy').format(fromDate),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: titleColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TO DATE",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: subColor.withOpacity(0.6),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await CustomDateTimePicker.show(
                                    context,
                                    initialDate: toDate,
                                    showTime: false,
                                    accent: primaryBlue,
                                  );
                                  if (picked != null) setModalState(() => toDate = picked);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.event_busy_rounded, size: 18, color: primaryBlue),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          DateFormat('dd MMM yyyy').format(toDate),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: titleColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Format selector
                  Text(
                    "FILE FORMAT",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: subColor.withOpacity(0.6),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedFormat = 'pdf'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: selectedFormat == 'pdf' ? primaryBlue : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: selectedFormat == 'pdf' ? primaryBlue : titleColor.withOpacity(0.05)),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.picture_as_pdf_rounded, color: selectedFormat == 'pdf' ? Colors.white : primaryBlue, size: 24),
                                const SizedBox(height: 8),
                                Text(
                                  "PDF Document",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: selectedFormat == 'pdf' ? Colors.white : titleColor.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedFormat = 'excel'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: selectedFormat == 'excel' ? primaryBlue : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: selectedFormat == 'excel' ? primaryBlue : titleColor.withOpacity(0.05)),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.table_chart_rounded, color: selectedFormat == 'excel' ? Colors.white : primaryBlue, size: 24),
                                const SizedBox(height: 8),
                                Text(
                                  "Excel Sheet",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: selectedFormat == 'excel' ? Colors.white : titleColor.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: Text(
                            "Cancel",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: subColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: downloading
                              ? null
                              : () async {
                                  setModalState(() => downloading = true);
                                  try {
                                    final token = await UserStore.getToken();

                                    // Build URL based on mode
                                    final String startDate;
                                    final String endDate;
                                    if (isRangeReport) {
                                      startDate = DateFormat('yyyy-MM-dd').format(fromDate);
                                      endDate = DateFormat('yyyy-MM-dd').format(toDate);
                                    } else {
                                      startDate = DateFormat('yyyy-MM-dd').format(selectedDate);
                                      endDate = startDate;
                                    }

                                    final String url = ApiConstants.getAllowanceReport(startDate, endDate, selectedFormat);

                                    debugPrint("====== CURL COMMAND ======");
                                    debugPrint("curl -X GET '$url' -H 'Authorization: Bearer $token'");
                                    debugPrint("==========================");

                                    final response = await http.get(
                                      Uri.parse(url),
                                      headers: ApiConstants.getHeaders(token),
                                    );

                                    debugPrint("====== RESPONSE ======");
                                    debugPrint("Status Code: ${response.statusCode}");
                                    if (response.headers['content-type']?.contains('application/json') ?? false) {
                                      debugPrint("Body: ${response.body}");
                                    } else {
                                      debugPrint("Body: [Binary data, length: ${response.bodyBytes.length}]");
                                    }
                                    debugPrint("======================");

                                    if (!context.mounted) return;

                                    if (response.statusCode == 200) {
                                      // Determine file extension
                                      final ext = selectedFormat == 'excel' ? 'xlsx' : 'pdf';
                                      final fileName = 'allowance_report_${startDate}_to_$endDate.$ext';

                                      // Save to temp directory
                                      final dir = await getTemporaryDirectory();
                                      final file = File('${dir.path}/$fileName');
                                      await file.writeAsBytes(response.bodyBytes);

                                      if (!context.mounted) return;
                                      Navigator.pop(context);

                                      // Open the file
                                      final result = await OpenFilex.open(file.path);
                                      if (result.type != ResultType.done && context.mounted) {
                                        showTopToast(context, 'Could not open file: ${result.message}', isError: true);
                                      }
                                    } else {
                                      // Try to parse error message
                                      String errorMsg = 'Failed to download report';
                                      try {
                                        final body = json.decode(response.body);
                                        errorMsg = body['message'] ?? errorMsg;
                                      } catch (_) {}

                                      if (!context.mounted) return;
                                      Navigator.pop(context);
                                      showTopToast(context, errorMsg, isError: true);
                                    }
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    setModalState(() => downloading = false);
                                    showTopToast(context, e.toString(), isError: true);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          child: downloading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                )
                              : Text(
                                  "Generate ${selectedFormat.toUpperCase()}",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
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
          style: TextStyle(fontWeight: FontWeight.w900, color: titleColor, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor, size: 16),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.file_download_outlined, color: primaryBlue, size: 18),
            ),
            onPressed: () => _showAllowanceReportSheet(primaryBlue, titleColor, isDark ? Colors.white70 : Colors.black54, isDark),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (!_showPendingTab)
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: Container(
              height: 52,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showPendingTab = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: !_showPendingTab ? primaryBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: !_showPendingTab
                              ? [BoxShadow(color: primaryBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                              : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isTamil ? "உருவாக்கப்பட்டவை" : "Created Allowance",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: !_showPendingTab
                                ? Colors.white
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showPendingTab = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: _showPendingTab ? const Color(0xFFF59E0B) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _showPendingTab
                              ? [BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                              : [],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isTamil ? "நிலுவையில்" : "Pending",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _showPendingTab
                                    ? Colors.white
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                            Consumer(
builder: (context, ref, _) {
final store = ref.watch(adminAllowanceStoreProvider);
                                if (store.pendingCreations.isEmpty) return const SizedBox.shrink();
                                return Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _showPendingTab ? Colors.white.withOpacity(0.2) : const Color(0xFFF59E0B).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${store.pendingCreations.length}",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _showPendingTab ? Colors.white : const Color(0xFFF59E0B),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Consumer(
builder: (context, ref, _) {
final store = ref.watch(adminAllowanceStoreProvider);
                if (_showPendingTab) {
                  if (store.isLoadingPendingCreations && store.pendingCreations.isEmpty) {
                    return _buildSkeletonLoading(isDark);
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await store.fetchPendingAllowanceCreations();
                    },
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      slivers: [
                        if (store.pendingCreations.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 80),
                              child: _buildEmptyPendingState(isTamil, isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  return _buildVerticalPendingCard(
                                    store.pendingCreations[index],
                                    isDark,
                                    isTamil,
                                    primaryBlue,
                                    titleColor,
                                    index,
                                  );
                                },
                                childCount: store.pendingCreations.length,
                              ),
                            ),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
                    ),
                  );
                } else {
                  if (store.isLoadingAllowances && store.allowances.isEmpty) {
                    return _buildSkeletonLoading(isDark);
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      await store.fetchAllowances(isRefresh: true);
                    },
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      slivers: [
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
                }
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

  Widget _buildEmptyPendingState(bool isTamil, Color subColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            isTamil ? "நிலுவையில் உள்ளவை எதுவும் இல்லை" : "All Caught Up!",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: subColor),
          ),
          const SizedBox(height: 8),
          Text(
            isTamil ? "அனைத்து படிகளும் வெற்றிகரமாக உருவாக்கப்பட்டது" : "No pending allowance creations found.",
            style: TextStyle(fontSize: 14, color: subColor.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalPendingCard(
    Map<String, dynamic> item,
    bool isDark,
    bool isTamil,
    Color primaryColor,
    Color titleColor,
    int index,
  ) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final routeRequest = item['routeRequest'] ?? {};
    final routeName = routeRequest['route_name'] ?? (isTamil ? 'தெரியவில்லை' : 'Unknown Route');
    
    String driverName = isTamil ? 'தெரியவில்லை' : 'Unknown Driver';
    String vehicleNumber = isTamil ? 'தெரியவில்லை' : 'Unknown Vehicle';
    
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

    final endedAtStr = item['ended_at'];
    String formattedEndTime = isTamil ? 'தெரியவில்லை' : 'Unknown Date';
    if (endedAtStr != null) {
      try {
        final endedAt = DateTime.parse(endedAtStr).toLocal();
        formattedEndTime = DateFormat('dd MMM yyyy • hh:mm a').format(endedAt);
      } catch (_) {}
    }

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 80).clamp(0, 400)),
      curve: Curves.easeOutQuart,
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFF59E0B).withOpacity(0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hourglass_top_rounded, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 6),
                          Text(
                            isTamil ? "உருவாக்க நிலுவை" : "PENDING CREATION",
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFF59E0B),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  routeName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person_rounded, size: 14, color: primaryColor.withOpacity(0.6)),
                              const SizedBox(width: 4),
                              Text(
                                isTamil ? "ஓட்டுநர்" : "DRIVER",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: subColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            driverName,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.directions_bus_rounded, size: 14, color: primaryColor.withOpacity(0.6)),
                              const SizedBox(width: 4),
                              Text(
                                isTamil ? "வாகனம்" : "VEHICLE",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: subColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vehicleNumber,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 14, color: subColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "${isTamil ? 'முடிந்தது' : 'Completed'}: $formattedEndTime",
                        style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
