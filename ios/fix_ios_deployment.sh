#!/bin/bash
# Fixes FlutterGeneratedPluginSwiftPackage minimum iOS version to 15.0
# Run this after every `flutter pub get` or `flutter clean`
PACKAGE_SWIFT="$(dirname "$0")/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
if [ -f "$PACKAGE_SWIFT" ]; then
  sed -i '' 's/.iOS("13.0")/.iOS("15.0")/g' "$PACKAGE_SWIFT"
  echo "✅ Patched Package.swift iOS version to 15.0"
else
  echo "⚠️  Package.swift not found. Run 'flutter pub get' first."
fi
