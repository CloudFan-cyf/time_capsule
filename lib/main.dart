import 'package:flutter/material.dart';
import 'package:time_capsule/generated/l10n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:time_capsule/providers/auxiliary/theme_manager.dart';
import 'package:time_capsule/providers/auxiliary/theme_scope.dart';

import 'package:time_capsule/ui/app_shell.dart';
import 'package:time_capsule/ui/pages/create_capsule_page.dart';

final ThemeManager _themeManager = ThemeManager();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ThemeScope(notifier: _themeManager, child: const TimeCapsuleApp()));
}

class TimeCapsuleApp extends StatelessWidget {
  const TimeCapsuleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tm = ThemeScope.of(context);

    return MaterialApp(
      onGenerateTitle: (ctx) => S.of(ctx).appTitle,
      theme: tm.lightTheme,
      darkTheme: tm.darkTheme,
      themeMode: tm.themeMode,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale?.languageCode == 'zh') {
          return const Locale('zh', 'CN');
        } else {
          for (final supportedLocale in supportedLocales) {
            if (supportedLocale.languageCode == locale?.languageCode) {
              return supportedLocale;
            }
          }
          return supportedLocales.first;
        }
      },
      home: const AppShell(),
      routes: {'/create': (_) => const CreateCapsulePage()},
    );
  }
}
