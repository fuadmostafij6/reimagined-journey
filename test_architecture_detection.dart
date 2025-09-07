// Test file to demonstrate architecture detection
// This shows how the app will detect different device architectures

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

void main() async {
  print('=== Device Architecture Detection Test ===\n');
  
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    
    print('Device Information:');
    print('Model: ${androidInfo.model}');
    print('Brand: ${androidInfo.brand}');
    print('Manufacturer: ${androidInfo.manufacturer}');
    print('Android Version: ${androidInfo.version.release}');
    print('SDK Version: ${androidInfo.version.sdkInt}');
    print('Supported ABIs: ${androidInfo.supportedAbis}');
    print('');
    
    // Simulate the detection logic
    final detectedArch = await _getDeviceArchitecture();
    print('Detected Architecture: $detectedArch');
    print('');
    
    // Show which APK would be selected
    final apkName = _getApkNameForArchitecture(detectedArch);
    print('Selected APK: $apkName');
    
  } else {
    print('This test is for Android devices only.');
  }
}

Future<String> _getDeviceArchitecture() async {
  try {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final supportedAbis = androidInfo.supportedAbis;
      
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
    
    return 'arm64-v8a';
  } catch (e) {
    print('Error getting device architecture: $e');
    return 'arm64-v8a';
  }
}

String _getApkNameForArchitecture(String arch) {
  switch (arch) {
    case 'arm64-v8a':
      return 'app-arm64-v8a-release.apk (21.3 MB) - Modern devices';
    case 'armeabi-v7a':
      return 'app-armeabi-v7a-release.apk (18.7 MB) - Older devices';
    case 'x86_64':
      return 'app-x86_64-release.apk (22.5 MB) - Emulators/Tablets';
    case 'x86':
      return 'app-x86-release.apk (20.1 MB) - Older emulators';
    case 'armeabi':
      return 'app-armeabi-release.apk (16.8 MB) - Very old devices';
    default:
      return 'app-release.apk (25.0 MB) - Universal fallback';
  }
}
