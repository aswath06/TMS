import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/io_client.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tripzo/components/custom_button.dart';
import 'package:tripzo/components/custom_input.dart';
import 'package:tripzo/components/app_branding.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/validators.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/utils/toast_utils.dart';
import '../main_screen.dart' show MainScreen;
import 'package:tripzo/utils/api_error_parser.dart';

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
  bool _isAppleLoading = false;
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

  @override
  void initState() {
    super.initState();
    _checkBlockedAlert();
  }

  Future<void> _checkBlockedAlert() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('showBlockedAlert') == true) {
      await prefs.remove('showBlockedAlert');
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.block, color: Colors.red),
                const SizedBox(width: 8),
                Text('Account Blocked', style: TextStyle(color: Colors.red)),
              ],
            ),
            content: const Text('Your account has been blocked by the administrator. Please contact support.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

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

  Future<String?> _getDeviceModel() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.utsname.machine;
      }
    } catch (e) {
      debugPrint("Failed to get device info: $e");
    }
    return null;
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

      final String? deviceModel = await _getDeviceModel();
      final body = {
        "identifier": _emailController.text.trim(),
        "password": _passwordController.text.trim(),
        if (deviceModel != null) "device_model": deviceModel,
      };

      // ✅ PRINT CURL
      final curl =
          '''
curl -X POST "$url" 
-H "Content-Type: application/json" 
-d '${jsonEncode(body)}'
''';

      debugPrint("🔥 LOGIN CURL:\n$curl");

      final response = await client.post(
        Uri.parse(url),
        headers: ApiConstants.getHeaders(null),
        body: jsonEncode(body),
      );

      // ✅ PRINT RESPONSE
      debugPrint(ApiErrorParser.parse(response, fallback: "✅ STATUS CODE"));
      debugPrint("📦 RESPONSE BODY: ${response.body}");

      if (response.body.isEmpty) {
        throw "Empty response";
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final token = data['token'] ?? '';

        final user = data['user'] ?? {};
        final String? rawRole = user['role']?.toString();
        
        if (rawRole == null || rawRole.trim().isEmpty || rawRole.toLowerCase() == 'undefined') {
          throw "Role is undefined";
        }

        final allowedRoles = [
          'transport admin',
          'super admin',
          'faculty',
          'non teaching',
          'intern',
          'security',
          'student',
          'driver'
        ];
        
        if (!allowedRoles.contains(rawRole.toLowerCase())) {
          throw "You don't have permission to access this resource";
        }

        await UserStore.saveUserData(
          token: token,
          role: rawRole.toLowerCase(),
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
      
      final String? deviceModel = await _getDeviceModel();
      final body = {
        "idToken": idToken,
        if (deviceModel != null) "device_model": deviceModel,
      };

      final response = await client.post(
        Uri.parse(ApiConstants.googleLogin),
        headers: ApiConstants.getHeaders(null),
        body: jsonEncode(body),
      );

      if (response.body.isEmpty) {
        throw "Server returned an empty response. Please try again later.";
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final String jwtToken = responseData['token'];
        final Map<String, dynamic> userData = responseData['user'];
        final String? rawRole = userData['role']?.toString();

        if (rawRole == null || rawRole.trim().isEmpty || rawRole.toLowerCase() == 'undefined') {
          throw "Role is undefined";
        }

        final allowedRoles = [
          'transport admin',
          'super admin',
          'faculty',
          'non teaching',
          'intern',
          'security',
          'student',
          'driver'
        ];

        if (!allowedRoles.contains(rawRole.toLowerCase())) {
          throw "You don't have permission to access this resource";
        }

        await UserStore.saveUserData(
          token: jwtToken,
          role: rawRole.toLowerCase(),
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

  // ✅ APPLE LOGIN with SSL bypass
  Future<void> _handleAppleSignIn() async {
    if (!_agreeToTerms) {
      showTopToast(context, "Please agree to the Terms & Conditions to proceed.", isError: true);
      return;
    }
    final client = _createHttpClient();
    try {
      setState(() => _isAppleLoading = true);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final String? idToken = credential.identityToken;
      if (idToken == null) throw "Failed to retrieve Apple Identity Token.";

      final String? deviceModel = await _getDeviceModel();
      final body = {
        "idToken": idToken,
        if (deviceModel != null) "device_model": deviceModel,
      };

      final response = await client.post(
        Uri.parse(ApiConstants.appleLogin),
        headers: ApiConstants.getHeaders(null),
        body: jsonEncode(body),
      );

      if (response.body.isEmpty) {
        throw "Server returned an empty response. Please try again later.";
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final String jwtToken = responseData['token'];
        final Map<String, dynamic> userData = responseData['user'];
        final String? rawRole = userData['role']?.toString();

        if (rawRole == null || rawRole.trim().isEmpty || rawRole.toLowerCase() == 'undefined') {
          throw "Role is undefined";
        }

        final allowedRoles = [
          'transport admin',
          'super admin',
          'faculty',
          'non teaching',
          'intern',
          'security',
          'student',
          'driver'
        ];

        if (!allowedRoles.contains(rawRole.toLowerCase())) {
          throw "You don't have permission to access this resource";
        }

        await UserStore.saveUserData(
          token: jwtToken,
          role: rawRole.toLowerCase(),
          email: userData['email'],
          id: userData['id'] ?? 0,
        );

        if (mounted) {
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
      debugPrint("APPLE LOGIN ERROR: $error");

      if (mounted) {
        showTopToast(context, error.toString(), isError: true);
      }
    } finally {
      client.close();
      if (mounted) setState(() => _isAppleLoading = false);
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
                      if (!_agreeToTerms) _buildTermsAndConditions() else ...[
                        _buildLoginForm(),
                        _buildDivider(),
                        _buildGoogleButton(),
                        if (Platform.isIOS) ...[
                          const SizedBox(height: 16),
                          _buildAppleButton(),
                        ]
                      ],
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
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
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
          const SizedBox(height: 24),
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

  Widget _buildAppleButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isAppleLoading ? null : _handleAppleSignIn,
        icon: _isAppleLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.apple,
                size: 26,
                color: Colors.black,
              ),
        label: const Text(
          "Continue with Apple",
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

  Widget _buildTermsAndConditions() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subCol = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Terms & Privacy Policy",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: textCol,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Please read and understand what data & permissions TripZo accesses to deliver a reliable experience.",
            style: TextStyle(
              fontSize: 13,
              color: subCol,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _buildPolicyTextRow(
            number: "1",
            title: "Background Synchronization",
            content: "Uses a foreground service to reliably synchronize vehicle routes, student manifests, and schedules in real-time. This guarantees seamless updates and data accuracy, ensuring that all ride tracking details remain up-to-date even when the application is minimized or running in the background.",
            titleColor: textCol,
            subColor: subCol,
          ),
          _buildPolicyTextRow(
            number: "2",
            title: "Real-Time Notifications",
            content: "Connects to our centralized real-time messaging gateway to broadcast push notifications. You will receive instant alerts for immediate route updates, emergency modifications, schedule shifts, and administrative announcements without any delay.",
            titleColor: textCol,
            subColor: subCol,
          ),
          _buildPolicyTextRow(
            number: "3",
            title: "Data Security & Privacy",
            content: "All sensitive profile details, login sessions, and tokens are stored securely using hardware-accelerated local encryption. We adhere to strict privacy standards: your personal information is never sold, shared, or exposed to third-party entities under any circumstances.",
            titleColor: textCol,
            subColor: subCol,
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: "I UNDERSTAND & AGREE",
            onPressed: () {
              setState(() {
                _agreeToTerms = true;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyTextRow({
    required String number,
    required String title,
    required String content,
    required Color titleColor,
    required Color subColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$number. $title",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: titleColor,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: subColor,
              height: 1.5,
            ),
          ),
        ],
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
                    content: "Uses a foreground service to reliably synchronize vehicle routes, student manifests, and schedules in real-time. This guarantees seamless updates and data accuracy, ensuring that all ride tracking details remain up-to-date even when the application is minimized or running in the background.",
                    isDark: isDark,
                    accent: accent,
                  ),
                  _buildPremiumSection(
                    title: "Real-Time Notifications",
                    content: "Connects to our centralized real-time messaging gateway to broadcast push notifications. You will receive instant alerts for immediate route updates, emergency modifications, schedule shifts, and administrative announcements without any delay.",
                    isDark: isDark,
                    accent: accent,
                  ),
                  _buildPremiumSection(
                    title: "Data Security & Privacy",
                    content: "All sensitive profile details, login sessions, and tokens are stored securely using hardware-accelerated local encryption. We adhere to strict privacy standards: your personal information is never sold, shared, or exposed to third-party entities under any circumstances.",
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
              color: const Color(0xFF6366F1).withValues(alpha: 0.05),
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
              color: const Color(0xFF6366F1).withValues(alpha: 0.03),
            ),
          ),
        ),
      ],
    );
  }
}
