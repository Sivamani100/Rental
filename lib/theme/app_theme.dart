import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ─── Swiggy Brand Colors ────────────────────────────────────────────────────
  static const Color swiggyOrange     = Color(0xFFFC8019); // Primary brand orange
  static const Color swiggyOrangeDark = Color(0xFFE8720D); // Darker shade for gradients
  static const Color swiggyYellow     = Color(0xFFF3C334); // Accent yellow
  static const Color swiggyGreen      = Color(0xFF1BA672); // Success / Pure Veg
  static const Color swiggyRed        = Color(0xFFE23744); // Error / Not Available

  // ─── Header / Dark Navy ─────────────────────────────────────────────────────
  static const Color swiggyNavyHeader = Color(0xFF041029); // Deep blue nav header background
  static const Color swiggyNavyCard   = Color(0xFF282C3F); // Card bg in dark mode (Swiggy body text)

  // ─── Light Palette ───────────────────────────────────────────────────────────
  static const Color lightScaffold      = Color(0xFFF2F2F7); // Light grey background
  static const Color lightCard          = Color(0xFFFFFFFF);
  static const Color lightBorder        = Color(0xFFE8E8EC);
  static const Color lightTextPrimary   = Color(0xFF282C3F); // Swiggy body text
  static const Color lightTextSecondary = Color(0xFF7E808C); // Swiggy secondary text
  static const Color lightOrangeSurface = Color(0xFFFFF3EA);
  static const Color lightSearchBg      = Color(0xFFF5F5F5); // Search bar fill

  // ─── Dark Palette ────────────────────────────────────────────────────────────
  static const Color darkScaffold      = Color(0xFF1A1A2E);
  static const Color darkCard          = Color(0xFF16213E);
  static const Color darkCardElevated  = Color(0xFF0F3460);
  static const Color darkBorder        = Color(0xFF2D2D42);
  static const Color darkTextPrimary   = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFA3A3B8);

  // ─── Legacy aliases ──────────────────────────────────────────────────────────
  static const Color primaryYellow = swiggyOrange;
  static const Color primaryOrange = swiggyOrange;

  // ─── Swiggy Orange Gradient ──────────────────────────────────────────────────
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [swiggyOrange, swiggyOrangeDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Swiggy Bottom Nav Bar Decoration ───────────────────────────────────────
  static BoxDecoration get swiggyBottomNavDecoration => BoxDecoration(
    color: Colors.white,
    border: Border(
      top: BorderSide(color: const Color(0xFFE8E8EC), width: 1),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 16,
        offset: const Offset(0, -4),
      ),
    ],
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'ProximaNova',
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightScaffold,
      colorScheme: const ColorScheme.light(
        primary: swiggyOrange,
        onPrimary: Colors.white,
        secondary: swiggyYellow,
        onSecondary: Color(0xFF282C3F),
        surface: lightCard,
        onSurface: lightTextPrimary,
        error: swiggyRed,
        onError: Colors.white,
      ),
      cardColor: lightCard,
      dividerColor: lightBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: lightTextPrimary,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(false),
        trackVisibility: WidgetStateProperty.all(false),
        thickness: WidgetStateProperty.all(5.0),
        radius: const Radius.circular(8.0),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged) || states.contains(WidgetState.hovered)) {
            return const Color(0xFF94A3B8);
          }
          return const Color(0xFFCBD5E1).withValues(alpha: 0.7);
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE8E8EC)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: swiggyOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: swiggyOrange,
          side: const BorderSide(color: swiggyOrange, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightCard,
        modalBackgroundColor: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSearchBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: swiggyOrange, width: 1.5),
        ),
        hintStyle: const TextStyle(color: lightTextSecondary),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: swiggyOrange,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'ProximaNova',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkScaffold,
      colorScheme: const ColorScheme.dark(
        primary: swiggyOrange,
        onPrimary: Colors.white,
        secondary: swiggyYellow,
        onSecondary: Color(0xFF282C3F),
        surface: darkCard,
        onSurface: darkTextPrimary,
        error: swiggyRed,
        onError: Colors.white,
      ),
      cardColor: darkCard,
      dividerColor: darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: darkTextPrimary,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.all(false),
        trackVisibility: WidgetStateProperty.all(false),
        thickness: WidgetStateProperty.all(5.0),
        radius: const Radius.circular(8.0),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged) || states.contains(WidgetState.hovered)) {
            return Colors.white38;
          }
          return Colors.white24;
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF1E2330),
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: swiggyOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: swiggyOrange,
          side: const BorderSide(color: swiggyOrange, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        modalBackgroundColor: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCardElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: swiggyOrange, width: 1.5),
        ),
        hintStyle: const TextStyle(color: darkTextSecondary),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: swiggyOrange,
      ),
    );
  }
}
