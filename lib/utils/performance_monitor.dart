import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Performance monitoring utility for splash screen optimization
class PerformanceMonitor {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, Duration> _durations = {};
  
  /// Start timing a performance metric
  static void startTiming(String metricName) {
    _startTimes[metricName] = DateTime.now();
    if (kDebugMode) {
      developer.log('⏱️ Started timing: $metricName');
    }
  }
  
  /// End timing and log the duration
  static Duration endTiming(String metricName) {
    final startTime = _startTimes[metricName];
    if (startTime == null) {
      if (kDebugMode) {
        developer.log('❌ No start time found for: $metricName');
      }
      return Duration.zero;
    }
    
    final duration = DateTime.now().difference(startTime);
    _durations[metricName] = duration;
    
    if (kDebugMode) {
      developer.log('⏱️ $metricName: ${duration.inMilliseconds}ms');
    }
    
    _startTimes.remove(metricName);
    return duration;
  }
  
  /// Get duration for a metric
  static Duration? getDuration(String metricName) {
    return _durations[metricName];
  }
  
  /// Log all performance metrics
  static void logAllMetrics() {
    if (kDebugMode) {
      developer.log('📊 Performance Summary:');
      _durations.forEach((metric, duration) {
        developer.log('   $metric: ${duration.inMilliseconds}ms');
      });
    }
  }
  
  /// Clear all metrics
  static void clearMetrics() {
    _startTimes.clear();
    _durations.clear();
  }
  
  /// Check if a metric exceeds threshold
  static bool exceedsThreshold(String metricName, Duration threshold) {
    final duration = _durations[metricName];
    if (duration == null) return false;
    return duration > threshold;
  }
  
  /// Get performance summary for splash screen
  static Map<String, String> getSplashPerformanceSummary() {
    final summary = <String, String>{};
    
    final appStart = getDuration('app_start');
    final nativeSplash = getDuration('native_splash');
    final flutterInit = getDuration('flutter_init');
    final splashScreen = getDuration('splash_screen');
    final navigation = getDuration('navigation');
    
    if (appStart != null) {
      summary['App Start'] = '${appStart.inMilliseconds}ms';
    }
    if (nativeSplash != null) {
      summary['Native Splash'] = '${nativeSplash.inMilliseconds}ms';
    }
    if (flutterInit != null) {
      summary['Flutter Init'] = '${flutterInit.inMilliseconds}ms';
    }
    if (splashScreen != null) {
      summary['Splash Screen'] = '${splashScreen.inMilliseconds}ms';
    }
    if (navigation != null) {
      summary['Navigation'] = '${navigation.inMilliseconds}ms';
    }
    
    return summary;
  }
}
