import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../features/capsules/data/models/network_time.dart';

abstract class TimeService {
  Future<NetworkTimeResult> getTrustedNowUtc();
  Future<bool> canOpen({required int unlockAtUtcMs});
}

class TimeSyncException implements Exception {
  final String message;
  TimeSyncException(this.message);

  @override
  String toString() => 'TimeSyncException: $message';
}

class TimeServiceImpl implements TimeService {
  TimeServiceImpl({
    Duration? ntpTimeout,
    Duration? httpsTimeout,
    Duration? cacheTtl,
    Duration? maxSkewBetweenSources,
  }) : _ntpTimeout = ntpTimeout ?? const Duration(seconds: 2),
       _httpsTimeout = httpsTimeout ?? const Duration(seconds: 3),
       _cacheTtl = cacheTtl ?? const Duration(seconds: 20),
       _maxSkew = maxSkewBetweenSources ?? const Duration(seconds: 10);

  final Duration _ntpTimeout;
  final Duration _httpsTimeout;
  final Duration _cacheTtl;

  /// NTP 与 HTTPS 同时成功时，如果两者相差超过该阈值，则更偏向 HTTPS（TLS）
  final Duration _maxSkew;

  NetworkTimeResult? _cache;
  DateTime? _cacheAtUtc;

  // -------- Sources --------

  // Tencent public NTP servers (good in China + global)
  // NTP Pool for China / Global
  static const List<String> _ntpHosts = [
    'ntp.tencent.com',
    'ntp1.tencent.com',
    'cn.pool.ntp.org',
    'pool.ntp.org',
    'asia.pool.ntp.org',
    'time.apple.com',
    'time.windows.com',
  ];

  // HTTPS Date header sources (mix CN + international)
  static final List<Uri> _httpsUris = [
    Uri.parse('https://www.baidu.com/'),
    Uri.parse('https://www.qq.com/'),
    Uri.parse('https://www.aliyun.com/'),
    Uri.parse('https://www.cloudflare.com/'),
    Uri.parse('https://www.microsoft.com/'),
    Uri.parse('https://www.apple.com/'),
  ];

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

    // ✅ 关键：让 future 的类型变成 NetworkTimeResult?，这样 catchError 返回 null 合法
    final Future<NetworkTimeResult?> ntpFuture = _getNtpNowUtc()
        .timeout(_ntpTimeout)
        .then<NetworkTimeResult?>(
          (dt) => NetworkTimeResult(nowUtc: dt, source: 'NTP'),
        )
        .catchError((_) => null);

    final Future<NetworkTimeResult?> httpsFuture = _getHttpsNowUtc()
        .timeout(_httpsTimeout)
        .then<NetworkTimeResult?>(
          (dt) => NetworkTimeResult(nowUtc: dt, source: 'HTTPS'),
        )
        .catchError((_) => null);

    // ✅ Future.wait 也指定泛型，避免推断成 dynamic
    final results = await Future.wait<NetworkTimeResult?>([
      ntpFuture,
      httpsFuture,
    ]);

    final ntpRes = results[0];
    final httpsRes = results[1];

    NetworkTimeResult? chosen;

    if (ntpRes != null && httpsRes != null) {
      final diff = ntpRes.nowUtc.difference(httpsRes.nowUtc).abs();
      chosen = diff <= _maxSkew ? ntpRes : httpsRes;
    } else {
      chosen = ntpRes ?? httpsRes;
    }

    if (chosen == null) {
      throw TimeSyncException(
        'Failed to obtain trusted time from both NTP and HTTPS.',
      );
    }

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
      // 无法联网校时 -> 不可信 -> 默认不能打开（防止本地时间被篡改绕过）
      return false;
    }
  }

  // -------- HTTPS Date strategy --------

  Future<DateTime> _getHttpsNowUtc() async {
    final futures = _httpsUris.map(
      (u) => _fetchHttpsDate(u).timeout(_httpsTimeout),
    );
    return _firstSuccessful<DateTime>(futures);
  }

  Future<DateTime> _fetchHttpsDate(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = _httpsTimeout
      ..userAgent = 'TimeCapsule/1.0';

    final sw = Stopwatch()..start();

    HttpClientResponse resp;
    try {
      // 优先 HEAD（省流量），若 405/不支持，再退回 GET
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

      // HTTP Date 是 GMT/UTC，可用 dart:io 的 HttpDate.parse 解析
      final serverUtc = HttpDate.parse(dateStr).toUtc();

      // 用半个 RTT 做简单延迟补偿
      final adjust = Duration(microseconds: sw.elapsedMicroseconds ~/ 2);
      return serverUtc.add(adjust);
    } finally {
      client.close(force: true);
    }
  }

  // -------- NTP strategy --------

  static const int _ntpEpochOffsetSeconds = 2208988800; // 1900->1970
  static const int _ntpPacketSize = 48;

  Future<DateTime> _getNtpNowUtc() async {
    // 逐个 host 并行发起，取第一个成功的
    final futures = _ntpHosts.map((h) => _fetchNtpTime(h).timeout(_ntpTimeout));
    return _firstSuccessful<DateTime>(futures);
  }

  Future<DateTime> _fetchNtpTime(String host) async {
    final addresses = await InternetAddress.lookup(host);
    if (addresses.isEmpty) {
      throw TimeSyncException('NTP DNS lookup failed: $host');
    }

    final addr = addresses.first;
    final socket = await RawDatagramSocket.bind(
      addr.type == InternetAddressType.IPv6
          ? InternetAddress.anyIPv6
          : InternetAddress.anyIPv4,
      0,
    );

    try {
      final request = Uint8List(_ntpPacketSize);
      request[0] = 0x1B; // LI=0, VN=3, Mode=3 (client)

      // 填一个 transmit timestamp（非必须，但规范一些）
      final now = DateTime.now().toUtc();
      _writeNtpTimestamp(request, 40, now);

      final sw = Stopwatch()..start();
      socket.send(request, addr, 123);

      final completer = Completer<Datagram>();
      late StreamSubscription sub;

      sub = socket.listen((_) {
        final dg = socket.receive();
        if (dg != null && dg.data.length >= _ntpPacketSize) {
          if (!completer.isCompleted) completer.complete(dg);
          sub.cancel();
        }
      });

      final dg = await completer.future;
      sw.stop();

      final data = dg.data;
      final serverTransmitUtc = _readNtpTimestamp(data, 40);

      // 用半 RTT 补偿（避免依赖本地系统时间精确性）
      final adjust = Duration(microseconds: sw.elapsedMicroseconds ~/ 2);
      return serverTransmitUtc.add(adjust);
    } finally {
      socket.close();
    }
  }

  void _writeNtpTimestamp(Uint8List buf, int offset, DateTime utc) {
    final ms = utc.millisecondsSinceEpoch;
    final seconds = (ms ~/ 1000) + _ntpEpochOffsetSeconds;
    final fracMs = ms % 1000;
    final fraction = ((fracMs / 1000.0) * 0x100000000).floor(); // 2^32

    final bd = ByteData.sublistView(buf);
    bd.setUint32(offset, seconds, Endian.big);
    bd.setUint32(offset + 4, fraction, Endian.big);
  }

  DateTime _readNtpTimestamp(Uint8List buf, int offset) {
    final bd = ByteData.sublistView(buf);
    final seconds = bd.getUint32(offset, Endian.big);
    final fraction = bd.getUint32(offset + 4, Endian.big);

    final unixSeconds = seconds - _ntpEpochOffsetSeconds;
    final micros =
        (unixSeconds * 1000000) + ((fraction * 1000000) ~/ 0x100000000);

    return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
  }

  // -------- util: first success --------

  Future<T> _firstSuccessful<T>(Iterable<Future<T>> futures) {
    final list = futures.toList();
    if (list.isEmpty) {
      return Future.error(TimeSyncException('No candidates'));
    }

    final completer = Completer<T>();
    var remaining = list.length;
    final errors = <Object>[];

    for (final f in list) {
      f
          .then((value) {
            if (!completer.isCompleted) completer.complete(value);
          })
          .catchError((e) {
            errors.add(e);
            remaining -= 1;
            if (remaining == 0 && !completer.isCompleted) {
              completer.completeError(
                TimeSyncException('All candidates failed: $errors'),
              );
            }
          });
    }

    return completer.future;
  }
}
