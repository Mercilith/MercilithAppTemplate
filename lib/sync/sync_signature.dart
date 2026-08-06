import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Signs bytes with an Ed25519 private key — see `SyncKey`'s doc comment
/// for why this exists alongside AES-GCM encryption: encryption alone
/// can't attribute a message to *which* holder of a shared secret produced
/// it, only that it was produced by someone who has the secret. Only the
/// device that called `SyncKey.generate` ever holds the matching private
/// key (`GeneratedSyncKey.signingPrivateKeySeed`), so a valid signature
/// means "the device that created this connection," not just "some paired
/// device."
class SyncSigner {
  SyncSigner._(this._keyPair);

  final SimpleKeyPair _keyPair;

  static Future<SyncSigner> fromSeed(Uint8List privateKeySeed) async {
    final keyPair = await Ed25519().newKeyPairFromSeed(privateKeySeed);
    return SyncSigner._(keyPair);
  }

  Future<Uint8List> sign(Uint8List message) async {
    final signature = await Ed25519().sign(message, keyPair: _keyPair);
    return Uint8List.fromList(signature.bytes);
  }
}

/// Verifies a signature produced by [SyncSigner] against a known public
/// key (`SyncKey.signingPublicKey`) — every paired device can construct
/// one of these (the public key is shared openly, embedded in the encoded
/// key), but only the original creator can produce a signature that
/// verifies against it.
class SyncVerifier {
  SyncVerifier(Uint8List publicKeyBytes)
    : _publicKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);

  final SimplePublicKey _publicKey;

  /// Returns `false` (never throws) for a malformed or mismatched
  /// signature — expected, ordinary outcomes on a shared public broker
  /// topic, not something callers need to special-case with a try/catch.
  Future<bool> verify(Uint8List message, Uint8List signatureBytes) async {
    try {
      return await Ed25519().verify(
        message,
        signature: Signature(signatureBytes, publicKey: _publicKey),
      );
    } catch (_) {
      return false;
    }
  }
}
