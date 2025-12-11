import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
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
    final t = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    final r = Random.secure().nextInt(1 << 32).toRadixString(16);
    return '$t-$r';
  }

  @override
  Future<CapsuleCreateResult> createCapsuleFromFile(
    File src,
    CapsuleParams params,
  ) async {
    // 占位：确保 device key 存在（后续加密会用）
    await fileStore.getOrCreateDeviceKey();
    debugPrint('Device key ensured for capsule creation.');
    final id = _newId();
    final createdAtUtcMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final origFilename = p.basename(src.path);
    final origSize = await src.length();

    // 1) copy 源文件到 payload.enc（占位，暂不加密）
    final payload = await fileStore.copySourceToPayload(
      capsuleId: id,
      src: src,
    );

    // 2) 写 manifest.json
    final manifestMap = <String, Object?>{
      'id': id,
      'title': params.title,
      'createdAtUtcMs': createdAtUtcMs,
      'unlockAtUtcMs': params.unlockAtUtcMs,
      'origFilename': origFilename,
      'mime': null, // 占位：后续可补 MIME sniff
      'origSize': origSize,
      'payload': {
        'path': 'payload.enc',
        'formatVersion': 1,
        'placeholder': true,
      },
      // 下面这些字段后续加密版本再加入：
      // 'keyWrap': {...},
      // 'integrity': {...},
      'status': 0,
    };

    final manifestFile = await fileStore.writeManifest(
      capsuleId: id,
      manifest: manifestMap,
    );

    final capsule = Capsule(
      id: id,
      title: params.title,
      origFilename: origFilename,
      mime: null,
      createdAtUtcMs: createdAtUtcMs,
      unlockAtUtcMs: params.unlockAtUtcMs,
      origSize: origSize,
      encPath: payload.path,
      manifestPath: manifestFile.path,
      status: 0,
      lastTimeCheckUtcMs: null,
      lastTimeSource: null,
    );

    return CapsuleCreateResult(capsule);
  }

  int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  @override
  Future<File> decryptCapsuleToTemp({
    required File payloadFile,
    required File manifestFile,
  }) async {
    // 占位：不解密，直接 copy 到临时目录返回
    final m = await fileStore.readManifest(manifestFile);
    final origFilename = (m['origFilename'] as String?) ?? 'file.bin';

    final tmp = await fileStore.createTempFile(
      filename:
          'timecapsule_${DateTime.now().millisecondsSinceEpoch}_$origFilename',
    );

    if (await tmp.exists()) await tmp.delete();
    await payloadFile.copy(tmp.path);

    // 你也可以顺手更新 manifest 里的 lastTimeCheck / lastTimeSource（可选）
    // 不过严格来说这应该由 repository / db 负责

    return tmp;
  }
}
