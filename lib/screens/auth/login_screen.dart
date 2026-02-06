import 'package:flutter/material.dart';
import 'package:tms/components/custom_button.dart';
import 'package:tms/components/custom_input.dart';
import 'package:tms/components/app_branding.dart';
import "../../utils/routes.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoggingIn = false;
  bool _isGoogleLoading = false;

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all fields"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoggingIn = true);
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isLoggingIn = false);
      String role = _emailController.text.toLowerCase().contains('driver')
          ? 'driver'
          : 'faculty';
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.dashboard,
        arguments: role,
      );
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
          ),
          const SizedBox(height: 20),
          CustomInput(
            label: "Password",
            controller: _passwordController,
            icon: Icons.lock_outline_rounded,
            isPassword: true,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
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
      onPressed: () {
        setState(() => _isGoogleLoading = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _isGoogleLoading = false);
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.dashboard,
              arguments: 'faculty',
            );
          }
        });
      },
    );
  }
}
