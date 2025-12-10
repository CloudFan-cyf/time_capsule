import 'package:flutter/widgets.dart';
import 'theme_manager.dart';

class ThemeScope extends InheritedNotifier<ThemeManager> {
  const ThemeScope({
    super.key,
    required ThemeManager notifier,
    required Widget child,
  }) : super(notifier: notifier, child: child);

  static ThemeManager of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(
      scope != null,
      'ThemeScope not found. Wrap your app with ThemeScope.',
    );
    return scope!.notifier!;
  }
}
