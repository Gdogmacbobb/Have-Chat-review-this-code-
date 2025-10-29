// Stub for dart:ui_web on non-web platforms
// This file is imported on mobile (iOS/Android) where dart:ui_web doesn't exist

class PlatformViewRegistry {
  void registerViewFactory(String viewId, dynamic Function(int) viewFactory) {
    throw UnsupportedError('Platform views are only supported on web');
  }
}

final platformViewRegistry = PlatformViewRegistry();
