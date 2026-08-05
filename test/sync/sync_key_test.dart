import 'package:flutter_test/flutter_test.dart';
import 'package:mercilith_app_template/mercilith_app_template.dart';

void main() {
  group('SyncKey', () {
    test('encode/decode round-trips topic, secret, and permissions', () {
      final key = SyncKey.generate(
        permissions: {SyncPermission.sync, SyncPermission.control},
      );
      final parsed = SyncKey.parse(key.encode());

      expect(parsed.topicSeed, key.topicSeed);
      expect(parsed.secret, key.secret);
      expect(parsed.permissions, key.permissions);
      expect(parsed.topic, key.topic);
    });

    test('generated keys are unique', () {
      final a = SyncKey.generate(permissions: {SyncPermission.sync});
      final b = SyncKey.generate(permissions: {SyncPermission.sync});
      expect(a.topicSeed, isNot(b.topicSeed));
      expect(a.secret, isNot(b.secret));
      expect(a.topic, isNot(b.topic));
    });

    test('topic is namespaced and derived only from topicSeed', () {
      final key = SyncKey.generate(permissions: {SyncPermission.sync});
      expect(key.topic, startsWith('mercilith/sync/v1/'));
      expect(key.topic.length, 'mercilith/sync/v1/'.length + 32);
    });

    test('single-permission and empty-permission sets round-trip', () {
      final syncOnly = SyncKey.generate(permissions: {SyncPermission.sync});
      expect(SyncKey.parse(syncOnly.encode()).permissions, {SyncPermission.sync});

      final none = SyncKey.generate(permissions: {});
      expect(SyncKey.parse(none.encode()).permissions, isEmpty);

      final all = SyncKey.generate(permissions: SyncPermission.values.toSet());
      expect(SyncKey.parse(all.encode()).permissions, SyncPermission.values.toSet());
    });

    test('parse tolerates hyphens/spaces and case', () {
      final key = SyncKey.generate(permissions: {SyncPermission.sync});
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

    test('parse rejects a truncated key', () {
      final key = SyncKey.generate(permissions: {SyncPermission.sync});
      final encoded = key.encode();
      expect(
        () => SyncKey.parse(encoded.substring(0, encoded.length - 10)),
        throwsFormatException,
      );
    });

    test('parse rejects an unsupported format version', () {
      // Flip the version nibble encoded in the first character ('0' -> '1'
      // shifts the leading 5 bits, which contain the version byte).
      final key = SyncKey.generate(permissions: {SyncPermission.sync});
      final encoded = key.encode();
      final tampered = encoded.startsWith('0')
          ? '1${encoded.substring(1)}'
          : '0${encoded.substring(1)}';
      expect(() => SyncKey.parse(tampered), throwsFormatException);
    });
  });
}
