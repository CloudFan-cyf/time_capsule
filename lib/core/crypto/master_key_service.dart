// lib/core/crypto/master_key_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'package:time_capsule/core/storage/secure_key_store.dart';
import 'package:time_capsule/core/storage/file_store.dart';

class MasterKeyService {
  MasterKeyService({
    required SecureKeyStore secureKeyStore,
    required FileStore fileStore,
    AesGcm? aesGcm,
  }) : _secureKeyStore = secureKeyStore,
       _fileStore = fileStore,
       _aesGcm = aesGcm ?? AesGcm.with256bits();

  final SecureKeyStore _secureKeyStore;
  final FileStore _fileStore;
  final AesGcm _aesGcm;

  /// 获取或生成 UMK（用户主密钥，32 bytes）
  ///
  /// - 若已存在 master_key_blob.json：用 DPK 解密得到 UMK
  /// - 若不存在或解密失败：生成新的 UMK，并写入 blob
  Future<Uint8List> getOrCreateUmk() async {
    final dpk = await _secureKeyStore.getOrCreateDeviceKey();
    final existingBlob = await _fileStore.readMasterKeyBlob();

    if (existingBlob != null) {
      try {
        final umk = await _decryptUmk(dpk, existingBlob);
        if (umk.length == 32) {
          return umk;
        }
      } catch (_) {
        // blob 损坏则重新生成
      }
    }

    // 生成新的 UMK（32 bytes 随机值）
    final rnd = Random.secure();
    final umkBytes = Uint8List.fromList(
      List<int>.generate(32, (_) => rnd.nextInt(256)),
    );

    final blob = await _encryptUmk(dpk, umkBytes);
    await _fileStore.writeMasterKeyBlob(blob);

    return umkBytes;
  }

  /// 导出主密钥到指定文件（简单 JSON：version + umkB64）
  Future<void> exportUmkToFile(File target) async {
    final umk = await getOrCreateUmk();
    final payload = <String, Object?>{
      'version': 1,
      'createdAtUtcMs': DateTime.now().toUtc().millisecondsSinceEpoch,
      'umkB64': base64Encode(umk),
    };
    final text = const JsonEncoder.withIndent('  ').convert(payload);
    await target.writeAsString(text, flush: true);
  }

  /// 从导出的 key 文件导入 UMK，并用当前设备的 DPK 重新加密写入 blob
  Future<void> importUmkFromFile(File src) async {
    final text = await src.readAsString();
    final obj = jsonDecode(text);
    if (obj is! Map) {
      throw const FormatException('Invalid key file (not JSON object)');
    }

    final umkB64 = obj['umkB64'];
    if (umkB64 is! String) {
      throw const FormatException('Invalid key file (missing "umkB64")');
    }
    final umkBytes = Uint8List.fromList(base64Decode(umkB64));
    if (umkBytes.length != 32) {
      throw FormatException('Unexpected UMK length: ${umkBytes.length}');
    }

    final dpk = await _secureKeyStore.getOrCreateDeviceKey();
    final blob = await _encryptUmk(dpk, umkBytes);
    await _fileStore.writeMasterKeyBlob(blob);
  }

  Future<Uint8List> _decryptUmk(Uint8List dpk, Uint8List blobBytes) async {
    final jsonStr = utf8.decode(blobBytes);
    final obj = jsonDecode(jsonStr);
    if (obj is! Map) {
      throw const FormatException('Invalid master key blob');
    }

    final version = obj['v'] ?? obj['version'] ?? 1;
    if (version != 1) {
      throw FormatException('Unsupported master key blob version: $version');
    }

    final nonceB64 = obj['nonce'] as String?;
    final cipherB64 = obj['ciphertext'] as String?;
    final tagB64 = obj['tag'] as String?;
    if (nonceB64 == null || cipherB64 == null || tagB64 == null) {
      throw const FormatException('Missing fields in master key blob');
    }

    final nonce = base64Decode(nonceB64);
    final cipherText = base64Decode(cipherB64);
    final tag = base64Decode(tagB64);

    final secretKey = SecretKey(dpk);
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(tag));

    final clear = await _aesGcm.decrypt(secretBox, secretKey: secretKey);
    return Uint8List.fromList(clear);
  }

  Future<Uint8List> _encryptUmk(Uint8List dpk, Uint8List umk) async {
    final secretKey = SecretKey(dpk);
    // GCM nonce 12 bytes
    final rnd = Random.secure();
    final nonce = Uint8List.fromList(
      List<int>.generate(12, (_) => rnd.nextInt(256)),
    );

    final secretBox = await _aesGcm.encrypt(
      umk,
      secretKey: secretKey,
      nonce: nonce,
    );

    final map = <String, Object?>{
      'v': 1,
      'alg': 'AES-256-GCM',
      'nonce': base64Encode(nonce),
      'ciphertext': base64Encode(secretBox.cipherText),
      'tag': base64Encode(secretBox.mac.bytes),
    };

    final jsonBytes = utf8.encode(jsonEncode(map));
    return Uint8List.fromList(jsonBytes);
  }

  /// 生成导出用的 JSON 文本（UI 决定写到哪里）
  Future<String> exportUmkJson() async {
    final umk = await getOrCreateUmk();
    final payload = <String, Object?>{
      'version': 1,
      'createdAtUtcMs': DateTime.now().toUtc().millisecondsSinceEpoch,
      'umkB64': base64Encode(umk),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
