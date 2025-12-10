import 'dart:io';
import 'models/capsule.dart';
import 'models/errors.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/time/time_service.dart';

abstract class CapsuleRepository {
  Future<List<Capsule>> listCapsules();
  Future<Capsule> createCapsuleFromFile(File src, CapsuleParams params);
  Future<OpenResult> openCapsule(Capsule capsule);
}

class OpenResult {
  final bool opened;
  final File? decryptedFile;
  final TimeCapsuleError? error;
  OpenResult({required this.opened, this.decryptedFile, this.error});
}

class CapsuleRepositoryImpl implements CapsuleRepository {
  final CryptoService cryptoService;
  final TimeService timeService;

  CapsuleRepositoryImpl({
    required this.cryptoService,
    required this.timeService,
  });

  @override
  Future<List<Capsule>> listCapsules() async {
    // TODO: read from SQLite
    return [];
  }

  @override
  Future<Capsule> createCapsuleFromFile(File src, CapsuleParams params) async {
    final res = await cryptoService.createCapsuleFromFile(src, params);
    // TODO: persist to SQLite
    return res.capsule;
  }

  @override
  Future<OpenResult> openCapsule(Capsule capsule) async {
    final ok = await timeService.canOpen(unlockAtUtcMs: capsule.unlockAtUtcMs);
    if (!ok) {
      return OpenResult(
        opened: false,
        error: TimeCapsuleError('LOCKED', '未到解锁时间'),
      );
    }
    final payload = File(capsule.encPath);
    final manifest = File(capsule.manifestPath);
    try {
      final file = await cryptoService.decryptCapsuleToTemp(
        payloadFile: payload,
        manifestFile: manifest,
      );
      return OpenResult(opened: true, decryptedFile: file);
    } catch (e) {
      return OpenResult(
        opened: false,
        error: TimeCapsuleError('DECRYPT_FAIL', e.toString()),
      );
    }
  }
}
