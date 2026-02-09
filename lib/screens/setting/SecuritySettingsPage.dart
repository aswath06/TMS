import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Disable Security",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _buildPinField(
                  controller: verifyController,
                  hint: "Current PIN",
                  errorText: verifyError,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (verifyController.text == storedPin) {
                              setModalState(() => isLoading = true);
                              await Future.delayed(const Duration(seconds: 1));
                              await _clearPinData();
                              Navigator.pop(context);
                              _showSnackBar("Security Disabled Successfully");
                            } else {
                              setModalState(
                                () => verifyError = "Incorrect PIN",
                              );
                            }
                          },
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Confirm & Disable",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          void validateAndSave() async {
            // Reset errors locally first
            setModalState(() {
              currentError = null;
              newError = null;
              confirmError = null;
            });

            bool hasError = false;

            // 1. Check current PIN if it exists
            if (storedPin != null && currentController.text != storedPin) {
              setModalState(() => currentError = "Incorrect current PIN");
              hasError = true;
            }

            // 2. Check new PIN length
            if (newController.text.length < 4) {
              setModalState(() => newError = "PIN must be at least 4 digits");
              hasError = true;
            }

            // 3. Check mismatch
            if (newController.text != confirmController.text) {
              setModalState(() => confirmError = "New PINs do not match");
              hasError = true;
            }

            if (hasError) return;

            // Start Loading Effect
            setModalState(() => isLoading = true);
            await Future.delayed(const Duration(seconds: 1));

            // Success State
            setModalState(() {
              isLoading = false;
              isSuccess = true;
            });

            await Future.delayed(const Duration(milliseconds: 500));

            storedPin = newController.text;
            await _savePreference('userPin', storedPin!);
            await _savePreference('isPinEnabled', true);
            setState(() => isPinEnabled = true);

            Navigator.pop(context);
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
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    storedPin != null ? "Change App PIN" : "Set App PIN",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (storedPin != null) ...[
                    _buildPinField(
                      controller: currentController,
                      hint: "Current PIN",
                      errorText: currentError,
                      isSuccess: isSuccess,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                  ],

                  _buildPinField(
                    controller: newController,
                    hint: "New PIN",
                    errorText: newError,
                    isSuccess: isSuccess,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 16),

                  _buildPinField(
                    controller: confirmController,
                    hint: "Confirm New PIN",
                    errorText: confirmError,
                    isSuccess: isSuccess,
                    enabled: !isLoading,
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSuccess
                            ? Colors.green
                            : const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: (isLoading || isSuccess)
                          ? null
                          : validateAndSave,
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
                              isSuccess ? "Success!" : "Save PIN",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String hint,
    String? errorText,
    bool isSuccess = false,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: true,
      enabled: enabled,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: InputDecoration(
        counterText: "",
        hintText: hint,
        errorText: errorText, // THIS SHOWS THE ERROR BELOW FIELD
        errorStyle: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: isSuccess
            ? Colors.green.withOpacity(0.05)
            : Colors.black.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: isSuccess ? Colors.green : Colors.transparent,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: isSuccess ? Colors.green : const Color(0xFF6366F1),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }

  void _showSnackBar(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );

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
    final Color primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
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
                color: titleColor,
              ),
            ),
            const SizedBox(height: 32),
            _buildSecurityTile(
              icon: Icons.dialpad_rounded,
              title: "App PIN",
              subtitle: isPinEnabled
                  ? "PIN Active • Tap to change"
                  : "Secure your app with a PIN",
              cardColor: cardColor,
              titleColor: titleColor,
              subColor: subTitleColor,
              primaryBlue: primaryBlue,
              value: isPinEnabled,
              onChanged: (val) {
                if (val) {
                  _showPinSetup();
                } else {
                  _showVerifyToDisable();
                }
              },
              onTileTap: _showPinSetup,
            ),
            const SizedBox(height: 16),
            _buildSecurityTile(
              icon: Icons.fingerprint_rounded,
              title: "Biometric Lock",
              subtitle: "Fingerprint or Face ID",
              cardColor: cardColor,
              titleColor: titleColor,
              subColor: subTitleColor,
              primaryBlue: primaryBlue,
              value: isBiometricEnabled,
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
    required Color cardColor,
    required Color titleColor,
    required Color subColor,
    required Color primaryBlue,
    required bool value,
    required ValueChanged<bool> onChanged,
    VoidCallback? onTileTap,
    bool isEnabled = true,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isEnabled ? 1.0 : 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: ListTile(
          onTap: isEnabled ? onTileTap : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryBlue, size: 24),
          ),
          title: Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w800, color: titleColor),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: subColor),
          ),
          trailing: Switch(
            value: value,
            onChanged: isEnabled
                ? onChanged
                : (val) {
                    if (val && !isPinEnabled) _showSnackBar("Enable PIN first");
                  },
            activeTrackColor: primaryBlue,
          ),
        ),
      ),
    );
  }
}
