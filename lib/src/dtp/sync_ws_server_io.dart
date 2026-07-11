import 'dart:io';

class SyncClientHandle {
  SyncClientHandle(this._socket);
  final WebSocket _socket;

  void send(String message) {
    try {
      _socket.add(message);
    } catch (_) {}
  }
}

/// Native (`dart:io`) live-sync WebSocket host.
class SyncWsServer {
  SyncWsServer._(this._server, this.port);

  final HttpServer _server;
  final int port;
  final Map<WebSocket, SyncClientHandle> _handles = {};

  static bool get isSupported => true;

  int get clientCount => _handles.length;

  static Future<SyncWsServer> start({
    required String token,
    String path = '/sync',
    required void Function(SyncClientHandle socket) onConnect,
    required void Function(SyncClientHandle socket, String message) onMessage,
    void Function(SyncClientHandle socket)? onDisconnect,
  }) async {
    final server = await _bind();
    final self = SyncWsServer._(server, server.port);
    server.listen((HttpRequest req) async {
      try {
        if (req.uri.path == '/ping') {
          req.response
            ..statusCode = HttpStatus.ok
            ..write('ok');
          await req.response.close();
          return;
        }
        if (req.uri.path != path) {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
          return;
        }
        if (req.uri.queryParameters['token'] != token) {
          req.response.statusCode = HttpStatus.forbidden;
          await req.response.close();
          return;
        }
        if (!WebSocketTransformer.isUpgradeRequest(req)) {
          req.response.statusCode = HttpStatus.badRequest;
          await req.response.close();
          return;
        }
        final ws = await WebSocketTransformer.upgrade(req);
        final handle = SyncClientHandle(ws);
        self._handles[ws] = handle;
        onConnect(handle);
        ws.listen(
          (data) {
            if (data is String) onMessage(handle, data);
          },
          onDone: () {
            self._handles.remove(ws);
            onDisconnect?.call(handle);
          },
          onError: (_) {
            self._handles.remove(ws);
            onDisconnect?.call(handle);
          },
          cancelOnError: true,
        );
      } catch (_) {
        try {
          await req.response.close();
        } catch (_) {}
      }
    });
    return self;
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

  void broadcast(String message, {SyncClientHandle? except}) {
    _handles.forEach((ws, handle) {
      if (except != null && identical(handle, except)) return;
      try {
        ws.add(message);
      } catch (_) {}
    });
  }

  Future<void> stop() async {
    for (final ws in _handles.keys.toList()) {
      try {
        await ws.close();
      } catch (_) {}
    }
    _handles.clear();
    await _server.close(force: true);
  }
}
