import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
      duration: const Duration(seconds: 2),
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
      setState(() {
        _statusText = 'Checking for updates...';
      });

      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;

      // Fetch latest release from GitHub
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/fuadmostafij6/reimagined-journey/releases/latest'),
        headers: {
          'Authorization': 'Bearer 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',
          'Accept': 'application/vnd.github+json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _latestRelease = GitHubRelease.fromJson(data);
        
        setState(() {
          _statusText = 'Update check complete';
        });

        // Compare versions
        if (_isNewVersionAvailable()) {
          await Future.delayed(const Duration(seconds: 1));
          _showUpdateDialog();
        } else {
          await Future.delayed(const Duration(seconds: 2));
          _navigateToHome();
        }
      } else {
        setState(() {
          _statusText = 'Failed to check updates';
        });
        await Future.delayed(const Duration(seconds: 2));
        _navigateToHome();
      }
    } catch (e) {
      setState(() {
        _statusText = 'Error: $e';
      });
      await Future.delayed(const Duration(seconds: 2));
      _navigateToHome();
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
    showDialog(
      context: context,
      barrierDismissible: false,
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
              _navigateToHome();
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

      // Request storage permission
      final storageStatus = await Permission.storage.request();
      if (storageStatus != PermissionStatus.granted) {
        setState(() {
          _statusText = 'Storage permission denied';
        });
        await Future.delayed(const Duration(seconds: 2));
        _navigateToHome();
        return;
      }

      setState(() {
        _statusText = 'Downloading update...';
      });

      // Get download directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        setState(() {
          _statusText = 'Failed to get storage directory';
        });
        await Future.delayed(const Duration(seconds: 2));
        _navigateToHome();
        return;
      }

      final file = File('${directory.path}/app-update.apk');

      // Download the APK
      final response = await http.get(
        Uri.parse(_latestRelease!.browserDownloadUrl),
      );

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        
        setState(() {
          _statusText = 'Installing update...';
        });

        // Install the APK
        await _installApk(file.path);
      } else {
        setState(() {
          _statusText = 'Download failed';
        });
        await Future.delayed(const Duration(seconds: 2));
        _navigateToHome();
      }
    } catch (e) {
      setState(() {
        _statusText = 'Error: $e';
      });
      await Future.delayed(const Duration(seconds: 2));
      _navigateToHome();
    }
  }

  Future<void> _installApk(String apkPath) async {
    try {
      // Request install permission
      final installStatus = await Permission.requestInstallPackages.request();
      if (installStatus != PermissionStatus.granted) {
        setState(() {
          _statusText = 'Install permission denied';
        });
        await Future.delayed(const Duration(seconds: 2));
        _navigateToHome();
        return;
      }

      // Launch the APK installer
      final uri = Uri.parse('file://$apkPath');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        // Exit the app to allow installation
        SystemNavigator.pop();
      } else {
        setState(() {
          _statusText = 'Failed to launch installer';
        });
        await Future.delayed(const Duration(seconds: 2));
        _navigateToHome();
      }
    } catch (e) {
      setState(() {
        _statusText = 'Installation failed: $e';
      });
      await Future.delayed(const Duration(seconds: 2));
      _navigateToHome();
    }
  }

  void _navigateToHome() {
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
              // App Logo/Icon
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
                          gradient: const LinearGradient(
                            colors: [Colors.blue, Colors.blueAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.live_tv,
                          color: Colors.white,
                          size: 60,
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
                      'TV App',
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
    
    // Find the APK asset
    final apkAsset = assets.firstWhere(
      (asset) => asset.name.endsWith('.apk'),
      orElse: () => GitHubAsset(name: '', browserDownloadUrl: ''),
    );

    return GitHubRelease(
      tagName: json['tag_name'] ?? '',
      name: json['name'] ?? '',
      body: json['body'] ?? '',
      browserDownloadUrl: apkAsset.browserDownloadUrl,
      assets: assets,
    );
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
