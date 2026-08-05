import 'dart:math';

const String _hexChars = '0123456789abcdef';

/// A random UUIDv4-shaped id (RFC 4122 layout, version/variant bits set)
/// for stable cross-device row identity. Every syncable row a consuming
/// app writes locally gets one of these once, at creation, so devices that
/// each seed their own autoincrement `id` column independently still agree
/// on which row is which once they start exchanging [SyncEnvelope]s.
///
/// A dedicated helper (rather than the separate `uuid` package) keeps this
/// one small format decision shared by every consumer of this package
/// without adding a dependency neither the transport nor the crypto here
/// otherwise needs.
String generateSyncId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  // Version 4 (random) — top nibble of byte 6.
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  // Variant 1 (RFC 4122) — top two bits of byte 8.
  bytes[8] = (bytes[8] & 0x3F) | 0x80;

  String hex(int start, int end) {
    final buffer = StringBuffer();
    for (var i = start; i < end; i++) {
      buffer.write(_hexChars[(bytes[i] >> 4) & 0xF]);
      buffer.write(_hexChars[bytes[i] & 0xF]);
    }
    return buffer.toString();
  }

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
