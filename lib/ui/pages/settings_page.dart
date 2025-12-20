// lib/ui/pages/settings_page.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p show join;
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  String _timeSource = '...';
  DateTime? _lastTrustedUtc; // 最近一次拿到的可信 UTC 时间
  DateTime? _trustedAtLocalUtc; // 拿到可信时间那一刻，本地 UTC（用于 UI 平滑递增）
  DateTime? _lastSyncLocalUtc; // 上次同步发生的本地 UTC（用于 “xx秒前”）
  String? _timeErr;

  bool _syncing = false;
  DateTime? _cooldownUntilLocalUtc; // 刷新按钮冷却截止时刻（本地 UTC）
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
    if (_syncing) return;

    // 冷却：在 cacheTtl 内不允许频繁点击
    final nowLocalUtc = DateTime.now().toUtc();
    final cd = _cooldownUntilLocalUtc;
    if (cd != null && nowLocalUtc.isBefore(cd)) {
      if (!mounted) return;
      final remain = cd.difference(nowLocalUtc).inSeconds.clamp(0, 1 << 30);
      showSnack(context, l10n.timeRefreshCooldown(remain)); // 需要在 l10n 加一句
      return;
    }

    _syncing = true;
    try {
      final res = await _timeService.getTrustedNowUtc();

      if (!mounted) return;
      final nowLocalUtc2 = DateTime.now().toUtc();

      setState(() {
        _timeSource = res.source;
        _lastTrustedUtc = res.nowUtc;
        _trustedAtLocalUtc = nowLocalUtc2;
        _lastSyncLocalUtc = nowLocalUtc2;
        _timeErr = null;

        // 冷却到 now + cacheTtl
        _cooldownUntilLocalUtc = nowLocalUtc2.add(_timeService.cacheTtl);

        if (kDebugMode) {
          debugPrint(
            'Time attestation OK: source=${res.source}, '
            'trustedUtc=${res.nowUtc.toIso8601String()}, '
            'localUtc=${nowLocalUtc2.toIso8601String()}',
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _timeSource = 'OFFLINE';
        _timeErr = e.toString();
        _lastSyncLocalUtc = DateTime.now().toUtc();
        // 失败也给一点冷却，避免疯狂点（同样用 cacheTtl）
        _cooldownUntilLocalUtc = DateTime.now().toUtc().add(
          _timeService.cacheTtl,
        );
      });
    } finally {
      _syncing = false;
    }
  }

  DateTime _currentDisplayUtc() {
    // 用于 UI 展示：若拿到可信时间，则按本地经过时间递增
    final trusted = _lastTrustedUtc;
    final atLocal = _trustedAtLocalUtc;
    if (trusted == null || atLocal == null) {
      return DateTime.now().toUtc();
    }
    final delta = DateTime.now().toUtc().difference(atLocal);
    // delta 可能为负（系统时间被往回拨），做个保护
    final safeDelta = delta.isNegative ? Duration.zero : delta;
    return trusted.add(safeDelta);
  }

  String _timeSubtitle() {
    final nowLocal = _currentDisplayUtc().toLocal();
    final t = DateFormat('yyyy-MM-dd HH:mm:ss').format(nowLocal);

    final lastLocalUtc = _lastSyncLocalUtc;
    final secondsAgo = lastLocalUtc == null
        ? null
        : DateTime.now().toUtc().difference(lastLocalUtc).inSeconds;
    final agoText = secondsAgo == null
        ? l10n.notSynced
        : l10n.syncedSecondsAgo(secondsAgo);

    if (_timeErr == null || _timeErr!.isEmpty) {
      return l10n.timeStatusSubtitleWithAgo(_timeSource, t, agoText);
    }

    String displayErr = _timeErr!;
    if (kDebugMode) debugPrint('Time attestation error: $_timeErr');
    const int maxErrLen = 20;
    if (displayErr.length > maxErrLen) {
      displayErr = '${displayErr.substring(0, maxErrLen)}…';
    }
    return l10n.timeStatusSubtitleWithAgoAndError(
      _timeSource,
      t,
      agoText,
      displayErr,
    );
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
          ], text: l10n.shareExportText);
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
      showSnack(context, l10n.importSuccess);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, l10n.importFailed(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final nowUtc = DateTime.now().toUtc();
    final cooldownUntil = _cooldownUntilLocalUtc;
    final inCooldown = cooldownUntil != null && nowUtc.isBefore(cooldownUntil);
    final remainSec = inCooldown
        ? cooldownUntil.difference(nowUtc).inSeconds
        : 0;

    final storageSubtitle = _loadingPath
        ? l10n.settingsStorageLoading
        : _usingDefault
        ? l10n.settingsStorageUsingDefault(_effectivePath ?? '')
        : l10n.settingsStorageUsingCustom(_effectivePath ?? '');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.access_time),
          title: Text(l10n.timeStatusTitle),
          subtitle: Text(_timeSubtitle()),
          isThreeLine: true,
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: inCooldown
                ? l10n.timeRefreshCooldown(remainSec)
                : l10n.Refresh,
            onPressed: (inCooldown || _syncing) ? null : _syncTime,
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.key),
          title: Text(l10n.exportMasterKey),
          subtitle: Text(l10n.exportMasterKeyDesc),
          onTap: _exportMasterKey,
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: Text(l10n.importMasterKey),
          subtitle: Text(l10n.importMasterKeyDesc),
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
        // --- About (static) ---
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(Icons.info_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.appName, // 名称
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.aboutIntro,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snap) {
                        if (!snap.hasData) return Text('${l10n.version} v...');
                        final info = snap.data!;
                        final v = info.version.trim();
                        final b = info.buildNumber.trim();

                        final text = b.isEmpty ? 'v$v' : 'v$v ($b)';
                        return Text(
                          '${l10n.version} $text',
                          style: Theme.of(context).textTheme.bodyMedium,
                        );
                      },
                    ),

                    const SizedBox(height: 6),
                    Text(
                      l10n.aboutPrivacyHint, // 一句隐私说明
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
