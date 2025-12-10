import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'package:time_capsule/core/storage/file_store.dart';
import 'package:time_capsule/features/capsules/data/models/capsule.dart';

abstract class CryptoService {
  Future<CapsuleCreateResult> createCapsuleFromFile(
    File src,
    CapsuleParams params,
  );

  Future<File> decryptCapsuleToTemp({
    required File payloadFile,
    required File manifestFile,
  });
}

class CryptoServiceImpl implements CryptoService {
  final FileStore fileStore;

  CryptoServiceImpl({FileStore? fileStore})
    : fileStore = fileStore ?? FileStoreImpl();

  String _newId() {
    final r = Random.secure().nextInt(1 << 32).toRadixString(16);
    final t = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    return '$t-$r';
  }

  @override
  Future<CapsuleCreateResult> createCapsuleFromFile(
    File src,
    CapsuleParams params,
  ) async {
    // 先确保 device key 存在（占位：后续真正加密时会用到）
    await fileStore.getOrCreateDeviceKey();

    final id = _newId();
    final createdAtUtcMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final origFilename = p.basename(src.path);
    final origSize = await src.length();

    // 1) 创建胶囊目录 & copy 源文件到 payload.enc（占位，不加密）
    final payload = await fileStore.copySourceToPayload(
      capsuleId: id,
      src: src,
    );

    // 2) 写 manifest.json（先用最小字段，后续加密会补 keyWrap / integrity 等）
    final manifest = <String, Object?>{
      'id': id,
      'title': params.title,
      'createdAtUtcMs': createdAtUtcMs,
      'unlockAtUtcMs': params.unlockAtUtcMs,
      'origFilename': origFilename,
      'origSize': origSize,
      'payload': {
        'path': 'payload.enc',
        'formatVersion': 1,
        'placeholder': true, // 标记当前是占位明文 copy
      },
    };
    final manifestFile = await fileStore.writeManifest(
      capsuleId: id,
      manifest: manifest,
    );

    // 3) 组装 Capsule 模型（字段名按你现有 model 调整）
    final capsule = Capsule(
      id: id,
      title: params.title,
      unlockAtUtcMs: params.unlockAtUtcMs,
      createdAtUtcMs: createdAtUtcMs,
      encPath: payload.path,
      manifestPath: manifestFile.path,
      status: 0, // 初始状态
      // 如果你的 Capsule 还有 origFilename/origSize 等字段，也建议带上
      origFilename: origFilename,
      origSize: origSize,
    );

    return CapsuleCreateResult(capsule);
  }

  @override
  Future<File> decryptCapsuleToTemp({
    required File payloadFile,
    required File manifestFile,
  }) async {
    // 占位版：不解密，直接 copy 到 temp 并返回
    final manifest = await fileStore.readManifest(manifestFile);
    final origFilename = (manifest['origFilename'] as String?) ?? 'file.bin';

    final tmp = await fileStore.createTempFile(
      filename:
          'timecapsule_${DateTime.now().millisecondsSinceEpoch}_$origFilename',
    );

    if (await tmp.exists()) {
      await tmp.delete();
    }
    await payloadFile.copy(tmp.path);
    return tmp;
  }
}
