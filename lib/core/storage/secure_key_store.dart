// lib/core/security/secure_key_store.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 管理“设备保护密钥”（Device Protection Key, DPK）
///
/// - DPK 是每台设备独立的 32 字节随机密钥
/// - 存在系统安全区（iOS Keychain / Android Keystore / Windows Credential 等）
/// - 用来在本地加密 UMK blob（用户主密钥），不会直接参与文件内容加密
abstract class SecureKeyStore {
  /// 获取或生成本设备的 DPK（32 bytes）
  Future<Uint8List> getOrCreateDeviceKey();
}

class SecureKeyStoreImpl implements SecureKeyStore {
  static const _storageKeyDeviceKey = 'device_key_v1';

  final FlutterSecureStorage _storage;

  SecureKeyStoreImpl({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<Uint8List> getOrCreateDeviceKey() async {
    final existing = await _storage.read(key: _storageKeyDeviceKey);
    if (existing != null && existing.isNotEmpty) {
      final bytes = base64Decode(existing);
      return Uint8List.fromList(bytes);
    }

    // 不存在则生成新的 32 字节随机值
    final rnd = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => rnd.nextInt(256)),
    );

    // base64 存到 secure storage
    await _storage.write(key: _storageKeyDeviceKey, value: base64Encode(bytes));
    return bytes;
  }
}
