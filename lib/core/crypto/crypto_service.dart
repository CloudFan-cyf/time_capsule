import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'package:time_capsule/core/storage/file_store.dart';
import 'package:time_capsule/features/capsules/data/models/capsule.dart';

abstract class CryptoService {
  /// 旧接口：单文件创建（向后兼容）
  Future<CapsuleCreateResult> createCapsuleFromFile(
    File src,
    CapsuleParams params,
  );

  /// 新接口：多文件创建，同一个胶囊中可包含多个文件
  Future<CapsuleCreateResult> createCapsuleFromFiles(
    List<File> srcFiles,
    CapsuleParams params,
  );

  /// 解密（当前为占位：只负责“准备好 files/ 下的明文文件”）并返回所有可预览文件
  Future<List<File>> ensureDecryptedFiles({required File manifestFile});
}

class CryptoServiceImpl implements CryptoService {
  final FileStore fileStore;

  CryptoServiceImpl({FileStore? fileStore})
    : fileStore = fileStore ?? FileStoreImpl();

  String _newId() {
    final t = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    final r = Random.secure().nextInt(1 << 32).toRadixString(16);
    return '$t-$r';
  }

  String _sanitizeFilename(String name) {
    // 简单清理一下非法字符
    final replaced = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return replaced.isEmpty ? 'file.bin' : replaced;
  }

  @override
  Future<CapsuleCreateResult> createCapsuleFromFile(
    File src,
    CapsuleParams params,
  ) {
    // 向后兼容：单文件走多文件接口
    return createCapsuleFromFiles([src], params);
  }

  @override
  Future<CapsuleCreateResult> createCapsuleFromFiles(
    List<File> srcFiles,
    CapsuleParams params,
  ) async {
    if (srcFiles.isEmpty) {
      throw ArgumentError('srcFiles must not be empty');
    }

    final id = _newId();
    final createdAtUtcMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    // 胶囊目录
    final capsuleDir = await fileStore.ensureCapsuleDir(id);
    final filesDir = Directory(p.join(capsuleDir.path, 'files'));
    if (!await filesDir.exists()) {
      await filesDir.create(recursive: true);
    }

    final filesMeta = <Map<String, Object?>>[];

    String firstOrigName = '';
    int? firstSize;
    String? firstEncRelPath;

    for (var i = 0; i < srcFiles.length; i++) {
      final src = srcFiles[i];
      final origName = _sanitizeFilename(p.basename(src.path));
      final size = await src.length();

      final indexStr = i.toString().padLeft(4, '0');
      final destName = '${indexStr}_$origName';
      final relPath = p.join('files', destName);
      final destFile = File(p.join(filesDir.path, destName));

      if (await destFile.exists()) {
        await destFile.delete();
      }
      await src.copy(destFile.path);

      filesMeta.add({
        'index': i,
        'name': origName,
        'relPath': relPath,
        'size': size,
        'mime': null, // 未来可以根据扩展名填 MIME
      });

      if (i == 0) {
        firstOrigName = origName;
        firstSize = size;
        firstEncRelPath = relPath;
      }
    }

    // 写 manifest.json
    final manifestMap = <String, Object?>{
      'id': id,
      'title': params.title,
      'createdAtUtcMs': createdAtUtcMs,
      'unlockAtUtcMs': params.unlockAtUtcMs,
      'origFilename': firstOrigName,
      'mime': null,
      'origSize': firstSize,
      'status': 0,
      'files': filesMeta,
      // 为了兼容旧的 listCapsules 逻辑，仍保留一个 payload 字段指向第一个文件
      'payload': {
        'path': firstEncRelPath ?? '',
        'formatVersion': 1,
        'placeholder': true,
      },
    };

    final manifestFile = await fileStore.writeManifest(
      capsuleId: id,
      manifest: manifestMap,
    );

    final encPath = firstEncRelPath != null
        ? p.join(capsuleDir.path, firstEncRelPath)
        : p.join(capsuleDir.path, 'files', '0000_$firstOrigName');

    final capsule = Capsule(
      id: id,
      title: params.title,
      origFilename: firstOrigName,
      mime: null,
      createdAtUtcMs: createdAtUtcMs,
      unlockAtUtcMs: params.unlockAtUtcMs,
      origSize: firstSize,
      encPath: encPath,
      manifestPath: manifestFile.path,
      status: 0,
      lastTimeCheckUtcMs: null,
      lastTimeSource: null,
    );

    return CapsuleCreateResult(capsule);
  }

  @override
  Future<List<File>> ensureDecryptedFiles({required File manifestFile}) async {
    final manifest = await fileStore.readManifest(manifestFile);
    final capsuleDir = manifestFile.parent;

    final result = <File>[];

    // 新格式：files 数组
    final filesField = manifest['files'];
    if (filesField is List) {
      for (final entry in filesField) {
        if (entry is! Map) continue;
        final relPath = entry['relPath'] as String?;
        if (relPath == null || relPath.isEmpty) continue;

        final f = File(p.join(capsuleDir.path, relPath));
        if (await f.exists()) {
          result.add(f);
        }
      }
      if (result.isNotEmpty) {
        // 当前占位版：没有真正“加密 → 解密”的过程，文件本身就是明文
        return result;
      }
    }

    // 旧格式兼容：只有一个 payload.enc
    final payloadField = manifest['payload'];
    if (payloadField is Map) {
      final rel = payloadField['path'] as String? ?? 'payload.enc';
      final payloadFile = File(p.join(capsuleDir.path, rel));
      if (await payloadFile.exists()) {
        final origFilename =
            (manifest['origFilename'] as String?) ?? 'file.bin';
        final plainFile = File(p.join(capsuleDir.path, origFilename));
        if (!await plainFile.exists()) {
          await payloadFile.copy(plainFile.path);
        }
        result.add(plainFile);
      }
    }

    return result;
  }
}
