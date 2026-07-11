import 'dart:convert';

import 'package:http/http.dart' as http;

import '../common/share_target.dart';
import '../common/token.dart';
import 'share_http_server.dart';

/// Payload version. Bump if the export shape changes incompatibly.
const int kShareSchemaVersion = 1;

/// A live sharing session on the host device.
class ShareSession {
  ShareSession({
    required this.ip,
    required this.port,
    required this.token,
    required this.label,
    this.path = '/data.json',
  });

  final String? ip;
  final int port;
  final String token;
  final String label;
  final String path;

  String get downloadUrl => 'http://$ip:$port$path?token=$token';

  String get qrPayload => ShareTarget(
        ip: ip ?? '',
        port: port,
        token: token,
        label: label,
        path: path,
        mode: 'share',
      ).toQrPayload(ip: ip, port: port, schemaVersion: kShareSchemaVersion);
}

/// Result of an import, for confirmation UI.
class ImportSummary {
  ImportSummary({
    required this.itemCount,
    this.label = '',
    this.extra = const {},
  });

  final int itemCount;
  final String label;
  final Map<String, dynamic> extra;
}

/// Exports/imports JSON data between devices over the local Wi-Fi network.
///
/// **FTP (File Transfer Pattern)** — one-shot HTTP GET of a token-gated JSON
/// payload. The host runs a temporary LAN server; receivers scan a QR or enter
/// IP + port + token manually.
class LocalFileShareService {
  LocalFileShareService({
    required this.buildExport,
    required this.importExport,
    this.canImport,
    this.dataPath = '/data.json',
    this.label = '',
  });

  /// Build the JSON export from local storage.
  final Map<String, dynamic> Function() buildExport;

  /// Apply the downloaded export to local storage.
  final Future<ImportSummary> Function(Map<String, dynamic> json) importExport;

  /// Optional guard — return false to block import (e.g. active sessions).
  final bool Function()? canImport;

  final String dataPath;
  final String label;

  ShareHttpServer? _server;

  bool get isSupported => ShareHttpServer.isSupported;

  bool canImportNow() => canImport?.call() ?? true;

  Future<ShareSession> startSharing({void Function()? onClientDownloaded}) async {
    await stopSharing();
    final token = generateShareToken();
    final export = buildExport();
    export['v'] = kShareSchemaVersion;
    export['exportedAt'] = DateTime.now().toUtc().toIso8601String();
    if (label.isNotEmpty) export['label'] = label;
    final body = jsonEncode(export);
    _server = await ShareHttpServer.start(
      body: body,
      token: token,
      path: dataPath,
      onDownloaded: onClientDownloaded,
    );
    final ip = await resolveLocalIp();
    return ShareSession(
      ip: ip,
      port: _server!.port,
      token: token,
      label: label,
      path: dataPath,
    );
  }

  Future<void> stopSharing() async {
    await _server?.stop();
    _server = null;
  }

  Future<Map<String, dynamic>> fetchExport(ShareTarget target) async {
    final path = target.path.isNotEmpty ? target.path : dataPath;
    final uri =
        Uri.parse('http://${target.ip}:${target.port}$path?token=${target.token}');
    late http.Response resp;
    try {
      resp = await http.get(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const ShareException(
          'Could not reach the host device. Make sure both devices are on '
          'the same Wi-Fi network.');
    }
    if (resp.statusCode == 403) {
      throw const ShareException('Invalid or expired token.');
    }
    if (resp.statusCode != 200) {
      throw ShareException('Host device returned ${resp.statusCode}.');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw const ShareException('The received data was malformed.');
    }
    return decoded.cast<String, dynamic>();
  }

  ImportSummary previewImport(Map<String, dynamic> json) {
    final items = (json['items'] as List?)?.length ??
        (json['records'] as List?)?.length ??
        (json['entities'] as List?)?.length ??
        0;
    return ImportSummary(
      itemCount: items,
      label: json['label']?.toString() ?? json['name']?.toString() ?? '',
      extra: Map<String, dynamic>.from(json)
        ..remove('items')
        ..remove('records')
        ..remove('entities'),
    );
  }

  Future<ImportSummary> importIntoStorage(Map<String, dynamic> json) async {
    return importExport(json);
  }
}
