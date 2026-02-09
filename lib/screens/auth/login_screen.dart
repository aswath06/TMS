import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tms/components/custom_button.dart';
import 'package:tms/components/custom_input.dart';
import 'package:tms/components/app_branding.dart';
import 'package:tms/store/user_store.dart';
import 'package:tms/utils/validators.dart';
import 'package:tms/utils/api_constants.dart';
import "../../utils/routes.dart";
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

  // FIXED: Using the Web Client ID for serverClientId to enable idToken generation
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '1044594848603-3l3hi7sf390vgru417runabvpuimfpn2.apps.googleusercontent.com',
    scopes: <String>['email', 'profile', 'openid'],
    hostedDomain: 'bitsathy.ac.in',
  );

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoggingIn = true);
    try {
      // Logic for traditional email/password login
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        String role = _emailController.text.toLowerCase().contains('driver')
            ? 'driver'
            : 'faculty';
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.dashboard,
          arguments: role,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
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

      final response = await http.post(
        Uri.parse(ApiConstants.googleLogin),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final String jwtToken = responseData['token'];
        final Map<String, dynamic> userData = responseData['user'];

        await UserStore.saveUserData(
          token: jwtToken,
          role: userData['role'] ?? 'faculty',
          email: userData['email'],
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
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
