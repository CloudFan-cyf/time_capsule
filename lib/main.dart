import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:time_capsule/ui/app_shell.dart';
import 'package:time_capsule/ui/pages/create_capsule_page.dart';
import 'package:time_capsule/providers/auxiliary/theme_manager.dart';
import 'package:time_capsule/l10n/app_localizations.dart';

void main() {
  runApp(const TimeCapsuleApp());
}

class TimeCapsuleApp extends StatefulWidget {
  const TimeCapsuleApp({super.key});

  @override
  State<TimeCapsuleApp> createState() => _TimeCapsuleAppState();
}

class _TimeCapsuleAppState extends State<TimeCapsuleApp> {
  final settings = AppSettings();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: settings.themeMode,
        locale: settings.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: AppShell(settings: settings),
        routes: {'/create': (_) => const CreateCapsulePage()},
      ),
    );
  }
}
