import 'package:flutter_test/flutter_test.dart';
import 'package:mercilith_app_template/mercilith_app_template.dart';

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
}
