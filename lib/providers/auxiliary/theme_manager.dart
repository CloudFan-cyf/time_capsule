import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      textTheme: _textTheme,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      textTheme: _textTheme,
    );
  }

  static const _textTheme = TextTheme(
    displayLarge: TextStyle(fontWeight: FontWeight.w700),
    displayMedium: TextStyle(fontWeight: FontWeight.w700),
    headlineMedium: TextStyle(fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16.0),
    bodyMedium: TextStyle(fontSize: 14.0),
  );
}

class AppSettings extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  Locale locale = const Locale('zh');

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  void setLocale(Locale newLocale) {
    locale = newLocale;
    notifyListeners();
  }
}
