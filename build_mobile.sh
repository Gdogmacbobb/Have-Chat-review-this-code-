#!/bin/bash
# YNFNY Mobile Build Script
# Builds Android APK and iOS app for mobile testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}📱 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to build Android APK
build_android() {
    print_status "Building Android APK..."
    
    # Clean previous build
    flutter clean
    flutter pub get
    
    # Build release APK with environment variables  
    print_status "Compiling Android APK with native camera support..."
    
    # Check if env.json exists and use it if available
    if [ -f "env.json" ]; then
        print_status "Using environment configuration from env.json"
        flutter build apk --release \
            --dart-define-from-file=env.json \
            --target-platform android-arm,android-arm64,android-x64
    else
        print_warning "env.json not found - building with default configuration"
        flutter build apk --release \
            --target-platform android-arm,android-arm64,android-x64
    fi
    
    # Check if build was successful
    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        APK_SIZE=$(du -h build/app/outputs/flutter-apk/app-release.apk | cut -f1)
        print_success "Android APK built successfully!"
        print_success "File: build/app/outputs/flutter-apk/app-release.apk (${APK_SIZE})"
        print_success "Install with: adb install build/app/outputs/flutter-apk/app-release.apk"
    else
        print_error "Android APK build failed!"
        return 1
    fi
}

# Function to build iOS app
build_ios() {
    print_status "Building iOS app for TestFlight..."
    
    # Clean previous build
    flutter clean
    flutter pub get
    
    # Build iOS release
    print_status "Compiling iOS app with native camera support..."
    
    # Check if env.json exists and use it if available
    if [ -f "env.json" ]; then
        print_status "Using environment configuration from env.json"
        flutter build ios --release \
            --dart-define-from-file=env.json \
            --no-codesign
    else
        print_warning "env.json not found - building with default configuration"
        flutter build ios --release \
            --no-codesign
    fi
    
    # Check if build was successful
    if [ -d "build/ios/iphoneos/Runner.app" ]; then
        print_success "iOS app built successfully!"
        print_success "Location: build/ios/iphoneos/Runner.app"
        print_warning "To create IPA for TestFlight:"
        echo "  1. Open ios/Runner.xcworkspace in Xcode"
        echo "  2. Select 'Any iOS Device' as target"
        echo "  3. Go to Product → Archive"
        echo "  4. Upload to App Store Connect"
    else
        print_error "iOS build failed!"
        return 1
    fi
}

# Main script logic
echo -e "${BLUE}"
echo "🎬 YNFNY Mobile Build System"
echo "Building native mobile apps with camera functionality"
echo -e "${NC}"

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    print_error "Flutter not found! Please install Flutter first."
    exit 1
fi

# Check Flutter doctor
print_status "Checking Flutter environment..."
flutter doctor --verbose

# Parse command line arguments
case "${1:-both}" in
    "android")
        build_android
        ;;
    "ios")
        build_ios
        ;;
    "both")
        print_status "Building both Android and iOS apps..."
        build_android
        echo
        build_ios
        ;;
    *)
        echo "Usage: $0 [android|ios|both]"
        echo "  android: Build only Android APK"
        echo "  ios:     Build only iOS app"
        echo "  both:    Build both platforms (default)"
        exit 1
        ;;
esac

print_success "🎉 Mobile build process completed!"
echo
print_status "Next steps for testing:"
echo "📱 Android: Install APK directly on device for testing"
echo "🍎 iOS: Use Xcode to create IPA and upload to TestFlight"