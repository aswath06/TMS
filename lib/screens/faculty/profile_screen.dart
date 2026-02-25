import 'package:flutter/material.dart';
import 'package:tms/components/profile/info_card.dart';
import 'package:tms/components/profile/profile_hero.dart';
import 'package:tms/components/profile/typing_text.dart';
import 'package:tms/screens/setting/settings_page.dart';
import 'package:tms/store/faculty_store.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    if (useFacultyStore.profileData.value == null) {
      useFacultyStore.fetchProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark),
          RefreshIndicator(
            onRefresh: () => useFacultyStore.fetchProfile(),
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
                          valueListenable: useFacultyStore.isLoading,
                          builder: (context, isLoading, _) {
                            return ValueListenableBuilder(
                              valueListenable: useFacultyStore.errorMessage,
                              builder: (context, error, _) {
                                if (error != null) {
                                  return _buildErrorState(error, titleColor);
                                }
                                return ValueListenableBuilder(
                                  valueListenable: useFacultyStore.profileData,
                                  builder: (context, data, _) {
                                    return _buildProfileContent(
                                      data,
                                      isLoading,
                                      isDark,
                                      titleColor,
                                      cardColor,
                                      subTitleColor,
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
    final bool showTyping = isLoading && data == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileHero(
          name: showTyping ? "..." : (data?['name'] ?? "Faculty User"),
          subtitle: showTyping
              ? "Updating..."
              : "${data?['role'] ?? 'Faculty'} • ${data?['user_name'] ?? ''}",
          cardColor: cardColor,
          titleColor: titleColor,
          subColor: subColor,
          isDark: isDark,
        ),
        const SizedBox(height: 32),
        _buildSectionTitle("Faculty Details", titleColor),
        const SizedBox(height: 16),
        _buildMenuGrid(data, isLoading, cardColor, titleColor, subColor),
        const SizedBox(height: 40),
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
        'icon': Icons.alternate_email_rounded,
        'color': Colors.blue,
      },
      {
        'title': 'Username',
        'val': data?['user_name'],
        'icon': Icons.person_outline_rounded,
        'color': Colors.indigo,
      },
      {
        'title': 'Role',
        'val': data?['role'] ?? 'Faculty',
        'icon': Icons.work_outline_rounded,
        'color': Colors.amber.shade700,
      },
      {
        'title': 'Status',
        'val': data?['isLogin'] == true ? 'Active' : 'Offline',
        'icon': Icons.check_circle_outline_rounded,
        'color': Colors.green,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final bool isDataMissing = item['val'] == null && isLoading;
        return InfoCard(
          title: item['title'],
          value: isDataMissing ? "" : (item['val'] ?? "—").toString(),
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
          "Faculty Profile",
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
          icon: Icon(
            Icons.settings_outlined,
            color: titleColor.withOpacity(0.6),
            size: 26,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
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
            onPressed: () => useFacultyStore.fetchProfile(),
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecor(bool isDark) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: CircleAvatar(
              radius: 140,
              backgroundColor: const Color(
                0xFF6366F1,
              ).withOpacity(isDark ? 0.06 : 0.04),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: const Color(
                0xFFA855F7,
              ).withOpacity(isDark ? 0.04 : 0.02),
            ),
          ),
        ],
      ),
    );
  }
}
