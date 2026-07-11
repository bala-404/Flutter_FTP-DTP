/// Web / unsupported-platform stub for [ShareHttpServer].
class ShareHttpServer {
  ShareHttpServer._();

  static bool get isSupported => false;

  int get port => 0;

  static Future<ShareHttpServer> start({
    required String body,
    required String token,
    String path = '/data.json',
    void Function()? onDownloaded,
  }) async {
    throw UnsupportedError(
        'Local Wi-Fi sharing is not supported on this platform.');
  }

  Future<void> stop() async {}
}

Future<String?> resolveLocalIp() async => null;
