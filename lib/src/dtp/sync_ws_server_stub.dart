class SyncClientHandle {
  void send(String message) {}
}

class SyncWsServer {
  SyncWsServer._();

  static bool get isSupported => false;

  int get port => 0;
  int get clientCount => 0;

  static Future<SyncWsServer> start({
    required String token,
    String path = '/sync',
    required void Function(SyncClientHandle socket) onConnect,
    required void Function(SyncClientHandle socket, String message) onMessage,
    void Function(SyncClientHandle socket)? onDisconnect,
  }) async {
    throw UnsupportedError(
        'Hosting live sync is not supported on this platform.');
  }

  void broadcast(String message, {SyncClientHandle? except}) {}

  Future<void> stop() async {}
}
