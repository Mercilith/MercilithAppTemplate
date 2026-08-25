import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mercilith_app_template/mercilith_app_template.dart';
import 'package:mercilith_app_template/sync/base32_crockford.dart';

void main() {
  group('RelayPairingCode', () {
    Uint8List bytesFrom(int start, int length) =>
        Uint8List.fromList(List.generate(length, (i) => (start + i) % 256));

    test('parse round-trips a code produced by the same Crockford codec', () {
      final userId = bytesFrom(0, RelayPairingCode.userIdLength);
      final relaySecretKey = bytesFrom(16, RelayPairingCode.relaySecretKeyLength);
      final code = base32CrockfordEncode(
        Uint8List.fromList([...userId, ...relaySecretKey]),
      );

      final parsed = RelayPairingCode.parse(code);
      expect(parsed.userId, userId);
      expect(parsed.relaySecretKey, relaySecretKey);
    });

    test('a 48-byte payload always encodes to 77 characters', () {
      final userId = bytesFrom(0, RelayPairingCode.userIdLength);
      final relaySecretKey = bytesFrom(16, RelayPairingCode.relaySecretKeyLength);
      final code = base32CrockfordEncode(
        Uint8List.fromList([...userId, ...relaySecretKey]),
      );
      expect(code.length, 77);
    });

    test('userIdHex is lowercase hex of the userId bytes', () {
      final code = RelayPairingCode(
        userId: Uint8List.fromList([0x0a, 0x1b, 0x2c, 0x3d, ...List.filled(12, 0)]),
        relaySecretKey: bytesFrom(0, RelayPairingCode.relaySecretKeyLength),
      );
      expect(code.userIdHex, startsWith('0a1b2c3d'));
      expect(code.userIdHex.length, 32);
    });

    test('parse is case-insensitive and tolerates hyphens/spaces, matching '
        "SyncKey's own decoder", () {
      final userId = bytesFrom(0, RelayPairingCode.userIdLength);
      final relaySecretKey = bytesFrom(16, RelayPairingCode.relaySecretKeyLength);
      final code = base32CrockfordEncode(
        Uint8List.fromList([...userId, ...relaySecretKey]),
      );
      final decorated = code
          .toLowerCase()
          .replaceAllMapped(RegExp('.{4}'), (m) => '${m.group(0)}-')
          .trim();

      final parsed = RelayPairingCode.parse(decorated);
      expect(parsed.userId, userId);
      expect(parsed.relaySecretKey, relaySecretKey);
    });

    test('parse rejects a code of the wrong length', () {
      expect(() => RelayPairingCode.parse('0000'), throwsFormatException);
      final tooShort = base32CrockfordEncode(Uint8List(40));
      expect(() => RelayPairingCode.parse(tooShort), throwsFormatException);
    });

    test('constructor rejects wrongly-sized byte arrays', () {
      expect(
        () => RelayPairingCode(
          userId: Uint8List(15),
          relaySecretKey: Uint8List(32),
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => RelayPairingCode(
          userId: Uint8List(16),
          relaySecretKey: Uint8List(31),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
