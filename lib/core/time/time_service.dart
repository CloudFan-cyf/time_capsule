import 'dart:async';
import 'dart:io';

import '../../features/capsules/data/models/network_time.dart';

abstract class TimeService {
  Future<NetworkTimeResult> getTrustedNowUtc();
  Future<bool> canOpen({required int unlockAtUtcMs});
  Duration get cacheTtl;
}

class TimeSyncException implements Exception {
  final String message;
  TimeSyncException(this.message);

  @override
  String toString() => 'TimeSyncException: $message';
}

/// 可信在线时间证明（Trusted Online Time Attestation）
///
/// - 只使用 HTTPS（TLS）来源：读取 HTTP Date 头（UTC/GMT）
/// - 通过多源一致性（quorum-ish）降低单点伪造风险
class TimeServiceImpl implements TimeService {
  TimeServiceImpl({
    Duration? httpsTimeout,
    Duration? cacheTtl,
    Duration? maxSkewBetweenHttpsSources,
  }) : _httpsTimeout = httpsTimeout ?? const Duration(seconds: 3),
       _cacheTtl = cacheTtl ?? const Duration(seconds: 20),
       _maxSkew = maxSkewBetweenHttpsSources ?? const Duration(seconds: 10);

  final Duration _httpsTimeout;
  final Duration _cacheTtl;

  /// 多个 HTTPS 源同时成功时，允许的最大偏差窗口
  final Duration _maxSkew;
  @override
  Duration get cacheTtl => _cacheTtl;

  NetworkTimeResult? _cache;
  DateTime? _cacheAtUtc;

  /// HTTPS Date header sources (CN + international).
  /// 这些站点通常在大陆/国际都可访问（但仍可能受网络环境影响）。
  static final List<Uri> _httpsUris = [
    Uri.parse('https://www.baidu.com/'),
    Uri.parse('https://www.qq.com/'),
    Uri.parse('https://www.aliyun.com/'),
    Uri.parse('https://www.cloudflare.com/'),
    Uri.parse('https://www.microsoft.com/'),
    Uri.parse('https://www.apple.com/'),
  ];

  final List<String> _lastErrors = [];

  @override
  Future<NetworkTimeResult> getTrustedNowUtc() async {
    // cache
    final c = _cache;
    final at = _cacheAtUtc;
    if (c != null && at != null) {
      final age = DateTime.now().toUtc().difference(at);
      if (age >= Duration.zero && age <= _cacheTtl) {
        return c;
      }
    }

    _lastErrors.clear();

    // 并行请求所有 HTTPS 源，收集成功项
    final futures = _httpsUris.map((u) => _tryHttps(u));
    final results = await Future.wait<NetworkTimeResult?>(futures);

    final ok = results.whereType<NetworkTimeResult>().toList();
    if (ok.isEmpty) {
      throw TimeSyncException(
        'HTTPS time attestation failed. '
        'Errors: ${_lastErrors.join(' | ')}',
      );
    }

    // 选择可信时间：优先找“至少 2 个源在 _maxSkew 内一致”的最大簇
    final chosen = _chooseByMaxCluster(ok, _maxSkew);

    _cache = chosen;
    _cacheAtUtc = DateTime.now().toUtc();
    return chosen;
  }

  @override
  Future<bool> canOpen({required int unlockAtUtcMs}) async {
    try {
      final res = await getTrustedNowUtc();
      return res.nowUtc.millisecondsSinceEpoch >= unlockAtUtcMs;
    } catch (_) {
      // 无法拿到可信在线时间 -> 不允许解锁（防止本地时间篡改绕过）
      return false;
    }
  }

  // -------- HTTPS single source --------

  Future<NetworkTimeResult?> _tryHttps(Uri uri) async {
    try {
      final dt = await _fetchHttpsDate(uri).timeout(_httpsTimeout);
      // source 里带 host，方便 UI/debug
      return NetworkTimeResult(nowUtc: dt, source: 'HTTPS:${uri.host}');
    } catch (e) {
      _lastErrors.add('${uri.host}: $e');
      return null;
    }
  }

  Future<DateTime> _fetchHttpsDate(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = _httpsTimeout
      ..userAgent = 'TimeCapsule/1.0';

    final sw = Stopwatch()..start();

    HttpClientResponse resp;
    try {
      // 优先 HEAD（省流量），若不支持再退回 GET
      try {
        final req = await client.headUrl(uri);
        req.followRedirects = true;
        req.maxRedirects = 5;
        resp = await req.close();
      } catch (_) {
        final req = await client.getUrl(uri);
        req.followRedirects = true;
        req.maxRedirects = 5;
        resp = await req.close();
      }

      sw.stop();

      final dateStr = resp.headers.value(HttpHeaders.dateHeader);
      await resp.drain(); // 确保关闭响应流

      if (dateStr == null || dateStr.isEmpty) {
        throw TimeSyncException('No Date header from ${uri.host}');
      }

      final serverUtc = HttpDate.parse(dateStr).toUtc();

      // 简单 RTT/2 延迟补偿
      final adjust = Duration(microseconds: sw.elapsedMicroseconds ~/ 2);
      return serverUtc.add(adjust);
    } finally {
      client.close(force: true);
    }
  }

  // -------- choose best by cluster --------

  /// 从多个时间结果中选“最大一致簇”，并返回该簇内的最小时间（更保守，防止提前解锁）。
  NetworkTimeResult _chooseByMaxCluster(
    List<NetworkTimeResult> items,
    Duration maxSkew,
  ) {
    // 按时间升序
    items.sort((a, b) => a.nowUtc.compareTo(b.nowUtc));

    // 滑动窗口找最大簇：窗口内最大-最小 <= maxSkew
    var bestStart = 0;
    var bestEnd = 0; // inclusive
    var i = 0;

    for (var j = 0; j < items.length; j++) {
      while (items[j].nowUtc.difference(items[i].nowUtc) > maxSkew) {
        i++;
      }
      // 当前窗口 [i, j]
      final size = j - i + 1;
      final bestSize = bestEnd - bestStart + 1;
      if (size > bestSize) {
        bestStart = i;
        bestEnd = j;
      }
    }

    final bestSize = bestEnd - bestStart + 1;

    if (bestSize >= 2) {
      // 簇内取最小时间：更保守（避免被伪造到未来）
      return items[bestStart];
    }

    // 只有一个源成功：退化为单点（可用性优先）
    // 为了安全，你也可以改成：bestSize<2 直接抛错。
    return items.first;
  }
}
