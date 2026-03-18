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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoggingIn = true);

    final client = _createHttpClient();
    try {
      final response = await client.post(
        Uri.parse(ApiConstants.login),
        headers: ApiConstants.getHeaders(null),
        body: jsonEncode({
          "identifier": _emailController.text.trim(),
          "password": _passwordController.text.trim(),
        }),
      );

      if (response.body.isEmpty) {
        throw "Server returned an empty response. Please try again later.";
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final String token = data['token'];
        final Map<String, dynamic> user = data['user'];

        await UserStore.saveUserData(
          token: token,
          role: user['role'] ?? 'faculty',
          email: user['email'],
          id: user['id'] ?? 0,
        );

        if (mounted) {
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
      debugPrint("LOGIN ERROR: $e");
      String errorMessage = e.toString();
      bool isNetworkError = false;

      if (errorMessage.contains("SocketException") ||
          errorMessage.contains("Connection failed") ||
          errorMessage.contains("ClientException") ||
          errorMessage.contains("HandshakeException") ||
          errorMessage.contains("CERTIFICATE_VERIFY_FAILED")) {
        errorMessage = "Network error. Please check your internet connection and try again.";
        isNetworkError = true;
      }

      if (mounted) {
        LoginErrorDialog.show(
          context,
          message: errorMessage,
          onRetry: isNetworkError ? _handleLogin : null,
        );
      }
    } finally {
      client.close();
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  // ✅ GOOGLE LOGIN with SSL bypass
  Future<void> _handleGoogleSignIn() async {
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
        LoginErrorDialog.show(context, message: error.toString());
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
            validator: AppValidators.validateEmail,
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
          const SizedBox(height: 12),
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
            : Image.network(
                'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
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
