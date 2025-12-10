import '../models/network_time.dart';

abstract class TimeService {
  Future<NetworkTimeResult> getTrustedNowUtc();
  Future<bool> canOpen({required int unlockAtUtcMs});
}

class TimeServiceImpl implements TimeService {
  @override
  Future<NetworkTimeResult> getTrustedNowUtc() async {
    // TODO: NTP + HTTPS Date strategy
    return NetworkTimeResult(nowUtc: DateTime.now().toUtc(), source: 'LOCAL');
  }

  @override
  Future<bool> canOpen({required int unlockAtUtcMs}) async {
    final res = await getTrustedNowUtc();
    return res.nowUtc.millisecondsSinceEpoch >= unlockAtUtcMs;
  }
}
