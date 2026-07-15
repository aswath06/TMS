import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/components/common/custom_date_time_picker.dart';

import 'package:tripzo/utils/toast_utils.dart';

void showFuelDownloadModal(BuildContext context, Color primaryBlue, Color titleColor, Color subColor, bool isDark) {
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  
  String exportType = 'Tripzo';
  String format = 'pdf';
  
  List<dynamic> allVehicles = [];
  List<dynamic> allBunks = [];
  
  List<int> selectedVehicles = [];
  List<int> selectedBunks = [];
  
  bool isLoadingData = true;
  bool isDownloading = false;

  Future<void> fetchData(void Function(void Function()) setModalState) async {
    try {
      final token = await UserStore.getToken();
      
      final vehicleResponse = await http.get(Uri.parse(ApiConstants.getAllVehiclesWithoutPagination), headers: ApiConstants.getHeaders(token));
      if (vehicleResponse.statusCode == 200) {
        final res = json.decode(vehicleResponse.body);
        allVehicles = res['data'] ?? [];
      }
      
      final bunkResponse = await http.get(Uri.parse(ApiConstants.fuelBunks), headers: ApiConstants.getHeaders(token));
      if (bunkResponse.statusCode == 200) {
        final res = json.decode(bunkResponse.body);
        allBunks = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint("Error fetching modal data: $e");
    } finally {
      setModalState(() {
        isLoadingData = false;
      });
    }
  }

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

  void showMultiSelectSheet(
    BuildContext context, 
    String title, 
    List<dynamic> items, 
    List<int> selectedIds, 
    String Function(dynamic) getName,
    int Function(dynamic) getId,
    void Function(List<int>) onSaved,
  ) {
    List<int> tempSelected = List.from(selectedIds);
    String searchQuery = '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(builder: (sheetContext, setSheetState) {
          final filteredItems = items.where((item) {
            return getName(item).toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: EdgeInsets.only(
              top: 24, left: 24, right: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
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
                    Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: titleColor)),
                    IconButton(icon: Icon(Icons.close, color: subColor), onPressed: () => Navigator.pop(sheetContext)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (val) {
                    setSheetState(() {
                      searchQuery = val;
                    });
                  },
                  style: GoogleFonts.plusJakartaSans(color: titleColor),
                  decoration: InputDecoration(
                    hintText: "Search...",
                    hintStyle: GoogleFonts.plusJakartaSans(color: subColor),
                    prefixIcon: Icon(Icons.search, color: subColor),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredItems.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final id = getId(item);
                      final name = getName(item);
                      final isSelected = tempSelected.contains(id);
                      
                      return GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            if (isSelected) {
                              tempSelected.remove(id);
                            } else {
                              tempSelected.add(id);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? primaryBlue.withValues(alpha: 0.05) : (isDark ? const Color(0xFF0F172A) : Colors.white),
                            border: Border.all(color: isSelected ? primaryBlue : subColor.withValues(alpha: 0.15), width: isSelected ? 2 : 1),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isSelected ? [BoxShadow(color: primaryBlue.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))] : [],
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected ? primaryBlue : Colors.transparent,
                                  border: Border.all(color: isSelected ? primaryBlue : subColor.withValues(alpha: 0.5), width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(name, style: GoogleFonts.plusJakartaSans(color: isSelected ? primaryBlue : titleColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 15)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      onSaved(tempSelected);
                      Navigator.pop(sheetContext);
                    },
                    child: Text("Apply Selection (${tempSelected.length})", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                )
              ],
            ),
          );
        });
      },
    );
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          
          if (isLoadingData && allVehicles.isEmpty) {
            fetchData(setModalState);
          }

          return Container(
            padding: EdgeInsets.only(
              top: 24,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Export Fuel Ledger Registry",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: subColor),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const SizedBox(height: 24),

                if (isLoadingData) 
                  const Center(child: CircularProgressIndicator())
                else ...[
                  Text("OPERATIONAL DATE RANGE", style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: subColor, letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: Border.all(color: subColor.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await CustomDateTimePicker.show(context, initialDate: fromDate, showTime: false, accent: primaryBlue);
                              if (picked != null) setModalState(() => fromDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              color: Colors.transparent,
                              alignment: Alignment.center,
                              child: Text(DateFormat('dd / MM / yyyy').format(fromDate), style: GoogleFonts.plusJakartaSans(color: titleColor, fontSize: 15, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        Text("-", style: GoogleFonts.plusJakartaSans(color: subColor, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await CustomDateTimePicker.show(context, initialDate: toDate, showTime: false, accent: primaryBlue);
                              if (picked != null) setModalState(() => toDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              color: Colors.transparent,
                              alignment: Alignment.center,
                              child: Text(DateFormat('dd / MM / yyyy').format(toDate), style: GoogleFonts.plusJakartaSans(color: titleColor, fontSize: 15, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        Container(width: 1, height: 24, color: subColor.withValues(alpha: 0.2)),
                        IconButton(
                          icon: Icon(Icons.calendar_month_outlined, color: subColor, size: 20),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // App Selector
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setModalState(() => exportType = 'Tripzo'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(color: exportType == 'Tripzo' ? primaryBlue : subColor.withValues(alpha: 0.3), width: 1.5),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Tripzo", style: GoogleFonts.plusJakartaSans(color: titleColor, fontWeight: FontWeight.bold)),
                              if (exportType == 'Tripzo') ...[
                                const SizedBox(width: 12),
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: primaryBlue, shape: BoxShape.circle)),
                              ]
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => setModalState(() => exportType = 'Inventura'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(color: exportType == 'Inventura' ? primaryBlue : subColor.withValues(alpha: 0.3), width: 1.5),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Inventura", style: GoogleFonts.plusJakartaSans(color: titleColor, fontWeight: FontWeight.bold)),
                              if (exportType == 'Inventura') ...[
                                const SizedBox(width: 12),
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: primaryBlue, shape: BoxShape.circle)),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (exportType != 'Inventura') ...[
                    // Vehicle Selector
                    GestureDetector(
                      onTap: () => showMultiSelectSheet(
                        context, "Select Vehicles", allVehicles, selectedVehicles, 
                        (v) => v['vehicle_number'] ?? v['bus_number'] ?? "Unknown", 
                        (v) => v['id'],
                        (res) => setModalState(() => selectedVehicles = res),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(border: Border.all(color: subColor.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(selectedVehicles.isEmpty ? "Select vehicles..." : "${selectedVehicles.length} vehicles selected", style: GoogleFonts.plusJakartaSans(color: selectedVehicles.isEmpty ? subColor : titleColor)),
                            Icon(Icons.keyboard_arrow_down, color: subColor),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bunk Selector
                    GestureDetector(
                      onTap: () => showMultiSelectSheet(
                        context, "Select Fuel Bunks", allBunks, selectedBunks, 
                        (b) => b['name'] ?? "Unknown", 
                        (b) => b['id'],
                        (res) => setModalState(() => selectedBunks = res),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(border: Border.all(color: subColor.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(selectedBunks.isEmpty ? "Select fuel bunks..." : "${selectedBunks.length} bunks selected", style: GoogleFonts.plusJakartaSans(color: selectedBunks.isEmpty ? subColor : titleColor)),
                            Icon(Icons.keyboard_arrow_down, color: subColor),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Format Selector
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
                    const SizedBox(height: 32),
                  ],

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
                              String vehiclesParam = selectedVehicles.join(',');
                              String bunksParam = selectedBunks.join(',');

                              String finalUrl = ApiConstants.getFuelReport(startStr, endStr, format, exportType, vehiclesParam, bunksParam);
                              
                              final token = await UserStore.getToken();
                              final response = await http.get(
                                Uri.parse(finalUrl),
                                headers: ApiConstants.getHeaders(token),
                              );
                              
                              if (response.statusCode == 200) {
                                final directory = await getTemporaryDirectory();
                                final file = File('${directory.path}/Fuel_Report_$startStr.$format');
                                await file.writeAsBytes(response.bodyBytes);
                                
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  showTopToast(context, "Fuel report generated successfully!");
                                }
                                
                                await OpenFilex.open(file.path);
                              } else {
                                if (context.mounted) showTopToast(context, "Failed to download report. (Error: ${response.statusCode})", isError: true);
                              }
                            } catch (e) {
                              debugPrint("Download Error: $e");
                              if (context.mounted) showTopToast(context, "Could not complete download.", isError: true);
                            } finally {
                              setModalState(() => isDownloading = false);
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
                            : Text("Generate Report", style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}
