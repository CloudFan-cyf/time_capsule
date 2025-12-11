// lib/ui/pages/settings_page.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:time_capsule/core/storage/file_store.dart';
import 'package:time_capsule/generated/l10n.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FileStore _fileStore = FileStoreImpl();

  bool _loadingPath = true;
  bool _usingDefault = true;
  String? _effectivePath; // 实际使用的路径（默认或自定义）

  @override
  void initState() {
    super.initState();
    _loadCurrentPath();
  }

  Future<void> _loadCurrentPath() async {
    setState(() {
      _loadingPath = true;
    });

    final override = await _fileStore.getCapsulesRootOverridePath();
    String effective;
    if (override != null && override.isNotEmpty) {
      effective = override;
    } else {
      final dir = await _fileStore.capsulesDir();
      effective = dir.path;
    }

    if (!mounted) return;
    setState(() {
      _effectivePath = effective;
      _usingDefault = override == null || override.isEmpty;
      _loadingPath = false;
    });
  }

  Future<void> _pickCapsulesDir() async {
    final selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    await _fileStore.setCapsulesRootOverridePath(selectedDirectory);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(S.of(context).storageDirSet)));
    await _loadCurrentPath();
  }

  Future<void> _resetCapsulesDir() async {
    await _fileStore.setCapsulesRootOverridePath(null);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(S.of(context).storageDirReset)));
    await _loadCurrentPath();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final storageSubtitle = _loadingPath
        ? l10n.settingsStorageLoading
        : _usingDefault
        ? l10n.settingsStorageUsingDefault(_effectivePath ?? '')
        : l10n.settingsStorageUsingCustom(_effectivePath ?? '');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.security),
          title: Text(l10n.settingsSecurityTitle),
          subtitle: Text(l10n.settingsSecuritySubtitle),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.folder),
          title: Text(l10n.settingsStorageTitle),
          subtitle: Text(storageSubtitle),
          isThreeLine: true,
          onTap: _pickCapsulesDir,
          trailing: _usingDefault
              ? IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: l10n.settingsPickDir,
                  onPressed: _pickCapsulesDir,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: l10n.settingsPickDir,
                      onPressed: _pickCapsulesDir,
                    ),
                    IconButton(
                      icon: const Icon(Icons.restore),
                      tooltip: l10n.settingsRestoreDefault,
                      onPressed: _resetCapsulesDir,
                    ),
                  ],
                ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.aboutTitle),
          subtitle: Text(l10n.aboutSubtitle),
        ),
      ],
    );
  }
}
