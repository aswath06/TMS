import 'package:flutter/material.dart';
import 'package:tripzo/screens/setting/SecuritySettingsPage.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/store/isdark.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:provider/provider.dart';
import 'scanner_page.dart';
import 'package:tripzo/utils/toast_utils.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  String _userRole = "";

  // Sync initial state with the Global Stores
  String _selectedLanguage = LanguageStore.isTamil ? "தமிழ்" : "English";

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await UserStore.getRole();
    if (mounted) {
      setState(() {
        _userRole = role ?? "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine current states from global stores
    // Listen to theme and language changes
    final themeStore = Provider.of<ThemeStore>(context);
    final lStore = Provider.of<LanguageStore>(context);
    final bool isTamil = LanguageStore.isTamil;
    
    // Update local state if it differs (e.g. after language was changed elsewhere or on load)
    _selectedLanguage = isTamil ? "தமிழ்" : "English";

    final bool isDark = ThemeStore.isDark;

    // Dynamic Colors based on Store state
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subTitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, titleColor, primaryBlue, isTamil),
                    const SizedBox(height: 32),

                    // --- NOTIFICATIONS ---
                    _buildSectionTitle(
                      isTamil ? "அறிவிப்புகள்" : "Notifications",
                      titleColor,
                      primaryBlue,
                    ),
                    const SizedBox(height: 16),
                    _buildToggleTile(
                      Icons.notifications_active_outlined,
                      isTamil ? "செய்தி அறிவிப்பு" : "Push Notifications",
                      isTamil
                          ? "முக்கிய தகவல்களை உடனுக்குடன் பெறவும்"
                          : "Receive alerts and updates",
                      _notificationsEnabled,
                      (val) => setState(() => _notificationsEnabled = val),
                      cardColor,
                      titleColor,
                      subTitleColor,
                      primaryBlue,
                    ),

                    const SizedBox(height: 32),

                    // --- APPEARANCE ---
                    _buildSectionTitle(
                      isTamil ? "வடிவம்" : "Appearance",
                      titleColor,
                      primaryBlue,
                    ),
                    const SizedBox(height: 16),
                    _buildThemeSelector(
                      themeStore,
                      cardColor,
                      subTitleColor,
                      primaryBlue,
                      isTamil,
                    ),

                    // --- LOCALIZATION (ONLY FOR DRIVERS) ---
                    if (_userRole.toLowerCase() == "driver") ...[
                      const SizedBox(height: 32),
                      _buildSectionTitle(
                        isTamil ? "மொழி" : "Localization",
                        titleColor,
                        primaryBlue,
                      ),
                      const SizedBox(height: 16),
                      _buildLanguageSelector(
                        cardColor,
                        subTitleColor,
                        primaryBlue,
                      ),
                    ],

                    const SizedBox(height: 32),

                    // --- SECURITY ---
                    _buildSectionTitle(
                      isTamil ? "பாதுகாப்பு" : "Security",
                      titleColor,
                      primaryBlue,
                    ),
                    const SizedBox(height: 16),
                    _settingsTile(
                      Icons.lock_outline,
                      isTamil
                          ? "ரகசியம் மற்றும் பாதுகாப்பு"
                          : "Privacy & Security",
                      isTamil
                          ? "கடவுச்சொல் மற்றும் தரவு மேலாண்மை"
                          : "Password and data control",
                      cardColor,
                      titleColor,
                      subTitleColor,
                      primaryBlue,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SecuritySettingsPage(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // --- MAINTENANCE ---
                    _buildSectionTitle(
                      isTamil ? "நிர்வாகம்" : "Maintenance",
                      titleColor,
                      primaryBlue,
                    ),
                    const SizedBox(height: 16),
                    _buildUpdateTile(
                      cardColor,
                      titleColor,
                      subTitleColor,
                      primaryBlue,
                      isTamil,
                    ),
                    const SizedBox(height: 12),

                    // SCANNER TILE
                    _settingsTile(
                      Icons.qr_code_scanner_rounded,
                      isTamil ? "ஸ்கேன் செய்க" : "Scan Code",
                      isTamil
                          ? "கேமராவை வைத்து ஸ்கேன் செய்யவும்"
                          : "Scan using camera",
                      cardColor,
                      titleColor,
                      subTitleColor,
                      primaryBlue,
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScannerPage(),
                          ),
                        );
                        if (result != null) {
                          showTopToast(
                            context,
                            isTamil
                                ? "ஸ்கேன் செய்யப்பட்டது: $result"
                                : "Scanned: $result",
                          );
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // LOGOUT TILE
                    _settingsTile(
                      Icons.logout_rounded,
                      isTamil ? "வெளியேறு" : "Sign Out",
                      isTamil
                          ? "கணக்கிலிருந்து பாதுகாப்பாக வெளியேறவும்"
                          : "Log out of your account",
                      cardColor,
                      Colors.redAccent,
                      subTitleColor,
                      Colors.red,
                      onTap: () => _showLogoutBottomSheet(
                        context,
                        isTamil,
                        primaryBlue,
                        isDark,
                        cardColor,
                        titleColor,
                        subTitleColor,
                      ),
                    ),

                    const SizedBox(height: 60),
                    _buildAppVersion(subTitleColor, isTamil),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- THEME SELECTOR ---
  // --- THEME SELECTOR ---
  Widget _buildThemeSelector(
    ThemeStore themeStore,
    Color cardColor,
    Color subColor,
    Color primaryBlue,
    bool isTamil,
  ) {
    final bool isDark = ThemeStore.isDark;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                // Use the instance method setTheme
                await themeStore.setTheme(false);
                if (mounted) setState(() {});
              },
              child: _buildThemeOption(
                isTamil ? "பகல்" : "Light Mode",
                Icons.light_mode_outlined,
                !isDark,
                subColor,
                primaryBlue,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                // Use the instance method setTheme
                await themeStore.setTheme(true);
                if (mounted) setState(() {});
              },
              child: _buildThemeOption(
                isTamil ? "இரவு" : "Dark Mode",
                Icons.dark_mode_outlined,
                isDark,
                subColor,
                primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- LANGUAGE SELECTOR ---
  Widget _buildLanguageSelector(
    Color cardColor,
    Color subColor,
    Color primaryBlue,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildLanguageOption(
              "English",
              _selectedLanguage == "English",
              subColor,
              primaryBlue,
            ),
          ),
          Expanded(
            child: _buildLanguageOption(
              "தமிழ்",
              _selectedLanguage == "தமிழ்",
              subColor,
              primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    String label,
    bool isSelected,
    Color subColor,
    Color primaryBlue,
  ) {
    return GestureDetector(
      onTap: () async {
        await Provider.of<LanguageStore>(context, listen: false).setLanguage(label);
        if (mounted) setState(() {
          _selectedLanguage = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isSelected ? Colors.white : subColor,
            ),
          ),
        ),
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildHeader(
    BuildContext context,
    Color titleColor,
    Color primaryBlue,
    bool isTamil,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.arrow_back_ios,
                    size: 18,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isTamil ? "அமைப்புகள்" : "SETTINGS",
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isTamil ? "மாற்றங்கள்" : "Configuration",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
          ],
        ),
        _buildTopIcon(Icons.tune_outlined, titleColor),
      ],
    );
  }

  Widget _buildUpdateTile(
    Color cardColor,
    Color titleColor,
    Color subColor,
    Color primaryBlue,
    bool isTamil,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        leading: _buildIconContainer(
          Icons.system_update_alt_rounded,
          primaryBlue,
        ),
        title: Text(
          isTamil ? "புதிய அப்டேட் சரிபார்" : "Check for Update",
          style: TextStyle(fontWeight: FontWeight.w800, color: titleColor),
        ),
        subtitle: Text(
          "${isTamil ? 'தற்போதைய பதிப்பு' : 'Current'}: v2.4.0",
          style: TextStyle(fontSize: 13, color: subColor),
        ),
        trailing: TextButton(
          onPressed: () {},
          child: Text(
            isTamil ? "சரிபார்" : "Check",
            style: TextStyle(fontWeight: FontWeight.bold, color: primaryBlue),
          ),
        ),
      ),
    );
  }

  Widget _buildAppVersion(Color subColor, bool isTamil) => Center(
    child: Column(
      children: [
        Text(
          isTamil ? "பதிப்பு 2.4.0 (சரியானது)" : "App Version 2.4.0 (Stable)",
          style: TextStyle(
            color: subColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isTamil ? "BIT-SSG குழுவினரால் உருவாக்கப்பட்டது" : "Built by BIT-SSG",
          style: TextStyle(color: subColor.withOpacity(0.5), fontSize: 11),
        ),
      ],
    ),
  );

  Widget _settingsTile(
    IconData icon,
    String title,
    String subtitle,
    Color cardColor,
    Color titleColor,
    Color subColor,
    Color primaryBlue, {
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        onTap: onTap,
        leading: _buildIconContainer(icon, primaryBlue),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w800, color: titleColor),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: subColor),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    Color titleColor,
    Color primaryBlue,
  ) => Row(
    children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          color: primaryBlue,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: titleColor,
        ),
      ),
    ],
  );

  Widget _buildToggleTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    Color cardColor,
    Color titleColor,
    Color subColor,
    Color primaryBlue,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        leading: _buildIconContainer(icon, primaryBlue),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w800, color: titleColor),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: subColor),
        ),
        trailing: Switch.adaptive(
          value: value,
          activeColor: primaryBlue,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    String label,
    IconData icon,
    bool isSelected,
    Color subColor,
    Color primaryBlue,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? primaryBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: isSelected ? Colors.white : subColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isSelected ? Colors.white : subColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecor(bool isDark) => Positioned.fill(
    child: Stack(
      children: [
        Positioned(
          top: -50,
          right: -50,
          child: CircleAvatar(
            radius: 150,
            backgroundColor: const Color(
              0xFF6366F1,
            ).withOpacity(isDark ? 0.1 : 0.05),
          ),
        ),
        Positioned(
          bottom: 0,
          left: -50,
          child: CircleAvatar(
            radius: 120,
            backgroundColor: const Color(
              0xFFEC4899,
            ).withOpacity(isDark ? 0.08 : 0.04),
          ),
        ),
      ],
    ),
  );

  Widget _buildTopIcon(IconData icon, Color titleColor) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: titleColor.withOpacity(0.05),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: titleColor.withOpacity(0.6), size: 20),
  );
  Widget _buildIconContainer(IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color, size: 22),
  );

  void _showLogoutBottomSheet(BuildContext context, bool isTamil, Color p, bool isDark, Color cardColor, Color titleColor, Color subTitleColor) {
    final TextEditingController passwordController = TextEditingController();
    bool isObscured = true;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handlebar
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Header Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTamil ? "வெளியேறுதல்" : "Account Logout",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isTamil ? "தொடர உங்கள் கடவுச்சொல்லை உள்ளிடவும்" : "Enter your password to confirm",
                              style: TextStyle(
                                fontSize: 12,
                                color: subTitleColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Password Input
                    Text(
                      isTamil ? "கடவுச்சொல்*" : "Confirm Password*",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: titleColor.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: passwordController,
                        obscureText: isObscured,
                        style: TextStyle(color: titleColor, fontSize: 15),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: isDark ? Colors.white54 : Colors.grey),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              color: isDark ? Colors.white54 : Colors.grey,
                            ),
                            onPressed: () {
                              setModalState(() {
                                isObscured = !isObscured;
                              });
                            },
                          ),
                          hintText: isTamil ? "உங்கள் கடவுச்சொல்" : "••••••••",
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isLoading ? null : () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              isTamil ? "ரத்துசெய்" : "Cancel",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () async {
                                    final pwd = passwordController.text.trim();
                                    if (pwd.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(isTamil ? "கடவுச்சொல்லை உள்ளிடவும்" : "Please enter your password"),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    setModalState(() {
                                      isLoading = true;
                                    });

                                    try {
                                      final token = await UserStore.getToken();
                                      final response = await http.post(
                                        Uri.parse(ApiConstants.logoutMe),
                                        headers: {
                                          "Authorization": "TMS $token",
                                          "Content-Type": "application/json",
                                          ApiConstants.bypassHeaderKey: ApiConstants.bypassHeaderValue,
                                        },
                                        body: jsonEncode({
                                          "password": pwd,
                                        }),
                                      );

                                      if (response.statusCode == 200) {
                                        Navigator.pop(context); // Close bottom sheet
                                        showTopToast(
                                          context,
                                          isTamil ? "வெற்றிகரமாக வெளியேறப்பட்டது" : "Logged out successfully",
                                        );
                                        await UserStore.forceLogout();
                                      } else {
                                        String errorMsg = "Incorrect password";
                                        try {
                                          final decoded = jsonDecode(response.body);
                                          errorMsg = decoded['message'] ?? decoded['error'] ?? "Incorrect password";
                                        } catch (_) {}
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(errorMsg),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } catch (err) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text("Error: $err"),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    } finally {
                                      setModalState(() {
                                        isLoading = false;
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(
                                    isTamil ? "வெளியேறு" : "LOGOUT",
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 1,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
