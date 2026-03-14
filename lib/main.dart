import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

// Stores
import 'package:tripzo/store/VehicleStore.dart';
import 'package:tripzo/store/request_store.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:tripzo/store/dashboard_store.dart';

// Utils
import 'utils/routes.dart';

void main() async {
  // Ensure Flutter framework is initialized before running code
  WidgetsFlutterBinding.ensureInitialized();

  // INITIALIZE DATE FORMATTING
  try {
    await initializeDateFormatting('ta', null);
    await initializeDateFormatting('en', null);
  } catch (e) {
    debugPrint("Locale initialization error: $e");
  }

  // Premium Edge-to-Edge System UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VehicleStore()),
        ChangeNotifierProvider.value(value: useRequestStore),
        ChangeNotifierProvider.value(value: useDriverStore),
        ChangeNotifierProvider.value(value: dashboardStore),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TripZo',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: null,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          primary: const Color(0xFF4F46E5),
          surface: const Color(0xFFF8FAFC),
          onSurface: const Color(0xFF0F172A),
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
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
