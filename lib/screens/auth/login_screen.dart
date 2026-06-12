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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import '../../providers/notification_provider.dart';
import 'package:tripzo/utils/toast_utils.dart';
import '../main_screen.dart' show MainScreen;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoggingIn = false;
  bool _isGoogleLoading = false;
  bool _agreeToTerms = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: Platform.isAndroid 
        ? null 
        : '1044594848603-df94i707o6tqhbo26takb58rip2olp9v.apps.googleusercontent.com',
    serverClientId:
        '1044594848603-3l3hi7sf390vgru417runabvpuimfpn2.apps.googleusercontent.com',
    scopes: <String>['email', 'profile', 'openid'],
    hostedDomain: 'bitsathy.ac.in',
  );

  // ✅ Bypass SSL certificate verification for DevTunnels (dev only)
  IOClient _createHttpClient() {
    final httpClient = HttpClient();
    
    // SECURITY FIX: Never bypass SSL in production, otherwise Apple App Store will reject the app!
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      httpClient.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    }
    
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
          ref.read(notificationProviderFamily).initialize(token: token);

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
          ref.read(notificationProviderFamily).initialize(token: jwtToken);

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TermsAndConditionsScreen(),
      ),
    );
  }
}

class TermsAndConditionsScreen extends ConsumerWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final Color textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subCol = isDark ? Colors.white70 : const Color(0xFF475569);
    final Color accent = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 160.0,
            floating: false,
            pinned: true,
            backgroundColor: bgColor,
            elevation: 0,
            iconTheme: IconThemeData(color: textCol),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 48, bottom: 16, right: 24),
              title: Text(
                "Terms &\nConditions",
                style: TextStyle(
                  color: textCol,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      accent.withValues(alpha: 0.1),
                      bgColor,
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Please read and understand what data & permissions TripZo accesses to deliver a reliable driver experience.",
                    style: TextStyle(
                      fontSize: 15,
                      color: subCol,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildPremiumSection(
                    title: "Background Synchronization",
                    content: "Uses a Foreground Data Sync service to reliably synchronize critical mission assignments and updates in real-time, even when the app is in the background.",
                    isDark: isDark,
                    accent: accent,
                  ),
                  _buildPremiumSection(
                    title: "Real-Time Notifications",
                    content: "Connects to a real-time socket server to instantly notify you of new missions, ride changes, and important administrative communications.",
                    isDark: isDark,
                    accent: accent,
                  ),
                  _buildPremiumSection(
                    title: "NO GPS Location Tracking",
                    content: "Background and fine/coarse GPS location tracking packages and services have been completely disabled. We do NOT collect, transmit, or record your physical coordinates.",
                    isDark: isDark,
                    accent: Colors.redAccent,
                  ),
                  _buildPremiumSection(
                    title: "Data Security & Access",
                    content: "Your authentication token and profile details are encrypted locally on your device. We never sell, share, or misuse your private account information.",
                    isDark: isDark,
                    accent: accent,
                  ),
                  const SizedBox(height: 48),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: const Text(
                        "I UNDERSTAND & AGREE",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
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

  Widget _buildPremiumSection({
    required String title,
    required String content,
    required bool isDark,
    required Color accent,
  }) {
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subCol = isDark ? Colors.white70 : const Color(0xFF475569);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textCol,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 20.0),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: subCol,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BackgroundDecorator extends ConsumerWidget {
  const BackgroundDecorator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
