import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../common/share_target.dart';
import '../common/token.dart';
import '../ftp/share_http_server.dart';
import 'device_id.dart';
import 'sync_message.dart';
import 'sync_ws_server.dart';

enum SyncRole { none, host, client }

enum SyncConnectionStatus { idle, hosting, connecting, connected, error }

/// Host connection info shown to the user (QR/manual pairing).
class SyncHostInfo {
  SyncHostInfo({
    required this.ip,
    required this.port,
    required this.token,
    this.path = '/sync',
  });

  final String? ip;
  final int port;
  final String token;
  final String path;

  String get qrPayload => jsonEncode({
        'ip': ip,
        'port': port,
        'token': token,
        'path': path,
        'mode': 'sync',
      });
}

/// Callbacks that wire the sync engine to your app's storage layer.
abstract class SyncAdapter {
  /// Build full state for a newly connected client.
  Future<Map<String, dynamic>> buildSnapshot();

  /// Apply a remote message to local storage (with echo suppression support).
  Future<void> applyRemote(SyncMessage message);

  /// Start watching local changes. Call [onLocalChange] when data changes locally.
  void startWatching(void Function(SyncMessage message) onLocalChange);

  /// Stop all watchers started by [startWatching].
  Future<void> stopWatching();
}

/// **DTP (Data Transfer Pattern)** — realtime LAN sync over WebSocket.
///
/// Replicated model: every device keeps a full local copy. The host relays
/// changes between clients. Local writes are watched and pushed; remote
/// messages are applied with echo suppression handled by the [SyncAdapter].
class RealtimeSyncEngine {
  RealtimeSyncEngine(this.adapter);

  final SyncAdapter adapter;

  SyncRole role = SyncRole.none;
  SyncConnectionStatus status = SyncConnectionStatus.idle;
  String? lastError;

  SyncWsServer? _server;
  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  ShareTarget? _clientTarget;
  bool _manualStop = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  void Function()? onChanged;

  bool get isHostSupported => SyncWsServer.isSupported;
  int get clientCount => _server?.clientCount ?? 0;
  bool get isActive => role != SyncRole.none;

  void _notify() {
    try {
      onChanged?.call();
    } catch (_) {}
  }

  void _setStatus(SyncConnectionStatus s, {String? error}) {
    status = s;
    lastError = error;
    _notify();
  }

  Future<SyncHostInfo> startHost({String syncPath = '/sync'}) async {
    await stop();
    await DeviceId.ensure();
    _manualStop = false;
    final token = generateShareToken();
    _server = await SyncWsServer.start(
      token: token,
      path: syncPath,
      onConnect: (socket) async {
        final snapshot = SyncMessage(
          type: SyncType.snapshot,
          origin: DeviceId.value,
          data: await adapter.buildSnapshot(),
        );
        socket.send(snapshot.encode());
        _notify();
      },
      onMessage: (socket, raw) async {
        final msg = SyncMessage.tryDecode(raw);
        if (msg == null) return;
        await adapter.applyRemote(msg);
        _server?.broadcast(raw, except: socket);
        _notify();
      },
      onDisconnect: (_) => _notify(),
    );
    role = SyncRole.host;
    adapter.startWatching(_dispatch);
    final ip = await resolveLocalIp();
    _setStatus(SyncConnectionStatus.hosting);
    return SyncHostInfo(ip: ip, port: _server!.port, token: token, path: syncPath);
  }

  Future<void> joinAsClient(ShareTarget target) async {
    await stop();
    await DeviceId.ensure();
    _manualStop = false;
    _clientTarget = target;
    _reconnectAttempts = 0;
    role = SyncRole.client;
    adapter.startWatching(_dispatch);
    await _connectClient();
  }

  Future<void> _connectClient() async {
    final target = _clientTarget;
    if (target == null) return;
    _setStatus(SyncConnectionStatus.connecting);
    try {
      final path = target.path.isNotEmpty ? target.path : '/sync';
      final uri =
          Uri.parse('ws://${target.ip}:${target.port}$path?token=${target.token}');
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _channelSub = channel.stream.listen(
        (data) async {
          _reconnectAttempts = 0;
          if (status != SyncConnectionStatus.connected) {
            _setStatus(SyncConnectionStatus.connected);
          }
          if (data is String) {
            final msg = SyncMessage.tryDecode(data);
            if (msg != null) {
              await adapter.applyRemote(msg);
              _notify();
            }
          }
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (e) {
      _setStatus(SyncConnectionStatus.error, error: 'Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_manualStop || role != SyncRole.client) return;
    _channelSub?.cancel();
    _channelSub = null;
    _channel = null;
    if (_reconnectAttempts >= 20) {
      _setStatus(SyncConnectionStatus.error, error: 'Lost connection to host.');
      return;
    }
    _reconnectAttempts++;
    final delay = Duration(seconds: (2 * _reconnectAttempts).clamp(2, 20));
    _setStatus(SyncConnectionStatus.connecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connectClient);
  }

  Future<void> stop() async {
    _manualStop = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await adapter.stopWatching();
    await _channelSub?.cancel();
    _channelSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    await _server?.stop();
    _server = null;
    role = SyncRole.none;
    _clientTarget = null;
    _setStatus(SyncConnectionStatus.idle);
  }

  void _dispatch(SyncMessage msg) {
    final raw = msg.encode();
    if (role == SyncRole.host) {
      _server?.broadcast(raw);
    } else if (role == SyncRole.client) {
      try {
        _channel?.sink.add(raw);
      } catch (_) {}
    }
  }

  /// Helper for adapters: create an entity upsert message.
  static SyncMessage entityUpsert({
    required String id,
    required Map<String, dynamic> data,
  }) =>
      SyncMessage(
        type: SyncType.entityUpsert,
        origin: DeviceId.value,
        id: id,
        data: data,
      );

  /// Helper for adapters: create an entity delete message.
  static SyncMessage entityDelete({required String id}) => SyncMessage(
        type: SyncType.entityDelete,
        origin: DeviceId.value,
        id: id,
      );

  /// Helper for adapters: create a collection replace message.
  static SyncMessage collectionReplace({required dynamic data}) => SyncMessage(
        type: SyncType.collection,
        origin: DeviceId.value,
        data: data,
      );

  /// Last-write-wins comparator for ISO date strings.
  static bool isNewer(String? a, String? b) {
    if (a == null) return false;
    if (b == null) return true;
    final da = DateTime.tryParse(a);
    final db = DateTime.tryParse(b);
    if (da == null || db == null) return false;
    return da.isAfter(db);
  }
}
