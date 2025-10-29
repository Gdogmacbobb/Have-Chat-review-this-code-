import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


/// A class that contains all theme configurations for the street performance discovery application.
class AppTheme {
  AppTheme._();

  // NYC Night Palette - Dark backgrounds optimized for video content consumption
  // Primary Orange: Main brand color for CTAs and key UI elements, optimized for dark backgrounds
  static const Color primaryOrange = Color(0xFFFF8C00);
  // Accent Red: Strategic highlights and error states, used sparingly for maximum impact
  static const Color accentRed = Color(0xFFFF0000);
  // Background Dark: Primary dark background following Material Design dark theme guidelines
  static const Color backgroundDark = Color(0xFF121212);
  // Surface Dark: Card backgrounds and elevated surfaces with subtle contrast from primary background
  static const Color surfaceDark = Color(0xFF1E1E1E);
  // Text Primary: High contrast white text for optimal readability on dark surfaces
  static const Color textPrimary = Color(0xFFFFFFFF);
  // Text Secondary: Muted text for captions and secondary information, maintaining accessibility standards
  static const Color textSecondary = Color(0xFFB3B3B3);
  // Success Green: Donation confirmations and positive feedback, avoiding brand confusion with muted tone
  static const Color successGreen = Color(0xFF4CAF50);
  // Border Subtle: Minimal borders when spatial separation needed, used sparingly
  static const Color borderSubtle = Color(0xFF333333);
  // Video Overlay: Semi-transparent overlay for video controls and text, ensuring content readability
  static const Color videoOverlay = Color(0xCC000000);
  // Input Background: Form fields and input areas with sufficient contrast for text entry
  static const Color inputBackground = Color(0xFF2C2C2C);

  // Light theme colors (minimal usage for system compatibility)
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF5F5F5);
  static const Color textOnLight = Color(0xFF000000);

  // Shadow colors with 20% opacity black for subtle elevation
  static const Color shadowDark = Color(0x33000000);
  static const Color shadowLight = Color(0x1A000000);

  /// Dark theme (primary theme for street performance app)
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: primaryOrange,
      onPrimary: backgroundDark,
      primaryContainer: primaryOrange.withAlpha(51),
      onPrimaryContainer: textPrimary,
      secondary: accentRed,
      onSecondary: textPrimary,
      secondaryContainer: accentRed.withAlpha(51),
      onSecondaryContainer: textPrimary,
      tertiary: successGreen,
      onTertiary: backgroundDark,
      tertiaryContainer: successGreen.withAlpha(51),
      onTertiaryContainer: textPrimary,
      error: accentRed,
      onError: textPrimary,
      surface: surfaceDark,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: borderSubtle,
      outlineVariant: borderSubtle.withAlpha(128),
      shadow: shadowDark,
      scrim: videoOverlay,
      inverseSurface: surfaceLight,
      onInverseSurface: textOnLight,
      inversePrimary: primaryOrange,
    ),
    scaffoldBackgroundColor: backgroundDark,
    cardColor: surfaceDark,
    dividerColor: borderSubtle,
    iconTheme: const IconThemeData(
      color: textPrimary,
      size: 28,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundDark,
      foregroundColor: textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.montserrat(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
    ),
    cardTheme: const CardThemeData(
      color: surfaceDark,
      elevation: 2.0,
      shadowColor: shadowDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12.0)),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surfaceDark,
      selectedItemColor: primaryOrange,
      unselectedItemColor: textSecondary,
      elevation: 4.0,
      type: BottomNavigationBarType.fixed,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryOrange,
      foregroundColor: backgroundDark,
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: backgroundDark,
        backgroundColor: primaryOrange,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        elevation: 2.0,
        shadowColor: shadowDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryOrange,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        side: const BorderSide(color: primaryOrange, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryOrange,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    textTheme: _buildTextTheme(isLight: false),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: inputBackground,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: primaryOrange, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: accentRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: accentRed, width: 2.0),
      ),
      labelStyle: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      hintStyle: GoogleFonts.inter(
        color: textPrimary.withOpacity(0.7),
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      errorStyle: GoogleFonts.inter(
        color: accentRed,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      floatingLabelStyle: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      prefixStyle: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      suffixStyle: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      counterStyle: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      helperStyle: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: primaryOrange,
      selectionColor: primaryOrange.withAlpha(77),
      selectionHandleColor: primaryOrange,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryOrange;
        }
        return textSecondary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryOrange.withAlpha(77);
        }
        return borderSubtle;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryOrange;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(backgroundDark),
      side: const BorderSide(color: borderSubtle, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4.0),
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryOrange;
        }
        return borderSubtle;
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryOrange,
      linearTrackColor: borderSubtle,
      circularTrackColor: borderSubtle,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primaryOrange,
      thumbColor: primaryOrange,
      overlayColor: primaryOrange.withAlpha(51),
      inactiveTrackColor: borderSubtle,
      trackHeight: 4.0,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: primaryOrange,
      unselectedLabelColor: textSecondary,
      indicatorColor: primaryOrange,
      indicatorSize: TabBarIndicatorSize.label,
      labelStyle: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: surfaceDark,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: shadowDark,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceDark,
      contentTextStyle: GoogleFonts.inter(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      actionTextColor: primaryOrange,
      behavior: SnackBarBehavior.floating,
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surfaceDark,
      modalBackgroundColor: surfaceDark,
      elevation: 8.0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20.0),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceDark,
      elevation: 8.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      titleTextStyle: GoogleFonts.montserrat(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      contentTextStyle: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ),
    ),
  );

  /// Light theme (minimal implementation for system compatibility)
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: primaryOrange,
      onPrimary: textPrimary,
      primaryContainer: primaryOrange.withAlpha(26),
      onPrimaryContainer: primaryOrange,
      secondary: accentRed,
      onSecondary: textPrimary,
      secondaryContainer: accentRed.withAlpha(26),
      onSecondaryContainer: accentRed,
      tertiary: successGreen,
      onTertiary: textPrimary,
      tertiaryContainer: successGreen.withAlpha(26),
      onTertiaryContainer: successGreen,
      error: accentRed,
      onError: textPrimary,
      surface: surfaceLight,
      onSurface: textOnLight,
      onSurfaceVariant: textOnLight.withAlpha(179),
      outline: borderSubtle,
      outlineVariant: borderSubtle.withAlpha(128),
      shadow: shadowLight,
      scrim: videoOverlay,
      inverseSurface: surfaceDark,
      onInverseSurface: textPrimary,
      inversePrimary: primaryOrange,
    ),
    scaffoldBackgroundColor: backgroundLight,
    cardColor: surfaceLight,
    dividerColor: borderSubtle.withAlpha(77),
    textTheme: _buildTextTheme(isLight: true),
    dialogTheme: const DialogThemeData(backgroundColor: surfaceLight),
  );

  /// Helper method to build text theme based on brightness
  static TextTheme _buildTextTheme({required bool isLight}) {
    final Color textHigh = isLight ? textOnLight : textPrimary;
    final Color textMedium =
        isLight ? textOnLight.withAlpha(179) : textSecondary;
    final Color textDisabled =
        isLight ? textOnLight.withAlpha(102) : textSecondary.withAlpha(153);

    return TextTheme(
      // Display styles - Montserrat for bold, urban-inspired headings
      displayLarge: GoogleFonts.montserrat(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        color: textHigh,
        letterSpacing: -0.25,
      ),
      displayMedium: GoogleFonts.montserrat(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        color: textHigh,
      ),
      displaySmall: GoogleFonts.montserrat(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        color: textHigh,
      ),

      // Headline styles - Montserrat for street culture confidence
      headlineLarge: GoogleFonts.montserrat(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: textHigh,
      ),
      headlineMedium: GoogleFonts.montserrat(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: textHigh,
      ),
      headlineSmall: GoogleFonts.montserrat(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textHigh,
      ),

      // Title styles - Inter for optimal mobile reading
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: textHigh,
        letterSpacing: 0,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textHigh,
        letterSpacing: 0.15,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textHigh,
        letterSpacing: 0.1,
      ),

      // Body styles - Inter for excellent character spacing and clarity
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textHigh,
        letterSpacing: 0.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textHigh,
        letterSpacing: 0.25,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textMedium,
        letterSpacing: 0.4,
      ),

      // Label styles - Inter for consistency with hierarchy
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textHigh,
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textMedium,
        letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w300,
        color: textDisabled,
        letterSpacing: 0.5,
      ),
    );
  }

  /// Custom text styles for specific use cases
  static TextStyle donationAmountStyle({required bool isLight}) {
    final Color textColor = isLight ? textOnLight : textPrimary;
    return GoogleFonts.jetBrainsMono(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      color: textColor,
      letterSpacing: 0.5,
    );
  }

  static TextStyle performerStatsStyle({required bool isLight}) {
    final Color textColor = isLight ? textOnLight : textPrimary;
    return GoogleFonts.jetBrainsMono(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: textColor,
      letterSpacing: 0.25,
    );
  }

  static TextStyle videoOverlayStyle() {
    return GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textPrimary,
      shadows: [
        const Shadow(
          color: videoOverlay,
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ],
    );
  }

  /// Box decoration for glassmorphism effects
  static BoxDecoration glassmorphismDecoration({
    Color? backgroundColor,
    double borderRadius = 12.0,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? surfaceDark.withAlpha(204),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderSubtle.withAlpha(77),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: shadowDark,
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Box decoration for performer profile cards with tactile feel
  static BoxDecoration performerCardDecoration() {
    return BoxDecoration(
      color: surfaceDark,
      borderRadius: BorderRadius.circular(12.0),
      boxShadow: [
        BoxShadow(
          color: shadowDark,
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}
