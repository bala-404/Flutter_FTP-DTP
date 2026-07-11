/// Cross-platform entry point for the LAN share HTTP server.
export 'share_http_server_stub.dart'
    if (dart.library.io) 'share_http_server_io.dart';
