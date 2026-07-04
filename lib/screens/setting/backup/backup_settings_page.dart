import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/utils/toast_utils.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tripzo/utils/download_helper.dart';

class BackupSettingsPage extends StatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  bool _isLoading = true;
  bool _isManualBackupLoading = false;
  Map<String, dynamic> _dashboardData = {};
  List<dynamic> _backups = [];

  bool _emailNotifications = false;
  int _maxBackups = 5;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
    _fetchSettings();
  }

  Future<void> _fetchDashboard() async {
    try {
      final token = await UserStore.getToken();
      final response = await http.get(
        Uri.parse("${ApiConstants.baseUrl}/api/backups/dashboard"),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _dashboardData = data['data']['cards'] ?? {};
            _backups = data['data']['backups'] ?? [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showTopToast(context, "Error fetching backups: $e", isError: true);
      }
    }
  }

  Future<void> _fetchSettings() async {
    try {
      final token = await UserStore.getToken();
      final response = await http.get(
        Uri.parse("${ApiConstants.baseUrl}/api/backups/settings"),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _emailNotifications = data['data']['email_notifications'] ?? false;
            _maxBackups = data['data']['max_backups'] ?? 5;
          });
        }
      }
    } catch (e) {
      debugPrint("Settings fetch error: $e");
    }
  }

  Future<void> _updateSettings(int maxBackups, bool emailNotifications) async {
    try {
      final token = await UserStore.getToken();
      final response = await http.put(
        Uri.parse("${ApiConstants.baseUrl}/api/backups/settings"),
        headers: ApiConstants.getHeaders(token),
        body: json.encode({
          "max_backups": maxBackups,
          "email_notifications": emailNotifications,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _maxBackups = maxBackups;
            _emailNotifications = emailNotifications;
          });
          if (mounted) {
            showTopToast(context, "Settings updated successfully");
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, "Error updating settings: $e", isError: true);
      }
    }
  }

  Future<void> _showSettingsDialog() async {
    int tempMaxBackups = _maxBackups;
    bool tempEmailNotifications = _emailNotifications;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
          final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
          final primaryBlue = const Color(0xFF6366F1);

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 24,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
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
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.settings_suggest_rounded,
                        color: primaryBlue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      "Backup Settings",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Maximum Backups",
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: titleColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Keep only the most recent files",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    if (tempMaxBackups > 1) {
                                      setModalState(() => tempMaxBackups--);
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.remove_rounded,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  "$tempMaxBackups",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    color: primaryBlue,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    if (tempMaxBackups < 20) {
                                      setModalState(() => tempMaxBackups++);
                                    }
                                  },
                                  icon: Icon(
                                    Icons.add_rounded,
                                    color: primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: primaryBlue,
                        title: Text(
                          "Email Notifications",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: titleColor,
                          ),
                        ),
                        subtitle: Text(
                          "Receive updates on automated backups",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        value: tempEmailNotifications,
                        onChanged: (val) {
                          setModalState(() => tempEmailNotifications = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _updateSettings(tempMaxBackups, tempEmailNotifications);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "Save Preferences",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Future<void> _createManualBackup(String password) async {
    setState(() => _isManualBackupLoading = true);
    try {
      final token = await UserStore.getToken();
      final response = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/api/backups/manual"),
        headers: ApiConstants.getHeaders(token),
        body: json.encode({"password": password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            showTopToast(context, "Backup created successfully");
            _fetchDashboard();
          }
        } else {
          if (mounted) {
            showTopToast(
              context,
              data['message'] ?? "Error creating backup",
              isError: true,
            );
          }
        }
      } else {
        if (mounted) {
          showTopToast(
            context,
            "Invalid password or server error",
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, "Network error: $e", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isManualBackupLoading = false);
      }
    }
  }

  Future<void> _showManualBackupDialog() async {
    final TextEditingController passwordController = TextEditingController();
    bool obscureText = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
          final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
          final primaryBlue = const Color(0xFF6366F1);

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 24,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
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
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.security_rounded,
                      color: primaryBlue,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    "Admin Verification",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    "Enter your Super Admin password to proceed\nwith the manual backup creation.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: TextField(
                    controller: passwordController,
                    obscureText: obscureText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                      letterSpacing: obscureText ? 4.0 : 1.0,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(20),
                      hintText: "Enter Password",
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: Colors.grey,
                        fontWeight: FontWeight.normal,
                        letterSpacing: 1.0,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.lock_outline_rounded,
                        color: primaryBlue,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureText
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setModalState(() {
                            obscureText = !obscureText;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          "Cancel",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          if (passwordController.text.isNotEmpty) {
                            Navigator.pop(context);
                            _createManualBackup(passwordController.text);
                          } else {
                            showTopToast(
                              context,
                              "Password is required",
                              isError: true,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "Start Backup",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
      ),
    );
  }

  Future<void> _downloadBackup(int id) async {
    try {
      final token = await UserStore.getToken();
      showTopToast(context, "Downloading backup...");
      final response = await http.get(
        Uri.parse("${ApiConstants.baseUrl}/api/backups/download/$id"),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await downloadFile(bytes, "backup_$id.sql");
        showTopToast(context, "Backup downloaded successfully");
      } else {
        showTopToast(context, "Failed to download", isError: true);
      }
    } catch (e) {
      showTopToast(context, "Error: $e", isError: true);
    }
  }

  Future<void> _deleteBackup(int id) async {
    try {
      final token = await UserStore.getToken();
      final response = await http.delete(
        Uri.parse("${ApiConstants.baseUrl}/api/backups/$id"),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            showTopToast(context, "Backup deleted successfully");
            _fetchDashboard();
          }
        }
      } else {
        if (mounted) {
          showTopToast(context, "Failed to delete backup", isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, "Network error: $e", isError: true);
      }
    }
  }

  Future<void> _showDeleteConfirmDialog(int id) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Backup"),
        content: const Text(
          "Are you sure you want to delete this backup? This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteBackup(id);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Database Backups",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: _isLoading
          ? _buildShimmerLoading(isDark, cardColor, primaryBlue)
          : RefreshIndicator(
              onRefresh: _fetchDashboard,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            "Total",
                            _dashboardData['total_backups']?.toString() ?? "0",
                            Icons.storage,
                            cardColor,
                            primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              double totalSize = 0.0;
                              for (var backup in _backups) {
                                if (backup['file_size_mb'] != null) {
                                  totalSize += double.tryParse(backup['file_size_mb'].toString()) ?? 0.0;
                                }
                              }
                              return _buildStatCard(
                                "Total Size",
                                "${totalSize.toStringAsFixed(2)} MB",
                                Icons.data_usage,
                                cardColor,
                                Colors.orange,
                              );
                            }
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Manual Backup Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isManualBackupLoading
                            ? null
                            : _showManualBackupDialog,
                        icon: _isManualBackupLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.backup, color: Colors.white),
                        label: Text(
                          _isManualBackupLoading
                              ? "Creating..."
                              : "Create Manual Backup",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    const Text(
                      "Recent Backups",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_backups.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            "No backups found",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _backups.length,
                        itemBuilder: (context, index) {
                          final backup = _backups[index];
                          return _buildBackupItem(
                            backup,
                            cardColor,
                            primaryBlue,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildShimmerLoading(bool isDark, Color cardColor, Color primaryBlue) {
    final Color baseColor = isDark ? Colors.white10 : Colors.grey[300]!;
    final Color highlightColor = isDark ? Colors.white24 : Colors.grey[100]!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              height: 24,
              width: 150,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Shimmer.fromColors(
                baseColor: baseColor,
                highlightColor: highlightColor,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  height: 140,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color cardColor,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBackupItem(dynamic backup, Color cardColor, Color primaryColor) {
    final DateTime createdAt = DateTime.parse(backup['createdAt']);
    final formattedDate = DateFormat(
      'MMM dd, yyyy - hh:mm a',
    ).format(createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  backup['backup_name'] ?? "",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: backup['backup_type'] == 'MANUAL'
                      ? Colors.blue.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  backup['backup_type'] ?? "",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: backup['backup_type'] == 'MANUAL'
                        ? Colors.blue
                        : Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.table_chart_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${backup['total_tables']} tables",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.sd_storage_outlined,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${backup['file_size_mb']} MB",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    onPressed: () => _downloadBackup(backup['id']),
                    icon: const Icon(
                      Icons.download_rounded,
                      color: Colors.blue,
                    ),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    onPressed: () => _showDeleteConfirmDialog(backup['id']),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedDate,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                "By: ${backup['created_by_username'] ?? 'System'}",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
