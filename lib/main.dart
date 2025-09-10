import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/youtube_search_page.dart';
import 'pages/live_tv_page.dart';
import 'screens/splash_screen.dart';
import 'screens/fast_splash_screen.dart';
import 'screens/instant_splash_screen.dart';
import 'utils/performance_monitor.dart';

void main() async {
  // Start performance monitoring
  PerformanceMonitor.startTiming('app_start');
  
  WidgetsFlutterBinding.ensureInitialized();
  
  // Allow runtime font fetching only on mobile; disable on desktop/web
  GoogleFonts.config.allowRuntimeFetching = Platform.isAndroid || Platform.isIOS;
  
  // Initialize Google Mobile Ads SDK in background to avoid blocking startup
  if (Platform.isAndroid || Platform.isIOS) {
    _initializeAdsInBackground();
  }
  
  runApp(const MyApp());
}

void _initializeAdsInBackground() async {
  try {
    await MobileAds.instance.initialize();
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(testDeviceIds: <String>[]),
    );
  } catch (e) {
    // Silently handle ads initialization errors
    print('Ads initialization failed: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseSeed = const Color(0xFF6750A4);
    final isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;

    final lightTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: baseSeed, brightness: Brightness.light),
      textTheme: isDesktop ? null : GoogleFonts.notoSansTextTheme(),
      scaffoldBackgroundColor: const Color(0xFFF7F7FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F1B2E),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.black.withOpacity(0.06),
        selectedColor: const Color(0xFF2962FF),
        labelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF000000).withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    final darkScheme = ColorScheme.fromSeed(seedColor: baseSeed, brightness: Brightness.dark);
    final darkTheme = ThemeData(
      useMaterial3: true,
      colorScheme: darkScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      textTheme: isDesktop ? ThemeData.dark().textTheme : GoogleFonts.notoSansTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F1B2E),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withOpacity(0.08),
        selectedColor: const Color(0xFF2962FF),
        labelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        hintStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2962FF), width: 2),
        ),
      ),
      dividerColor: Colors.white.withOpacity(0.12),
    );

    return MaterialApp(
      title: 'onAir',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 0;

  final _pages = const [
    YoutubeSearchPage(),
    LiveTvPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[1],
    );
  }
}
