import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(
          leading: Icon(Icons.security),
          title: Text('安全设置（占位）'),
          subtitle: Text('后续添加主密钥管理、校时策略等设置选项'),
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('关于'),
          subtitle: Text('时光胶囊 App · MVP'),
        ),
      ],
    );
  }
}
