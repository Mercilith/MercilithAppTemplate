import 'dart:typed_data';

/// Packet types `relay_plugin` recognizes under pluginId `"relay"` — see
/// `RelayPacket` for the outer envelope these travel inside.
enum RelayPacketType {
  /// Client -> server (an upsert/tombstone for one key) or server -> client
  /// (one reply row during a resync replay).
  store(1),

  /// Client -> server, empty payload: "send me every key you currently
  /// hold for my user." Server replies with one [store] per key (including
  /// tombstones), then [resyncComplete].
  resyncRequest(2),

  /// Server -> client, empty payload: marks the end of a resync reply.
  resyncComplete(3);

  const RelayPacketType(this.value);

  final int value;

  static RelayPacketType? fromValue(int value) => switch (value) {
    1 => store,
    2 => resyncRequest,
    3 => resyncComplete,
    _ => null,
  };
}

/// The outer packet envelope every message on a relay channel is wrapped
/// in, regardless of plugin — MclHost-Core's core dispatches by
/// [pluginId], with everything after it opaque to core and owned by that
/// plugin. Wire format:
///
/// ```
/// byte 0        version (currently 1)
/// byte 1        pluginId length in bytes (N)
/// bytes 2..2+N  pluginId, ASCII, not NUL-terminated
/// byte 2+N      packet type
/// remainder     payload, opaque to core
/// ```
///
/// For `relay_plugin` (`pluginId == "relay"`), [payload] is either a
/// [RelayStorePacket]'s encoding (for [RelayPacketType.store]) or empty
/// (for the other two types).
class RelayPacket {
  RelayPacket({required this.pluginId, required this.type, required this.payload});

  static const int version = 1;

  final String pluginId;
  final RelayPacketType type;
  final Uint8List payload;

  Uint8List encode() {
    final idBytes = Uint8List.fromList(pluginId.codeUnits);
    return (BytesBuilder()
          ..addByte(version)
          ..addByte(idBytes.length)
          ..add(idBytes)
          ..addByte(type.value)
          ..add(payload))
        .toBytes();
  }

  /// Returns `null` for anything that doesn't parse as a valid envelope of
  /// a known version/packet type — expected, ordinary traffic on a shared
  /// channel (another plugin's packets, a version mismatch), not an error
  /// callers need to distinguish.
  static RelayPacket? decode(Uint8List bytes) {
    if (bytes.length < 3) return null;
    if (bytes[0] != version) return null;
    final idLen = bytes[1];
    if (bytes.length < 2 + idLen + 1) return null;
    final pluginId = String.fromCharCodes(bytes.sublist(2, 2 + idLen));
    final type = RelayPacketType.fromValue(bytes[2 + idLen]);
    if (type == null) return null;
    return RelayPacket(
      pluginId: pluginId,
      type: type,
      payload: Uint8List.sublistView(bytes, 2 + idLen + 1),
    );
  }
}

/// The payload of a [RelayPacketType.store] packet — a single
/// last-write-wins row, keyed by an opaque, app-owned [key]. Wire format:
///
/// ```
/// keyLen(u8)  key(keyLen bytes, opaque, max 64 bytes total)
/// flags(u8)   bit0 = tombstone (deleted; blob is empty)
/// updatedAt(u64, LITTLE-ENDIAN)   caller's clock — only relative order matters
/// blob(remainder, opaque ciphertext, max 1 MiB, empty for tombstone)
/// ```
///
/// ⚠️ Byte order note: [updatedAtMillis] is encoded **little-endian**,
/// unlike the big-endian step encoding in `SyncKey.relayChannelForSlot` —
/// don't conflate the two.
class RelayStorePacket {
  RelayStorePacket({
    required this.key,
    required this.tombstone,
    required this.updatedAtMillis,
    required this.blob,
  }) : assert(key.length <= maxKeyLength, 'relay key must be <= $maxKeyLength bytes'),
       assert(blob.length <= maxBlobLength, 'relay blob must be <= $maxBlobLength bytes');

  static const int maxKeyLength = 64;
  static const int maxBlobLength = 1 << 20;

  final Uint8List key;
  final bool tombstone;

  /// Milliseconds since the Unix epoch, UTC, per the caller's own clock —
  /// only used for last-write-wins ordering server-side, never interpreted
  /// as wall-clock truth.
  final int updatedAtMillis;

  /// Opaque ciphertext (already `_wrap`-encrypted/signed by the caller).
  /// Empty when [tombstone] is true.
  final Uint8List blob;

  Uint8List encode() {
    final updatedAtBytes = ByteData(8)
      ..setUint64(0, updatedAtMillis, Endian.little);
    return (BytesBuilder()
          ..addByte(key.length)
          ..add(key)
          ..addByte(tombstone ? 1 : 0)
          ..add(updatedAtBytes.buffer.asUint8List())
          ..add(blob))
        .toBytes();
  }

  static RelayStorePacket decode(Uint8List bytes) {
    final keyLen = bytes[0];
    final key = Uint8List.sublistView(bytes, 1, 1 + keyLen);
    final flags = bytes[1 + keyLen];
    final updatedAtStart = 2 + keyLen;
    final updatedAtBytes = ByteData.sublistView(
      bytes,
      updatedAtStart,
      updatedAtStart + 8,
    );
    final blob = Uint8List.sublistView(bytes, updatedAtStart + 8);
    return RelayStorePacket(
      key: key,
      tombstone: flags & 0x1 != 0,
      updatedAtMillis: updatedAtBytes.getUint64(0, Endian.little),
      blob: blob,
    );
  }
}
