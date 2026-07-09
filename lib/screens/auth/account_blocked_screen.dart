import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/components/custom_button.dart';
import 'package:tripzo/services/api_service.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:tripzo/utils/routes.dart';

class AccountBlockedScreen extends ConsumerStatefulWidget {
  const AccountBlockedScreen({super.key});

  @override
  ConsumerState<AccountBlockedScreen> createState() => _AccountBlockedScreenState();
}

class _AccountBlockedScreenState extends ConsumerState<AccountBlockedScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _checkStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Just hitting the me endpoint will go through the sessionAuth middleware.
      // If it returns 200, it means the user is no longer blocked.
      // If it throws an exception with "Your account has been blocked", ApiService will catch it 
      // but ApiService now routes here. 
      // Actually, we should make a direct call or use ApiService and catch the error.
      await ApiService.get(ApiConstants.userMe);
      
      // If we reach here, we are unblocked!
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.splash, (route) => false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Your account is still blocked.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, color: Colors.redAccent, size: 100),
              const SizedBox(height: 24),
              const Text(
                'ACCOUNT BLOCKED',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your account has been blocked by the administrator. Please contact support for more information.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              CustomButton(
                text: 'Refresh Status',
                isLoading: _isLoading,
                onPressed: _checkStatus,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
