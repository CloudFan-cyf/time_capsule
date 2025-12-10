class TimeCapsuleError implements Exception {
  final String code; // e.g. TIME_VERIFY_REQUIRED, LOCKED, ...
  final String message;
  TimeCapsuleError(this.code, this.message);

  @override
  String toString() => 'TimeCapsuleError($code): $message';
}
