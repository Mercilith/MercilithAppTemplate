import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AEAD encryption/decryption for bytes published on a shared, untrusted
/// MQTT topic (see `MqttSyncTransport`'s doc comment — the broker itself
/// provides zero confidentiality). Every message this class produces is
/// self-contained: nonce, ciphertext, and authentication tag concatenated
/// into one blob, so the wire format needs no extra framing.
///
/// Pure-Dart (via the `cryptography` package's default implementation), so
/// this works identically on Android and Windows desktop with no native
/// code required.
class SyncCrypto {
  SyncCrypto(Uint8List secret) : _secretKey = SecretKey(secret);

  static final AesGcm _algorithm = AesGcm.with256bits();

  final SecretKey _secretKey;

  Future<Uint8List> encrypt(Uint8List plaintext) async {
    final box = await _algorithm.encrypt(plaintext, secretKey: _secretKey);
    return Uint8List.fromList([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  /// Throws [SecretBoxAuthenticationError] if [wireBytes] was tampered with
  /// or wasn't encrypted with this key — callers on a shared topic should
  /// treat that as "not meant for this connection" and drop the message
  /// rather than surface it as an error, since a wrong-key message is
  /// expected traffic (anyone can publish to a public broker's topic).
  Future<Uint8List> decrypt(Uint8List wireBytes) async {
    final nonceLength = _algorithm.nonceLength;
    final macLength = _algorithm.macAlgorithm.macLength;
    if (wireBytes.length < nonceLength + macLength) {
      throw const FormatException('Sync message too short to be valid.');
    }
    final nonce = wireBytes.sublist(0, nonceLength);
    final cipherText = wireBytes.sublist(
      nonceLength,
      wireBytes.length - macLength,
    );
    final mac = Mac(wireBytes.sublist(wireBytes.length - macLength));
    final plaintext = await _algorithm.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: _secretKey,
    );
    return Uint8List.fromList(plaintext);
  }
}
