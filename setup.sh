#!/bin/bash
# ============================================
# BuilderVet - Project Setup Script
# ============================================
# Run this ONCE on your machine to generate
# the platform folders (android/, ios/, etc.)
# ============================================

set -e

echo "🏗️  Setting up BuilderVet..."

# Check Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found. Install it first: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Save our files
echo "📦 Backing up source files..."
cp -r lib lib_backup
cp -r assets assets_backup
cp pubspec.yaml pubspec_backup.yaml

# Create fresh Flutter project in temp dir
echo "🔧 Generating platform files..."
cd ..
flutter create buildervet_temp --org com.buildervet
cd buildervet

# Copy platform folders from generated project
cp -r ../buildervet_temp/android .
cp -r ../buildervet_temp/ios .
cp -r ../buildervet_temp/test .
cp -r ../buildervet_temp/web . 2>/dev/null || true
cp -r ../buildervet_temp/linux . 2>/dev/null || true
cp -r ../buildervet_temp/macos . 2>/dev/null || true
cp -r ../buildervet_temp/windows . 2>/dev/null || true

# Restore our files (overwrite generated ones)
echo "📂 Restoring source files..."
rm -rf lib
mv lib_backup lib
rm -rf assets
mv assets_backup assets
mv pubspec_backup.yaml pubspec.yaml

# Clean up temp project
rm -rf ../buildervet_temp

# Install dependencies
echo "📥 Installing dependencies..."
flutter pub get

echo ""
echo "✅ BuilderVet is ready!"
echo ""
echo "Run on your device:"
echo "  flutter run"
echo ""
echo "Run on iOS Simulator:"
echo "  open -a Simulator && flutter run"
echo ""
echo "Run on Android emulator:"
echo "  flutter emulators --launch <emulator_id> && flutter run"
echo ""
