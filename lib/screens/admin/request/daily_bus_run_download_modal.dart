import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';

import 'package:tripzo/utils/toast_utils.dart';
import 'package:tripzo/utils/api_error_parser.dart';

void showDailyBusRunDownloadModal(BuildContext context, Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  
  String format = 'pdf'; // pdf, excel
  String reportType = 'detailed'; // detailed, incharge
  
  bool isDownloading = false;

  Widget buildOptionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: subColor,
        letterSpacing: 0.5,
      ),
    );
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext modalContext) {
      return StatefulBuilder(builder: (context, setModalState) {
        return Container(
          padding: EdgeInsets.only(
            top: 24, left: 24, right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: subColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Download Report", style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: titleColor)),
                  IconButton(
                    icon: Icon(Icons.close, color: subColor),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Select date and format to generate report",
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500, color: subColor),
              ),
              const SizedBox(height: 24),

              // Date Selection
              buildOptionLabel("OPERATIONAL DATE RANGE"),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await CustomDateTimePicker.show(
                          context,
                          initialDate: fromDate,
                          minDate: DateTime(2000),
                          showTime: false,
                        );
                        if (picked != null) {
                          setModalState(() {
                            fromDate = picked;
                            if (toDate.isBefore(fromDate)) toDate = fromDate;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(border: Border.all(color: subColor.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd/MM/yyyy').format(fromDate), style: GoogleFonts.plusJakartaSans(color: titleColor, fontWeight: FontWeight.w600)),
                            Icon(Icons.calendar_today, size: 16, color: subColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text("-", style: GoogleFonts.plusJakartaSans(color: subColor, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await CustomDateTimePicker.show(
                          context,
                          initialDate: toDate,
                          minDate: fromDate,
                          showTime: false,
                        );
                        if (picked != null) {
                          setModalState(() => toDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(border: Border.all(color: subColor.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd/MM/yyyy').format(toDate), style: GoogleFonts.plusJakartaSans(color: titleColor, fontWeight: FontWeight.w600)),
                            Icon(Icons.calendar_today, size: 16, color: subColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Format Selector
              buildOptionLabel("REPORT FORMAT"),
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setModalState(() => format = 'pdf'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: format == 'pdf' ? primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
                        border: Border.all(color: format == 'pdf' ? primaryBlue : subColor.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text("PDF", style: GoogleFonts.plusJakartaSans(color: format == 'pdf' ? primaryBlue : subColor, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => setModalState(() => format = 'excel'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: format == 'excel' ? primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
                        border: Border.all(color: format == 'excel' ? primaryBlue : subColor.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text("Excel", style: GoogleFonts.plusJakartaSans(color: format == 'excel' ? primaryBlue : subColor, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Report Type Selector
              buildOptionLabel("REPORT TYPE"),
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => setModalState(() => reportType = 'detailed'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: reportType == 'detailed' ? primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
                        border: Border.all(color: reportType == 'detailed' ? primaryBlue : subColor.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text("Detailed", style: GoogleFonts.plusJakartaSans(color: reportType == 'detailed' ? primaryBlue : subColor, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => setModalState(() => reportType = 'incharge'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: reportType == 'incharge' ? primaryBlue.withValues(alpha: 0.1) : Colors.transparent,
                        border: Border.all(color: reportType == 'incharge' ? primaryBlue : subColor.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text("Incharge Report", style: GoogleFonts.plusJakartaSans(color: reportType == 'incharge' ? primaryBlue : subColor, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text("Cancel", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isDownloading ? null : () async {
                        setModalState(() => isDownloading = true);
                        try {
                          String startStr = DateFormat('yyyy-MM-dd').format(fromDate);
                          String endStr = DateFormat('yyyy-MM-dd').format(toDate);

                          String finalUrl = "${ApiConstants.baseUrl}/daily-bus/bus-runs/reports/date-wise?start_date=$startStr&end_date=$endStr&format=$format&type=$reportType";
                          
                          final token = await UserStore.getToken();
                          final response = await http.get(
                            Uri.parse(finalUrl),
                            headers: ApiConstants.getHeaders(token),
                          );
                          
                          if (response.statusCode == 200) {
                            final contentType = response.headers['content-type'];
                            if (contentType != null && contentType.contains('application/json')) {
                              if (context.mounted) showTopToast(context, ApiErrorParser.parse(response, fallback: "Failed to download report."), isError: true);
                              return;
                            }
                            
                            final directory = await getTemporaryDirectory();
                            final fileExt = format == "pdf" ? "pdf" : "xlsx";
                            final fileNamePrefix = reportType == "incharge" ? "Daily_Bus_Run_Incharge_Report" : "Daily_Bus_Run_Report";
                            
                            final file = File('${directory.path}/${fileNamePrefix}_${startStr}_to_${endStr}.$fileExt');
                            await file.writeAsBytes(response.bodyBytes);
                            
                            if (context.mounted) {
                              Navigator.pop(context);
                              showTopToast(context, "${reportType == 'incharge' ? 'Incharge' : format.toUpperCase()} report generated successfully!");
                            }
                            
                            await OpenFilex.open(file.path);
                          } else {
                            if (context.mounted) showTopToast(context, ApiErrorParser.parse(response, fallback: "Failed to download report. (Error)"), isError: true);
                          }
                        } catch (e) {
                          debugPrint("Download Error: $e");
                          if (context.mounted) showTopToast(context, "Could not complete download.", isError: true);
                        } finally {
                          if (context.mounted) {
                            setModalState(() => isDownloading = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: isDownloading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text("Generate ${format == 'pdf' ? 'PDF' : 'Excel'}", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      });
    },
  );
}
