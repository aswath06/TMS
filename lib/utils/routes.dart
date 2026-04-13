import 'package:flutter/material.dart';
import 'package:tripzo/screens/admin/admin_dashboard_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/get_started_screen.dart';
import '../screens/auth/setup_permissions_screen.dart';
import '../screens/main_screen.dart';
import '../screens/auth/lock_screen.dart';

class AppRoutes {
  static const String adminDashboard = '/admin-dashboard';
  static const String splash = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String lockScreen = '/lock-screen';
  static const String getStarted = '/get-started';
  static const String setupPermissions = '/setup-permissions';

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
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());

      case getStarted:
        return MaterialPageRoute(builder: (_) => const GetStartedScreen());

      case setupPermissions:
        return MaterialPageRoute(builder: (_) => const SetupPermissionsScreen());

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
