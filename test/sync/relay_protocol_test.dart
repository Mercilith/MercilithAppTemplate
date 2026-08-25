import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mercilith_app_template/mercilith_app_template.dart';

void main() {
  group('RelayPacket', () {
    test('encode/decode round-trips pluginId, type, and payload', () {
      final payload = Uint8List.fromList([1, 2, 3, 4]);
      final packet = RelayPacket(
        pluginId: 'relay',
        type: RelayPacketType.store,
        payload: payload,
      );
      final decoded = RelayPacket.decode(packet.encode());
      expect(decoded, isNotNull);
      expect(decoded!.pluginId, 'relay');
      expect(decoded.type, RelayPacketType.store);
      expect(decoded.payload, payload);
    });

    test('encodes the exact wire format from the spec', () {
      final packet = RelayPacket(
        pluginId: 'relay',
        type: RelayPacketType.resyncRequest,
        payload: Uint8List(0),
      );
      // 01 05 72 65 6c 61 79 02
      expect(packet.encode(), [0x01, 0x05, 0x72, 0x65, 0x6c, 0x61, 0x79, 0x02]);
    });

    test('empty payload round-trips for resyncRequest/resyncComplete', () {
      for (final type in [RelayPacketType.resyncRequest, RelayPacketType.resyncComplete]) {
        final packet = RelayPacket(pluginId: 'relay', type: type, payload: Uint8List(0));
        final decoded = RelayPacket.decode(packet.encode());
        expect(decoded!.type, type);
        expect(decoded.payload, isEmpty);
      }
    });

    test('decode returns null for too-short bytes', () {
      expect(RelayPacket.decode(Uint8List(0)), isNull);
      expect(RelayPacket.decode(Uint8List.fromList([1, 2])), isNull);
    });

    test('decode returns null for an unsupported version', () {
      final packet = RelayPacket(
        pluginId: 'relay',
        type: RelayPacketType.store,
        payload: Uint8List(0),
      );
      final bytes = packet.encode();
      bytes[0] = 99;
      expect(RelayPacket.decode(bytes), isNull);
    });

    test('decode returns null for an unrecognized packet type', () {
      final packet = RelayPacket(
        pluginId: 'relay',
        type: RelayPacketType.store,
        payload: Uint8List(0),
      );
      final bytes = packet.encode();
      bytes[bytes.length - 1] = 99; // last byte before empty payload = type
      expect(RelayPacket.decode(bytes), isNull);
    });

    test('decode tolerates a different pluginId (ignored by caller if unwanted)', () {
      final packet = RelayPacket(
        pluginId: 'core',
        type: RelayPacketType.store,
        payload: Uint8List.fromList([9]),
      );
      final decoded = RelayPacket.decode(packet.encode());
      expect(decoded!.pluginId, 'core');
    });
  });

  group('RelayStorePacket', () {
    test('encode/decode round-trips key, tombstone flag, updatedAt, blob',
        () {
      final packet = RelayStorePacket(
        key: Uint8List.fromList([4, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
        tombstone: false,
        updatedAtMillis: 1750000000123,
        blob: Uint8List.fromList([0xAA, 0xBB, 0xCC]),
      );
      final decoded = RelayStorePacket.decode(packet.encode());
      expect(decoded.key, packet.key);
      expect(decoded.tombstone, isFalse);
      expect(decoded.updatedAtMillis, 1750000000123);
      expect(decoded.blob, packet.blob);
    });

    test('a tombstone has flags bit0 set and an empty blob', () {
      final packet = RelayStorePacket(
        key: Uint8List.fromList([0]),
        tombstone: true,
        updatedAtMillis: 42,
        blob: Uint8List(0),
      );
      final encoded = packet.encode();
      // keyLen(1) key(1) flags(1) -> flags is byte index 2.
      expect(encoded[2] & 0x1, 1);
      final decoded = RelayStorePacket.decode(encoded);
      expect(decoded.tombstone, isTrue);
      expect(decoded.blob, isEmpty);
    });

    test('updatedAt is encoded little-endian', () {
      final packet = RelayStorePacket(
        key: Uint8List.fromList([1]),
        tombstone: false,
        updatedAtMillis: 0x0102030405060708,
        blob: Uint8List(0),
      );
      final encoded = packet.encode();
      // keyLen(1) key(1) flags(1) -> updatedAt starts at index 3, LE so
      // the least-significant byte (0x08) comes first.
      expect(encoded.sublist(3, 11), [0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01]);
    });

    test('key length is capped at 64 bytes by assertion', () {
      expect(
        () => RelayStorePacket(
          key: Uint8List(65),
          tombstone: false,
          updatedAtMillis: 0,
          blob: Uint8List(0),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
