import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/utils/toast_utils.dart';

// Stores
import 'package:tripzo/store/VehicleStore.dart';
import 'package:tripzo/store/request_store.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/dashboard_store.dart';
import 'package:tripzo/store/isdark.dart';
import 'package:tripzo/store/istamil.dart';
import 'package:tripzo/store/admin_allowance_store.dart';

// Utils
import 'utils/routes.dart';
import 'package:tripzo/services/location_service.dart';
import 'package:tripzo/services/notification_local_service.dart';
import 'package:tripzo/services/notification_api_service.dart';
import 'package:tripzo/providers/notification_provider.dart';
import 'package:tripzo/store/providers.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  // Ensure Flutter framework is initialized before running code
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();

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



  // FORCE PORTRAIT MODE ONLY
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
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
