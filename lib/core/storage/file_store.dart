// lib/store/file_store.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class FileStore {
  /// App Support 目录（iOS/Android/desktop 都在沙盒内，适合放业务数据）
  Future<Directory> appSupportDir();

  /// 临时目录（解密/占位打开时拷贝到这里，方便清理）
  Future<Directory> tempDir();

  /// capsules 根目录：{appSupportDir}/capsules
  Future<Directory> capsulesDir();

  /// keys 目录：{appSupportDir}/keys
  Future<Directory> keysDir();

  /// 设备密钥文件：{appSupportDir}/keys/device_key.bin
  Future<File> deviceKeyFile();

  /// 读取设备密钥（不存在则返回 null）
  Future<Uint8List?> readDeviceKey();

  /// 写设备密钥（原子写）
  Future<void> writeDeviceKey(Uint8List keyBytes);

  /// 获取或生成设备密钥（默认 32 bytes）
  Future<Uint8List> getOrCreateDeviceKey({int length = 32});

  /// 确保某胶囊目录存在：{capsulesDir}/{capsuleId}
  Future<Directory> ensureCapsuleDir(String capsuleId);

  /// payload.enc 的 File handle
  Future<File> payloadFile(String capsuleId);

  /// manifest.json 的 File handle
  Future<File> manifestFile(String capsuleId);

  /// 将源文件拷贝到 payload.enc（占位：不加密）
  Future<File> copySourceToPayload({
    required String capsuleId,
    required File src,
  });

  /// 写 manifest.json（原子写）
  Future<File> writeManifest({
    required String capsuleId,
    required Map<String, Object?> manifest,
  });

  /// 读 manifest.json
  Future<Map<String, Object?>> readManifest(File manifestFile);

  /// 列出所有 manifest.json 文件（用于先不做 SQLite 时的 listCapsules）
  Future<List<File>> listAllManifestFiles();

  /// 创建一个临时文件路径（不会自动写入）
  Future<File> createTempFile({required String filename});

  /// 原子写文本
  Future<void> writeStringAtomic(File file, String content);

  /// 原子写字节
  Future<void> writeBytesAtomic(File file, List<int> bytes);
}

class FileStoreImpl implements FileStore {
  static const String _capsulesFolder = 'capsules';
  static const String _keysFolder = 'keys';
  static const String _deviceKeyName = 'device_key.bin';
  static const String _payloadName = 'payload.enc';
  static const String _manifestName = 'manifest.json';

  Directory? _support;
  Directory? _temp;
  Directory? _capsules;
  Directory? _keys;

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

  @override
  Future<Directory> capsulesDir() async {
    if (_capsules != null) return _capsules!;
    final base = await appSupportDir();
    _capsules = Directory(p.join(base.path, _capsulesFolder));
    if (!await _capsules!.exists()) {
      await _capsules!.create(recursive: true);
    }
    return _capsules!;
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
    return File(p.join(dir.path, _payloadName));
  }

  @override
  Future<File> manifestFile(String capsuleId) async {
    final dir = await ensureCapsuleDir(capsuleId);
    return File(p.join(dir.path, _manifestName));
  }

  @override
  Future<File> copySourceToPayload({
    required String capsuleId,
    required File src,
  }) async {
    final dst = await payloadFile(capsuleId);
    // 覆盖写：先删再 copy，避免 copy 到已有文件报错/残留
    if (await dst.exists()) {
      await dst.delete();
    }
    await src.copy(dst.path); // stream copy，适合大文件
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
      throw FormatException('manifest is not a JSON object');
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
        final mf = File(p.join(ent.path, _manifestName));
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
    // 简单安全处理：去掉路径分隔与非法字符
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

    // 原子替换：尽量 rename；失败则 copy+delete（Windows 某些情况下 rename 会失败）
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
