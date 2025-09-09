/// Release-specific configuration for optimal performance
class ReleaseConfig {
  // Disable debug features in release builds
  static const bool enableDebugLogs = false;
  static const bool enablePerformanceOverlay = false;
  static const bool enableSlowAnimations = false;
  
  // Splash screen timing for release builds
  static const Duration splashScreenDuration = Duration(milliseconds: 500);
  static const Duration nativeSplashTransition = Duration(milliseconds: 200);
  
  // Network timeouts for release builds
  static const Duration networkTimeout = Duration(seconds: 3);
  static const Duration updateCheckTimeout = Duration(seconds: 2);
  
  // Animation durations optimized for release
  static const Duration fastAnimation = Duration(milliseconds: 300);
  static const Duration mediumAnimation = Duration(milliseconds: 500);
  static const Duration slowAnimation = Duration(milliseconds: 800);
  
  // Memory optimization settings
  static const int maxCacheSize = 50; // MB
  static const int maxImageCacheSize = 100; // MB
  
  // Performance monitoring
  static const bool enablePerformanceMonitoring = false;
  static const bool enableCrashReporting = true;
}
