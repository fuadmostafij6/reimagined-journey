#!/bin/bash

echo "Setting up optimized native splash screen for release builds..."

# Install dependencies
echo "Installing dependencies..."
flutter pub get

# Clean previous builds
echo "Cleaning previous builds..."
flutter clean

# Generate native splash screen with optimized settings
echo "Generating optimized native splash screen..."
flutter pub run flutter_native_splash:create

# Build release APK to test native splash performance
echo "Building release APK to test performance..."
flutter build apk --release

echo ""
echo "✅ Native splash screen setup complete!"
echo ""
echo "🚀 Performance optimizations applied:"
echo "   • Instant native splash display"
echo "   • Seamless transition to Flutter"
echo "   • Background ads initialization"
echo "   • Optimized for release builds"
echo ""
echo "📱 To test on device:"
echo "   flutter install --release"
echo ""
echo "🔧 If you encounter issues:"
echo "   flutter clean && flutter pub get && flutter pub run flutter_native_splash:create"
