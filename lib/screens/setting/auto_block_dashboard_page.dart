import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/utils/toast_utils.dart';
import 'package:tripzo/store/isdark.dart';

class AutoBlockDashboardPage extends StatefulWidget {
  const AutoBlockDashboardPage({Key? key}) : super(key: key);

  @override
  State<AutoBlockDashboardPage> createState() => _AutoBlockDashboardPageState();
}

class _AutoBlockDashboardPageState extends State<AutoBlockDashboardPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  String _searchQuery = "";
  int _selectedTab = 0; // 0 = Warnings, 1 = Blocks

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);
    try {
      final token = await UserStore.getToken();
      String url = ApiConstants.getAutoBlockStats;
      if (_searchQuery.isNotEmpty) {
        url += "?search=$_searchQuery";
      }
      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(token),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _stats = data['data'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching auto block stats: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(int id, String reason) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );
      final token = await UserStore.getToken();
      final response = await http.post(
        Uri.parse(ApiConstants.unblockUser(id)),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode({"unblock_reason": reason}),
      );
      
      if (mounted) Navigator.pop(context); // pop loading dialog
      
      if (response.statusCode == 200) {
        showTopToast(context, "User unblocked successfully");
        _fetchStats();
      } else {
        final err = jsonDecode(response.body);
        showTopToast(context, err['message'] ?? "Failed to unblock", isError: true);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      showTopToast(context, e.toString(), isError: true);
    }
  }

  void _showUnblockModal(Map<String, dynamic> blockItem) {
    final user = blockItem['blocked_user'];
    final TextEditingController reasonController = TextEditingController();
    final isDark = ThemeStore.isDark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Unblock ${user['name'] ?? 'User'}",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "They will regain access to the transport portal immediately.",
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: reasonController,
                style: TextStyle(color: titleColor),
                decoration: InputDecoration(
                  labelText: "Reason (Optional)",
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFF10B981))),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981), // Emerald 500
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _unblockUser(user['id'], reasonController.text);
                      },
                      child: Text(
                        "Confirm",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSettingsModal() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final token = await UserStore.getToken();
      final response = await http.get(
        Uri.parse(ApiConstants.getAutoBlockSettings),
        headers: ApiConstants.getHeaders(token),
      );
      
      if (mounted) Navigator.pop(context); // pop loading dialog
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          _showSettingsBottomSheet(data['data']);
        } else {
          _showSettingsBottomSheet({});
        }
      } else {
        showTopToast(context, "Failed to load settings", isError: true);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      showTopToast(context, e.toString(), isError: true);
    }
  }

  void _showSettingsBottomSheet(Map<String, dynamic> initialSettings) {
    bool isActive = initialSettings['is_active'] ?? false;
    bool blockModeDay = (initialSettings['block_mode'] ?? 'SHIFT') == 'DAY';
    bool studentActive = initialSettings['student_active'] ?? true;
    bool facultyActive = initialSettings['faculty_active'] ?? true;
    bool nonTeachingActive = initialSettings['non_teaching_active'] ?? true;
    bool internActive = initialSettings['intern_active'] ?? true;

    final isDark = ThemeStore.isDark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.grey.shade50;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Widget _buildToggleRow(String title, String subtitle, bool value, Function(bool) onChanged) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: titleColor, fontSize: 14)),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey)),
                          ],
                        ],
                      ),
                    ),
                    Switch(
                      value: value,
                      activeColor: Colors.indigoAccent,
                      onChanged: onChanged,
                    ),
                  ],
                ),
              );
            }

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Auto-Block Settings",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: titleColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildToggleRow(
                            "Enable Automatic Blocking",
                            "Master toggle for the auto-block system",
                            isActive,
                            (val) => setModalState(() => isActive = val),
                          ),
                          const SizedBox(height: 12),
                          Text("Block Mode Strategy", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: titleColor)),
                          const SizedBox(height: 8),
                          _buildToggleRow(
                            "Use Full Day Blocking?",
                            "Shift-Wise: 1 warning per missed shift (Max 2/day).\nFull Day: 1 warning total per day if any shift is missed.",
                            blockModeDay,
                            (val) => setModalState(() => blockModeDay = val),
                          ),
                          const SizedBox(height: 12),
                          Text("Role Specific Toggles", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: titleColor)),
                          const SizedBox(height: 8),
                          _buildToggleRow("Students", "", studentActive, (val) => setModalState(() => studentActive = val)),
                          _buildToggleRow("Faculty", "", facultyActive, (val) => setModalState(() => facultyActive = val)),
                          _buildToggleRow("Non-Teaching", "", nonTeachingActive, (val) => setModalState(() => nonTeachingActive = val)),
                          _buildToggleRow("Interns", "", internActive, (val) => setModalState(() => internActive = val)),
                          const SizedBox(height: 8),
                          Text("* Toggling a role off pauses the auto-blocking checks. Previous warning counts will be retained.", style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                      color: bgColor,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5), // Indigo 600
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () async {
                              // Save settings
                              Navigator.pop(context);
                              await _saveSettings({
                                "is_active": isActive,
                                "block_mode": blockModeDay ? "DAY" : "SHIFT",
                                "student_active": studentActive,
                                "faculty_active": facultyActive,
                                "non_teaching_active": nonTeachingActive,
                                "intern_active": internActive,
                              });
                            },
                            child: Text(
                              "Save Settings",
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Future<void> _saveSettings(Map<String, dynamic> payload) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final token = await UserStore.getToken();
      final response = await http.put(
        Uri.parse(ApiConstants.updateAutoBlockSettings),
        headers: ApiConstants.getHeaders(token),
        body: jsonEncode(payload),
      );
      if (mounted) Navigator.pop(context); // close loader
      
      if (response.statusCode == 200) {
        showTopToast(context, "Settings saved successfully");
      } else {
        final err = jsonDecode(response.body);
        showTopToast(context, err['message'] ?? "Failed to save settings", isError: true);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      showTopToast(context, e.toString(), isError: true);
    }
  }

  Widget _buildMetricCard(String title, dynamic value, Color iconColor, Color iconBgColor, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: iconBgColor.withOpacity(isDark ? 0.05 : 0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "$value",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: iconColor,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? iconColor.withOpacity(0.1) : iconBgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildListItems(bool isDark) {
    if (_selectedTab == 0) {
      final warnings = _stats?['recentWarnings'] ?? [];
      if (warnings.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text("No warnings found", style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
        );
      }
      return Column(
        children: List.generate(warnings.length, (index) {
          final w = warnings[index];
          final user = w['user'] ?? {};
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.amber.shade100,
                          child: Text((user['name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['name'] ?? 'Unknown', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                            Text(user['role']?['name'] ?? '', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "WARNING",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      );
    } else {
      final blocks = _stats?['recentBlocks'] ?? [];
      if (blocks.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text("No blocks found", style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
        );
      }
      return Column(
        children: List.generate(blocks.length, (index) {
          final b = blocks[index];
          final user = b['blocked_user'] ?? {};
          final bool isUnblocked = b['unblocked_at'] != null;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          child: Text((user['name'] ?? 'U')[0].toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['name'] ?? 'Unknown', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                            Text(user['role']?['name'] ?? '', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUnblocked ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isUnblocked ? "UNBLOCKED" : "BLOCKED",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isUnblocked ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isUnblocked) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showUnblockModal(b),
                      child: Text("Unblock User", style: GoogleFonts.plusJakartaSans(color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeStore.isDark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

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
          "Auto-Block Dashboard",
          style: GoogleFonts.plusJakartaSans(
            color: titleColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: titleColor),
            onPressed: _openSettingsModal,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SEARCH BAR ---
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  style: TextStyle(color: titleColor),
                  decoration: InputDecoration(
                    hintText: "Search by name or roll no...",
                    hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                            onPressed: () {
                              setState(() => _searchQuery = "");
                              _fetchStats();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: (val) {
                    setState(() => _searchQuery = val);
                    _fetchStats();
                  },
                ),
              ),
              const SizedBox(height: 24),

              // --- METRIC CARDS ---
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      "Warnings", 
                      _isLoading ? "-" : _stats?['totalWarnings'] ?? 0, 
                      const Color(0xFFD97706), 
                      const Color(0xFFFEF3C7), 
                      Icons.warning_rounded,
                      isDark
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      "Blocks", 
                      _isLoading ? "-" : _stats?['totalBlocks'] ?? 0, 
                      const Color(0xFFE11D48), 
                      const Color(0xFFFFE4E6), 
                      Icons.person_off_rounded,
                      isDark
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // --- TOGGLE TAB BAR ---
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? (isDark ? const Color(0xFF334155) : Colors.white) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedTab == 0 ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "Recent Warnings",
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _selectedTab == 0 ? (isDark ? Colors.white : Colors.black) : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTab = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? (isDark ? const Color(0xFF334155) : Colors.white) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _selectedTab == 1 ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "Recent Blocks",
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _selectedTab == 1 ? (isDark ? Colors.white : Colors.black) : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- LIST CONTENT ---
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _buildListItems(isDark),
                
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
