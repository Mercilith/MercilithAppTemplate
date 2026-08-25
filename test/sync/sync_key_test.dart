import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mercilith_app_template/mercilith_app_template.dart';
import 'package:mercilith_app_template/sync/base32_crockford.dart';

void main() {
  group('SyncKey', () {
    test(
        'encode/decode round-trips topic seed, secret, permissions, and '
        'signing public key', () async {
      final generated = await SyncKey.generate(
        permissions: {SyncPermission.sync, SyncPermission.control},
      );
      final key = generated.key;
      final parsed = SyncKey.parse(key.encode());

      expect(parsed.topicSeed, key.topicSeed);
      expect(parsed.secret, key.secret);
      expect(parsed.permissions, key.permissions);
      expect(parsed.signingPublicKey, key.signingPublicKey);
      expect(await parsed.currentTopic(), await key.currentTopic());
    });

    test('generated keys are unique, including the signing key', () async {
      final a = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      final b = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      expect(a.topicSeed, isNot(b.topicSeed));
      expect(a.secret, isNot(b.secret));
      expect(a.signingPublicKey, isNot(b.signingPublicKey));
    });

    test('topic is namespaced and derived from topicSeed and the slot',
        () async {
      final key = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      final now = DateTime.utc(2026, 1, 1, 12, 0, 0);
      final topic = await key.topicForSlot(SyncKey.slotFor(now));
      expect(topic, startsWith('mercilith/sync/v1/'));
      expect(topic.length, 'mercilith/sync/v1/'.length + 64); // sha256 hex
    });

    test('adjacent slots produce different topics; the same slot is stable',
        () async {
      final key = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      final slot = SyncKey.slotFor(DateTime.utc(2026, 1, 1));
      final topicA = await key.topicForSlot(slot);
      final topicB = await key.topicForSlot(slot);
      final topicNext = await key.topicForSlot(slot + 1);
      expect(topicA, topicB);
      expect(topicA, isNot(topicNext));
    });

    test('slotFor is UTC-epoch-based, not affected by DateTime.isUtc alone',
        () {
      // The same instant, expressed once as UTC and once with an explicit
      // non-UTC offset, must land in the same slot — this is the
      // "cross-timezone compatible" requirement: every device agrees on
      // the slot from the same underlying instant regardless of the
      // device's local timezone.
      final utc = DateTime.utc(2026, 6, 15, 12, 0, 0);
      final sameInstantElsewhere =
          utc.toLocal(); // same instant, local wall-clock representation
      expect(SyncKey.slotFor(utc), SyncKey.slotFor(sameInstantElsewhere));
    });

    test('single-permission and empty-permission sets round-trip',
        () async {
      final syncOnly =
          (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      expect(SyncKey.parse(syncOnly.encode()).permissions, {SyncPermission.sync});

      final none = (await SyncKey.generate(permissions: {})).key;
      expect(SyncKey.parse(none.encode()).permissions, isEmpty);

      final all =
          (await SyncKey.generate(permissions: SyncPermission.values.toSet()))
              .key;
      expect(SyncKey.parse(all.encode()).permissions, SyncPermission.values.toSet());
    });

    test('parse tolerates hyphens/spaces and case', () async {
      final key = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      final encoded = key.encode();
      final decorated = encoded
          .toLowerCase()
          .replaceAllMapped(RegExp('.{4}'), (m) => '${m.group(0)}-')
          .trim();

      final parsed = SyncKey.parse(decorated);
      expect(parsed.secret, key.secret);
    });

    test('parse rejects garbage input', () {
      expect(() => SyncKey.parse('not-a-real-key'), throwsFormatException);
      expect(() => SyncKey.parse(''), throwsFormatException);
    });

    test('parse rejects a truncated key', () async {
      final key = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      final encoded = key.encode();
      expect(
        () => SyncKey.parse(encoded.substring(0, encoded.length - 10)),
        throwsFormatException,
      );
    });

    test('parse rejects an unsupported format version', () async {
      // Flip the version nibble encoded in the first character ('0' -> '1'
      // shifts the leading 5 bits, which contain the version byte).
      final key = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      final encoded = key.encode();
      final tampered = encoded.startsWith('0')
          ? '1${encoded.substring(1)}'
          : '0${encoded.substring(1)}';
      expect(() => SyncKey.parse(tampered), throwsFormatException);
    });
  });

  group('SyncKey relay support', () {
    Uint8List relayKeyBytes([int seed = 7]) =>
        Uint8List.fromList(List.generate(32, (i) => (i + seed) % 256));

    test('a freshly generated key has no relaySecretKey', () async {
      final key = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      expect(key.relaySecretKey, isNull);
    });

    test('withRelaySecretKey attaches the key without touching P2P fields',
        () async {
      final base = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      final withRelay = base.withRelaySecretKey(relayKeyBytes());

      expect(withRelay.relaySecretKey, relayKeyBytes());
      expect(withRelay.topicSeed, base.topicSeed);
      expect(withRelay.secret, base.secret);
      expect(withRelay.signingPublicKey, base.signingPublicKey);
      expect(withRelay.permissions, base.permissions);
    });

    test('encode/decode round-trips relaySecretKey when present', () async {
      final base = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      final withRelay = base.withRelaySecretKey(relayKeyBytes());

      final parsed = SyncKey.parse(withRelay.encode());
      expect(parsed.relaySecretKey, relayKeyBytes());
      expect(parsed.topicSeed, base.topicSeed);
      expect(parsed.secret, base.secret);
    });

    test('encode/decode round-trips a null relaySecretKey', () async {
      final key = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      final parsed = SyncKey.parse(key.encode());
      expect(parsed.relaySecretKey, isNull);
    });

    test('parse still accepts a legacy v2-format key (no relay byte)',
        () async {
      final key = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      final v3 = key.encode();
      // Rebuild the raw bytes as v2: same as v3 minus the trailing
      // presence byte, with the version byte set to 2 instead of 3.
      final decoded = base32CrockfordDecode(v3);
      final legacyBytes = Uint8List.fromList([
        2,
        ...decoded.sublist(1, decoded.length - 1),
      ]);
      final legacyEncoded = base32CrockfordEncode(legacyBytes);

      final parsed = SyncKey.parse(legacyEncoded);
      expect(parsed.relaySecretKey, isNull);
      expect(parsed.topicSeed, key.topicSeed);
      expect(parsed.secret, key.secret);
      expect(parsed.signingPublicKey, key.signingPublicKey);
    });

    test('currentRelayChannel throws without a relaySecretKey', () async {
      final key = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      expect(() => key.currentRelayChannel(), throwsStateError);
    });

    test('relay channel is namespaced and 16 lowercase hex digits',
        () async {
      final key = (await SyncKey.generate(permissions: {SyncPermission.sync}))
          .key
          .withRelaySecretKey(relayKeyBytes());
      final channel =
          await key.relayChannelForSlot(SyncKey.relaySlotFor(DateTime.utc(2026, 1, 1)));
      expect(channel, startsWith('mclhost/v1/users/'));
      final hex = channel.substring('mclhost/v1/users/'.length);
      expect(hex.length, 16);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(hex), isTrue);
    });

    test('relay channel is stable within a 5-minute slot, differs across it',
        () async {
      final key = (await SyncKey.generate(permissions: {SyncPermission.sync}))
          .key
          .withRelaySecretKey(relayKeyBytes());
      final slot = SyncKey.relaySlotFor(DateTime.utc(2026, 1, 1));
      final a = await key.relayChannelForSlot(slot);
      final b = await key.relayChannelForSlot(slot);
      final next = await key.relayChannelForSlot(slot + 1);
      expect(a, b);
      expect(a, isNot(next));
    });

    test('relaySlotFor uses 300-second (not millisecond) steps', () {
      final base = DateTime.utc(2026, 1, 1, 0, 0, 0);
      final justUnder = base.add(const Duration(seconds: 299));
      final atBoundary = base.add(const Duration(seconds: 300));
      expect(SyncKey.relaySlotFor(justUnder), SyncKey.relaySlotFor(base));
      expect(SyncKey.relaySlotFor(atBoundary), isNot(SyncKey.relaySlotFor(base)));
    });

    test('relay channel differs from the control-tier topic for the same key',
        () async {
      final key = (await SyncKey.generate(permissions: {SyncPermission.sync}))
          .key
          .withRelaySecretKey(relayKeyBytes());
      final controlTopic = await key.currentTopic(at: DateTime.utc(2026, 1, 1));
      final relayChannel = await key.currentRelayChannel(at: DateTime.utc(2026, 1, 1));
      expect(controlTopic, isNot(contains('mclhost')));
      expect(relayChannel, isNot(contains('mercilith/sync')));
    });
  });
}
