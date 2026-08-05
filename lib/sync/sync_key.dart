import 'dart:math';
import 'dart:typed_data';

import 'base32_crockford.dart';
import 'sync_permission.dart';

/// A pairing key for cross-device sync. Generated on one device, copied by
/// hand (or however the app chooses to present it — text, QR, etc.) to
/// another device and added there. The key is the *only* secret in this
/// design — there is no server, no account, no broker-side access control
/// (see `MqttSyncTransport`'s doc comment) — so it does two jobs at once:
///
/// - [topic] (derived from [topicSeed]) is which MQTT topic the paired
///   devices talk on. It isn't secret by itself (16 random bytes hex-
///   encoded into the topic string is enough to make it unguessable) but
///   it never needs to be, since nothing meaningful can be read from
///   traffic on that topic without [secret].
/// - [secret] is the AES-256 key every message on that topic is encrypted
///   with (see `SyncCrypto`). Anyone holding the encoded key string can
///   decrypt everything on the topic and, if [permissions] includes
///   [SyncPermission.sync] or [SyncPermission.control], can also inject
///   valid-looking data or commands. Treat the encoded string itself with
///   the same care as a password.
class SyncKey {
  SyncKey({
    required this.topicSeed,
    required this.secret,
    required this.permissions,
  }) : assert(
         topicSeed.length == topicSeedLength,
         'topicSeed must be $topicSeedLength bytes',
       ),
       assert(secret.length == secretLength, 'secret must be $secretLength bytes');

  static const int topicSeedLength = 16;
  static const int secretLength = 32;
  static const int _formatVersion = 1;
  static const int _encodedLength = 2 + topicSeedLength + secretLength;

  final Uint8List topicSeed;
  final Uint8List secret;
  final Set<SyncPermission> permissions;

  factory SyncKey.generate({required Set<SyncPermission> permissions}) {
    final random = Random.secure();
    return SyncKey(
      topicSeed: _randomBytes(random, topicSeedLength),
      secret: _randomBytes(random, secretLength),
      permissions: permissions,
    );
  }

  static Uint8List _randomBytes(Random random, int length) =>
      Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));

  /// The MQTT topic this key's connection communicates on. Namespaced under
  /// `mercilith/sync/v1/` so future protocol versions or unrelated
  /// Mercilith-app traffic on the same public broker can't collide with it.
  String get topic {
    final hex = topicSeed
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'mercilith/sync/v1/$hex';
  }

  /// Encodes this key to a single copy-pasteable string (Crockford Base32 —
  /// see `base32_crockford.dart` for why that alphabet).
  String encode() {
    final bytes = BytesBuilder()
      ..addByte(_formatVersion)
      ..addByte(SyncPermission.packAll(permissions))
      ..add(topicSeed)
      ..add(secret);
    return base32CrockfordEncode(bytes.toBytes());
  }

  /// Throws [FormatException] if [encoded] isn't a validly-formed key
  /// (wrong length, unsupported version, invalid characters).
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
    return SyncKey(
      topicSeed: Uint8List.sublistView(bytes, 2, 2 + topicSeedLength),
      secret: Uint8List.sublistView(
        bytes,
        2 + topicSeedLength,
        _encodedLength,
      ),
      permissions: permissions,
    );
  }
}
