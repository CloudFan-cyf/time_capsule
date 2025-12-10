import 'package:flutter/material.dart';

class ThemeManager extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = Colors.indigo;

  /// 设为 null 表示使用系统默认字体
  String? _fontFamily;

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  String? get fontFamily => _fontFamily;

  set themeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void setSeedColor(Color color) {
    if (_seedColor == color) return;
    _seedColor = color;
    notifyListeners();
  }

  void setFontFamily(String? family) {
    if (_fontFamily == family) return;
    _fontFamily = family;
    notifyListeners();
  }

  ThemeData get lightTheme => _build(Brightness.light);
  ThemeData get darkTheme => _build(Brightness.dark);

  ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );

    final textTheme = (_fontFamily == null)
        ? base.textTheme
        : base.textTheme.apply(fontFamily: _fontFamily);

    return base.copyWith(textTheme: textTheme);
  }
}
