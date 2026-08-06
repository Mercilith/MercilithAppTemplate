import 'dart:typed_data';

/// Wire framing that lets a receiver tell whether a message claims to be
/// signed *before* attempting verification: a 1-byte flag, an optional
/// fixed 64-byte Ed25519 signature (`SyncSigner`/`SyncVerifier`), then the
/// AES-GCM ciphertext (`SyncCrypto`). Signs/verifies over the ciphertext
/// (encrypt-then-sign) — this class knows nothing about encryption itself,
/// same separation of concerns as `SyncCrypto` vs `MqttSyncTransport`.
class SignedMessage {
  SignedMessage({required this.ciphertext, this.signature})
    : assert(
        signature == null || signature.length == signatureLength,
        'signature must be $signatureLength bytes when present',
      );

  static const int signatureLength = 64;

  final Uint8List ciphertext;

  /// Null when this message wasn't signed — expected for any device
  /// other than the connection's creator, which never holds a private
  /// signing key.
  final Uint8List? signature;

  Uint8List encode() {
    if (signature == null) {
      return Uint8List.fromList([0, ...ciphertext]);
    }
    return Uint8List.fromList([1, ...signature!, ...ciphertext]);
  }

  /// Throws [FormatException] on a malformed wire payload (unknown flag
  /// byte, or too short to hold the signature its flag claims).
  static SignedMessage decode(Uint8List wire) {
    if (wire.isEmpty) {
      throw const FormatException('Empty signed message.');
    }
    final flag = wire[0];
    if (flag == 0) {
      return SignedMessage(ciphertext: Uint8List.sublistView(wire, 1));
    }
    if (flag == 1) {
      if (wire.length < 1 + signatureLength) {
        throw const FormatException('Signed message truncated.');
      }
      return SignedMessage(
        signature: Uint8List.sublistView(wire, 1, 1 + signatureLength),
        ciphertext: Uint8List.sublistView(wire, 1 + signatureLength),
      );
    }
    throw FormatException('Unknown signed-message flag: $flag');
  }
}
