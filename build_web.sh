#!/bin/bash
# YNFNY Web Build Script
# This script ensures Material Icons are preserved during builds
# The --no-tree-shake-icons flag is REQUIRED to keep all icon glyphs

set -e

echo "🧹 Cleaning previous build..."
flutter clean

echo "🗑️  Removing build and .dart_tool directories..."
rm -rf build .dart_tool

echo "📦 Getting dependencies..."
flutter pub get

echo "🌐 Building for web (HTML renderer via web/index.html, preserving Material Icons)..."
flutter build web --no-tree-shake-icons

echo "✅ Build complete! Icons, images, and fonts preserved."
echo "📊 Build output:"
ls -lh build/web/*.js | head -3
