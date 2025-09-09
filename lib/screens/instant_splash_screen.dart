import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../pages/live_tv_page.dart';
import '../utils/performance_monitor.dart';

/// Instant splash screen that immediately transitions from native splash
/// Optimized for release builds on real devices
class InstantSplashScreen extends StatefulWidget {
  const InstantSplashScreen({super.key});

  @override
  State<InstantSplashScreen> createState() => _InstantSplashScreenState();
}

class _InstantSplashScreenState extends State<InstantSplashScreen> {
  @override
  void initState() {
    super.initState();
    
    // Start performance monitoring
    PerformanceMonitor.startTiming('splash_screen');
    
    // Immediately navigate to home - no delays, no animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToHome();
    });
  }

  void _navigateToHome() {
    if (!mounted) return;
    
    // End performance monitoring
    PerformanceMonitor.endTiming('splash_screen');
    PerformanceMonitor.startTiming('navigation');
    
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LiveTvPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Return the same design as native splash for seamless transition
    return Scaffold(
      backgroundColor: const Color(0xFF1F1B2E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1F1B2E),
              Color(0xFF2B2250),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo - matches native splash exactly
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  child: Image(
                    image: AssetImage('assets/logo.png'),
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // App Name
              const Text(
                'onAir',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
