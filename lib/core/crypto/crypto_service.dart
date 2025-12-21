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
  static const List<int> _magicTCF1 = [0x54, 0x43, 0x46, 0x31]; // 'TCF1'
  static const int _encHeaderSize = 26;
  static const int _gcmNonceSize = 12;
  static const int _gcmTagSize = 16;

  // 默认分块大小：1 MiB（可根据你性能需求调大到 4~8MiB）
  static const int _defaultChunkSize = 1 << 20;

  Uint8List _nonceForChunk(Uint8List prefix8, int chunkIndex) {
    final nonce = Uint8List(_gcmNonceSize);
    nonce.setRange(0, 8, prefix8);
    final bd = ByteData.sublistView(nonce);
    bd.setUint32(8, chunkIndex, Endian.big);
    return nonce;
  }

  Uint8List _buildHeader({
    required int chunkSize,
    required int plainSize,
    required Uint8List noncePrefix8,
  }) {
    final buf = Uint8List(_encHeaderSize);
    buf.setRange(0, 4, _magicTCF1);
    buf[4] = 1; // version
    buf[5] = 0; // flags
    final bd = ByteData.sublistView(buf);
    bd.setUint32(6, chunkSize, Endian.big);
    bd.setUint64(10, plainSize, Endian.big);
    buf.setRange(18, 26, noncePrefix8);
    return buf;
  }

  ({int version, int chunkSize, int plainSize, Uint8List noncePrefix8})
  _parseHeader(Uint8List header) {
    if (header.length < _encHeaderSize) {
      throw const FormatException('Encrypted header too small');
    }
    for (var i = 0; i < 4; i++) {
      if (header[i] != _magicTCF1[i]) {
        throw const FormatException('Not a TCF1 encrypted file');
      }
    }
    final version = header[4];
    if (version != 1) {
      throw FormatException('Unsupported encrypted file version: $version');
    }
    final bd = ByteData.sublistView(header);
    final chunkSize = bd.getUint32(6, Endian.big);
    final plainSize64 = bd.getUint64(10, Endian.big);
    if (chunkSize <= 0) {
      throw FormatException('Invalid chunkSize: $chunkSize');
    }
    if (plainSize64 > 0x7fffffff) {
      // Dart int 在 64-bit 上没问题，但这里给个防御性提示（可按需移除）
    }
    final prefix8 = Uint8List.fromList(header.sublist(18, 26));
    return (
      version: version,
      chunkSize: chunkSize,
      plainSize: plainSize64.toInt(),
      noncePrefix8: prefix8,
    );
  }

  Future<void> _commitTempFile(File tmp, File target) async {
    await target.parent.create(recursive: true);
    try {
      if (await target.exists()) {
        await target.delete();
      }
      await tmp.rename(target.path);
    } catch (_) {
      // Windows/Android 某些情况下 rename 可能失败，退化为 copy+delete
      await tmp.copy(target.path);
      try {
        await tmp.delete();
      } catch (_) {}
    }
  }

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

  /// 文件加密输出格式（分块容器 v1，支持大文件）
  ///
  /// Header(26 bytes):
  /// - magic: 4 bytes = 'TCF1'
  /// - version: 1 byte = 1
  /// - flags: 1 byte = 0
  /// - chunkSize: uint32 (BE)
  /// - plainSize: uint64 (BE)
  /// - noncePrefix: 8 bytes (random)
  ///
  /// Body:
  /// for each chunk i:
  ///   nonce = noncePrefix(8) + uint32(i, BE)  // total 12 bytes
  ///   write: cipherText(len=plainChunkLen) + tag(16)

  Future<void> _encryptFileToEnc({
    required File src,
    required File encOut,
    required Uint8List dek,
    int chunkSize = _defaultChunkSize,
  }) async {
    final plainSize = await src.length();
    final noncePrefix8 = _randBytes(8);

    final tmpEnc = File('${encOut.path}.tmp');

    RandomAccessFile? inRaf;
    RandomAccessFile? outRaf;

    try {
      await tmpEnc.parent.create(recursive: true);
      outRaf = await tmpEnc.open(mode: FileMode.write);

      // header
      final header = _buildHeader(
        chunkSize: chunkSize,
        plainSize: plainSize,
        noncePrefix8: noncePrefix8,
      );
      await outRaf.writeFrom(header);

      // body: chunk-by-chunk
      inRaf = await src.open(mode: FileMode.read);
      var chunkIndex = 0;

      while (true) {
        final plainChunk = await inRaf.read(chunkSize);
        if (plainChunk.isEmpty) break;

        final nonce = _nonceForChunk(noncePrefix8, chunkIndex);
        final secretBox = await _aesGcm.encrypt(
          plainChunk,
          secretKey: SecretKey(dek),
          nonce: nonce,
        );

        // ciphertext len == plaintext len
        await outRaf.writeFrom(secretBox.cipherText);
        await outRaf.writeFrom(secretBox.mac.bytes);
        chunkIndex++;
      }

      await outRaf.flush();
      await outRaf.close();
      outRaf = null;

      // 原子提交 enc 文件
      await _commitTempFile(tmpEnc, encOut);
    } finally {
      try {
        await inRaf?.close();
      } catch (_) {}
      try {
        await outRaf?.close();
      } catch (_) {}
      // 若中途失败，尽力删除 tmp
      try {
        if (await tmpEnc.exists()) await tmpEnc.delete();
      } catch (_) {}
    }
  }

  Future<void> _decryptEncToFile({
    required File encFile,
    required File plainOut,
    required Uint8List dek,
  }) async {
    final tmpPlain = File('${plainOut.path}.tmp');

    RandomAccessFile? inRaf;
    RandomAccessFile? outRaf;

    try {
      inRaf = await encFile.open(mode: FileMode.read);

      final headerBytes = await inRaf.read(_encHeaderSize);
      final h = _parseHeader(headerBytes);

      var remaining = h.plainSize;
      var chunkIndex = 0;

      await tmpPlain.parent.create(recursive: true);
      outRaf = await tmpPlain.open(mode: FileMode.write);

      while (remaining > 0) {
        final plainLen = remaining < h.chunkSize ? remaining : h.chunkSize;

        final cipherText = await inRaf.read(plainLen);
        if (cipherText.length != plainLen) {
          throw const FormatException(
            'Unexpected EOF while reading ciphertext',
          );
        }
        final tag = await inRaf.read(_gcmTagSize);
        if (tag.length != _gcmTagSize) {
          throw const FormatException('Unexpected EOF while reading tag');
        }

        final nonce = _nonceForChunk(h.noncePrefix8, chunkIndex);
        final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(tag));

        final clear = await _aesGcm.decrypt(
          secretBox,
          secretKey: SecretKey(dek),
        );

        await outRaf.writeFrom(clear);

        remaining -= plainLen;
        chunkIndex++;
      }

      await outRaf.flush();
      await outRaf.close();
      outRaf = null;

      await _commitTempFile(tmpPlain, plainOut);
    } finally {
      try {
        await inRaf?.close();
      } catch (_) {}
      try {
        await outRaf?.close();
      } catch (_) {}
      try {
        if (await tmpPlain.exists()) await tmpPlain.delete();
      } catch (_) {}
    }
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
        'encContainer': 'TCF1',
        'encContainerVersion': 1,
        'chunkSize': _defaultChunkSize,
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

      final expectedSize = entry['origSize'];
      if (await plainFile.exists()) {
        if (expectedSize is int) {
          final len = await plainFile.length();
          if (len == expectedSize) {
            result.add(plainFile);
            continue;
          } else {
            // 脏/旧文件，删掉重解
            try {
              await plainFile.delete();
            } catch (_) {}
          }
        } else {
          // 没有 expectedSize 时，仍选择复用（或你也可以选择强制重解）
          result.add(plainFile);
          continue;
        }
      }

      await _decryptEncToFile(encFile: encFile, plainOut: plainFile, dek: dek);
      result.add(plainFile);
    }

    return result;
  }
}
