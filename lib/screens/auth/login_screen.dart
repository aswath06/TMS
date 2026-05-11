import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';

import 'package:tripzo/components/custom_button.dart';
import 'package:tripzo/components/custom_input.dart';
import 'package:tripzo/components/app_branding.dart';
import 'package:tripzo/components/auth/login_error_dialog.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/validators.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import 'package:tripzo/utils/toast_utils.dart';
import '../main_screen.dart' show MainScreen;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoggingIn = false;
  bool _isGoogleLoading = false;
  bool _agreeToTerms = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '1044594848603-d8jula4v28ackbnro25un3cl3vr9bv64.apps.googleusercontent.com',
    scopes: <String>['email', 'profile', 'openid'],
    hostedDomain: 'bitsathy.ac.in',
  );

  // ✅ Bypass SSL certificate verification for DevTunnels (dev only)
  IOClient _createHttpClient() {
    final httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    return IOClient(httpClient);
  }

  // ✅ UPDATED REAL LOGIN
  Future<void> _handleLogin() async {
    if (!_agreeToTerms) {
      showTopToast(context, "Please agree to the Terms & Conditions to proceed.", isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoggingIn = true);

    final client = _createHttpClient();

    try {
      final url = ApiConstants.login;

      final body = {
        "identifier": _emailController.text.trim(),
        "password": _passwordController.text.trim(),
      };

      // ✅ PRINT CURL
      final curl =
          '''
curl -X POST "$url" \
-H "Content-Type: application/json" \
-d '${jsonEncode(body)}'
''';

      debugPrint("🔥 LOGIN CURL:\n$curl");

      final response = await client.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(null),
        body: jsonEncode(body),
      );

      // ✅ PRINT RESPONSE
      debugPrint("✅ STATUS CODE: ${response.statusCode}");
      debugPrint("📦 RESPONSE BODY: ${response.body}");

      if (response.body.isEmpty) {
        throw "Empty response";
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = data['token'] ?? '';

        final user = data['user'] ?? {};

        await UserStore.saveUserData(
          token: token,
          role: user['role']?.toString().toLowerCase() ?? 'faculty',
          email: user['email'] ?? '', // ✅ FIXED
          id: user['id'] ?? 0,
        );

        if (mounted) {
          Provider.of<NotificationProvider>(
            context,
            listen: false,
          ).initialize(token: token);

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  MainScreen(userRole: user['role'].toString().toLowerCase()),
            ),
            (route) => false,
          );
        }
      } else {
        throw data['message'] ?? "Login failed";
      }
    } catch (e) {
      debugPrint("❌ LOGIN ERROR: $e");
      if (mounted) {
        showTopToast(context, e.toString(), isError: true);
      }
    } finally {
      client.close();
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  // ✅ GOOGLE LOGIN with SSL bypass
  Future<void> _handleGoogleSignIn() async {
    if (!_agreeToTerms) {
      showTopToast(context, "Please agree to the Terms & Conditions to proceed.", isError: true);
      return;
    }
    final client = _createHttpClient();
    try {
      setState(() => _isGoogleLoading = true);

      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final String? idToken = googleAuth.idToken;
      if (idToken == null) throw "Failed to retrieve ID Token.";

      final response = await client.post(
        Uri.parse(ApiConstants.googleLogin),
        headers: ApiConstants.getHeaders(null),
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.body.isEmpty) {
        throw "Server returned an empty response. Please try again later.";
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final String jwtToken = responseData['token'];
        final Map<String, dynamic> userData = responseData['user'];

        await UserStore.saveUserData(
          token: jwtToken,
          role: userData['role'] ?? 'faculty',
          email: userData['email'],
          id: userData['id'] ?? 0,
        );

        if (mounted) {
          // Initialize Notifications
          Provider.of<NotificationProvider>(
            context,
            listen: false,
          ).initialize(token: jwtToken);

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(
                userRole: userData['role'].toString().toLowerCase(),
              ),
            ),
            (route) => false,
          );
        }
      } else {
        throw responseData['message'] ?? "Backend Authentication Failed";
      }
    } catch (error) {
      debugPrint("GOOGLE LOGIN ERROR: $error");

      if (mounted) {
        showTopToast(context, error.toString(), isError: true);
      }
    } finally {
      client.close();
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          const BackgroundDecorator(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppBranding(),
                      const SizedBox(height: 48),
                      _buildLoginForm(),
                      _buildDivider(),
                      _buildGoogleButton(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          CustomInput(
            label: "Email Address",
            controller: _emailController,
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            // validator: AppValidators.validateEmail,
          ),
          const SizedBox(height: 20),
          CustomInput(
            label: "Password",
            controller: _passwordController,
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            validator: AppValidators.validatePassword,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
              child: const Text(
                "Forgot Password?",
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              setState(() {
                _agreeToTerms = !_agreeToTerms;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _agreeToTerms,
                      activeColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      onChanged: (val) {
                        setState(() {
                          _agreeToTerms = val ?? false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          "I agree to the ",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        GestureDetector(
                          onTap: _showTermsDialog,
                          child: const Text(
                            "Terms & Conditions",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6366F1),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: "Sign In",
            isLoading: _isLoggingIn,
            onPressed: _handleLogin,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Row(
        children: [
          const Expanded(child: Divider(thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "OR",
              style: TextStyle(
                color: Colors.grey.shade400,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Expanded(child: Divider(thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
        icon: _isGoogleLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Image.asset(
                'assets/google_logo.png',
                height: 22,
              ),
        label: const Text(
          "Continue with Google",
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          side: BorderSide(color: Colors.grey.shade200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final bool isDark = Theme.of(context).brightness == Brightness.dark;
            final Color textCol = isDark ? Colors.white : const Color(0xFF0F172A);
            final Color subCol = isDark ? Colors.white60 : const Color(0xFF475569);
            final Color cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              elevation: 10,
              backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.gavel_rounded, color: Color(0xFF6366F1), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            "Terms & Conditions",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textCol,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Please read and understand what data & permissions TripZo accesses to deliver a reliable driver experience.",
                      style: TextStyle(fontSize: 12, color: subCol, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildTermItem(
                            icon: Icons.sync_rounded,
                            title: "Background Synchronization",
                            description: "Uses a Foreground Data Sync service to reliably synchronize critical mission assignments and updates in real-time, even when the app is in the background.",
                            cardBg: cardBg,
                            textCol: textCol,
                            subCol: subCol,
                          ),
                          _buildTermItem(
                            icon: Icons.notifications_active_rounded,
                            title: "Real-Time Notifications",
                            description: "Connects to a real-time socket server to instantly notify you of new missions, ride changes, and important administrative communications.",
                            cardBg: cardBg,
                            textCol: textCol,
                            subCol: subCol,
                          ),
                          _buildTermItem(
                            icon: Icons.location_off_rounded,
                            title: "NO GPS Location Tracking",
                            description: "Background and fine/coarse GPS location tracking packages and services have been completely disabled. We do NOT collect, transmit, or record your physical coordinates.",
                            iconColor: Colors.redAccent,
                            cardBg: cardBg,
                            textCol: textCol,
                            subCol: subCol,
                          ),
                          _buildTermItem(
                            icon: Icons.security_rounded,
                            title: "Data Security & Access",
                            description: "Your authentication token and profile details are encrypted locally on your device. We never sell, share, or misuse your private account information.",
                            cardBg: cardBg,
                            textCol: textCol,
                            subCol: subCol,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey.shade200),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        setStateDialog(() {
                          _agreeToTerms = !_agreeToTerms;
                        });
                        setState(() {});
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _agreeToTerms,
                              activeColor: const Color(0xFF6366F1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              onChanged: (val) {
                                setStateDialog(() {
                                  _agreeToTerms = val ?? false;
                                });
                                setState(() {});
                              },
                            ),
                            const Expanded(
                              child: Text(
                                "I agree to all the Terms & Conditions mentioned above",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        text: "I Agree & Understand",
                        onPressed: () {
                          if (!_agreeToTerms) {
                            showTopToast(context, "Please check the agreement box to continue.", isError: true);
                            return;
                          }
                          Navigator.pop(context);
                        },
                      ),
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

  Widget _buildTermItem({
    required IconData icon,
    required String title,
    required String description,
    required Color cardBg,
    required Color textCol,
    required Color subCol,
    Color iconColor = const Color(0xFF6366F1),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textCol),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(fontSize: 10, height: 1.35, color: subCol, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BackgroundDecorator extends StatelessWidget {
  const BackgroundDecorator({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1).withOpacity(0.05),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          left: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1).withOpacity(0.03),
            ),
          ),
        ),
      ],
    );
  }
}
