import 'package:flutter/material.dart';
import 'package:tms/components/profile/info_card.dart';
import 'package:tms/components/profile/profile_hero.dart';
import 'package:tms/components/profile/typing_text.dart';
import 'package:tms/screens/setting/settings_page.dart';
import 'package:tms/store/admin_store.dart';

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
        : const Color(0xFFF1F5F9);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark),
          RefreshIndicator(
            onRefresh: () => useAdminStore.fetchProfile(),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverSafeArea(
                  sliver: SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHeader(context, titleColor),
                        const SizedBox(height: 30),
                        ValueListenableBuilder(
                          valueListenable: useAdminStore.isLoading,
                          builder: (context, isLoading, child) {
                            return ValueListenableBuilder(
                              valueListenable: useAdminStore.errorMessage,
                              builder: (context, error, child) {
                                if (error != null)
                                  return _buildErrorState(error, titleColor);
                                return ValueListenableBuilder(
                                  valueListenable: useAdminStore.adminData,
                                  builder: (context, data, child) {
                                    return _buildProfileContent(
                                      data,
                                      isLoading,
                                      isDark,
                                      titleColor,
                                      cardColor,
                                      subColor,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ]),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(
    Map<String, dynamic>? data,
    bool isLoading,
    bool isDark,
    Color titleColor,
    Color cardColor,
    Color subColor,
  ) {
    bool showTyping = isLoading && data == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileHero(
          name: showTyping ? "..." : (data?['name'] ?? "Admin User"),
          subtitle: showTyping
              ? "Updating..."
              : "System Administrator • ${data?['user_name'] ?? 'admin'}",
          cardColor: cardColor,
          titleColor: titleColor,
          subColor: subColor,
          isDark: isDark,
        ),
        const SizedBox(height: 32),
        _buildSectionTitle("Account Details", titleColor),
        const SizedBox(height: 16),
        _buildMenuGrid(data, isLoading, cardColor, titleColor, subColor),
        const SizedBox(height: 32),
        _buildSectionTitle("Administrative Files", titleColor),
        const SizedBox(height: 16),
        _buildFileSection(cardColor, titleColor, subColor),
      ],
    );
  }

  Widget _buildMenuGrid(
    Map<String, dynamic>? data,
    bool isLoading,
    Color cardColor,
    Color titleColor,
    Color subColor,
  ) {
    final List<Map<String, dynamic>> items = [
      {
        'title': 'Email',
        'val': data?['email'],
        'icon': Icons.email,
        'color': Colors.blue,
      },
      {
        'title': 'Phone',
        'val': data?['phone'],
        'icon': Icons.phone,
        'color': Colors.green,
      },
      {
        'title': 'Role',
        'val': 'Admin',
        'icon': Icons.security,
        'color': Colors.amber,
      },
      {
        'title': 'Status',
        'val': data?['isLogin'] == true ? 'Active' : 'Offline',
        'icon': Icons.check_circle,
        'color': Colors.indigo,
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
        childAspectRatio: 1.3,
      ),
      itemBuilder: (context, i) {
        final item = items[i];
        bool isDataMissing = (item['val'] == null && isLoading);

        return InfoCard(
          title: item['title'],
          value: isDataMissing ? "" : item['val'].toString(),
          valueWidget: isDataMissing
              ? TypingText(
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
          icon: item['icon'],
          iconColor: item['color'],
          cardColor: cardColor,
          titleColor: titleColor,
          subColor: subColor,
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Color titleColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Admin Profile",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          ),
          icon: const Icon(Icons.settings),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 20, color: const Color(0xFF6366F1)),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error, Color titleColor) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 10),
          Text(error, style: TextStyle(color: titleColor)),
          TextButton(
            onPressed: () => useAdminStore.fetchProfile(),
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSection(Color cardColor, Color titleColor, Color subColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: Colors.red),
          const SizedBox(width: 16),
          Text(
            "Access_Logs.pdf",
            style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Icon(Icons.download, color: subColor),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecor(bool isDark) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Colors.blue.withOpacity(0.05),
            ),
          ),
        ],
      ),
    );
  }
}
