// lib/ui/pages/settings_page.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p show join;

import 'package:time_capsule/core/storage/file_store.dart';
import 'package:time_capsule/core/storage/secure_key_store.dart';
import 'package:time_capsule/core/crypto/master_key_service.dart';
import 'package:time_capsule/generated/l10n.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final FileStore _fileStore;
  late final MasterKeyService _masterKeyService;

  bool _loadingPath = true;
  bool _usingDefault = true;
  String? _effectivePath; // 实际使用的路径（默认或自定义）

  @override
  void initState() {
    super.initState();
    _fileStore = FileStoreImpl();
    _masterKeyService = MasterKeyService(
      secureKeyStore: SecureKeyStoreImpl(),
      fileStore: _fileStore,
    );
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

  Future<void> _exportMasterKey() async {
    try {
      final dirPath = await FilePicker.platform.getDirectoryPath();
      if (dirPath == null) return;

      final file = File(p.join(dirPath, 'time_capsule_master_key.json'));
      await _masterKeyService.exportUmkToFile(file);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('主密钥已导出到：${file.path}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出主密钥失败：$e')));
    }
  }

  Future<void> _importMasterKey() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: false,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null) {
        throw Exception('选中的文件没有路径');
      }

      final file = File(path);
      await _masterKeyService.importUmkFromFile(file);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('导入主密钥成功')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导入主密钥失败：$e')));
    }
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
        ListTile(
          leading: const Icon(Icons.key),
          title: const Text('导出主密钥'),
          subtitle: const Text('生成可在其他设备导入的主密钥文件'),
          onTap: _exportMasterKey,
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('导入主密钥'),
          subtitle: const Text('从导出的主密钥文件恢复访问权限'),
          onTap: _importMasterKey,
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
