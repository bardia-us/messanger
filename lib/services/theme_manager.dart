import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // پیشفرض: سیستم
  static const String KEY = "theme_mode";

  ThemeMode get themeMode => _themeMode;

  ThemeManager() {
    _loadTheme();
  }

  void toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(KEY, _themeMode.toString());
  }

  void _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(KEY);
    if (saved != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.toString() == saved,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }
}
