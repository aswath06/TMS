import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:tms/components/custom_button.dart';
import 'package:tms/components/custom_input.dart';
import 'package:tms/components/app_branding.dart';
import 'package:tms/screens/auth/forgot_password_screen.dart';
import 'package:tms/utils/validators.dart';
import 'package:tms/utils/api_constants.dart'; // Import the new constants file
import "../../utils/routes.dart";

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
    scopes: <String>['email', 'profile'],
  );

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoggingIn = true);
    try {
      await Future.delayed(const Duration(seconds: 2));
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

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Using the centralized ApiConstants here
      final response = await http.post(
        Uri.parse(ApiConstants.googleLogin),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'idToken': googleAuth.idToken}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // Extracting data based on your specific JSON structure
        final String userRole = data['user']?['role']?.toLowerCase() ?? 'user';
        final String token = data['token'];

        debugPrint("Authentication Successful. Role: $userRole");

        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.dashboard,
            arguments: userRole,
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['message'] ?? "Authentication failed";
      }
    } catch (error) {
      debugPrint("GOOGLE LOGIN ERROR: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9)],
          ),
        ),
        child: Stack(
          children: [
            const BackgroundDecorator(),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const AppBranding(),
                      const SizedBox(height: 40),
                      _buildLoginForm(),
                      _buildDivider(),
                      _buildGoogleButton(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.05),
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForgotPasswordScreen(),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
              ),
              child: const Text(
                "Forgot Password?",
                style: TextStyle(fontWeight: FontWeight.w600),
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
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Row(
        children: [
          Expanded(child: Divider(color: Color(0xFFCBD5E1))),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "OR CONTINUE WITH",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          Expanded(child: Divider(color: Color(0xFFCBD5E1))),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    return CustomButton(
      text: "Sign in with Google",
      isLoading: _isGoogleLoading,
      backgroundColor: Colors.white,
      textColor: const Color(0xFF0F172A),
      icon: Image.network(
        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
        height: 20,
      ),
      onPressed: _handleGoogleSignIn,
    );
  }
}

class BackgroundDecorator extends StatelessWidget {
  const BackgroundDecorator({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
