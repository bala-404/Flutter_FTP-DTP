import 'dart:convert';

/// Connection details parsed from a scanned QR code or entered manually.
class ShareTarget {
  ShareTarget({
    required this.ip,
    required this.port,
    required this.token,
    this.label = '',
    this.path = '/data.json',
    this.mode = 'share',
  });

  final String ip;
  final int port;
  final String token;
  final String label;
  final String path;
  final String mode;

  factory ShareTarget.fromQr(String raw) {
    final map = jsonDecode(raw);
    if (map is! Map) {
      throw const ShareException('Unrecognized QR code.');
    }
    final ip = map['ip']?.toString();
    final port = (map['port'] as num?)?.toInt();
    final token = map['token']?.toString();
    if (ip == null || ip.isEmpty || port == null || token == null) {
      throw const ShareException('QR code is missing connection details.');
    }
    return ShareTarget(
      ip: ip,
      port: port,
      token: token,
      label: map['label']?.toString() ?? map['store']?.toString() ?? '',
      path: map['path']?.toString() ?? '/data.json',
      mode: map['mode']?.toString() ?? 'share',
    );
  }

  String toQrPayload({
    String? ip,
    required int port,
    int schemaVersion = 1,
  }) =>
      jsonEncode({
        'v': schemaVersion,
        'ip': ip,
        'port': port,
        'token': token,
        if (label.isNotEmpty) 'label': label,
        'path': path,
        'mode': mode,
      });
}

class ShareException implements Exception {
  const ShareException(this.message);
  final String message;
  @override
  String toString() => message;
}
