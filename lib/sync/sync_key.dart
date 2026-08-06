import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'base32_crockford.dart';
import 'sync_permission.dart';

/// A pairing key for cross-device sync. Generated on one device, copied by
/// hand (or however the app chooses to present it — text, QR, etc.) to
/// another device and added there. The key is the *only* secret in this
/// design — there is no server, no account, no broker-side access control
/// (see `MqttSyncTransport`'s doc comment) — so it does three jobs at once:
///
/// - [topicForSlot]/[currentTopic] (derived from [topicSeed]) is which MQTT
///   topic the paired devices talk on *right now* — the topic rotates every
///   [slotDuration] (30s), computed from the current UTC time, so it isn't
///   a single fixed, observable channel for the connection's whole
///   lifetime. See the class-level doc on `topicForSlot` for why this is a
///   real hash rather than a predictable `baseTopic/slotN` suffix.
/// - [secret] is the AES-256 key every message on that topic is encrypted
///   with (see `SyncCrypto`). Anyone holding the encoded key string can
///   decrypt everything on the topic and, if [permissions] includes
///   [SyncPermission.sync] or [SyncPermission.control], can also inject
///   valid-looking data or commands. Treat the encoded string itself with
///   the same care as a password.
/// - [signingPublicKey] lets a receiver verify that a message was produced
///   by whichever device holds the matching private key — which, by
///   construction, is only ever the device that called [generate] (see
///   [GeneratedSyncKey]). Encryption alone can't do this: every paired
///   device shares the same AES secret, so ciphertext alone proves nothing
///   about *which* holder of that secret produced a message. See
///   `SyncSigner`/`SyncVerifier`.
class SyncKey {
  SyncKey({
    required this.topicSeed,
    required this.secret,
    required this.permissions,
    required this.signingPublicKey,
  }) : assert(
         topicSeed.length == topicSeedLength,
         'topicSeed must be $topicSeedLength bytes',
       ),
       assert(secret.length == secretLength, 'secret must be $secretLength bytes'),
       assert(
         signingPublicKey.length == signingPublicKeyLength,
         'signingPublicKey must be $signingPublicKeyLength bytes',
       );

  static const int topicSeedLength = 16;
  static const int secretLength = 32;
  static const int signingPublicKeyLength = 32;
  static const int _formatVersion = 2;
  static const int _encodedLength =
      2 + topicSeedLength + secretLength + signingPublicKeyLength;

  /// How often the topic rotates. See [topicForSlot].
  static const Duration slotDuration = Duration(seconds: 30);

  final Uint8List topicSeed;
  final Uint8List secret;
  final Uint8List signingPublicKey;
  final Set<SyncPermission> permissions;

  /// Generates a brand new key plus the private signing key that goes with
  /// it — see [GeneratedSyncKey] for why those travel separately (the
  /// private key is never part of the encoded string).
  static Future<GeneratedSyncKey> generate({
    required Set<SyncPermission> permissions,
  }) async {
    final random = Random.secure();
    final keyPair = await Ed25519().newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final key = SyncKey(
      topicSeed: _randomBytes(random, topicSeedLength),
      secret: _randomBytes(random, secretLength),
      permissions: permissions,
      signingPublicKey: Uint8List.fromList(publicKey.bytes),
    );
    return GeneratedSyncKey(
      key: key,
      signingPrivateKeySeed: Uint8List.fromList(privateKeyBytes),
    );
  }

  static Uint8List _randomBytes(Random random, int length) =>
      Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));

  /// The UTC-epoch-based slot index for [at] (or now) — `~/` truncating
  /// division by [slotDuration], so every device computes the same slot
  /// from its own clock regardless of timezone, with no coordination
  /// needed beyond roughly-accurate clocks.
  static int slotFor(DateTime at) =>
      at.toUtc().millisecondsSinceEpoch ~/ slotDuration.inMilliseconds;

  /// The MQTT topic this key's connection communicates on during [slot].
  /// Namespaced under `mercilith/sync/v1/`, followed by
  /// `sha256(topicSeed ++ slot)` hex-encoded — a real hash, not a
  /// predictable `<baseTopic>/<slot>` suffix, since [slot] is public
  /// information (derivable from the current time by anyone); a
  /// predictable suffix would make the rotation pointless; only someone
  /// holding [topicSeed] can compute past, current, or future topics.
  Future<String> topicForSlot(int slot) async {
    final slotBytes = ByteData(8)..setInt64(0, slot);
    final digest = await Sha256().hash([
      ...topicSeed,
      ...slotBytes.buffer.asUint8List(),
    ]);
    final hex = digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'mercilith/sync/v1/$hex';
  }

  /// [topicForSlot] for [slotFor] of [at] (or now).
  Future<String> currentTopic({DateTime? at}) =>
      topicForSlot(slotFor(at ?? DateTime.now()));

  /// Encodes this key to a single copy-pasteable string (Crockford Base32 —
  /// see `base32_crockford.dart` for why that alphabet).
  String encode() {
    final bytes = BytesBuilder()
      ..addByte(_formatVersion)
      ..addByte(SyncPermission.packAll(permissions))
      ..add(topicSeed)
      ..add(secret)
      ..add(signingPublicKey);
    return base32CrockfordEncode(bytes.toBytes());
  }

  /// Throws [FormatException] if [encoded] isn't a validly-formed key
  /// (wrong length, unsupported version, invalid characters). Only ever
  /// recovers the embedded public signing key — a private key can't be
  /// reconstructed from an encoded string, by design (see
  /// [GeneratedSyncKey]).
  factory SyncKey.parse(String encoded) {
    final bytes = base32CrockfordDecode(encoded.trim());
    if (bytes.length != _encodedLength) {
      throw FormatException(
        'Sync key has the wrong length (expected $_encodedLength bytes, '
        'got ${bytes.length}).',
      );
    }
    final version = bytes[0];
    if (version != _formatVersion) {
      throw FormatException('Unsupported sync key version: $version');
    }
    final permissions = SyncPermission.unpackAll(bytes[1]);
    final topicSeedEnd = 2 + topicSeedLength;
    final secretEnd = topicSeedEnd + secretLength;
    return SyncKey(
      topicSeed: Uint8List.sublistView(bytes, 2, topicSeedEnd),
      secret: Uint8List.sublistView(bytes, topicSeedEnd, secretEnd),
      signingPublicKey: Uint8List.sublistView(bytes, secretEnd, _encodedLength),
      permissions: permissions,
    );
  }
}

/// The result of [SyncKey.generate]: the shareable [key] plus the
/// [signingPrivateKeySeed] that only the generating device should ever
/// hold. [key] (and thus [SyncKey.signingPublicKey]) is safe to encode and
/// hand to another device; [signingPrivateKeySeed] must be persisted
/// locally by the caller instead — never encoded, never transmitted.
class GeneratedSyncKey {
  GeneratedSyncKey({required this.key, required this.signingPrivateKeySeed});

  final SyncKey key;
  final Uint8List signingPrivateKeySeed;
}
