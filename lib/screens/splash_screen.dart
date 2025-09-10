import 'dart:convert';
import 'dart:io';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../pages/live_tv_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _isLoading = true;
  String _statusText = 'Loading...';
  GitHubRelease? _latestRelease;
  String? _currentVersion;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkForUpdates();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200), // Reduced from 2 seconds
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  Future<void> _checkForUpdates() async {
    try {
      // Skip update check on non-Android platforms (avoid desktop network/permission issues)
      if (!Platform.isAndroid) {
        await Future.delayed(const Duration(milliseconds: 800));
        _navigateToHome();
        return;
      }

      setState(() {
        _statusText = 'Loading...';
      });

      // Get current app version (fast operation)
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;

      // Start update check in background with timeout
      _checkForUpdatesInBackground();
      
      // Navigate to home after minimum splash time (1.5 seconds)
      await Future.delayed(const Duration(milliseconds: 1500));
      _navigateToHome();
      
    } catch (e) {
      setState(() {
        _statusText = 'Loading...';
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      _navigateToHome();
    }
  }

  Future<void> _checkForUpdatesInBackground() async {
    try {
      if (!Platform.isAndroid) return;
      // Fetch latest release from GitHub with timeout
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/fuadmostafij6/reimagined-journey/releases/latest'),
      ).timeout(
        const Duration(seconds: 5), // 5 second timeout
        onTimeout: () {
          throw Exception('Update check timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _latestRelease = GitHubRelease.fromJson(data);
        
        // Debug: Print release info
        print('Latest release: ${_latestRelease!.tagName}');
        print('Download URL: ${_latestRelease!.browserDownloadUrl}');
        
        if (_latestRelease!.browserDownloadUrl.isNotEmpty && _isNewVersionAvailable()) {
          // Show update dialog if new version is available
          _showUpdateDialog();
        }
      }
    } catch (e) {
      print('Background update check failed: $e');
      // Silently fail - don't block the app
    }
  }

  bool _isNewVersionAvailable() {
    if (_latestRelease == null || _currentVersion == null) return false;
    
    // Extract version numbers (remove 'v-' prefix if present)
    String latestVersion = _latestRelease!.tagName.replaceAll('v-', '');
    String currentVersion = _currentVersion!;
    
    // Simple version comparison
    return latestVersion != currentVersion;
  }

  void _showUpdateDialog() {
    // Only show dialog if we're still in the splash screen context
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: true, // Allow dismissing
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.system_update,
                color: Colors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Update Available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version is available:',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Current Version: ',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _currentVersion ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        'Latest Version: ',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _latestRelease?.tagName.replaceAll('v-', '') ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _latestRelease?.body ?? 'Bug fixes and improvements',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Don't navigate to home if we're already there
              if (mounted) {
                _navigateToHome();
              }
            },
            child: Text(
              'Skip',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _downloadAndInstall();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Download & Install',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall() async {
    if (_latestRelease == null) return;

    try {
      setState(() {
        _statusText = 'Requesting permissions...';
      });

      // For Android 11+ (API 30+), we don't need storage permission for app's own directory
      // For older versions, request storage permission
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt < 30) {
          final storageStatus = await Permission.storage.request();
          if (storageStatus != PermissionStatus.granted) {
            setState(() {
              _statusText = 'Storage permission required for download';
            });
            await Future.delayed(const Duration(seconds: 2));
            _navigateToHome();
            return;
          }
        }
      }

      setState(() {
        _statusText = 'Downloading update...';
      });

      // Get app's cache directory (no permission needed)
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/app-update.apk');

      // Get device-specific download URL
      final downloadUrl = await _latestRelease!.getDeviceSpecificDownloadUrl();
      
      // Debug: Print download URL
      print('Downloading from: $downloadUrl');

      // Download the APK with timeout and better error handling
      final response = await http.get(
        Uri.parse(downloadUrl),
        headers: {
          'Authorization': 'Bearer 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',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; SM-G973F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw Exception('Download timeout');
        },
      );

      print('Download response status: ${response.statusCode}');
      print('Download response headers: ${response.headers}');

      if (response.statusCode == 200) {
        if (response.bodyBytes.isNotEmpty) {
          await file.writeAsBytes(response.bodyBytes);
          print('APK downloaded successfully, size: ${response.bodyBytes.length} bytes');
          
          setState(() {
            _statusText = 'Installing update...';
          });

          // Install the APK
          await _installApk(file.path);
        } else {
          setState(() {
            _statusText = 'Download failed: Empty file';
          });
          await Future.delayed(const Duration(seconds: 2));
          _navigateToHome();
        }
      } else {
        String errorMessage = 'Download failed: HTTP ${response.statusCode}';
        if (response.statusCode == 404) {
          errorMessage = 'APK file not found. Please check the release.';
        } else if (response.statusCode == 403) {
          errorMessage = 'Access denied. Please check permissions.';
        }
        
        setState(() {
          _statusText = errorMessage;
        });
        await Future.delayed(const Duration(seconds: 3));
        _navigateToHome();
      }
    } catch (e) {
      print('Download error: $e');
      setState(() {
        _statusText = 'Download failed: $e';
      });
      
      // Try alternative download method
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _statusText = 'Trying alternative download...';
      });
      
      try {
        await _downloadWithAlternativeMethod();
      } catch (e2) {
        print('Alternative download also failed: $e2');
        setState(() {
          _statusText = 'All download methods failed';
        });
        await Future.delayed(const Duration(seconds: 2));
        _navigateToHome();
      }
    }
  }

  Future<void> _downloadWithAlternativeMethod() async {
    if (_latestRelease == null) return;

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/app-update-alt.apk');

    // Try with different headers
    final response = await http.get(
      Uri.parse(_latestRelease!.browserDownloadUrl),
      headers: {
        'Authorization': 'Bearer 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',
        'User-Agent': 'tv-app/1.0',
        'Accept': 'application/octet-stream,*/*',
      },
    ).timeout(const Duration(minutes: 3));

    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      await file.writeAsBytes(response.bodyBytes);
      print('Alternative download successful, size: ${response.bodyBytes.length} bytes');
      
      setState(() {
        _statusText = 'Installing update...';
      });

      await _installApk(file.path);
    } else {
      throw Exception('Alternative download failed: HTTP ${response.statusCode}');
    }
  }

  Future<void> _installApk(String apkPath) async {
    try {
      // For Android 8.0+ (API 26+), we need to use ACTION_VIEW intent
      if (Platform.isAndroid) {
        // Check if we can install packages
        final installStatus = await Permission.requestInstallPackages.status;
        
        if (installStatus != PermissionStatus.granted) {
          // Try to request permission
          final requestResult = await Permission.requestInstallPackages.request();
          if (requestResult != PermissionStatus.granted) {
            setState(() {
              _statusText = 'Install permission required. Please enable "Install unknown apps" in settings.';
            });
            await Future.delayed(const Duration(seconds: 3));
            _navigateToHome();
            return;
          }
        }

        // Use FileProvider URI for secure file sharing
        final file = File(apkPath);
        if (!await file.exists()) {
          setState(() {
            _statusText = 'APK file not found';
          });
          await Future.delayed(const Duration(seconds: 2));
          _navigateToHome();
          return;
        }

        // Create content URI using FileProvider
        // Use cache path since we're downloading to getTemporaryDirectory()
        final uri = Uri.parse('content://com.onair.app.fileprovider/cache/app-update.apk');
        
        print('APK file path: $apkPath');
        print('File exists: ${await file.exists()}');
        print('File size: ${await file.length()}');
        print('Content URI: $uri');
        
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: uri.toString(),
          type: 'application/vnd.android.package-archive',
          flags: <int>[
            Flag.FLAG_ACTIVITY_NEW_TASK,
            Flag.FLAG_GRANT_READ_URI_PERMISSION,
            Flag.FLAG_GRANT_WRITE_URI_PERMISSION,
          ],
        );
        
        try {
          await intent.launch();
          // Exit the app to allow installation
          SystemNavigator.pop();
        } catch (e, s) {
          print('Intent launch error: $e');
          print('Stack trace: $s');
          
          // Fallback: Show manual installation message
          setState(() {
            _statusText = 'Please install the APK manually from: $apkPath';
          });
          await Future.delayed(const Duration(seconds: 3));
          _navigateToHome();
        }
      } else {
        // For non-Android platforms, use url_launcher
        final uri = Uri.parse('file://$apkPath');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          SystemNavigator.pop();
        } else {
          setState(() {
            _statusText = 'Failed to launch installer';
          });
          await Future.delayed(const Duration(seconds: 2));
          _navigateToHome();
        }
      }
    } catch (e, s) {
      print(e);
      print(s);
      setState(() {
        _statusText = 'Installation failed: $e';
      });
      await Future.delayed(const Duration(seconds: 2));
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    if (!mounted) return; // Prevent navigation if widget is disposed
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LiveTvPage(),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              // App Logo
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/logo.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 40),
              
              // App Name
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Text(
                      'onAir',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 8),
              
              // Version
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value * 0.7,
                    child: Text(
                      'Version ${_currentVersion ?? '1.0.1'}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 60),
              
              // Loading indicator
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Column(
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _statusText,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GitHubRelease {
  final String tagName;
  final String name;
  final String body;
  final String browserDownloadUrl;
  final List<GitHubAsset> assets;

  GitHubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.browserDownloadUrl,
    required this.assets,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    final assets = (json['assets'] as List?)
        ?.map((asset) => GitHubAsset.fromJson(asset))
        .toList() ?? [];
    
    // Find the APK asset - try different common APK names
    GitHubAsset? apkAsset;
    
    // First try to find app-release.apk
    try {
      apkAsset = assets.firstWhere((asset) => asset.name == 'app-release.apk');
    } catch (e) {
      // Try to find any .apk file
      try {
        apkAsset = assets.firstWhere((asset) => asset.name.endsWith('.apk'));
      } catch (e) {
        // Try to find files with 'release' in the name
        try {
          apkAsset = assets.firstWhere((asset) => 
            asset.name.toLowerCase().contains('release') && 
            asset.name.endsWith('.apk'));
        } catch (e) {
          apkAsset = null;
        }
      }
    }

    return GitHubRelease(
      tagName: json['tag_name'] ?? '',
      name: json['name'] ?? '',
      body: json['body'] ?? '',
      browserDownloadUrl: apkAsset?.browserDownloadUrl ?? '',
      assets: assets,
    );
  }

  // Get device-specific APK download URL based on actual device architecture
  Future<String> getDeviceSpecificDownloadUrl() async {
    try {
      // Get device architecture
      final deviceArch = await _getDeviceArchitecture();
      print('Detected device architecture: $deviceArch');
      
      // Try to find architecture-specific APK
      try {
        final specificAsset = assets.firstWhere((asset) => 
          asset.name.contains(deviceArch) && asset.name.endsWith('.apk'));
        print('Found specific APK: ${specificAsset.name}');
        return specificAsset.browserDownloadUrl;
      } catch (e) {
        print('No specific APK found for $deviceArch, trying fallback order');
        
        // Fallback order based on device architecture
        final fallbackOrder = _getFallbackOrder(deviceArch);
        
        for (String arch in fallbackOrder) {
          try {
            final fallbackAsset = assets.firstWhere((asset) => 
              asset.name.contains(arch) && asset.name.endsWith('.apk'));
            print('Using fallback APK: ${fallbackAsset.name}');
            return fallbackAsset.browserDownloadUrl;
          } catch (e) {
            continue;
          }
        }
        
        // Final fallback to generic APK
        print('Using generic APK as final fallback');
        return browserDownloadUrl;
      }
    } catch (e) {
      print('Error detecting architecture: $e');
      return browserDownloadUrl;
    }
  }

  // Detect actual device architecture
  Future<String> _getDeviceArchitecture() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        
        // Get supported ABIs (Application Binary Interfaces)
        final supportedAbis = androidInfo.supportedAbis;
        print('Supported ABIs: $supportedAbis');
        
        // Check for ARM64 first (most modern)
        if (supportedAbis.contains('arm64-v8a')) {
          return 'arm64-v8a';
        }
        
        // Check for ARM32
        if (supportedAbis.contains('armeabi-v7a')) {
          return 'armeabi-v7a';
        }
        
        // Check for x86_64 (emulators)
        if (supportedAbis.contains('x86_64')) {
          return 'x86_64';
        }
        
        // Check for x86 (older emulators)
        if (supportedAbis.contains('x86')) {
          return 'x86';
        }
        
        // Check for ARM (very old devices)
        if (supportedAbis.contains('armeabi')) {
          return 'armeabi';
        }
        
        // Fallback to first supported ABI
        if (supportedAbis.isNotEmpty) {
          return supportedAbis.first;
        }
      }
      
      // Default fallback
      return 'arm64-v8a';
    } catch (e) {
      print('Error getting device architecture: $e');
      return 'arm64-v8a';
    }
  }

  // Get fallback order based on detected architecture
  List<String> _getFallbackOrder(String detectedArch) {
    switch (detectedArch) {
      case 'arm64-v8a':
        return ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'];
      case 'armeabi-v7a':
        return ['armeabi-v7a', 'arm64-v8a', 'x86_64', 'x86'];
      case 'x86_64':
        return ['x86_64', 'x86', 'arm64-v8a', 'armeabi-v7a'];
      case 'x86':
        return ['x86', 'x86_64', 'armeabi-v7a', 'arm64-v8a'];
      default:
        return ['arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'];
    }
  }
}

class GitHubAsset {
  final String name;
  final String browserDownloadUrl;

  GitHubAsset({
    required this.name,
    required this.browserDownloadUrl,
  });

  factory GitHubAsset.fromJson(Map<String, dynamic> json) {
    return GitHubAsset(
      name: json['name'] ?? '',
      browserDownloadUrl: json['browser_download_url'] ?? '',
    );
  }
}
