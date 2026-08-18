import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/utils/toast_utils.dart';
import 'package:tripzo/store/isdark.dart';

class OrganizationManagementPage extends StatefulWidget {
  const OrganizationManagementPage({super.key});

  @override
  State<OrganizationManagementPage> createState() => _OrganizationManagementPageState();
}

class _OrganizationManagementPageState extends State<OrganizationManagementPage> {
  List<dynamic> _organizations = [];
  bool _isLoading = true;
  String _error = "";
  int? _currentOrgId;

  @override
  void initState() {
    super.initState();
    _fetchCurrentOrgId();
    _fetchOrganizations();
  }

  Future<void> _fetchCurrentOrgId() async {
    try {
      final token = await UserStore.getToken();
      if (token != null) {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final String normalized = base64Url.normalize(payload);
          final String resp = utf8.decode(base64Url.decode(normalized));
          final Map<String, dynamic> data = json.decode(resp);
          if (mounted) {
            setState(() {
              _currentOrgId = data['organization_id'];
            });
          }
        }
      }
    } catch (e) {
      // Ignore parse errors
    }
  }

  Future<void> _fetchOrganizations() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = "";
    });

    try {
      final token = await UserStore.getToken();
      final response = await http.get(
        Uri.parse(ApiConstants.getOrganizations),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _organizations = data['data'] ?? [];
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _error = data['message'] ?? "Failed to fetch organizations";
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = "Server error: ${response.statusCode}";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Connection error: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createOrganization(String name) async {
    try {
      final token = await UserStore.getToken();
      final response = await http.post(
        Uri.parse(ApiConstants.createOrganization),
        headers: ApiConstants.getHeaders(token),
        body: json.encode({"name": name}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            showTopToast(context, "Organization created successfully");
            _fetchOrganizations();
          }
        } else {
          if (mounted) {
            showTopToast(context, data['message'] ?? "Failed to create", isError: true);
          }
        }
      } else {
        if (mounted) {
          showTopToast(context, "Server error: ${response.statusCode}", isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, "Connection error", isError: true);
      }
    }
  }

  Future<void> _updateStatus(dynamic orgId, String status) async {
    try {
      final token = await UserStore.getToken();
      final response = await http.put(
        Uri.parse(ApiConstants.updateOrganizationStatus(orgId)),
        headers: ApiConstants.getHeaders(token),
        body: json.encode({"status": status}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            showTopToast(context, "Status updated successfully");
            _fetchOrganizations();
          }
        } else {
          if (mounted) {
            showTopToast(context, data['message'] ?? "Failed to update status", isError: true);
          }
        }
      } else {
        if (mounted) {
          showTopToast(context, "Server error: ${response.statusCode}", isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showTopToast(context, "Connection error", isError: true);
      }
    }
  }

  Future<void> _editOrganization(dynamic orgId, String newName) async {
    try {
      final token = await UserStore.getToken();
      final response = await http.put(
        Uri.parse(ApiConstants.editOrganization(orgId)),
        headers: ApiConstants.getHeaders(token),
        body: json.encode({"name": newName}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) showTopToast(context, "Organization updated successfully");
          _fetchOrganizations();
        } else {
          if (mounted) showTopToast(context, data['message'] ?? "Update failed", isError: true);
        }
      } else {
        if (mounted) showTopToast(context, "Server error", isError: true);
      }
    } catch (e) {
      if (mounted) showTopToast(context, "Connection error", isError: true);
    }
  }

  Future<void> _deleteOrganization(dynamic orgId) async {
    try {
      final token = await UserStore.getToken();
      final response = await http.delete(
        Uri.parse(ApiConstants.deleteOrganization(orgId)),
        headers: ApiConstants.getHeaders(token),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) showTopToast(context, "Organization deleted successfully");
          _fetchOrganizations();
        } else {
          if (mounted) showTopToast(context, data['message'] ?? "Deletion failed", isError: true);
        }
      } else {
        if (mounted) showTopToast(context, "Server error", isError: true);
      }
    } catch (e) {
      if (mounted) showTopToast(context, "Connection error", isError: true);
    }
  }

  Future<void> _verifyPinAndExecute(String pin, Future<void> Function() action) async {
    try {
      final token = await UserStore.getToken();
      final verifyResponse = await http.post(
        Uri.parse(ApiConstants.verifyPin),
        headers: ApiConstants.getHeaders(token),
        body: json.encode({"pin": pin}),
      );

      if (verifyResponse.statusCode == 200) {
        final verifyData = json.decode(verifyResponse.body);
        if (verifyData['success'] == true) {
          await action();
        } else {
          if (mounted) showTopToast(context, verifyData['message'] ?? "Invalid password", isError: true);
        }
      } else {
        if (mounted) showTopToast(context, "Password verification failed", isError: true);
      }
    } catch (e) {
      if (mounted) showTopToast(context, "Connection error", isError: true);
    }
  }

  void _showPasswordPrompt(String title, String description, Future<void> Function() action) {
    final TextEditingController pinController = TextEditingController();
    bool isObscured = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isDark = ThemeStore.isDark;
        final Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color primaryBlue = const Color(0xFF6366F1);

        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                color: bgColor,
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
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: titleColor)),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: TextField(
                      controller: pinController,
                      obscureText: isObscured,
                      style: GoogleFonts.plusJakartaSans(color: titleColor),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(20),
                        hintText: "Password",
                        hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.lock_outline_rounded, color: primaryBlue),
                        suffixIcon: IconButton(
                          icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              isObscured = !isObscured;
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            final pin = pinController.text.trim();
                            if (pin.isEmpty) {
                              showTopToast(context, "Please enter your password", isError: true);
                              return;
                            }
                            Navigator.pop(context);
                            _verifyPinAndExecute(pin, action);
                          },
                          child: Text("Confirm", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showOrgOptionsSheet(dynamic org) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isDark = ThemeStore.isDark;
        final Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

        return Container(
          padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 32),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Text(org['name'] ?? 'Organization', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.edit_rounded, color: Colors.blue),
                ),
                title: Text("Edit Organization", style: GoogleFonts.plusJakartaSans(color: titleColor, fontWeight: FontWeight.bold)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(org);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(org['status'] == 'ACTIVE' ? Icons.pause_circle_rounded : Icons.play_circle_filled_rounded, color: Colors.orange),
                ),
                title: Text(org['status'] == 'ACTIVE' ? "Deactivate" : "Activate", style: GoogleFonts.plusJakartaSans(color: titleColor, fontWeight: FontWeight.bold)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onTap: () {
                  Navigator.pop(context);
                  final newStatus = org['status'] == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
                  _showPasswordPrompt(
                    "Confirm Status Update",
                    "Please enter your password to change the status to $newStatus.",
                    () async => await _updateStatus(org['id'], newStatus),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.delete_rounded, color: Colors.red),
                ),
                title: Text("Delete Organization", style: GoogleFonts.plusJakartaSans(color: Colors.red, fontWeight: FontWeight.bold)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onTap: () {
                  Navigator.pop(context);
                  _showPasswordPrompt(
                    "Confirm Deletion",
                    "Are you sure you want to delete ${org['name']}? This action is permanent.",
                    () async => await _deleteOrganization(org['id']),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(dynamic org) {
    final TextEditingController nameController = TextEditingController(text: org['name']);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isDark = ThemeStore.isDark;
        final Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color primaryBlue = const Color(0xFF6366F1);

        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            color: bgColor,
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
                    child: Icon(Icons.edit_rounded, color: primaryBlue, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Text("Edit Organization", style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: titleColor)),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: TextField(
                  controller: nameController,
                  style: GoogleFonts.plusJakartaSans(color: titleColor),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(20),
                    hintText: "Organization Name",
                    hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.business_center_outlined, color: primaryBlue),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text("Cancel", style: GoogleFonts.plusJakartaSans(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final newName = nameController.text.trim();
                        if (newName.isNotEmpty && newName != org['name']) {
                          Navigator.pop(context);
                          _showPasswordPrompt(
                            "Confirm Edit",
                            "Please enter your password to save changes.",
                            () async => await _editOrganization(org['id'], newName),
                          );
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: Text("Save", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateDialog() {
    final TextEditingController nameController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final bool isDark = ThemeStore.isDark;
        final Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final Color primaryBlue = const Color(0xFF6366F1);

        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                      Icons.business_rounded,
                      color: primaryBlue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    "Create Organization",
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
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: TextField(
                  controller: nameController,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(20),
                    hintText: "Organization Name",
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: Colors.grey,
                      fontWeight: FontWeight.normal,
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.business_center_outlined,
                      color: primaryBlue,
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
                        final name = nameController.text.trim();
                        if (name.isNotEmpty) {
                          Navigator.pop(context);
                          _createOrganization(name);
                        } else {
                          showTopToast(context, "Name cannot be empty", isError: true);
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
                        "Create",
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeStore.isDark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTitleColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: titleColor),
        title: Text(
          "Organization Management",
          style: GoogleFonts.plusJakartaSans(
            color: titleColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: primaryBlue,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_business_rounded, color: Colors.white),
        label: Text(
          "Add New",
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _fetchOrganizations,
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                        label: Text(
                          "Retry",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                )
              : _organizations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.business_rounded, size: 64, color: subTitleColor.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            "No organizations found.",
                            style: GoogleFonts.plusJakartaSans(
                              color: subTitleColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final displayedOrgs = _organizations;
                        if (displayedOrgs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.business_rounded, size: 64, color: subTitleColor.withValues(alpha: 0.5)),
                                const SizedBox(height: 16),
                                Text(
                                  "No active organization found.",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: subTitleColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: displayedOrgs.length,
                          itemBuilder: (context, index) {
                            final org = displayedOrgs[index];
                            final String status = org['status'] ?? 'INACTIVE';
                            final bool isActive = status == 'ACTIVE';
                            final bool isCurrent = org['id'] == _currentOrgId;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    _showOrgOptionsSheet(org);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: primaryBlue.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            (org['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                                            style: GoogleFonts.plusJakartaSans(
                                              color: primaryBlue,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                org['name'] ?? 'Unnamed',
                                                style: GoogleFonts.plusJakartaSans(
                                                  color: titleColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: (isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      status,
                                                      style: GoogleFonts.plusJakartaSans(
                                                        color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (isCurrent)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: primaryBlue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: primaryBlue.withValues(alpha: 0.2)),
                                            ),
                                            child: Text(
                                              "CURRENT",
                                              style: GoogleFonts.plusJakartaSans(
                                                color: primaryBlue,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }
                    ),
    );
  }
}
