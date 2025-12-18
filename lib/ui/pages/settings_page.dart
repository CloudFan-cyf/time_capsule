// lib/ui/pages/settings_page.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p show join;
import 'package:share_plus/share_plus.dart';

import 'package:time_capsule/core/storage/file_store.dart';
import 'package:time_capsule/core/storage/secure_key_store.dart';
import 'package:time_capsule/core/crypto/master_key_service.dart';
import 'package:time_capsule/utlis/showsnackbar.dart';
import 'package:time_capsule/generated/l10n.dart';
import 'dart:async';
import 'package:time_capsule/core/time/time_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final FileStore _fileStore;
  late final MasterKeyService _masterKeyService;
  final TimeService _timeService = TimeServiceImpl();

  Timer? _tick;
  Duration? _offset;
  String _timeSource = '...';
  DateTime? _lastSyncUtc;
  String? _timeErr;
  late final S l10n = S.of(context);

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
    _syncTime();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (kDebugMode) {
      _debugPrintKeyStoragePaths();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _syncTime() async {
    try {
      final res = await _timeService.getTrustedNowUtc();
      final localUtc = DateTime.now().toUtc();
      if (!mounted) return;
      setState(() {
        _offset = res.nowUtc.difference(localUtc);
        _timeSource = res.source;
        _lastSyncUtc = DateTime.now().toUtc();
        _timeErr = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _offset = null;
        _timeSource = 'OFFLINE';
        _lastSyncUtc = DateTime.now().toUtc();
        _timeErr = e.toString();
      });
    }
  }

  DateTime _currentTrustedUtc() {
    final nowUtc = DateTime.now().toUtc();
    return _offset == null ? nowUtc : nowUtc.add(_offset!);
  }

  String _timeSubtitle() {
    final nowLocal = _currentTrustedUtc().toLocal();
    final t = DateFormat('yyyy-MM-dd HH:mm:ss').format(nowLocal);
    final last = _lastSyncUtc == null
        ? '未同步'
        : DateFormat('HH:mm:ss').format(_lastSyncUtc!.toLocal());
    final err = _timeErr == null ? '' : '\n错误：$_timeErr';
    return '来源：$_timeSource\n当前时间：$t\n上次同步：$last$err';
  }

  Future<void> _debugPrintKeyStoragePaths() async {
    try {
      final support = await _fileStore.appSupportDir();
      final keysDir = await _fileStore.keysDir();
      final blobFile = await _fileStore.masterKeyBlobFile();

      // 这些打印在 Android/Windows 都能看到
      debugPrint('=== [TimeCapsule] Key storage debug ===');
      debugPrint('Platform: ${Platform.operatingSystem}');
      debugPrint('appSupportDir: ${support.path}');
      debugPrint('keysDir: ${keysDir.path}');
      debugPrint('masterKeyBlobFile: ${blobFile.path}');
      debugPrint('======================================');
    } catch (e, st) {
      debugPrint('Key storage debug print failed: $e');
      debugPrint('$st');
    }
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
    showSnack(context, l10n.storageDirSet);
    await _loadCurrentPath();
  }

  Future<void> _resetCapsulesDir() async {
    await _fileStore.setCapsulesRootOverridePath(null);
    if (!mounted) return;
    showSnack(context, l10n.storageDirReset);
    await _loadCurrentPath();
  }

  Future<void> _exportMasterKey() async {
    final l10n = S.of(context);

    try {
      final jsonText = await _masterKeyService.exportUmkJson();

      if (Platform.isAndroid) {
        // ✅ Android：写到临时目录 -> share -> finally 删除
        final tmpDir = await _fileStore.tempDir();
        final tmpPath = p.join(tmpDir.path, 'time_capsule_umk_key.json');
        final tmpFile = File(tmpPath);

        await tmpFile.writeAsString(jsonText, flush: true);

        try {
          await Share.shareXFiles([
            XFile(tmpFile.path),
          ], text: 'TimeCapsule Master Key Export');
        } finally {
          // 尽力删除（不影响主流程）
          try {
            if (await tmpFile.exists()) {
              await tmpFile.delete();
            }
          } catch (_) {
            if (kDebugMode) {
              debugPrint(
                'Failed to delete temporary master key file: $tmpPath',
              );
            }
          }
        }

        if (!mounted) return;
        showSnack(context, l10n.exportSuccess);
        return;
      }

      // ✅ 其他平台：允许用户指定输出路径
      final outPath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.exportMasterKeyTitle,
        fileName: 'time_capsule_umk_key.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (outPath == null) return;

      await File(outPath).writeAsString(jsonText, flush: true);

      if (!mounted) return;
      showSnack(context, l10n.exportSuccess);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, l10n.exportFailed(e.toString()));
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
      showSnack(context, '导入主密钥成功');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, '导入主密钥失败：$e');
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
          leading: const Icon(Icons.access_time),
          title: const Text('联网校时状态'),
          subtitle: Text(_timeSubtitle()),
          isThreeLine: true,
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新校时',
            onPressed: _syncTime,
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.key),
          title: const Text('导出主密钥'),
          subtitle: const Text('导出可在其他设备导入的主密钥文件'),
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
