import 'dart:typed_data';

abstract class SecureKeyStore {
  Future<Uint8List> getOrCreateMasterKey();
}

class SecureKeyStoreImpl implements SecureKeyStore {
  @override
  Future<Uint8List> getOrCreateMasterKey() async {
    // TODO: integrate with platform secure storage
    // For now return a placeholder 32 bytes; will replace in implementation.
    return Uint8List(32);
  }
}
