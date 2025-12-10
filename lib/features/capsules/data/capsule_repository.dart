import 'dart:io';

import 'package:path/path.dart' as p;

import 'models/capsule.dart';
import 'models/errors.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/time/time_service.dart';
import 'package:time_capsule/core/storage/file_store.dart';

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
  final FileStore fileStore;

  CapsuleRepositoryImpl({
    required this.cryptoService,
    required this.timeService,
    FileStore? fileStore,
  }) : fileStore = fileStore ?? FileStoreImpl();

  int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  String? _asString(Object? v) => v is String ? v : null;

  @override
  Future<List<Capsule>> listCapsules() async {
    // 先用“扫描本地 manifest.json”的方式实现（后续接 SQLite 再替换）
    final manifests = await fileStore.listAllManifestFiles();
    final items = <Capsule>[];

    for (final mf in manifests) {
      try {
        final m = await fileStore.readManifest(mf);

        final id = _asString(m['id']) ?? p.basename(p.dirname(mf.path));
        final title = _asString(m['title']) ?? id;
        final origFilename = _asString(m['origFilename']) ?? 'unknown.bin';
        final mime = _asString(m['mime']);

        final createdAtUtcMs =
            _asInt(m['createdAtUtcMs']) ??
            (await mf.lastModified()).toUtc().millisecondsSinceEpoch;

        final unlockAtUtcMs = _asInt(m['unlockAtUtcMs']) ?? createdAtUtcMs;

        final origSize = _asInt(m['origSize']);

        // payload 路径：优先从 manifest.payload.path 读取（相对路径）
        String relPayload = 'payload.enc';
        final payloadObj = m['payload'];
        if (payloadObj is Map) {
          final pp = payloadObj['path'];
          if (pp is String && pp.isNotEmpty) relPayload = pp;
        }
        final encPath = p.normalize(p.join(p.dirname(mf.path), relPayload));

        // 状态字段若没有则默认 locked(0)。后续接 SQLite 再做更精细的状态管理
        final status = _asInt(m['status']) ?? 0;

        final lastTimeCheckUtcMs = _asInt(m['lastTimeCheckUtcMs']);
        final lastTimeSource = _asString(m['lastTimeSource']);

        items.add(
          Capsule(
            id: id,
            title: title,
            origFilename: origFilename,
            mime: mime,
            createdAtUtcMs: createdAtUtcMs,
            unlockAtUtcMs: unlockAtUtcMs,
            origSize: origSize,
            encPath: encPath,
            manifestPath: mf.path,
            status: status,
            lastTimeCheckUtcMs: lastTimeCheckUtcMs,
            lastTimeSource: lastTimeSource,
          ),
        );
      } catch (_) {
        // 单个胶囊坏了不影响整体列表；后续你可以在这里打日志并标记 corrupted
        continue;
      }
    }

    // 按创建时间倒序展示
    items.sort((a, b) => b.createdAtUtcMs.compareTo(a.createdAtUtcMs));
    return items;
  }

  @override
  Future<Capsule> createCapsuleFromFile(File src, CapsuleParams params) async {
    final res = await cryptoService.createCapsuleFromFile(src, params);
    // TODO: persist to SQLite（后续实现）
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
