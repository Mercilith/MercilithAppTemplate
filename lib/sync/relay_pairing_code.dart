import 'dart:typed_data';

import 'base32_crockford.dart';

/// A pairing code exported from MclHost-Core's "Show pairing code" GUI
/// action ("Show pairing code" on a `User`), decoded here on the consuming
/// app's side. MclHost-Core owns the *encoder*; this package only ever
/// decodes.
///
/// Wire format (per MclHost-Core, 2026-08-25):
/// ```
/// bytes = userId (16 raw bytes) ++ relaySecretKey (32 raw bytes)  // 48 bytes, id first
/// code  = Crockford Base32 of bytes, alphabet
///         "0123456789ABCDEFGHJKMNPQRSTVWXYZ", 5 bits/char MSB-first, no
///         padding character, final partial group zero-padded on low bits
///         — always 77 uppercase characters for this 48-byte payload.
/// ```
///
/// Decoding deliberately reuses [base32CrockfordDecode] — the same decoder
/// [SyncKey]'s own pairing codes use (case-insensitive, tolerates `-`/space
/// separators for manual entry) — rather than a second, stricter decoder,
/// so the manual-entry UX is consistent across both kinds of code.
/// MclHost-Core's encoder does *not* apply Crockford's I/L->1, O->0
/// typo-substitution when producing a code; this decoder doesn't apply it
/// either, matching that (same behavior [SyncKey.parse] already has).
class RelayPairingCode {
  RelayPairingCode({required this.userId, required this.relaySecretKey})
    : assert(userId.length == userIdLength, 'userId must be $userIdLength bytes'),
      assert(
        relaySecretKey.length == relaySecretKeyLength,
        'relaySecretKey must be $relaySecretKeyLength bytes',
      );

  static const int userIdLength = 16;
  static const int relaySecretKeyLength = 32;
  static const int _totalLength = userIdLength + relaySecretKeyLength;

  final Uint8List userId;

  /// Feeds directly into [SyncKey.withRelaySecretKey].
  final Uint8List relaySecretKey;

  /// Lowercase hex form of [userId], for display only (e.g. "paired with
  /// user 0a1b2c..."). The relay channel itself is derived purely from
  /// [relaySecretKey] (see `SyncKey.relayChannelForSlot`) — this never
  /// feeds into any cryptographic derivation.
  String get userIdHex =>
      userId.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Throws [FormatException] if [code] doesn't decode to exactly
  /// [_totalLength] bytes (48).
  factory RelayPairingCode.parse(String code) {
    final bytes = base32CrockfordDecode(code);
    if (bytes.length != _totalLength) {
      throw FormatException(
        'MclHost relay pairing code has the wrong length (expected '
        '$_totalLength bytes, got ${bytes.length}).',
      );
    }
    return RelayPairingCode(
      userId: Uint8List.sublistView(bytes, 0, userIdLength),
      relaySecretKey: Uint8List.sublistView(bytes, userIdLength, _totalLength),
    );
  }
}
