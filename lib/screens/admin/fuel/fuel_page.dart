import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import '../../../components/common/custom_date_time_picker.dart';
import '../../../utils/api_constants.dart';
import '../../../store/user_store.dart';
import '../../../utils/toast_utils.dart';
import 'create_fuel_request_page.dart';
import 'fuel_price_update_page.dart';

class FuelPage extends StatefulWidget {
  const FuelPage({super.key});

  @override
  State<FuelPage> createState() => _FuelPageState();
}

class _FuelPageState extends State<FuelPage> {
  bool _isRequestGeneration = true;
  DateTime? _selectedDate; // Null means "Show All"
  int? _expandedIndex;
  List<dynamic> _fuelLogs = [];
  bool _isLoading = true;

  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  late ScrollController _requestScrollController;
  late ScrollController _historyScrollController;

  @override
  void initState() {
    super.initState();
    _requestScrollController = ScrollController()..addListener(_onRequestScroll);
    _historyScrollController = ScrollController()..addListener(_onHistoryScroll);
    _fetchFuelLogs(isRefresh: true);
  }

  @override
  void dispose() {
    _requestScrollController.dispose();
    _historyScrollController.dispose();
    super.dispose();
  }

  void _onRequestScroll() {
    if (_requestScrollController.position.pixels >= _requestScrollController.position.maxScrollExtent - 200) {
      _fetchMoreFuelLogs();
    }
  }

  void _onHistoryScroll() {
    if (_historyScrollController.position.pixels >= _historyScrollController.position.maxScrollExtent - 200) {
      _fetchMoreFuelLogs();
    }
  }

  Future<void> _fetchFuelLogs({bool isRefresh = false}) async {
    if (isRefresh) {
      if (!mounted) return;
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _fuelLogs = [];
        _isLoading = true;
      });
    }

    try {
      final token = await UserStore.getToken();
      String url = "${ApiConstants.fuelLog}?page=$_currentPage&limit=20";
      
      if (_selectedDate != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
        url += "&from_date=$dateStr&to_date=$dateStr";
      }

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> newLogs = responseData['data'] ?? [];
          setState(() {
            if (isRefresh) {
              _fuelLogs = newLogs;
            } else {
              _fuelLogs.addAll(newLogs);
            }
            _isLoading = false;
            _isLoadingMore = false;
            if (newLogs.length < 20) {
              _hasMore = false;
            } else {
              _currentPage++;
            }
          });
        } else {
          setState(() {
            _isLoading = false;
            _isLoadingMore = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      debugPrint("Error fetching fuel logs: $e");
    }
  }

  Future<void> _fetchMoreFuelLogs() async {
    if (_isLoadingMore || !_hasMore) return;
    if (!mounted) return;
    setState(() => _isLoadingMore = true);
    await _fetchFuelLogs();
  }

  Future<void> _deleteFuelLog(int id) async {
    try {
      final token = await UserStore.getToken();
      
      // Console log curl
      debugPrint("\n--- DELETE REQUEST ---\ncurl --location --request DELETE '${ApiConstants.deleteFuelLog(id)}' \\\n--header 'Authorization: TMS $token'\n-------------------\n");

      final response = await http.delete(
        Uri.parse(ApiConstants.deleteFuelLog(id)),
        headers: ApiConstants.getHeaders(token),
      );

      debugPrint("\n--- DELETE RESPONSE ---\nStatus: ${response.statusCode}\nBody: ${response.body}\n----------------\n");

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? "Deleted successfully"),
              backgroundColor: Colors.green,
            ),
          );
          _fetchFuelLogs(isRefresh: true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? "Error"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to delete log"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Network error"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _wrapWithDismissible({
    required Widget child,
    required dynamic log,
    required int index,
    required Color primary,
  }) {
    return Dismissible(
      key: Key("fuel_log_${log['id']}"),
      direction: DismissDirection.startToEnd,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 32),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("Delete Fuel Log", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
            content: const Text("Are you sure you want to delete this fuel log? This action cannot be undone."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) => _deleteFuelLog(log['id']),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: titleColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              "Fuel Dashboard",
              style: GoogleFonts.plusJakartaSans(
                color: titleColor,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              _selectedDate == null ? "All Records" : DateFormat('EEEE, MMM dd yyyy').format(_selectedDate!),
              style: GoogleFonts.plusJakartaSans(
                color: subColor,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_today_rounded, color: primaryBlue, size: 18),
            ),
            onPressed: () async {
              final picked = await CustomDateTimePicker.show(
                context,
                initialDate: _selectedDate ?? DateTime.now(),
                showTime: false,
                accent: primaryBlue,
                titleColor: titleColor,
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _fetchFuelLogs(isRefresh: true);
              }
            },
          ),
          if (_selectedDate != null)
            IconButton(
              icon: Icon(Icons.clear_rounded, color: subColor, size: 20),
              onPressed: () {
                setState(() => _selectedDate = null);
                _fetchFuelLogs(isRefresh: true);
              },
            ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.currency_rupee_rounded, color: Colors.green, size: 18),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FuelPriceUpdatePage()),
              ).then((_) => _fetchFuelLogs(isRefresh: true)); // Refresh logs in case prices changed
            },
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.file_download_outlined, color: primaryBlue, size: 18),
            ),
            onPressed: () => _showReportGenerationSheet(primaryBlue, titleColor, subColor, isDark),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _buildToggleButton(primaryBlue, surfaceColor, isDark),
          const SizedBox(height: 24),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isRequestGeneration
                  ? _buildRequestGenerationView(titleColor, subColor, primaryBlue, isDark)
                  : _buildHistoryView(titleColor, subColor, primaryBlue, isDark),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateFuelRequestPage()),
          ).then((value) {
            if (value == true) {
              _fetchFuelLogs(isRefresh: true);
              setState(() => _isRequestGeneration = true);
            }
          });
        },
        backgroundColor: primaryBlue,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
      ),
    );
  }

  void _showReportGenerationSheet(Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
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
                    color: Colors.black.withValues(alpha: 0.15),
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
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryBlue.withValues(alpha: 0.1),
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
                              "Download Fuel Report",
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
                  if (!isRangeReport) ...[
                    _buildOptionLabel("REPORT DATE", subColor),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final picked = await CustomDateTimePicker.show(
                          context,
                          initialDate: selectedDate,
                          showTime: false,
                          accent: primaryBlue,
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: titleColor.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 18, color: primaryBlue),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('MMMM dd, yyyy').format(selectedDate),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
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
                              _buildOptionLabel("FROM DATE", subColor),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await CustomDateTimePicker.show(
                                    context,
                                    initialDate: fromDate,
                                    showTime: false,
                                    accent: primaryBlue,
                                  );
                                  if (picked != null) {
                                    setModalState(() => fromDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: titleColor.withValues(alpha: 0.05)),
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
                              _buildOptionLabel("TO DATE", subColor),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await CustomDateTimePicker.show(
                                    context,
                                    initialDate: toDate,
                                    showTime: false,
                                    accent: primaryBlue,
                                  );
                                  if (picked != null) {
                                    setModalState(() => toDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: titleColor.withValues(alpha: 0.05)),
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
                  _buildOptionLabel("FILE FORMAT", subColor),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildFormatChip('pdf', 'PDF Document', Icons.picture_as_pdf_rounded, selectedFormat == 'pdf', primaryBlue, titleColor, isDark, () {
                        setModalState(() => selectedFormat = 'pdf');
                      }),
                      const SizedBox(width: 12),
                      _buildFormatChip('excel', 'Excel Sheet', Icons.table_chart_rounded, selectedFormat == 'excel', primaryBlue, titleColor, isDark, () {
                        setModalState(() => selectedFormat = 'excel');
                      }),
                    ],
                  ),
                  const SizedBox(height: 32),
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
                                    final String startStr = DateFormat('yyyy-MM-dd').format(isRangeReport ? fromDate : selectedDate);
                                    final String endStr = DateFormat('yyyy-MM-dd').format(isRangeReport ? toDate : selectedDate);
                                    final String url = ApiConstants.getFuelReport(startStr, endStr, selectedFormat);
                                    
                                    final token = await UserStore.getToken();

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
                                    
                                    if (response.statusCode == 200) {
                                      if (response.headers['content-type']?.contains('application/json') ?? false) {
                                        final jsonResponse = jsonDecode(response.body);
                                        if (jsonResponse['success'] == false) {
                                          throw jsonResponse['message'] ?? "Unknown error occurred.";
                                        }
                                      }

                                      final bytes = response.bodyBytes;
                                      final tempDir = await getTemporaryDirectory();
                                      final ext = selectedFormat == 'pdf' ? 'pdf' : 'xlsx';
                                      final fileName = "Fuel_Report_${startStr}_to_${endStr}.$ext";
                                      final file = File("${tempDir.path}/$fileName");
                                      await file.writeAsBytes(bytes);
                                      
                                      await OpenFilex.open(file.path);
                                      
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        showTopToast(context, "Fuel report generated successfully!");
                                      }
                                    } else {
                                      String errMsg = "Failed to download report. Server responded with ${response.statusCode}.";
                                      try {
                                        final jsonResponse = jsonDecode(response.body);
                                        if (jsonResponse['message'] != null) {
                                          errMsg = jsonResponse['message'];
                                        }
                                      } catch (_) {}
                                      throw errMsg;
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      showTopToast(context, e.toString(), isError: true);
                                    }
                                  } finally {
                                    if (mounted) {
                                      setModalState(() => downloading = false);
                                    }
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

  Widget _buildOptionLabel(String label, Color subColor) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: subColor.withValues(alpha: 0.6),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildFormatChip(String id, String label, IconData icon, bool isSelected, Color primary, Color title, bool isDark, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? primary : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? primary : title.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : primary, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : title.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton(Color primary, Color surface, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 56,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: _isRequestGeneration ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.44,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isRequestGeneration = true;
                    _expandedIndex = null;
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      "Request Generation",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _isRequestGeneration ? Colors.white : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isRequestGeneration = false;
                    _expandedIndex = null;
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      "History",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: !_isRequestGeneration ? Colors.white : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(String imageUrl, Color titleColor, bool isDark) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(color: Colors.black.withValues(alpha: 0.8)),
              ),
              Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    headers: const {ApiConstants.bypassHeaderKey: ApiConstants.bypassHeaderValue},
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(child: CircularProgressIndicator(color: Colors.white.withValues(alpha: 0.5)));
                    },
                    errorBuilder: (context, error, stackTrace) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                        const SizedBox(height: 16),
                        Text("Unable to load image", style: GoogleFonts.plusJakartaSans(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 20,
                right: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestGenerationView(Color titleColor, Color subColor, Color primary, bool isDark) {
    if (_isLoading) return _buildShimmerLoading(isDark);
    
    final List<dynamic> filteredLogs = _fuelLogs.where((log) {
      if (log['fuel_entry_status'] != "PENDING_DRIVER_FILL") return false;
      if (_selectedDate == null) return true;
      
      final DateTime logDate = DateTime.parse(log['created_at']);
      return logDate.year == _selectedDate!.year &&
             logDate.month == _selectedDate!.month &&
             logDate.day == _selectedDate!.day;
    }).toList();

    // Sort by date (newest first)
    filteredLogs.sort((a, b) {
      final DateTime aDate = DateTime.parse(a['created_at']);
      final DateTime bDate = DateTime.parse(b['created_at']);
      return bDate.compareTo(aDate);
    });

    if (filteredLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_turned_in_rounded, size: 48, color: titleColor.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(
              _selectedDate == null ? "No pending requests found" : "No requests for ${DateFormat('MMM dd').format(_selectedDate!)}", 
              style: TextStyle(color: subColor, fontWeight: FontWeight.w600)
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchFuelLogs(isRefresh: true),
      child: ListView.builder(
        controller: _requestScrollController,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        itemCount: filteredLogs.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filteredLogs.length) {
            if (_isLoadingMore) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF6366F1),
                  ),
                ),
              );
            } else {
              return const SizedBox(height: 40);
            }
          }
          final req = filteredLogs[index];
          final bool isExpanded = _expandedIndex == index;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _wrapWithDismissible(
              child: _buildFuelCard(index, req, titleColor, subColor, primary, isDark, isHistory: false, isExpanded: isExpanded),
              log: req,
              index: index,
              primary: primary,
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryView(Color titleColor, Color subColor, Color primary, bool isDark) {
    if (_isLoading) return _buildShimmerLoading(isDark);

    final List<dynamic> historyItems = _fuelLogs.where((log) {
      if (log['fuel_entry_status'] != "COMPLETED") return false;
      if (_selectedDate == null) return true;

      final DateTime logDate = DateTime.parse(log['filled_at'] ?? log['created_at']);
      return logDate.year == _selectedDate!.year &&
             logDate.month == _selectedDate!.month &&
             logDate.day == _selectedDate!.day;
    }).toList();

    // Sort by date (newest first)
    historyItems.sort((a, b) {
      final DateTime aDate = DateTime.parse(a['filled_at'] ?? a['created_at']);
      final DateTime bDate = DateTime.parse(b['filled_at'] ?? b['created_at']);
      return bDate.compareTo(aDate);
    });

    if (historyItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: titleColor.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(
              _selectedDate == null ? "No history found" : "No history for ${DateFormat('MMM dd').format(_selectedDate!)}", 
              style: TextStyle(color: subColor, fontWeight: FontWeight.w600)
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchFuelLogs(isRefresh: true),
      child: ListView.builder(
        controller: _historyScrollController,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        itemCount: historyItems.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == historyItems.length) {
            if (_isLoadingMore) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF6366F1),
                  ),
                ),
              );
            } else {
              return const SizedBox(height: 40);
            }
          }
          final item = historyItems[index];
          final bool isExpanded = _expandedIndex == index;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _wrapWithDismissible(
              child: _buildFuelCard(index, item, titleColor, subColor, primary, isDark, isHistory: true, isExpanded: isExpanded),
              log: item,
              index: index,
              primary: primary,
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
          highlightColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 120, height: 16, color: Colors.white),
                      const SizedBox(height: 8),
                      Container(width: 80, height: 12, color: Colors.white),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(width: 40, height: 20, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(width: 60, height: 10, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFuelCard(int index, dynamic item, Color titleColor, Color subColor, Color primary, bool isDark, {required bool isHistory, required bool isExpanded}) {
    final String vNumber = item['vehicle']?['vehicle_number'] ?? "Unknown";
    final String driverName = item['driver']?['user']?['name'] ?? 
                             item['driver']?['name'] ?? 
                             item['filledByUser']?['name'] ?? 
                             "System";
    final String filledBy = item['filledByUser']?['name'] ?? "Admin";
    final String volume = isHistory 
        ? "${item['filled_volume'] ?? 0}L" 
        : "${item['required_volume'] ?? 0}L";
    
    String status = (item['fuel_entry_status'] ?? "").toString();
    if (status == "PENDING_DRIVER_FILL") {
      status = "PENDING";
    }

    final String price = item['bill_amount'] != null ? "₹${item['bill_amount']}" : "₹0.00";
    final String bunkName = item['bunk']?['name'] ?? "Unknown Bunk";
    final String indentNo = item['instance_id'] ?? "N/A";
    final String filledAt = item['filled_at'] != null 
        ? DateFormat('MMM dd, hh:mm a').format(DateTime.parse(item['filled_at']))
        : "N/A";
    final String odometer = "${item['current_odometer'] ?? 0} KM";

    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedIndex = isExpanded ? null : index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isExpanded ? primary : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
            width: isExpanded ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isExpanded ? 0.1 : 0.06),
              blurRadius: isExpanded ? 25 : 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.local_gas_station_rounded, color: primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vNumber,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 12, color: subColor.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              driverName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: subColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      volume,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: primary,
                      ),
                    ),
                    Text(
                      status.replaceAll('_', ' '),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isHistory ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildDetailItem("Indent No", indentNo, Icons.tag_rounded, primary, subColor, titleColor)),
                  const SizedBox(width: 16),
                  if (isHistory)
                    Expanded(child: _buildDetailItem("Odometer", odometer, Icons.speed_rounded, primary, subColor, titleColor))
                  else
                    const Expanded(child: SizedBox.shrink()),
                ],
              ),
              const SizedBox(height: 16),
              if (isHistory) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildDetailItem("Filled At", filledAt, Icons.access_time_rounded, primary, subColor, titleColor)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildDetailItem("Price", price, Icons.payments_rounded, primary, subColor, titleColor)),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildDetailItem("Bunk Name", bunkName, Icons.store_rounded, primary, subColor, titleColor)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDetailItem("Driver", driverName, Icons.person_rounded, primary, subColor, titleColor)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _buildDetailItem("Filled By", filledBy, Icons.admin_panel_settings_rounded, primary, subColor, titleColor)),
                  const SizedBox(width: 16),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
              if (isHistory && item['bill_file_url'] != null) ...[
                const SizedBox(height: 20),
                _buildOptionLabel("FUEL PROOF IMAGE", subColor),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showFullScreenImage(
                    item['bill_file_url'].startsWith('/') 
                        ? "${ApiConstants.baseUrl}${item['bill_file_url']}" 
                        : item['bill_file_url'],
                    titleColor,
                    isDark
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      item['bill_file_url'].startsWith('/') 
                          ? "${ApiConstants.baseUrl}${item['bill_file_url']}" 
                          : item['bill_file_url'],
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      headers: const {ApiConstants.bypassHeaderKey: ApiConstants.bypassHeaderValue},
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: titleColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_rounded, color: subColor.withValues(alpha: 0.5), size: 32),
                            const SizedBox(height: 8),
                            Text("No receipt image", style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon, Color primary, Color subColor, Color titleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: primary.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: subColor),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}
