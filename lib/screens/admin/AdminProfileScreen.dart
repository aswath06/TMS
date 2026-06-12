import 'package:flutter/material.dart';
import 'package:tripzo/screens/setting/settings_page.dart';
import 'package:tripzo/store/admin_store.dart';
import 'package:tripzo/screens/setting/scanner_page.dart';
import 'package:tripzo/utils/toast_utils.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  @override
  void initState() {
    super.initState();
    if (useAdminStore.adminData.value == null) {
      useAdminStore.fetchProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark, primaryBlue),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => useAdminStore.fetchProfile(),
              color: primaryBlue,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  _buildHeader(context, titleColor, primaryBlue),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 10),
                        ValueListenableBuilder(
                          valueListenable: useAdminStore.isLoading,
                          builder: (context, isLoading, child) {
                            return ValueListenableBuilder(
                              valueListenable: useAdminStore.errorMessage,
                              builder: (context, error, child) {
                                if (error != null) {
                                  return _buildErrorState(error, titleColor, primaryBlue);
                                }
                                return ValueListenableBuilder(
                                  valueListenable: useAdminStore.adminData,
                                  builder: (context, data, child) {
                                    return _buildProfileContent(
                                      context,
                                      data,
                                      isLoading,
                                      isDark,
                                      titleColor,
                                      surfaceColor,
                                      primaryBlue,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 120),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color titleColor, Color primaryBlue) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Admin Center",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Control Dashboard",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _buildCircularButton(
                  Icons.settings_outlined,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ),
                  Colors.grey.shade500,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularButton(IconData icon, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Icon(icon, size: 22, color: color),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    Map<String, dynamic>? profileData,
    bool isLoading,
    bool isDark,
    Color titleColor,
    Color surfaceColor,
    Color primaryBlue,
  ) {
    if (isLoading && profileData == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 100),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final String name = profileData?['name'] ?? "Admin User";
    final String username = profileData?['user_name'] ?? 'admin';
    final String roleStr = _getRoleName(profileData?['role']).toLowerCase();
    final bool showScanner = roleStr.contains('super admin') || roleStr.contains('transport admin');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileHero(profileData, name, username, isDark, surfaceColor, primaryBlue),
        const SizedBox(height: 32),
        _buildSectionTitle("System Access", titleColor, primaryBlue),
        const SizedBox(height: 16),
        _buildInfoGrid(profileData, isDark, surfaceColor, primaryBlue),
        if (showScanner) ...[
          const SizedBox(height: 32),
          _buildSectionTitle("Quick Actions", titleColor, primaryBlue),
          const SizedBox(height: 16),
          _buildScannerTile(context, isDark, surfaceColor, titleColor, primaryBlue),
        ],
      ],
    );
  }

  Widget _buildProfileHero(
    Map<String, dynamic>? profileData,
    String name,
    String username,
    bool isDark,
    Color surfaceColor,
    Color primaryBlue,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [primaryBlue, primaryBlue.withOpacity(0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Icon(
                Icons.admin_panel_settings_rounded,
                size: 50,
                color: primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "${_getRoleName(profileData?['role'])} • @$username",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getRoleName(dynamic role) {
    if (role == null) return 'Administrator';
    String roleStr = '';
    if (role is String) {
      roleStr = role;
    } else if (role is Map) {
      roleStr = role['name'] ?? role['code'] ?? role.toString();
    } else {
      roleStr = role.toString();
    }

    return roleStr.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Widget _buildInfoGrid(
    Map<String, dynamic>? profileData,
    bool isDark,
    Color surfaceColor,
    Color primaryBlue,
  ) {
    final List<Map<String, dynamic>> items = [
      {
        'title': 'Email Address',
        'val': profileData?['email'] ?? 'N/A',
        'icon': Icons.alternate_email_rounded,
        'color': Colors.blue,
      },
      {
        'title': 'Contact Number',
        'val': profileData?['phone'] ?? 'N/A',
        'icon': Icons.phone_android_rounded,
        'color': Colors.green,
      },
      {
        'title': 'Login Status',
        'val': profileData?['isLogin'] == true ? 'Online' : 'Active',
        'icon': Icons.bolt_rounded,
        'color': Colors.amber,
      },
      {
        'title': 'Authority Role',
        'val': _getRoleName(profileData?['role']),
        'icon': Icons.verified_rounded,
        'color': primaryBlue,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemBuilder: (context, i) {
        final item = items[i];
        return _buildInfoCard(item, isDark, surfaceColor);
      },
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> item, bool isDark, Color surfaceColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item['color'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item['icon'], size: 18, color: item['color']),
          ),
          const Spacer(),
          Text(
            item['val'],
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            item['title'],
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color, Color primaryBlue) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error, Color titleColor, Color primaryBlue) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 60),
          const SizedBox(height: 20),
          Text(
            error,
            style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => useAdminStore.fetchProfile(),
            child: const Text("Retry Connection", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecor(bool isDark, Color primaryBlue) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: CircleAvatar(
              radius: 200,
              backgroundColor: primaryBlue.withOpacity(0.03),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: primaryBlue.withOpacity(0.02),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerTile(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color titleColor,
    Color primaryBlue,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        ),
      ),
      child: ListTile(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ScannerPage(),
            ),
          );
          if (result != null) {
            showTopToast(context, "Scanned: $result");
          }
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.qr_code_scanner_rounded, color: primaryBlue, size: 22),
        ),
        title: Text(
          "Scan Code",
          style: TextStyle(fontWeight: FontWeight.w800, color: titleColor),
        ),
        subtitle: Text(
          "Scan using camera",
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }
}
