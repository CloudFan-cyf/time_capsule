import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import 'package:time_capsule/core/crypto/master_key_service.dart';
import 'package:time_capsule/core/storage/secure_key_store.dart';
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

  /// 解密并返回所有可预览文件（输出到 capsule/open/ 下）
  Future<List<File>> ensureDecryptedFiles({required File manifestFile});
}

class CryptoServiceImpl implements CryptoService {
  final FileStore fileStore;
  final MasterKeyService masterKeyService;

  final AesGcm _aesGcm = AesGcm.with256bits();

  CryptoServiceImpl({FileStore? fileStore, MasterKeyService? masterKeyService})
    : fileStore = fileStore ?? FileStoreImpl(),
      masterKeyService =
          masterKeyService ??
          MasterKeyService(
            secureKeyStore: SecureKeyStoreImpl(),
            fileStore: fileStore ?? FileStoreImpl(),
          );

  String _newId() {
    final t = DateTime.now().toUtc().microsecondsSinceEpoch.toString();
    final r = Random.secure().nextInt(1 << 32).toRadixString(16);
    return '$t-$r';
  }

  Uint8List _randBytes(int n) {
    final rnd = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => rnd.nextInt(256)));
  }

  String _sanitizeFilename(String name) {
    final replaced = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return replaced.isEmpty ? 'file.bin' : replaced;
  }

  /// 文件加密输出格式： nonce(12) + ciphertext + tag(16)
  Future<void> _encryptFileToEnc({
    required File src,
    required File encOut,
    required Uint8List dek,
  }) async {
    final plain = await src.readAsBytes(); // MVP：整文件读入内存（大文件后续可改流式）
    final nonce = _randBytes(12);

    final secretBox = await _aesGcm.encrypt(
      plain,
      secretKey: SecretKey(dek),
      nonce: nonce,
    );

    final bb = BytesBuilder(copy: false);
    bb.add(nonce);
    bb.add(secretBox.cipherText);
    bb.add(secretBox.mac.bytes);

    if (await encOut.exists()) {
      await encOut.delete();
    }
    await encOut.parent.create(recursive: true);
    await encOut.writeAsBytes(bb.takeBytes(), flush: true);
  }

  Future<void> _decryptEncToFile({
    required File encFile,
    required File plainOut,
    required Uint8List dek,
  }) async {
    final data = await encFile.readAsBytes();
    if (data.length < 12 + 16) {
      throw const FormatException('Encrypted file too small');
    }

    final nonce = data.sublist(0, 12);
    final tag = data.sublist(data.length - 16);
    final cipherText = data.sublist(12, data.length - 16);

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(tag));

    final clear = await _aesGcm.decrypt(secretBox, secretKey: SecretKey(dek));

    // 原子写：避免写一半崩溃导致脏文件
    await fileStore.writeBytesAtomic(plainOut, clear);
  }

  Future<Map<String, String>> _wrapDekWithUmk({
    required Uint8List umk,
    required Uint8List dek,
  }) async {
    final nonce = _randBytes(12);
    final secretBox = await _aesGcm.encrypt(
      dek,
      secretKey: SecretKey(umk),
      nonce: nonce,
    );

    return {
      'alg': 'AES-256-GCM',
      'nonceB64': base64Encode(nonce),
      'wrappedDekB64': base64Encode(secretBox.cipherText),
      'tagB64': base64Encode(secretBox.mac.bytes),
    };
  }

  Future<Uint8List> _unwrapDekWithUmk({
    required Uint8List umk,
    required Map keyWrap,
  }) async {
    final nonceB64 = keyWrap['nonceB64'] as String?;
    final wrappedB64 = keyWrap['wrappedDekB64'] as String?;
    final tagB64 = keyWrap['tagB64'] as String?;
    if (nonceB64 == null || wrappedB64 == null || tagB64 == null) {
      throw const FormatException('Invalid keyWrap fields');
    }

    final nonce = base64Decode(nonceB64);
    final cipherText = base64Decode(wrappedB64);
    final tag = base64Decode(tagB64);

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(tag));

    final dek = await _aesGcm.decrypt(secretBox, secretKey: SecretKey(umk));
    return Uint8List.fromList(dek);
  }

  @override
  Future<CapsuleCreateResult> createCapsuleFromFile(
    File src,
    CapsuleParams params,
  ) {
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

    // 取 UMK（用于包裹 DEK）
    final umk = await masterKeyService.getOrCreateUmk();

    // 每个胶囊一个 DEK
    final dek = _randBytes(32);

    // 包裹 DEK 写进 manifest
    final keyWrap = await _wrapDekWithUmk(umk: umk, dek: dek);

    // 胶囊目录
    final capsuleDir = await fileStore.ensureCapsuleDir(id);

    // enc 文件目录：capsule/files/*.enc
    final filesDir = Directory(p.join(capsuleDir.path, 'files'));
    if (!await filesDir.exists()) {
      await filesDir.create(recursive: true);
    }

    // 明文输出目录（解密后）：capsule/open/
    final openDirRel = 'open';

    final filesMeta = <Map<String, Object?>>[];

    String firstOrigName = '';
    int? firstSize;
    String? firstEncRelPath;

    for (var i = 0; i < srcFiles.length; i++) {
      final src = srcFiles[i];
      final origName = _sanitizeFilename(p.basename(src.path));
      final size = await src.length();

      final indexStr = i.toString().padLeft(4, '0');

      // 加密文件名：0000_xxx.ext.enc
      final encName = '${indexStr}_$origName.enc';
      final encRelPath = p.join('files', encName);
      final encFile = File(p.join(filesDir.path, encName));

      await _encryptFileToEnc(src: src, encOut: encFile, dek: dek);

      // 解密输出文件名：open/0000_xxx.ext
      final plainName = '${indexStr}_$origName';
      final plainRelPath = p.join(openDirRel, plainName);

      filesMeta.add({
        'index': i,
        'name': origName,
        'origSize': size,
        'encRelPath': encRelPath,
        'plainRelPath': plainRelPath,
        'encAlg': 'AES-256-GCM',
      });

      if (i == 0) {
        firstOrigName = origName;
        firstSize = size;
        firstEncRelPath = encRelPath;
      }
    }

    // 写 manifest.json
    final manifestMap = <String, Object?>{
      'id': id,
      'title': params.title,
      'createdAtUtcMs': createdAtUtcMs,
      'unlockAtUtcMs': params.unlockAtUtcMs,

      // 列表页展示用
      'origFilename': firstOrigName,
      'mime': null,
      'origSize': firstSize,
      'status': 0,

      // 关键：DEK 包裹信息
      'keyWrap': keyWrap,

      // 多文件
      'files': filesMeta,

      // 兼容旧 listCapsules：payload 指向第一个加密文件
      'payload': {
        'path': firstEncRelPath ?? '',
        'formatVersion': 2,
        'placeholder': false,
      },
    };

    final manifestFile = await fileStore.writeManifest(
      capsuleId: id,
      manifest: manifestMap,
    );

    final encPath = firstEncRelPath != null
        ? p.join(capsuleDir.path, firstEncRelPath)
        : p.join(capsuleDir.path, 'files', '0000_$firstOrigName.enc');

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

    // 1) 如果没有 keyWrap：认为是老的“未加密占位格式”，直接返回文件
    final keyWrapField = manifest['keyWrap'];
    if (keyWrapField == null) {
      final filesField = manifest['files'];
      if (filesField is List) {
        for (final entry in filesField) {
          if (entry is! Map) continue;
          final relPath = entry['relPath'] as String?;
          if (relPath == null || relPath.isEmpty) continue;
          final f = File(p.join(capsuleDir.path, relPath));
          if (await f.exists()) result.add(f);
        }
        return result;
      }

      final payloadField = manifest['payload'];
      if (payloadField is Map) {
        final rel = payloadField['path'] as String? ?? 'payload.enc';
        final f = File(p.join(capsuleDir.path, rel));
        if (await f.exists()) result.add(f);
      }
      return result;
    }

    // 2) 解包 DEK
    if (keyWrapField is! Map) {
      throw const FormatException('keyWrap must be an object');
    }

    final umk = await masterKeyService.getOrCreateUmk();
    final dek = await _unwrapDekWithUmk(umk: umk, keyWrap: keyWrapField);

    // 3) 解密每个文件到 open/
    final filesField = manifest['files'];
    if (filesField is! List) {
      throw const FormatException('files must be a list');
    }

    final openDir = Directory(p.join(capsuleDir.path, 'open'));
    if (!await openDir.exists()) {
      await openDir.create(recursive: true);
    }

    for (final entry in filesField) {
      if (entry is! Map) continue;

      final encRelPath =
          (entry['encRelPath'] as String?) ?? (entry['relPath'] as String?);
      final plainRelPath = entry['plainRelPath'] as String?;
      final name = entry['name'] as String? ?? 'file.bin';

      if (encRelPath == null || encRelPath.isEmpty) continue;

      final encFile = File(p.join(capsuleDir.path, encRelPath));
      if (!await encFile.exists()) {
        continue;
      }

      // 明文输出路径：优先用 plainRelPath，否则用 open/<name>
      final plainPath = plainRelPath != null && plainRelPath.isNotEmpty
          ? p.join(capsuleDir.path, plainRelPath)
          : p.join(openDir.path, _sanitizeFilename(name));
      final plainFile = File(plainPath);

      if (await plainFile.exists()) {
        result.add(plainFile);
        continue;
      }

      await _decryptEncToFile(encFile: encFile, plainOut: plainFile, dek: dek);
      result.add(plainFile);
    }

    return result;
  }
}
