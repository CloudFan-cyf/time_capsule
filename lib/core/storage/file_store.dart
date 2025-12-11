// lib/store/file_store.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class FileStore {
  /// App Support 目录（App 私有数据根）
  Future<Directory> appSupportDir();

  /// 临时目录（解密/预览用）
  Future<Directory> tempDir();

  /// 胶囊根目录：
  /// - 默认：appSupportDir/capsules
  /// - 若用户配置了自定义路径：直接用该路径
  Future<Directory> capsulesDir();

  /// 仅用于密钥等敏感数据，仍固定在 App 私有目录
  Future<Directory> keysDir();

  /// 设备密钥文件：{appSupportDir}/keys/device_key.bin
  Future<File> deviceKeyFile();

  /// 读取设备密钥（不存在则 null）
  Future<Uint8List?> readDeviceKey();

  /// 写设备密钥
  Future<void> writeDeviceKey(Uint8List keyBytes);

  /// 获取/生成设备密钥（默认 32 bytes）
  Future<Uint8List> getOrCreateDeviceKey({int length = 32});

  /// 确保某胶囊目录存在：{capsulesDir}/{capsuleId}
  Future<Directory> ensureCapsuleDir(String capsuleId);

  /// payload.enc
  Future<File> payloadFile(String capsuleId);

  /// manifest.json
  Future<File> manifestFile(String capsuleId);

  /// 将源文件拷贝到 payload.enc（占位：暂不加密）
  Future<File> copySourceToPayload({
    required String capsuleId,
    required File src,
  });

  /// 写 manifest.json
  Future<File> writeManifest({
    required String capsuleId,
    required Map<String, Object?> manifest,
  });

  /// 读 manifest.json
  Future<Map<String, Object?>> readManifest(File manifestFile);

  /// 列出所有 manifest.json（用于 listCapsules）
  Future<List<File>> listAllManifestFiles();

  /// 创建一个临时文件（不自动写入）
  Future<File> createTempFile({required String filename});

  /// 原子写文本
  Future<void> writeStringAtomic(File file, String content);

  /// 原子写字节
  Future<void> writeBytesAtomic(File file, List<int> bytes);

  /// 读取“胶囊根目录”的自定义路径（无则 null）
  Future<String?> getCapsulesRootOverridePath();

  /// 设置/取消“胶囊根目录”的自定义路径（传 null 或空字符串 = 恢复默认）
  Future<void> setCapsulesRootOverridePath(String? path);
}

class FileStoreImpl implements FileStore {
  static const String _capsulesFolder = 'capsules';
  static const String _keysFolder = 'keys';
  static const String _deviceKeyName = 'device_key.bin';

  static const String _configFolder = 'config';
  static const String _storageConfigName = 'storage.json';
  static const String _cfgKeyCapsulesRootOverride = 'capsulesRootOverride';

  Directory? _support;
  Directory? _temp;
  Directory? _keys;
  Directory? _configDir;

  Map<String, Object?>? _config;

  @override
  Future<Directory> appSupportDir() async {
    _support ??= await getApplicationSupportDirectory();
    if (!await _support!.exists()) {
      await _support!.create(recursive: true);
    }
    return _support!;
  }

  @override
  Future<Directory> tempDir() async {
    _temp ??= await getTemporaryDirectory();
    if (!await _temp!.exists()) {
      await _temp!.create(recursive: true);
    }
    return _temp!;
  }

  Future<Directory> _configDirEnsure() async {
    if (_configDir != null) return _configDir!;
    final base = await appSupportDir();
    _configDir = Directory(p.join(base.path, _configFolder));
    if (!await _configDir!.exists()) {
      await _configDir!.create(recursive: true);
    }
    return _configDir!;
  }

  Future<File> _storageConfigFile() async {
    final dir = await _configDirEnsure();
    return File(p.join(dir.path, _storageConfigName));
  }

  Future<Map<String, Object?>> _loadConfig() async {
    if (_config != null) return _config!;
    final f = await _storageConfigFile();
    if (!await f.exists()) {
      _config = <String, Object?>{};
      return _config!;
    }
    try {
      final text = await f.readAsString();
      final obj = jsonDecode(text);
      if (obj is Map) {
        _config = obj.map((k, v) => MapEntry(k.toString(), v));
      } else {
        _config = <String, Object?>{};
      }
    } catch (_) {
      _config = <String, Object?>{};
    }
    return _config!;
  }

  Future<void> _saveConfig() async {
    final cfg = _config ?? <String, Object?>{};
    final f = await _storageConfigFile();
    final text = const JsonEncoder.withIndent('  ').convert(cfg);
    await writeStringAtomic(f, text);
  }

  @override
  Future<String?> getCapsulesRootOverridePath() async {
    final cfg = await _loadConfig();
    final v = cfg[_cfgKeyCapsulesRootOverride];
    if (v is String && v.trim().isNotEmpty) {
      return v;
    }
    return null;
  }

  @override
  Future<void> setCapsulesRootOverridePath(String? path) async {
    final cfg = await _loadConfig();
    if (path == null || path.trim().isEmpty) {
      cfg.remove(_cfgKeyCapsulesRootOverride);
    } else {
      cfg[_cfgKeyCapsulesRootOverride] = path;
    }
    _config = cfg;
    await _saveConfig();
  }

  @override
  Future<Directory> capsulesDir() async {
    // 若用户配置了自定义路径，优先使用
    final override = await getCapsulesRootOverridePath();
    if (override != null && override.isNotEmpty) {
      final dir = Directory(override);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    // 默认：App Support 下的 capsules
    final base = await appSupportDir();
    final dir = Directory(p.join(base.path, _capsulesFolder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<Directory> keysDir() async {
    if (_keys != null) return _keys!;
    final base = await appSupportDir();
    _keys = Directory(p.join(base.path, _keysFolder));
    if (!await _keys!.exists()) {
      await _keys!.create(recursive: true);
    }
    return _keys!;
  }

  @override
  Future<File> deviceKeyFile() async {
    final dir = await keysDir();
    return File(p.join(dir.path, _deviceKeyName));
  }

  @override
  Future<Uint8List?> readDeviceKey() async {
    final f = await deviceKeyFile();
    if (!await f.exists()) return null;
    final bytes = await f.readAsBytes();
    return Uint8List.fromList(bytes);
  }

  @override
  Future<void> writeDeviceKey(Uint8List keyBytes) async {
    final f = await deviceKeyFile();
    await writeBytesAtomic(f, keyBytes);
  }

  @override
  Future<Uint8List> getOrCreateDeviceKey({int length = 32}) async {
    final existing = await readDeviceKey();
    if (existing != null && existing.isNotEmpty) return existing;

    final rnd = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(length, (_) => rnd.nextInt(256)),
    );
    await writeDeviceKey(bytes);
    return bytes;
  }

  @override
  Future<Directory> ensureCapsuleDir(String capsuleId) async {
    final root = await capsulesDir();
    final dir = Directory(p.join(root.path, capsuleId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<File> payloadFile(String capsuleId) async {
    final dir = await ensureCapsuleDir(capsuleId);
    return File(p.join(dir.path, 'payload.enc'));
  }

  @override
  Future<File> manifestFile(String capsuleId) async {
    final dir = await ensureCapsuleDir(capsuleId);
    return File(p.join(dir.path, 'manifest.json'));
  }

  @override
  Future<File> copySourceToPayload({
    required String capsuleId,
    required File src,
  }) async {
    final dst = await payloadFile(capsuleId);
    if (await dst.exists()) {
      await dst.delete();
    }
    await src.copy(dst.path);
    return dst;
  }

  @override
  Future<File> writeManifest({
    required String capsuleId,
    required Map<String, Object?> manifest,
  }) async {
    final f = await manifestFile(capsuleId);
    final content = const JsonEncoder.withIndent('  ').convert(manifest);
    await writeStringAtomic(f, content);
    return f;
  }

  @override
  Future<Map<String, Object?>> readManifest(File manifestFile) async {
    final text = await manifestFile.readAsString();
    final obj = jsonDecode(text);
    if (obj is! Map) {
      throw const FormatException('manifest is not a JSON object');
    }
    return obj.map((k, v) => MapEntry(k.toString(), v));
  }

  @override
  Future<List<File>> listAllManifestFiles() async {
    final root = await capsulesDir();
    if (!await root.exists()) return [];

    final result = <File>[];
    await for (final ent in root.list(followLinks: false)) {
      if (ent is Directory) {
        final mf = File(p.join(ent.path, 'manifest.json'));
        if (await mf.exists()) {
          result.add(mf);
        }
      }
    }
    return result;
  }

  @override
  Future<File> createTempFile({required String filename}) async {
    final dir = await tempDir();
    final safe = _sanitizeFilename(filename);
    final path = p.join(dir.path, safe);
    return File(path);
  }

  String _sanitizeFilename(String name) {
    final replaced = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return replaced.isEmpty ? 'temp.bin' : replaced;
  }

  @override
  Future<void> writeStringAtomic(File file, String content) async {
    final bytes = utf8.encode(content);
    await writeBytesAtomic(file, bytes);
  }

  @override
  Future<void> writeBytesAtomic(File file, List<int> bytes) async {
    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final tmpPath = '${file.path}.tmp';
    final tmp = File(tmpPath);

    if (await tmp.exists()) {
      await tmp.delete();
    }
    await tmp.writeAsBytes(bytes, flush: true);

    try {
      if (await file.exists()) {
        await file.delete();
      }
      await tmp.rename(file.path);
    } catch (_) {
      await tmp.copy(file.path);
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }
}
