import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Ensure this path is correct
import 'package:tripzo/utils/toast_utils.dart';

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  bool isPinEnabled = false;
  bool isBiometricEnabled = false;
  String? storedPin;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isPinEnabled = prefs.getBool('isPinEnabled') ?? false;
      isBiometricEnabled = prefs.getBool('isBiometricEnabled') ?? false;
      storedPin = prefs.getString('userPin');
    });
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _clearPinData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userPin');
    await prefs.setBool('isPinEnabled', false);
    await prefs.setBool('isBiometricEnabled', false);
    setState(() {
      storedPin = null;
      isPinEnabled = false;
      isBiometricEnabled = false;
    });
  }

  // --- MODAL: VERIFY TO DISABLE ---
  void _showVerifyToDisable() {
    final TextEditingController verifyController = TextEditingController();
    String? verifyError;
    bool isLoading = false;
    bool isVisible = false;

    // Use current theme brightness for modal
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color modalBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 20,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: modalBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(isDark),
                const SizedBox(height: 20),
                Text(
                  "Disable Security",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 24),
                _buildPinField(
                  controller: verifyController,
                  hint: "Current PIN",
                  errorText: verifyError,
                  enabled: !isLoading,
                  obscure: !isVisible,
                  isDark: isDark,
                  onToggleVisibility: () =>
                      setModalState(() => isVisible = !isVisible),
                ),
                const SizedBox(height: 24),
                _buildButton(
                  text: "Confirm & Disable",
                  color: Colors.redAccent,
                  isLoading: isLoading,
                  onPressed: () async {
                    if (verifyController.text == storedPin) {
                      setModalState(() => isLoading = true);
                      await Future.delayed(const Duration(milliseconds: 800));
                      await _clearPinData();
                      if (context.mounted) Navigator.pop(context);
                      _showSnackBar("Security Disabled Successfully");
                    } else {
                      setModalState(() => verifyError = "Incorrect PIN");
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- MODAL: PIN SETUP/CHANGE ---
  void _showPinSetup() {
    final TextEditingController currentController = TextEditingController();
    final TextEditingController newController = TextEditingController();
    final TextEditingController confirmController = TextEditingController();

    String? currentError;
    String? newError;
    String? confirmError;
    bool isLoading = false;
    bool isSuccess = false;
    bool isVisible = false;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color modalBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          void validateAndSave() async {
            FocusScope.of(context).unfocus();
            setModalState(() {
              currentError = null;
              newError = null;
              confirmError = null;
            });

            if (storedPin != null && currentController.text != storedPin) {
              setModalState(() => currentError = "Incorrect current PIN");
              return;
            }
            if (newController.text.length < 4) {
              setModalState(() => newError = "Minimum 4 digits required");
              return;
            }
            if (newController.text != confirmController.text) {
              setModalState(() => confirmError = "PINs do not match");
              return;
            }

            setModalState(() => isLoading = true);
            await Future.delayed(const Duration(seconds: 1));

            setModalState(() {
              isLoading = false;
              isSuccess = true;
            });

            await Future.delayed(const Duration(milliseconds: 600));

            storedPin = newController.text;
            await _savePreference('userPin', storedPin!);
            await _savePreference('isPinEnabled', true);
            setState(() => isPinEnabled = true);

            if (context.mounted) Navigator.pop(context);
            _showSnackBar("PIN Updated Successfully");
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 20,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: modalBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHandle(isDark),
                  const SizedBox(height: 20),
                  Text(
                    storedPin != null ? "Change App PIN" : "Set App PIN",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (storedPin != null) ...[
                    _buildPinField(
                      controller: currentController,
                      hint: "Current PIN",
                      errorText: currentError,
                      enabled: !isLoading,
                      obscure: !isVisible,
                      isDark: isDark,
                      onToggleVisibility: () =>
                          setModalState(() => isVisible = !isVisible),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildPinField(
                    controller: newController,
                    hint: "New PIN",
                    errorText: newError,
                    enabled: !isLoading,
                    obscure: !isVisible,
                    isDark: isDark,
                    onToggleVisibility: () =>
                        setModalState(() => isVisible = !isVisible),
                  ),
                  const SizedBox(height: 16),
                  _buildPinField(
                    controller: confirmController,
                    hint: "Confirm New PIN",
                    errorText: confirmError,
                    enabled: !isLoading,
                    obscure: !isVisible,
                    isDark: isDark,
                    onToggleVisibility: () =>
                        setModalState(() => isVisible = !isVisible),
                  ),
                  const SizedBox(height: 24),
                  _buildButton(
                    text: isSuccess ? "Success!" : "Save PIN",
                    color: isSuccess ? Colors.green : const Color(0xFF6366F1),
                    isLoading: isLoading,
                    onPressed: isSuccess ? null : validateAndSave,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildHandle(bool isDark) => Container(
    width: 40,
    height: 4,
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: isDark ? Colors.white24 : Colors.grey[400],
      borderRadius: BorderRadius.circular(10),
    ),
  );

  Widget _buildPinField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    String? errorText,
    bool enabled = true,
    bool obscure = true,
    VoidCallback? onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: TextInputType.number,
      maxLength: 6,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        counterText: "",
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
        errorText: errorText,
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 20,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          onPressed: onToggleVisibility,
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required bool isLoading,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) =>
      showTopToast(context, msg, isError: isError);

  @override
  Widget build(BuildContext context) {
    // Determine current dark state from Theme
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: primaryBlue, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "SECURITY",
          style: TextStyle(
            color: primaryBlue,
            fontSize: 12,
            letterSpacing: 2,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              "Privacy Controls",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 32),
            _buildSecurityTile(
              icon: Icons.dialpad_rounded,
              title: "App PIN",
              subtitle: isPinEnabled
                  ? "PIN Active • Tap to change"
                  : "Secure your app with a PIN",
              value: isPinEnabled,
              primaryBlue: primaryBlue,
              onChanged: (val) =>
                  val ? _showPinSetup() : _showVerifyToDisable(),
              onTileTap: _showPinSetup,
            ),
            const SizedBox(height: 16),
            _buildSecurityTile(
              icon: Icons.fingerprint_rounded,
              title: "Biometric Lock",
              subtitle: "Fingerprint or Face ID",
              value: isBiometricEnabled,
              primaryBlue: primaryBlue,
              isEnabled: isPinEnabled,
              onChanged: (val) {
                setState(() => isBiometricEnabled = val);
                _savePreference('isBiometricEnabled', val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Color primaryBlue,
    required ValueChanged<bool> onChanged,
    VoidCallback? onTileTap,
    bool isEnabled = true,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isEnabled ? 1.0 : 0.5,
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: isEnabled ? onTileTap : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryBlue, size: 24),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          trailing: Switch.adaptive(
            value: value,
            onChanged: isEnabled
                ? onChanged
                : (val) => _showSnackBar("Enable PIN first", isError: true),
            activeColor: primaryBlue,
          ),
        ),
      ),
    );
  }
}
