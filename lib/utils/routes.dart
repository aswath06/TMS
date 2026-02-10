import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/main_screen.dart';
import '../screens/auth/lock_screen.dart'; // Import the new LockScreen

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String lockScreen = '/lock-screen'; // New Route

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case login:
        return PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        );

      case lockScreen:
        // We pass the role to the lock screen so it knows where to go after success
        final role = settings.arguments as String? ?? 'faculty';
        return MaterialPageRoute(builder: (_) => LockScreen(role: role));

      case dashboard:
        final role = settings.arguments as String? ?? 'faculty';
        return MaterialPageRoute(builder: (_) => MainScreen(userRole: role));

      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }
}
