#!/bin/bash

echo "Setting up native splash screen for faster app startup..."

# Install dependencies
echo "Installing dependencies..."
flutter pub get

# Generate native splash screen
echo "Generating native splash screen..."
flutter pub run flutter_native_splash:create

echo "Native splash screen setup complete!"
echo "The app will now show a native splash screen immediately when launched."
echo "Run 'flutter clean && flutter pub get' if you encounter any issues."
