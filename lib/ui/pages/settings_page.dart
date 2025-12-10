import 'package:flutter/material.dart';
import '../../providers/auxiliary/theme_manager.dart';
import '../../l10n/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  final AppSettings? settings;
  const SettingsPage({super.key, this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.settings_brightness),
          title: Text(l10n.system),
          subtitle: const Text('跟随系统主题'),
          value: (settings?.themeMode ?? ThemeMode.system) == ThemeMode.system,
          onChanged: (value) {
            settings?.setThemeMode(value ? ThemeMode.system : ThemeMode.light);
          },
        ),
        const Divider(),
        ListTile(
          leading: Icon(Icons.security),
          title: Text('安全设置（占位）'),
          subtitle: Text('后续添加主密钥管理、校时策略等设置选项'),
        ),
        const Divider(),
        ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('关于'),
          subtitle: Text('时光胶囊 App · MVP'),
        ),
      ],
    );
  }
}
