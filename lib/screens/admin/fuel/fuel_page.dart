import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../components/common/custom_date_time_picker.dart';
import 'create_fuel_request_page.dart';

class FuelPage extends StatefulWidget {
  const FuelPage({super.key});

  @override
  State<FuelPage> createState() => _FuelPageState();
}

class _FuelPageState extends State<FuelPage> {
  bool _isRequestGeneration = true;
  DateTime _selectedDate = DateTime.now();
  int? _expandedIndex;

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
        title: Text(
          "Fuel Page",
          style: GoogleFonts.plusJakartaSans(
            color: titleColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
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
                initialDate: _selectedDate,
                showTime: false,
                accent: primaryBlue,
                titleColor: titleColor,
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
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
    String selectedFormat = 'pdf';

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
                      Column(
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
                            "Select date and format",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: subColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
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
                        ],
                      ),
                    ),
                  ),
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
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Downloading fuel report for ${DateFormat('MMM dd').format(selectedDate)}...")),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                      child: Text(
                        "Generate Report",
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
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

  Widget _buildRequestGenerationView(Color titleColor, Color subColor, Color primary, bool isDark) {
    final List<Map<String, dynamic>> pendingRequests = [
      {"vehicle": "TN 37 B 1234", "driver": "Rajesh Kumar", "volume": "50L", "date": DateTime.now(), "price": "5120.00", "bunk": "HP Fuel - Kovai Road"},
      {"vehicle": "TN 38 C 5678", "driver": "Suresh Raina", "volume": "40L", "date": DateTime.now().subtract(const Duration(days: 1)), "price": "4096.00", "bunk": "Indian Oil - Sathyamangalam"},
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: pendingRequests.length,
      itemBuilder: (context, index) {
        final req = pendingRequests[index];
        final bool isExpanded = _expandedIndex == index;
        final String dateStr = DateFormat('EEEE, MMM dd').format(req['date']);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                dateStr,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: primary,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const Divider(),
            _buildFuelCard(index, req, titleColor, subColor, primary, isDark, isHistory: false, isExpanded: isExpanded),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildHistoryView(Color titleColor, Color subColor, Color primary, bool isDark) {
    final List<Map<String, dynamic>> historyItems = [
      {
        "vehicle": "TN 37 B 1234", "driver": "Rajesh Kumar", "volume": "50L", "date": DateTime.now().subtract(const Duration(days: 2)), "price": "5120.00", "bunk": "HP Fuel - Kovai Road",
        "proof": "https://img.freepik.com/free-photo/view-gas-station-with-price-board_23-2149427021.jpg"
      },
      {
        "vehicle": "TN 38 C 5678", "driver": "Suresh Raina", "volume": "40L", "date": DateTime.now().subtract(const Duration(days: 3)), "price": "4096.00", "bunk": "Indian Oil - Sathyamangalam",
        "proof": "https://img.freepik.com/free-photo/view-gas-station-with-price-board_23-2149427021.jpg"
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: historyItems.length,
      itemBuilder: (context, index) {
        final bool isExpanded = _expandedIndex == index;
        return _buildFuelCard(index, historyItems[index], titleColor, subColor, primary, isDark, isHistory: true, isExpanded: isExpanded);
      },
    );
  }

  Widget _buildFuelCard(int index, Map<String, dynamic> item, Color titleColor, Color subColor, Color primary, bool isDark, {required bool isHistory, required bool isExpanded}) {
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
          border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
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
                        item['vehicle'],
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['driver'],
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: subColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item['volume'],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: primary,
                      ),
                    ),
                    Text(
                      isHistory ? "SUCCESS" : "PENDING",
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
                  _buildDetailItem("Bunk Name", item['bunk'], Icons.store_rounded, primary, subColor, titleColor),
                  _buildDetailItem("Total Price", "₹${item['price']}", Icons.payments_rounded, primary, subColor, titleColor),
                ],
              ),
              if (isHistory && item['proof'] != null) ...[
                const SizedBox(height: 20),
                _buildOptionLabel("FUEL PROOF IMAGE", subColor),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    item['proof'],
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150,
                      color: Colors.grey.withValues(alpha: 0.1),
                      child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
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
            Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: subColor)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: titleColor)),
      ],
    );
  }
}
