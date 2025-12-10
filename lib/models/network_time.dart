class NetworkTimeResult {
  final DateTime nowUtc;
  final String source; // 'NTP' | 'HTTPS'
  NetworkTimeResult({required this.nowUtc, required this.source});
}
