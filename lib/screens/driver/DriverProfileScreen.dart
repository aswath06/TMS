import 'package:flutter/material.dart';
import 'package:tms/components/profile/info_card.dart';
import 'package:tms/components/profile/profile_hero.dart';
import 'package:tms/components/profile/typing_text.dart';
import 'package:tms/screens/setting/settings_page.dart';
import 'package:tms/store/driver_store.dart';
import 'package:tms/store/istamil.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  @override
  void initState() {
    super.initState();
    if (useDriverStore.profileData.value == null) {
      useDriverStore.fetchProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTamil = LanguageStore.isTamil;
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
            onRefresh: () => useDriverStore.fetchProfile(),
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
                        _buildHeader(context, titleColor, isTamil),
                        const SizedBox(height: 30),
                        ValueListenableBuilder(
                          valueListenable: useDriverStore.isLoading,
                          builder: (context, isLoading, _) {
                            return ValueListenableBuilder(
                              valueListenable: useDriverStore.errorMessage,
                              builder: (context, error, _) {
                                if (error != null) {
                                  return _buildErrorState(
                                    error,
                                    titleColor,
                                    isTamil,
                                  );
                                }
                                return ValueListenableBuilder(
                                  valueListenable: useDriverStore.profileData,
                                  builder: (context, data, _) {
                                    return _buildProfileContent(
                                      data,
                                      isLoading,
                                      isDark,
                                      titleColor,
                                      cardColor,
                                      subTitleColor,
                                      isTamil,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 100),
                      ]),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
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
    bool isTamil,
  ) {
    final bool showTyping = isLoading && data == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileHero(
          name: showTyping
              ? "..."
              : (data?['name'] ?? (isTamil ? "ஓட்டுநர்" : "Driver")),
          subtitle: showTyping
              ? (isTamil ? "புதுப்பிக்கிறது..." : "Updating...")
              : "${data?['role'] ?? (isTamil ? 'ஓட்டுநர்' : 'Driver')} • ${data?['user_name'] ?? ''}",
          cardColor: cardColor,
          titleColor: titleColor,
          subColor: subColor,
          isDark: isDark,
        ),
        const SizedBox(height: 32),
        _buildSectionTitle(
          isTamil ? "ஓட்டுநர் விவரங்கள்" : "Driver Details",
          titleColor,
        ),
        const SizedBox(height: 16),
        _buildDriverGrid(
          data,
          isLoading,
          cardColor,
          titleColor,
          subColor,
          isTamil,
        ),
        const SizedBox(height: 32),
        _buildSectionTitle(
          isTamil ? "கணக்கு விவரங்கள்" : "Account Details",
          titleColor,
        ),
        const SizedBox(height: 16),
        _buildAccountGrid(
          data,
          isLoading,
          cardColor,
          titleColor,
          subColor,
          isTamil,
        ),
      ],
    );
  }

  Widget _buildDriverGrid(
    Map<String, dynamic>? data,
    bool isLoading,
    Color cardColor,
    Color titleColor,
    Color subColor,
    bool isTamil,
  ) {
    final List<Map<String, dynamic>> items = [
      {
        'title': isTamil ? 'பெயர்' : 'Full Name',
        'val': data?['name'],
        'icon': Icons.badge_rounded,
        'color': Colors.indigo,
      },
      {
        'title': isTamil ? 'பணியிடம்' : 'Role',
        'val': data?['role'],
        'icon': Icons.shutter_speed_rounded,
        'color': Colors.amber.shade700,
      },
      {
        'title': isTamil ? 'பயனர் பெயர்' : 'Username',
        'val': data?['user_name'],
        'icon': Icons.person_outline_rounded,
        'color': Colors.green,
      },
      {
        'title': isTamil ? 'தொலைபேசி' : 'Contact Info',
        'val': data?['phone'] ?? (isTamil ? 'பதிவில்லை' : 'Not set'),
        'icon': Icons.phone_android_rounded,
        'color': Colors.blue,
      },
    ];
    return _renderGrid(items, isLoading, cardColor, titleColor, subColor);
  }

  Widget _buildAccountGrid(
    Map<String, dynamic>? data,
    bool isLoading,
    Color cardColor,
    Color titleColor,
    Color subColor,
    bool isTamil,
  ) {
    final List<Map<String, dynamic>> items = [
      {
        'title': isTamil ? 'மின்னஞ்சல்' : 'Email',
        'val': data?['email'],
        'icon': Icons.alternate_email_rounded,
        'color': Colors.teal,
      },
      {
        'title': isTamil ? 'உள்நுழைவு' : 'Session',
        'val': data?['isLogin'] == true
            ? (isTamil ? 'செயலில்' : 'Active')
            : (isTamil ? 'இல்லை' : 'Offline'),
        'icon': Icons.circle,
        'color': data?['isLogin'] == true ? Colors.green : Colors.red,
      },
      {
        'title': isTamil ? 'வருகை சதவீதம்' : 'Attendance',
        'val': '—',
        'icon': Icons.pie_chart_rounded,
        'color': Colors.purple,
      },
      {
        'title': isTamil ? 'விடுப்பு நாட்கள்' : 'Leaves',
        'val': '—',
        'icon': Icons.calendar_month_rounded,
        'color': Colors.redAccent,
      },
    ];
    return _renderGrid(items, isLoading, cardColor, titleColor, subColor);
  }

  Widget _renderGrid(
    List<Map<String, dynamic>> items,
    bool isLoading,
    Color cardColor,
    Color titleColor,
    Color subColor,
  ) {
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

  Widget _buildHeader(BuildContext context, Color titleColor, bool isTamil) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          isTamil ? "ஓட்டுநர் விவரம்" : "Driver Profile",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        IconButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
            if (mounted) setState(() {});
          },
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

  Widget _buildErrorState(String error, Color titleColor, bool isTamil) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 10),
          Text(error, style: TextStyle(color: titleColor)),
          TextButton(
            onPressed: () => useDriverStore.fetchProfile(),
            child: Text(isTamil ? "மீண்டும் முயற்சி" : "Retry"),
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
