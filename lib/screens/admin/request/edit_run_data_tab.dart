import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:intl/intl.dart';

class EditRunDataTab extends StatefulWidget {
  final Map<String, dynamic> run;

  const EditRunDataTab({super.key, required this.run});

  @override
  State<EditRunDataTab> createState() => _EditRunDataTabState();
}

class _EditRunDataTabState extends State<EditRunDataTab> {
  String _selectedReadingType = 'START';
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  int? _mistakeIsOnId;
  DateTime? _selectedTime;

  // Previous values for display
  String? _prevOdometer;
  DateTime? _prevTime;
  bool _hasExistingData = false;

  bool _isLoading = false;

  final List<Map<String, String>> _readingTypes = [
    {'value': 'START', 'label': 'Morning Start'},
    {'value': 'CAMPUS_IN', 'label': 'Morning End (Campus In)'},
    {'value': 'CAMPUS_OUT', 'label': 'Evening Start (Campus Out)'},
    {'value': 'HALT', 'label': 'Evening End (Halt)'},
  ];

  List<Map<String, dynamic>> _mistakeOptions = [];

  @override
  void initState() {
    super.initState();
    _populateFields();
    _fetchRoles();
  }

  Future<void> _fetchRoles() async {
    try {
      final token = await UserStore.getToken();
      if (token == null) return;

      final res = await http.get(
        Uri.parse(ApiConstants.getRoles),
        headers: ApiConstants.getHeaders(token),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> roles = data['data'];
          final List<Map<String, dynamic>> fetchedRoles = roles
              .map((r) => {'id': r['id'], 'name': r['name']?.toString() ?? ''})
              .where((r) => r['name'] != '')
              .toList();

          if (fetchedRoles.isNotEmpty) {
            if (mounted) {
              setState(() {
                _mistakeOptions = fetchedRoles;
                if (_mistakeIsOnId == null || !_mistakeOptions.any((r) => r['id'] == _mistakeIsOnId)) {
                  _mistakeIsOnId = _mistakeOptions.first['id'];
                }
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching roles: $e");
    }
  }

  void _populateFields() {
    // Try both possible key names from the API
    final odometers = (widget.run['odometerReadings'] as List?)
        ?? (widget.run['odometer'] as List?)
        ?? [];
    final matchingOdo = odometers.firstWhere(
      (o) => o['reading_type'] == _selectedReadingType,
      orElse: () => null,
    );

    // Only treat as existing data if the odometer reading is actually > 0
    // The backend may create a placeholder row with 0 before the trip reaches that checkpoint
    final double odoVal = matchingOdo != null
        ? (double.tryParse((matchingOdo['odometer_reading'] ?? '0').toString()) ?? 0.0)
        : 0.0;
    final bool hasRealOdometer = odoVal > 0;

    if (matchingOdo != null && hasRealOdometer) {
      _hasExistingData = true;
      _prevOdometer = matchingOdo['odometer_reading']?.toString();
      _odometerController.text = _prevOdometer ?? '';

      final timeStr = matchingOdo['reading_time']?.toString();
      if (timeStr != null && timeStr.isNotEmpty) {
        try {
          _prevTime = DateTime.parse(timeStr).toLocal();
          _selectedTime = _prevTime;
          _timeController.text = DateFormat('dd MMM yyyy  hh:mm a').format(_selectedTime!);
        } catch (_) {
          _prevTime = null;
          _selectedTime = null;
        }
      } else {
        _prevTime = null;
        _selectedTime = null;
        _timeController.clear();
      }
    } else {
      _hasExistingData = false;
      _prevOdometer = null;
      _prevTime = null;
      _odometerController.clear();
      _timeController.clear();
      _selectedTime = null;
    }
    _remarkController.clear();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedTime ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedTime ?? DateTime.now()),
      );
      if (time != null) {
        setState(() {
          _selectedTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          _timeController.text = DateFormat('dd MMM yyyy  hh:mm a').format(_selectedTime!);
        });
      }
    }
  }

  Future<void> _updateRunData() async {
    if (!_hasExistingData) {
      _showSnackBar("No existing data to edit for this reading type.", Colors.orange);
      return;
    }
    if (_odometerController.text.isEmpty && _selectedTime == null) {
      _showSnackBar("Nothing to update.", Colors.orange);
      return;
    }
    if (_remarkController.text.trim().isEmpty) {
      _showSnackBar("Remark is required.", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await UserStore.getToken();
      if (token == null) throw Exception("Session expired");

      final url = "${ApiConstants.baseUrl}/daily-bus/daily-bus-runs/operations/edit-run-data";

      final Map<String, dynamic> body = {
        "run_id": widget.run['id'],
        "reading_type": _selectedReadingType,
        "role_id": _mistakeIsOnId?.toString(),
        "remark": _remarkController.text.trim(),
      };

      if (_odometerController.text.isNotEmpty) {
        body["new_odometer"] = _odometerController.text.trim();
      }
      if (_selectedTime != null) {
        body["new_time"] = _selectedTime!.toIso8601String();
      }

      final res = await http.put(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
        body: json.encode(body),
      );

      final data = json.decode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        _showSnackBar("Run Data updated successfully!", Colors.green);
        if (mounted) Navigator.pop(context, true);
      } else {
        _showSnackBar(data['message'] ?? "Failed to update", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue = const Color(0xFF6366F1);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Reading Type Selector ──────────────────────────────────────
          _buildLabel("Select Reading Type", titleColor),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primaryBlue.withOpacity(0.15)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedReadingType,
                isExpanded: true,
                dropdownColor: cardBg,
                icon: Icon(Icons.expand_more_rounded, color: subColor),
                items: _readingTypes.map((rt) {
                  return DropdownMenuItem(
                    value: rt['value'],
                    child: Row(
                      children: [
                        Icon(Icons.speed_rounded, color: primaryBlue, size: 16),
                        const SizedBox(width: 10),
                        Text(rt['label']!, style: GoogleFonts.outfit(color: titleColor, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedReadingType = val;
                      _populateFields();
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Previous Values Card ───────────────────────────────────────
          if (_hasExistingData) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6B35).withOpacity(0.08),
                    const Color(0xFFFF8C42).withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B35).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.history_rounded, color: Color(0xFFFF6B35), size: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "CURRENT VALUES",
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFFF6B35),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPrevValueTile(
                          icon: Icons.speed_rounded,
                          label: "Odometer",
                          value: _prevOdometer != null ? "${_prevOdometer!} km" : "N/A",
                          isDark: isDark,
                          titleColor: titleColor,
                          subColor: subColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPrevValueTile(
                          icon: Icons.access_time_rounded,
                          label: "Reading Time",
                          value: _prevTime != null
                              ? DateFormat('dd MMM\nhh:mm a').format(_prevTime!)
                              : "N/A",
                          isDark: isDark,
                          titleColor: titleColor,
                          subColor: subColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            // No existing data warning
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.red, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "No data recorded for this checkpoint yet. Only existing readings can be edited.",
                      style: GoogleFonts.outfit(fontSize: 13, color: Colors.red.shade700, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Arrow indicating change ────────────────────────────────────
          if (_hasExistingData) ...[
            Row(
              children: [
                Expanded(child: Divider(color: subColor.withOpacity(0.2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_downward_rounded, color: primaryBlue, size: 16),
                      const SizedBox(width: 4),
                      Text("Update to new values", style: GoogleFonts.outfit(color: primaryBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(child: Divider(color: subColor.withOpacity(0.2))),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // ── New Odometer ───────────────────────────────────────────────
          _buildLabel("New Odometer Reading", titleColor),
          const SizedBox(height: 8),
          TextField(
            controller: _odometerController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.outfit(color: titleColor, fontWeight: FontWeight.w600, fontSize: 15),
            enabled: _hasExistingData,
            decoration: InputDecoration(
              filled: true,
              fillColor: _hasExistingData ? inputBg : subColor.withOpacity(0.05),
              hintText: _hasExistingData ? "e.g. 48200.5" : "No data to edit",
              hintStyle: GoogleFonts.outfit(color: subColor.withOpacity(0.6)),
              prefixIcon: Icon(Icons.speed_rounded, color: _hasExistingData ? primaryBlue : subColor, size: 20),
              suffixText: "km",
              suffixStyle: TextStyle(color: subColor, fontWeight: FontWeight.bold),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryBlue.withOpacity(0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryBlue, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── New Time ───────────────────────────────────────────────────
          _buildLabel("New Reading Time", titleColor),
          const SizedBox(height: 8),
          TextField(
            controller: _timeController,
            readOnly: true,
            onTap: _hasExistingData ? _pickDateTime : null,
            style: GoogleFonts.outfit(color: titleColor, fontWeight: FontWeight.w600, fontSize: 15),
            decoration: InputDecoration(
              filled: true,
              fillColor: _hasExistingData ? inputBg : subColor.withOpacity(0.05),
              hintText: _hasExistingData ? "Tap to select date & time" : "No data to edit",
              hintStyle: GoogleFonts.outfit(color: subColor.withOpacity(0.6)),
              prefixIcon: Icon(Icons.calendar_today_rounded, color: _hasExistingData ? primaryBlue : subColor, size: 18),
              suffixIcon: _hasExistingData
                  ? Icon(Icons.edit_calendar_rounded, color: primaryBlue.withOpacity(0.6), size: 18)
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryBlue.withOpacity(0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryBlue, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Mistake By ────────────────────────────────────────────────
          _buildLabel("Mistake By", titleColor),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primaryBlue.withOpacity(0.15)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _mistakeIsOnId,
                isExpanded: true,
                dropdownColor: cardBg,
                icon: Icon(Icons.expand_more_rounded, color: subColor),
                items: _mistakeOptions.map((m) {
                  return DropdownMenuItem<int>(
                    value: m['id'],
                    child: Row(
                      children: [
                        Icon(Icons.person_outline_rounded, color: primaryBlue, size: 16),
                        const SizedBox(width: 10),
                        Text(m['name'], style: GoogleFonts.outfit(color: titleColor, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _mistakeIsOnId = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Remarks ───────────────────────────────────────────────────
          _buildLabel("Reason for Edit", titleColor),
          const SizedBox(height: 8),
          TextField(
            controller: _remarkController,
            maxLines: 3,
            style: GoogleFonts.outfit(color: titleColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: inputBg,
              hintText: "Describe why you are changing this data...",
              hintStyle: GoogleFonts.outfit(color: subColor.withOpacity(0.6)),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(Icons.notes_rounded, color: Color(0xFF6366F1), size: 20),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryBlue.withOpacity(0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primaryBlue, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Submit Button ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (_isLoading || !_hasExistingData) ? null : _updateRunData,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                disabledBackgroundColor: subColor.withOpacity(0.2),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Update Run Data",
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        color: color,
        fontWeight: FontWeight.w800,
        fontSize: 13,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildPrevValueTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required Color titleColor,
    required Color subColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFF6B35), size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: subColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: titleColor,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
