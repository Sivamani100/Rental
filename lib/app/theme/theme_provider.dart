import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  static final ThemeController instance = ThemeController._internal();

  ThemeController._internal();

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => ThemeMode.light;

  bool get isDarkMode => false;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_theme_mode', 'light');
    } catch (_) {}
    _themeMode = ThemeMode.light;
    notifyListeners();
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
}
