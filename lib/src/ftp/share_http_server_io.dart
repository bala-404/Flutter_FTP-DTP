import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

/// Native (`dart:io`) implementation of the LAN share HTTP server.
///
/// Serves a single in-memory JSON payload over the local Wi-Fi network:
///   GET /data.json?token=XXXX  → the export (token-gated)
///   GET /ping                  → "ok" health check
class ShareHttpServer {
  ShareHttpServer._(this._server, this.port);

  final HttpServer _server;
  final int port;

  static bool get isSupported => true;

  static Future<ShareHttpServer> start({
    required String body,
    required String token,
    String path = '/data.json',
    void Function()? onDownloaded,
  }) async {
    final server = await _bind();
    final wrapper = ShareHttpServer._(server, server.port);
    server.listen((HttpRequest req) async {
      try {
        final res = req.response;
        res.headers.set('Access-Control-Allow-Origin', '*');
        final reqPath = req.uri.path;
        if (reqPath == '/ping') {
          res
            ..statusCode = HttpStatus.ok
            ..write('ok');
          await res.close();
          return;
        }
        if (reqPath == path) {
          if (req.uri.queryParameters['token'] != token) {
            res.statusCode = HttpStatus.forbidden;
            await res.close();
            return;
          }
          res
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(body);
          await res.close();
          onDownloaded?.call();
          return;
        }
        res.statusCode = HttpStatus.notFound;
        await res.close();
      } catch (_) {
        try {
          await req.response.close();
        } catch (_) {}
      }
    });
    return wrapper;
  }

  static Future<HttpServer> _bind() async {
    var port = 8080;
    while (true) {
      try {
        return await HttpServer.bind(InternetAddress.anyIPv4, port,
            shared: true);
      } on SocketException {
        port++;
        if (port > 8120) rethrow;
      }
    }
  }

  Future<void> stop() async {
    await _server.close(force: true);
  }
}

/// Best-effort LAN IPv4 lookup: Wi-Fi IP first (mobile), then the first
/// non-loopback interface address (desktop / ethernet).
Future<String?> resolveLocalIp() async {
  try {
    final ip = await NetworkInfo().getWifiIP();
    if (ip != null && ip.isNotEmpty && ip != '0.0.0.0') return ip;
  } catch (_) {}
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final ni in interfaces) {
      for (final addr in ni.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
  } catch (_) {}
  return null;
}
