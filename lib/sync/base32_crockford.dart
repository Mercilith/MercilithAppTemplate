import 'dart:typed_data';

/// Crockford's Base32 (https://www.crockford.com/base32.html) — chosen over
/// standard/hex Base32 for [SyncKey]'s text encoding because it excludes
/// visually-ambiguous characters (I, L, O, U) that are easy to mistype when
/// a key is copied by hand between devices. Internal to this package; not
/// exported from the barrel.
const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

String base32CrockfordEncode(Uint8List bytes) {
  final buffer = StringBuffer();
  int bitBuffer = 0;
  int bitsInBuffer = 0;
  for (final byte in bytes) {
    bitBuffer = (bitBuffer << 8) | byte;
    bitsInBuffer += 8;
    while (bitsInBuffer >= 5) {
      bitsInBuffer -= 5;
      buffer.write(_alphabet[(bitBuffer >> bitsInBuffer) & 0x1F]);
      bitBuffer &= (1 << bitsInBuffer) - 1;
    }
  }
  if (bitsInBuffer > 0) {
    buffer.write(_alphabet[(bitBuffer << (5 - bitsInBuffer)) & 0x1F]);
  }
  return buffer.toString();
}

/// Throws [FormatException] on any character outside the Crockford
/// alphabet. Case-insensitive; ignores `-` and spaces so keys can be
/// presented to users in hyphenated groups without breaking round-trips.
Uint8List base32CrockfordDecode(String input) {
  final normalized = input.toUpperCase().replaceAll(RegExp('[- ]'), '');
  int bitBuffer = 0;
  int bitsInBuffer = 0;
  final out = <int>[];
  for (var i = 0; i < normalized.length; i++) {
    final index = _alphabet.indexOf(normalized[i]);
    if (index == -1) {
      throw FormatException('Invalid character in sync key', normalized, i);
    }
    bitBuffer = (bitBuffer << 5) | index;
    bitsInBuffer += 5;
    if (bitsInBuffer >= 8) {
      bitsInBuffer -= 8;
      out.add((bitBuffer >> bitsInBuffer) & 0xFF);
      bitBuffer &= (1 << bitsInBuffer) - 1;
    }
  }
  return Uint8List.fromList(out);
}
