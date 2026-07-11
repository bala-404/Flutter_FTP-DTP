import 'dart:math';

/// Generates a 6-character uppercase alphanumeric token (no ambiguous chars).
String generateShareToken() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rnd = Random.secure();
  return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
}
