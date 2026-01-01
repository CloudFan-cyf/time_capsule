import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'models/capsule.dart';
import 'models/errors.dart';
import 'package:flutter/services.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/time/time_service.dart';
import 'package:time_capsule/core/storage/file_store.dart';

abstract class CapsuleRepository {
  Future<List<Capsule>> listCapsules();

  /// 旧版单文件创建（兼容）
  Future<Capsule> createCapsuleFromFile(
    File src,
    CapsuleParams params, {
    CryptoProgressCallback? onProgress,
  });

  /// 新版多文件创建
  Future<Capsule> createCapsuleFromFiles(
    List<File> srcFiles,
    CapsuleParams params, {
    CryptoProgressCallback? onProgress,
    bool deleteSourceFiles = false,
    List<String> sourceUris, // ✅ 新增
  });

  Future<OpenResult> openCapsule(
    Capsule capsule, {
    CryptoProgressCallback? onDecryptProgress,
  });

  Future<void> saveCustomOrder(List<String> orderedIds);
  Future<void> deleteCapsule(Capsule capsule);
}

class OpenResult {
  final bool opened;
  final List<File> files;
  final TimeCapsuleError? error;

  File? get firstFile => files.isNotEmpty ? files.first : null;

  OpenResult({required this.opened, required this.files, this.error});
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
  static const MethodChannel _fileOps = MethodChannel('time_capsule/file_ops');

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

    // ---------------- 应用用户自定义 order ----------------
    final order = await fileStore.getCapsuleOrder(); // List<String>

    // 建索引：id -> Capsule
    final byId = <String, Capsule>{for (final c in items) c.id: c};

    // 1) 先按 order 把能匹配到的取出来
    final ordered = <Capsule>[];
    final cleanedOrder = <String>[]; // 顺便清理掉不存在的 id，防止 order 越积越脏

    for (final id in order) {
      final c = byId.remove(id);
      if (c != null) {
        ordered.add(c);
        cleanedOrder.add(id);
      }
    }

    // 2) 剩余未在 order 中的胶囊，按创建时间倒序
    final rest = byId.values.toList()
      ..sort((a, b) => b.createdAtUtcMs.compareTo(a.createdAtUtcMs));

    // 3) 可选：如果 order 被清理了（比如用户删了胶囊），回写一次
    if (cleanedOrder.length != order.length) {
      await fileStore.setCapsuleOrder(cleanedOrder);
    }

    return [...ordered, ...rest];
  }

  @override
  Future<Capsule> createCapsuleFromFile(
    File src,
    CapsuleParams params, {
    CryptoProgressCallback? onProgress,
  }) async {
    // 透传进度回调
    final res = await cryptoService.createCapsuleFromFile(src, params);
    // TODO: persist to SQLite
    return res.capsule;
  }

  @override
  Future<Capsule> createCapsuleFromFiles(
    List<File> srcFiles,
    CapsuleParams params, {
    CryptoProgressCallback? onProgress,
    bool deleteSourceFiles = false,
    List<String> sourceUris = const [],
  }) async {
    final res = await cryptoService.createCapsuleFromFiles(
      srcFiles,
      params,
      onProgress: onProgress,
    );

    if (deleteSourceFiles) {
      if (!kIsWeb && Platform.isAndroid) {
        // ✅ Android: 只发起一次删除请求，避免 BUSY
        final uris = sourceUris
            .where((u) => u.startsWith('content://'))
            .toList();
        if (kDebugMode) {
          debugPrint('[deleteSource] android uris=${uris.length}');
        }
        if (uris.isNotEmpty) {
          try {
            await _fileOps.invokeMethod('deleteUris', {'uris': uris});
          } on PlatformException catch (e) {
            if (kDebugMode) {
              debugPrint('[deleteSource] android channel failed: $e');
            }
          }
        } else {
          // 兜底：如果没有 uri（比如来自 file_picker cache path），就按路径删（可能只删缓存）
          for (final f in srcFiles) {
            try {
              if (await f.exists()) await f.delete();
            } catch (e) {
              if (kDebugMode) {
                debugPrint(
                  '[deleteSource] android path delete failed: ${f.path} err=$e',
                );
              }
            }
          }
        }
      } else {
        // ✅ Windows / macOS / Linux：路径删除
        for (final f in srcFiles) {
          final path = f.path;
          final ex = await f.exists();
          if (kDebugMode) {
            debugPrint('[deleteSource] path=$path exists=$ex');
          }
          if (!ex) continue;
          try {
            await f.delete();
            if (kDebugMode) debugPrint('[deleteSource] deleted: $path');
          } catch (e) {
            if (kDebugMode) debugPrint('[deleteSource] failed: $path err=$e');
          }
        }
      }
    }

    return res.capsule;
  }

  @override
  Future<OpenResult> openCapsule(
    Capsule capsule, {
    CryptoProgressCallback? onDecryptProgress,
  }) async {
    final ok = await timeService.canOpen(unlockAtUtcMs: capsule.unlockAtUtcMs);
    if (!ok) {
      return OpenResult(
        opened: false,
        files: const [],
        error: TimeCapsuleError('LOCKED', '未到解锁时间'),
      );
    }

    final manifest = File(capsule.manifestPath);
    try {
      // 透传解密进度回调
      final files = await cryptoService.ensureDecryptedFiles(
        manifestFile: manifest,
        onProgress: onDecryptProgress,
      );
      if (files.isEmpty) {
        return OpenResult(
          opened: false,
          files: const [],
          error: TimeCapsuleError('NO_FILES', '胶囊中没有可解密的文件'),
        );
      }
      return OpenResult(opened: true, files: files);
    } catch (e) {
      return OpenResult(
        opened: false,
        files: const [],
        error: TimeCapsuleError('DECRYPT_FAIL', e.toString()),
      );
    }
  }

  @override
  Future<void> saveCustomOrder(List<String> orderedIds) async {
    await fileStore.setCapsuleOrder(orderedIds);
  }

  @override
  Future<void> deleteCapsule(Capsule capsule) async {
    final dir = Directory(File(capsule.manifestPath).parent.path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    // 同时把顺序里删掉
    final order = await fileStore.getCapsuleOrder();
    order.remove(capsule.id);
    await fileStore.setCapsuleOrder(order);
  }
}
