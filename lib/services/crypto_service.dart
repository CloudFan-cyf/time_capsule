import 'dart:io';
import '../models/capsule.dart';

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
  @override
  Future<CapsuleCreateResult> createCapsuleFromFile(
    File src,
    CapsuleParams params,
  ) async {
    // TODO: Implement encryption, manifest creation, and storage
    throw UnimplementedError();
  }

  @override
  Future<File> decryptCapsuleToTemp({
    required File payloadFile,
    required File manifestFile,
  }) async {
    // TODO: Implement decryption logic to a temp file
    throw UnimplementedError();
  }
}
