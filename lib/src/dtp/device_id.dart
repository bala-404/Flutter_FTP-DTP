import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Stable per-install device id for echo suppression and last-write-wins.
class DeviceId {
  DeviceId._();

  static const String _defaultKey = 'ftp_dtp_device_id';
  static String? _cached;
  static String _storageKey = _defaultKey;

  /// Configure a custom SharedPreferences key before [ensure].
  static void configure({String storageKey = _defaultKey}) {
    _storageKey = storageKey;
  }

  static String get value => _cached ?? 'dev_unknown';

  static Future<String> ensure() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_storageKey);
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }
    final generated =
        'dev_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
    await prefs.setString(_storageKey, generated);
    _cached = generated;
    return generated;
  }
}
