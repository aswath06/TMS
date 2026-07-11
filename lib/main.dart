import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/utils/toast_utils.dart';

// Stores
import 'package:tripzo/store/isdark.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/store/user_store.dart';

// Utils
import 'utils/routes.dart';
import 'package:tripzo/services/location_service.dart';
import 'package:tripzo/services/notification_local_service.dart';
import 'package:tripzo/store/providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:tripzo/services/notification_firebase_service.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/store/app_lifecycle_provider.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class BlockInterceptorClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  static bool _isNavigatingToBlocked = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    
    if (response.statusCode == 403 && response.headers['x-account-blocked'] == 'true') {
      if (!_isNavigatingToBlocked) {
        _isNavigatingToBlocked = true;
        Future.microtask(() {
          if (AppRoutes.navigatorKey.currentContext != null) {
            final currentRoute = ModalRoute.of(AppRoutes.navigatorKey.currentContext!)?.settings.name;
            if (currentRoute != AppRoutes.accountBlocked) {
              AppRoutes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
                AppRoutes.accountBlocked,
                (route) => false,
              );
            }
          }
          // Reset the flag after a short delay to allow future interceptions if needed
          Future.delayed(const Duration(seconds: 2), () {
            _isNavigatingToBlocked = false;
          });
        });
      }
    }
    return response;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  http.runWithClient(() async {
    // Ensure Flutter framework is initialized before running code
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase
    await Firebase.initializeApp();
    
    // Set Firebase background messaging handler early
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize Background Location Service (Non-blocking)
    LocationService().initializeService().catchError((e) {
      debugPrint("Background Service Init Error: $e");
    });

    // Initialize Local Notification Service
    await NotificationLocalService.initialize();

    // INITIALIZE DATE FORMATTING
    try {
      await initializeDateFormatting('ta', null);
      await initializeDateFormatting('en', null);
    } catch (e) {
      debugPrint("Locale initialization error: $e");
    }

    // Load theme and other persistent data
    await themeStore.loadTheme();
    await languageStore.loadLanguage();
    
    // Initialize global in-memory static cache for user data
    await UserStore.init();

    // FORCE PORTRAIT MODE ONLY
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    runApp(
      const ProviderScope(
        child: AppLifecycleObserver(
          child: MyApp(),
        ),
      ),
    );
  }, () => BlockInterceptorClient());
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeStoreProvider);
    final bool isDark = ThemeStore.isDark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: MaterialApp(
        navigatorKey: AppRoutes.navigatorKey,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => CustomScaffoldMessenger(child: child!),
        title: 'TripZo',
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: null,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4F46E5),
            primary: const Color(0xFF4F46E5),
            surface: const Color(0xFFF8FAFC),
            onSurface: const Color(0xFF0F172A),
            brightness: Brightness.light,
          ),
          textTheme: const TextTheme(
            displayLarge: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
            headlineMedium: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            titleLarge: TextStyle(fontWeight: FontWeight.w700),
            bodyMedium: TextStyle(fontWeight: FontWeight.w500),
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: Colors.transparent,
            centerTitle: false,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          fontFamily: null,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4F46E5),
            primary: const Color(0xFF6366F1),
            surface: const Color(0xFF0F172A),
            onSurface: Colors.white,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          textTheme: const TextTheme(
            displayLarge: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
              color: Colors.white,
            ),
            headlineMedium: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
            titleLarge: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            bodyMedium: TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
          ),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            backgroundColor: Colors.transparent,
            centerTitle: false,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.generateRoute,
      ),
    );
  }
}
