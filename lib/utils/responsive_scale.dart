import 'package:flutter/material.dart';

/// ResponsiveScale service that provides Sizer-compatible responsive scaling
/// Drop-in replacement for package:sizer/sizer.dart
class ResponsiveScale {
  static late Size _screenSize;
  static late double _screenWidth;
  static late double _screenHeight;
  static late double _pixelRatio;
  
  /// Initialize ResponsiveScale with screen dimensions
  static void init(Size screenSize, double pixelRatio) {
    _screenSize = screenSize;
    _screenWidth = screenSize.width;
    _screenHeight = screenSize.height;
    _pixelRatio = pixelRatio;
  }
  
  /// Convert percentage width to pixels (equivalent to .w)
  static double w(num percentage) {
    return _screenWidth * (percentage / 100);
  }
  
  /// Convert percentage height to pixels (equivalent to .h)
  static double h(num percentage) {
    return _screenHeight * (percentage / 100);
  }
  
  /// Convert percentage to scaled pixels for text (equivalent to .sp)
  static double sp(num percentage) {
    // Use the shorter dimension for consistent text scaling
    final referenceSize = _screenWidth < _screenHeight ? _screenWidth : _screenHeight;
    return referenceSize * (percentage / 100);
  }
  
  /// Get screen width
  static double get screenWidth => _screenWidth;
  
  /// Get screen height  
  static double get screenHeight => _screenHeight;
  
  /// Get screen size
  static Size get screenSize => _screenSize;
}

/// Extension on numbers to provide .w, .h, .sp methods (drop-in Sizer replacement)
extension ResponsiveInt on int {
  /// Convert percentage width to pixels (equivalent to Sizer .w)
  double get w => ResponsiveScale.w(this);
  
  /// Convert percentage height to pixels (equivalent to Sizer .h)  
  double get h => ResponsiveScale.h(this);
  
  /// Convert percentage to scaled pixels for text (equivalent to Sizer .sp)
  double get sp => ResponsiveScale.sp(this);
}

extension ResponsiveDouble on double {
  /// Convert percentage width to pixels (equivalent to Sizer .w)
  double get w => ResponsiveScale.w(this);
  
  /// Convert percentage height to pixels (equivalent to Sizer .h)
  double get h => ResponsiveScale.h(this);
  
  /// Convert percentage to scaled pixels for text (equivalent to Sizer .sp)
  double get sp => ResponsiveScale.sp(this);
}

/// Widget wrapper that initializes ResponsiveScale (equivalent to Sizer widget)
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  
  const ResponsiveWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        ResponsiveScale.init(
          mediaQuery.size,
          mediaQuery.devicePixelRatio,
        );
        return child;
      },
    );
  }
}