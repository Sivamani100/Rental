import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Brand Yellow
  static const Color primaryYellow = Color(0xFFFFEB3A);
  
  // Light Palette
  static const Color lightScaffold = Color(0xFFFBF7F7);
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE8E8EC);
  static const Color lightTextPrimary = Color(0xFF141416);
  static const Color lightTextSecondary = Color(0xFF70707B);

  // Dark Palette (Pure OLED Dark)
  static const Color darkScaffold = Color(0xFF000000);
  static const Color darkCard = Color(0xFF101012);
  static const Color darkCardElevated = Color(0xFF18181C);
  static const Color darkBorder = Color(0xFF222228);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFA0A0AB);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightScaffold,
      colorScheme: const ColorScheme.light(
        primary: primaryYellow,
        onPrimary: Colors.black,
        secondary: Colors.black,
        onSecondary: Colors.white,
        surface: lightCard,
        onSurface: lightTextPrimary,
      ),
      cardColor: lightCard,
      dividerColor: lightBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryYellow,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkScaffold,
      colorScheme: const ColorScheme.dark(
        primary: primaryYellow,
        onPrimary: Colors.black,
        secondary: primaryYellow,
        onSecondary: Colors.black,
        surface: darkCard,
        onSurface: darkTextPrimary,
      ),
      cardColor: darkCard,
      dividerColor: darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryYellow,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white38, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }
}
