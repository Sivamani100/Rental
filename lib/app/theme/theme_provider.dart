import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rental/app/theme/app_theme.dart';

class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  static final ThemeController instance = ThemeController._internal();

  ThemeController._internal();

  ThemeMode _themeMode = ThemeMode.system;
  Color _appColor = const Color(0xFFFFD600); // Default Yellow

  ThemeMode get themeMode => ThemeMode.light;

  bool get isDarkMode => false;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme_mode', 'light');
      final colorInt = prefs.getInt('app_theme_color');
      if (colorInt != null) {
        _appColor = Color(colorInt);
        _updateAppThemeColors();
      }
    } catch (_) {}
    _themeMode = ThemeMode.light;
    notifyListeners();
  }

  void _updateAppThemeColors() {
    AppTheme.primaryAccent = _appColor;
    AppTheme.swiggyOrange = _appColor;
    AppTheme.swiggyOrangeDark = _appColor;
    AppTheme.swiggyYellow = _appColor;
    AppTheme.primaryYellow = _appColor;
    AppTheme.primaryOrange = _appColor;
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode == ThemeMode.system) {
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    if (isDarkMode) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme_mode', 'light');
    } catch (_) {}
  }

  Future<void> setAppColor(Color color) async {
    _appColor = color;
    _updateAppThemeColors();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('app_theme_color', color.value);
    } catch (_) {}
  }

  Color get appColor => _appColor;
}
