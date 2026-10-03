import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Primary & Accents
  static Color primaryAccent = const Color(0xFFFFD600); // Deep Yellow from Splash Screen
  static const Color primaryDark = Color(0xFF000000);   // OLED Black
  static const Color successGreen = Color(0xFF34C759);
  static const Color errorRed = Color(0xFFFF3B30);

  // Light Mode Surfaces
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF2F2F7);
  static const Color lightBorder = Color(0xFFE5E5EA);

  // Dark Mode Surfaces
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkBorder = Color(0xFF38383A);

  // Typography Colors
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textSecondaryLight = Color(0xFF8E8E93);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFF8E8E93);

  // Legacy mappings to prevent app breaking (mapping to iOS colors)
  static Color swiggyOrange = primaryAccent;
  static Color swiggyOrangeDark = primaryAccent;
  static Color swiggyYellow = primaryAccent;
  static const Color swiggyGreen = successGreen;
  static const Color swiggyRed = errorRed;
  static const Color swiggyNavyHeader = lightBackground;
  static const Color swiggyNavyCard = lightSurface;
  static const Color lightScaffold = lightBackground;
  static const Color lightCard = lightSurface;
  static const Color lightTextPrimary = textPrimaryLight;
  static const Color lightTextSecondary = textSecondaryLight;
  static const Color lightOrangeSurface = lightSurface;
  static const Color lightSearchBg = lightSurface;
  static const Color darkScaffold = darkBackground;
  static const Color darkCard = darkSurface;
  static const Color darkCardElevated = darkSurface;
  static const Color darkTextPrimary = textPrimaryDark;
  static const Color darkTextSecondary = textSecondaryDark;
  static Color primaryYellow = primaryAccent;
  static Color primaryOrange = primaryAccent;

  static LinearGradient get orangeGradient => LinearGradient(
    colors: [primaryAccent, primaryAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration get swiggyBottomNavDecoration => BoxDecoration(
    color: Colors.white,
    border: Border(
      top: BorderSide(color: lightBorder, width: 1),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 16,
        offset: const Offset(0, -4),
      ),
    ],
  );

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryAccent,
      scaffoldBackgroundColor: lightBackground,
      dividerColor: lightBorder,
      fontFamily: 'SF Pro Display', // Substitute with 'Inter' or 'Roboto' if SF isn't available
      colorScheme: ColorScheme.light(
        primary: primaryAccent,
        secondary: successGreen,
        error: errorRed,
        surface: lightSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimaryLight,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryAccent,
          side: BorderSide(color: primaryAccent, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryAccent,
      scaffoldBackgroundColor: darkBackground,
      dividerColor: darkBorder,
      fontFamily: 'SF Pro Display',
      colorScheme: ColorScheme.dark(
        primary: primaryAccent,
        secondary: successGreen,
        error: errorRed,
        surface: darkSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimaryDark,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryAccent,
          side: BorderSide(color: primaryAccent, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
    );
  }
}
