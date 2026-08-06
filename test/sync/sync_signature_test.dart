import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mercilith_app_template/mercilith_app_template.dart';

void main() {
  group('SyncSigner / SyncVerifier', () {
    test('a signature verifies against the matching public key', () async {
      final generated = await SyncKey.generate(permissions: {SyncPermission.sync});
      final signer = await SyncSigner.fromSeed(generated.signingPrivateKeySeed);
      final verifier = SyncVerifier(generated.key.signingPublicKey);
      final message = Uint8List.fromList(utf8.encode('hello sync'));

      final signature = await signer.sign(message);

      expect(await verifier.verify(message, signature), isTrue);
    });

    test('verification fails against the wrong public key', () async {
      final generatedA = await SyncKey.generate(permissions: {SyncPermission.sync});
      final generatedB = await SyncKey.generate(permissions: {SyncPermission.sync});
      final signer = await SyncSigner.fromSeed(generatedA.signingPrivateKeySeed);
      final wrongVerifier = SyncVerifier(generatedB.key.signingPublicKey);
      final message = Uint8List.fromList(utf8.encode('hello sync'));

      final signature = await signer.sign(message);

      expect(await wrongVerifier.verify(message, signature), isFalse);
    });

    test('verification fails for a tampered message', () async {
      final generated = await SyncKey.generate(permissions: {SyncPermission.sync});
      final signer = await SyncSigner.fromSeed(generated.signingPrivateKeySeed);
      final verifier = SyncVerifier(generated.key.signingPublicKey);
      final message = Uint8List.fromList(utf8.encode('hello sync'));

      final signature = await signer.sign(message);
      final tampered = Uint8List.fromList(utf8.encode('hello sunc'));

      expect(await verifier.verify(tampered, signature), isFalse);
    });

    test('verification fails (does not throw) for garbage signature bytes',
        () async {
      final generated = await SyncKey.generate(permissions: {SyncPermission.sync});
      final verifier = SyncVerifier(generated.key.signingPublicKey);
      final message = Uint8List.fromList(utf8.encode('hello sync'));

      expect(
        await verifier.verify(message, Uint8List.fromList([1, 2, 3])),
        isFalse,
      );
    });
  });

  group('SignedMessage', () {
    test('unsigned round-trips through encode/decode', () {
      final ciphertext = Uint8List.fromList(utf8.encode('ciphertext bytes'));
      final message = SignedMessage(ciphertext: ciphertext);

      final decoded = SignedMessage.decode(message.encode());

      expect(decoded.signature, isNull);
      expect(decoded.ciphertext, ciphertext);
    });

    test('signed round-trips through encode/decode', () {
      final ciphertext = Uint8List.fromList(utf8.encode('ciphertext bytes'));
      final signature = Uint8List(64)..fillRange(0, 64, 7);
      final message = SignedMessage(ciphertext: ciphertext, signature: signature);

      final decoded = SignedMessage.decode(message.encode());

      expect(decoded.signature, signature);
      expect(decoded.ciphertext, ciphertext);
    });

    test('decode rejects an empty payload', () {
      expect(
        () => SignedMessage.decode(Uint8List(0)),
        throwsFormatException,
      );
    });

    test('decode rejects a truncated signed payload', () {
      expect(
        () => SignedMessage.decode(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });

    test('decode rejects an unknown flag byte', () {
      expect(
        () => SignedMessage.decode(Uint8List.fromList([2, 1, 2, 3])),
        throwsFormatException,
      );
    });
  });
}
