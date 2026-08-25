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
///
/// [relaySecretKey] is a fourth, independent job added for MclHost-Core
/// relay integration: when present, it derives a *separate* rotating
/// channel ([currentRelayChannel]/[relayChannelForSlot]) used only for the
/// data-sync path routed through relay_plugin. It has nothing to do with
/// [topicSeed] — the two channels rotate on different cadences, from
/// different secrets, and a consuming app's control-tier traffic (e.g.
/// TaskApp's remote-automation commands) keeps using [topicSeed] regardless
/// of whether [relaySecretKey] is set.
class SyncKey {
  SyncKey({
    required this.topicSeed,
    required this.secret,
    required this.permissions,
    required this.signingPublicKey,
    this.relaySecretKey,
  }) : assert(
         topicSeed.length == topicSeedLength,
         'topicSeed must be $topicSeedLength bytes',
       ),
       assert(secret.length == secretLength, 'secret must be $secretLength bytes'),
       assert(
         signingPublicKey.length == signingPublicKeyLength,
         'signingPublicKey must be $signingPublicKeyLength bytes',
       ),
       assert(
         relaySecretKey == null || relaySecretKey.length == relaySecretKeyLength,
         'relaySecretKey must be $relaySecretKeyLength bytes',
       );

  static const int topicSeedLength = 16;
  static const int secretLength = 32;
  static const int signingPublicKeyLength = 32;
  static const int relaySecretKeyLength = 32;

  /// Format 2 is the pre-relay encoding (no [relaySecretKey] field at all);
  /// format 3 adds a presence byte plus the key itself. [parse] accepts
  /// both so an already-issued (pre-relay) pairing code still works;
  /// [encode] always writes the current version.
  static const int _formatVersion = 3;
  static const int _legacyFormatVersion = 2;
  static const int _baseEncodedLength =
      2 + topicSeedLength + secretLength + signingPublicKeyLength;

  /// How often the topic rotates. See [topicForSlot].
  static const Duration slotDuration = Duration(seconds: 30);

  /// How often the relay channel (see [currentRelayChannel]) rotates —
  /// matches MclHost-Core's `HiveMqChannelManager` cadence. Independent of
  /// [slotDuration]; the control-tier P2P topic keeps rotating on its own
  /// schedule regardless of relay use.
  static const Duration relaySlotDuration = Duration(seconds: 300);

  final Uint8List topicSeed;
  final Uint8List secret;
  final Uint8List signingPublicKey;
  final Set<SyncPermission> permissions;

  /// The MclHost user's raw 32-byte X25519 secret key, obtained via the
  /// MclHost-Core pairing flow (out of scope for this package — see the
  /// consuming app's pairing/enrollment screen). `null` for a connection
  /// that hasn't been paired with a relay ([currentRelayChannel] throws if
  /// called without one). Never derived from or interchangeable with
  /// [topicSeed] — see the class doc comment.
  final Uint8List? relaySecretKey;

  /// Generates a brand new key plus the private signing key that goes with
  /// it — see [GeneratedSyncKey] for why those travel separately (the
  /// private key is never part of the encoded string). [relaySecretKey] is
  /// never set here — a relay pairing is a separate, later step (see
  /// `withRelaySecretKey`) since it comes from MclHost-Core, not from this
  /// device.
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

  /// Returns a copy of this key with [relaySecretKey] set (or replaced) —
  /// the normal way a connection picks up relay routing after the user
  /// completes the MclHost-Core pairing flow, without touching any of the
  /// existing P2P fields.
  SyncKey withRelaySecretKey(Uint8List relaySecretKey) => SyncKey(
    topicSeed: topicSeed,
    secret: secret,
    permissions: permissions,
    signingPublicKey: signingPublicKey,
    relaySecretKey: relaySecretKey,
  );

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

  /// The UTC-epoch-based relay slot index for [at] (or now) — `floor` of
  /// whole seconds divided by [relaySlotDuration], matching
  /// MclHost-Core's `step = floor(epochSeconds / 300)` exactly (seconds,
  /// not milliseconds — a different base unit than [slotFor]).
  static int relaySlotFor(DateTime at) =>
      at.toUtc().millisecondsSinceEpoch ~/
      1000 ~/
      relaySlotDuration.inSeconds;

  /// The MclHost-Core relay channel this key's connection talks on during
  /// [slot]. Per the relay_plugin protocol: `HMAC-SHA256(key =
  /// relaySecretKey, message = slot as 8 bytes BIG-ENDIAN)`, first 8 bytes
  /// of the MAC read as a big-endian value and hex-encoded (16 lowercase
  /// hex digits, zero-padded) — done by hex-encoding those 8 bytes
  /// directly rather than round-tripping through a fixed-width `int`,
  /// since a `Dart` native `int` is signed 64-bit and the top MAC byte can
  /// set the sign bit, which would otherwise corrupt the hex text. Throws
  /// [StateError] if [relaySecretKey] isn't set.
  ///
  /// ⚠️ Byte order note: this step encoding is **big-endian**, unlike a
  /// relay Store packet's `updatedAt` field, which is little-endian (see
  /// `RelayStorePacket`) — don't conflate the two when touching this code.
  Future<String> relayChannelForSlot(int slot) async {
    final key = relaySecretKey;
    if (key == null) {
      throw StateError(
        'relayChannelForSlot requires relaySecretKey to be set — this '
        'connection has not been paired with an MclHost relay yet.',
      );
    }
    final stepBytes = ByteData(8)..setInt64(0, slot, Endian.big);
    final mac = await Hmac.sha256().calculateMac(
      stepBytes.buffer.asUint8List(),
      secretKey: SecretKey(key),
    );
    final hex = mac.bytes
        .take(8)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'mclhost/v1/users/$hex';
  }

  /// [relayChannelForSlot] for [relaySlotFor] of [at] (or now).
  Future<String> currentRelayChannel({DateTime? at}) =>
      relayChannelForSlot(relaySlotFor(at ?? DateTime.now()));

  /// Encodes this key to a single copy-pasteable string (Crockford Base32 —
  /// see `base32_crockford.dart` for why that alphabet). Always writes the
  /// current format ([_formatVersion]), including the relay-key presence
  /// byte (and the key itself, if set) even though most callers still pair
  /// a P2P-only key with no [relaySecretKey] — that's a legitimate,
  /// supported shape, not a legacy one.
  String encode() {
    final bytes = BytesBuilder()
      ..addByte(_formatVersion)
      ..addByte(SyncPermission.packAll(permissions))
      ..add(topicSeed)
      ..add(secret)
      ..add(signingPublicKey);
    final relayKey = relaySecretKey;
    if (relayKey != null) {
      bytes
        ..addByte(1)
        ..add(relayKey);
    } else {
      bytes.addByte(0);
    }
    return base32CrockfordEncode(bytes.toBytes());
  }

  /// Throws [FormatException] if [encoded] isn't a validly-formed key
  /// (wrong length, unsupported version, invalid characters). Only ever
  /// recovers the embedded public signing key — a private key can't be
  /// reconstructed from an encoded string, by design (see
  /// [GeneratedSyncKey]). Accepts both the current format (version 3, with
  /// the relay-key presence byte) and the pre-relay format (version 2,
  /// exactly [_baseEncodedLength] bytes) for backward compatibility with
  /// pairing codes issued before relay support existed.
  factory SyncKey.parse(String encoded) {
    final bytes = base32CrockfordDecode(encoded.trim());
    if (bytes.isEmpty) {
      throw const FormatException('Sync key is empty.');
    }
    final version = bytes[0];
    if (version != _formatVersion && version != _legacyFormatVersion) {
      throw FormatException('Unsupported sync key version: $version');
    }
    if (version == _legacyFormatVersion) {
      if (bytes.length != _baseEncodedLength) {
        throw FormatException(
          'Sync key has the wrong length (expected $_baseEncodedLength '
          'bytes for v2, got ${bytes.length}).',
        );
      }
      return _parseFrom(bytes, relaySecretKey: null);
    }
    if (bytes.length < _baseEncodedLength + 1) {
      throw FormatException(
        'Sync key has the wrong length (expected at least '
        '${_baseEncodedLength + 1} bytes for v3, got ${bytes.length}).',
      );
    }
    final hasRelayKey = bytes[_baseEncodedLength] != 0;
    Uint8List? relaySecretKey;
    if (hasRelayKey) {
      final relayEnd = _baseEncodedLength + 1 + relaySecretKeyLength;
      if (bytes.length != relayEnd) {
        throw FormatException(
          'Sync key has the wrong length (expected $relayEnd bytes for v3 '
          'with a relay key, got ${bytes.length}).',
        );
      }
      relaySecretKey = Uint8List.sublistView(
        bytes,
        _baseEncodedLength + 1,
        relayEnd,
      );
    } else if (bytes.length != _baseEncodedLength + 1) {
      throw FormatException(
        'Sync key has the wrong length (expected ${_baseEncodedLength + 1} '
        'bytes for v3 with no relay key, got ${bytes.length}).',
      );
    }
    return _parseFrom(bytes, relaySecretKey: relaySecretKey);
  }

  static SyncKey _parseFrom(Uint8List bytes, {required Uint8List? relaySecretKey}) {
    final permissions = SyncPermission.unpackAll(bytes[1]);
    final topicSeedEnd = 2 + topicSeedLength;
    final secretEnd = topicSeedEnd + secretLength;
    return SyncKey(
      topicSeed: Uint8List.sublistView(bytes, 2, topicSeedEnd),
      secret: Uint8List.sublistView(bytes, topicSeedEnd, secretEnd),
      signingPublicKey: Uint8List.sublistView(bytes, secretEnd, _baseEncodedLength),
      permissions: permissions,
      relaySecretKey: relaySecretKey,
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
