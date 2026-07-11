import 'dart:convert';

/// Message types exchanged over the live-sync WebSocket.
class SyncType {
  SyncType._();

  static const String snapshot = 'snapshot';
  static const String entityUpsert = 'entity_upsert';
  static const String entityDelete = 'entity_delete';
  static const String collection = 'collection';
  static const String ping = 'ping';
  static const String pong = 'pong';

  // Rupos dine-in aliases (backward compatible wire format).
  static const String orderUpsert = 'order_upsert';
  static const String orderDelete = 'order_delete';
  static const String tables = 'tables';
}

/// One envelope on the wire.
class SyncMessage {
  SyncMessage({
    required this.type,
    required this.origin,
    this.id,
    this.data,
    int? ts,
  }) : ts = ts ?? DateTime.now().millisecondsSinceEpoch;

  final String type;
  final String origin;
  final String? id;
  final dynamic data;
  final int ts;

  Map<String, dynamic> toMap() => {
        't': type,
        'o': origin,
        if (id != null) 'id': id,
        'ts': ts,
        if (data != null) 'd': data,
      };

  String encode() => jsonEncode(toMap());

  static SyncMessage? tryDecode(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      return SyncMessage(
        type: m['t']?.toString() ?? '',
        origin: m['o']?.toString() ?? '',
        id: m['id']?.toString(),
        data: m['d'],
        ts: (m['ts'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}
