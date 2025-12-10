import 'dart:typed_data';

class Capsule {
  final String id;
  final String title;
  final String origFilename;
  final String? mime;
  final int createdAtUtcMs;
  final int unlockAtUtcMs;
  final int? origSize;
  final String encPath;
  final String manifestPath;
  final int status; // 0/1/2 per spec
  final int? lastTimeCheckUtcMs;
  final String? lastTimeSource; // 'NTP' or 'HTTPS'

  Capsule({
    required this.id,
    required this.title,
    required this.origFilename,
    this.mime,
    required this.createdAtUtcMs,
    required this.unlockAtUtcMs,
    this.origSize,
    required this.encPath,
    required this.manifestPath,
    required this.status,
    this.lastTimeCheckUtcMs,
    this.lastTimeSource,
  });
}

class CapsuleParams {
  final String title;
  final int unlockAtUtcMs;

  CapsuleParams({required this.title, required this.unlockAtUtcMs});
}

class CapsuleCreateResult {
  final Capsule capsule;
  CapsuleCreateResult(this.capsule);
}
