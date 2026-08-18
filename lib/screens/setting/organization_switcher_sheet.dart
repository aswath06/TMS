import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/utils/toast_utils.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/store/isdark.dart';

class OrganizationSwitcherSheet extends StatefulWidget {
  const OrganizationSwitcherSheet({super.key});

  @override
  State<OrganizationSwitcherSheet> createState() => _OrganizationSwitcherSheetState();
}

class _OrganizationSwitcherSheetState extends State<OrganizationSwitcherSheet> {
  bool _isLoading = true;
  List<dynamic> _organizations = [];
  dynamic _currentOrgId;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final token = await UserStore.getToken();
      
      if (token != null) {
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            final payload = parts[1];
            final String normalized = base64Url.normalize(payload);
            final String resp = utf8.decode(base64Url.decode(normalized));
            final Map<String, dynamic> jwtData = json.decode(resp);
            _currentOrgId = jwtData['organization_id'];
          }
        } catch (e) {
          // Ignore JWT parse error
        }
      }

      final response = await http.get(
        Uri.parse("${ApiConstants.baseUrl}/auth/organizations"),
        headers: ApiConstants.getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (mounted) {
            setState(() {
              _organizations = data['data'];
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showTopToast(context, "Failed to load organizations", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeStore.isDark;
    final Color bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color primaryBlue = const Color(0xFF6366F1);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 32),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
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
          Text(
            "Switch Organization",
            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: titleColor),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_organizations.isEmpty)
            Expanded(
              child: Center(
                child: Text("No organizations found.", style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _organizations.length,
                itemBuilder: (context, index) {
                  final org = _organizations[index];
                  final bool isCurrent = org['id'] == _currentOrgId;
                  final bool isActive = org['status'] == 'ACTIVE';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
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
                      title: Text(
                        org['name'] ?? 'Unnamed',
                        style: GoogleFonts.plusJakartaSans(color: titleColor, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        org['status'] ?? 'INACTIVE',
                        style: GoogleFonts.plusJakartaSans(
                          color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: isCurrent
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "CURRENT",
                                style: GoogleFonts.plusJakartaSans(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                ),
                              ),
                            )
                          : const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                      onTap: () {
                        if (!isCurrent && isActive) {
                          Navigator.pop(context, org); // Close sheet and return org
                        } else if (!isActive) {
                          showTopToast(context, "Cannot switch to an inactive organization", isError: true);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _switchOrganization(BuildContext context, dynamic orgId, String orgName) async {
  try {
    final token = await UserStore.getToken();
    final response = await http.post(
      Uri.parse("${ApiConstants.baseUrl}/auth/organizations/switch-token"),
      headers: ApiConstants.getHeaders(token),
      body: json.encode({"orgId": orgId}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final newToken = data['token'];
        
        await UserStore.saveUserData(
          token: newToken,
          role: UserStore.role ?? '',
          email: UserStore.email ?? '',
          id: UserStore.userId ?? 0,
          name: UserStore.name ?? '',
        );

        if (context.mounted) {
          Navigator.pop(context); // Close the password sheet
          showTopToast(context, "Successfully switched to $orgName. Please restart the app or login again to apply changes.", isError: false);
        }
      } else {
        if (context.mounted) showTopToast(context, data['message'] ?? "Failed to switch", isError: true);
      }
    } else {
      if (context.mounted) showTopToast(context, "Server error: ${response.statusCode}", isError: true);
    }
  } catch (e) {
    if (context.mounted) showTopToast(context, "Connection error", isError: true);
  }
}

void _showPasswordPrompt(BuildContext context, dynamic org) {
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
                Text("Confirm Switch", style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold, color: titleColor)),
                const SizedBox(height: 12),
                Text(
                  "Please enter your password to switch to ${org['name']}.",
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
                        onPressed: () async {
                          final pin = pinController.text.trim();
                          if (pin.isEmpty) {
                            showTopToast(context, "Please enter your password", isError: true);
                            return;
                          }
                          
                          // Verify Pin inline
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
                                await _switchOrganization(context, org['id'], org['name']);
                              } else {
                                if (context.mounted) showTopToast(context, verifyData['message'] ?? "Invalid password", isError: true);
                              }
                            } else {
                              if (context.mounted) showTopToast(context, "Password verification failed", isError: true);
                            }
                          } catch (e) {
                            if (context.mounted) showTopToast(context, "Connection error", isError: true);
                          }
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

void showOrganizationSwitcherSheet(BuildContext context) async {
  final selectedOrg = await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const OrganizationSwitcherSheet(),
  );

  if (selectedOrg != null && context.mounted) {
    _showPasswordPrompt(context, selectedOrg);
  }
}
