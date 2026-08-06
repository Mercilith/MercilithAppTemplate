import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mercilith_app_template/mercilith_app_template.dart';

void main() {
  group('SyncCrypto', () {
    test('encrypt/decrypt round-trips plaintext', () async {
      final key = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      final crypto = SyncCrypto(key.secret);
      final plaintext = Uint8List.fromList(utf8.encode('hello sync'));

      final wire = await crypto.encrypt(plaintext);
      final decrypted = await crypto.decrypt(wire);

      expect(utf8.decode(decrypted), 'hello sync');
    });

    test('two encryptions of the same plaintext produce different bytes', () async {
      final key = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      final crypto = SyncCrypto(key.secret);
      final plaintext = Uint8List.fromList(utf8.encode('same message'));

      final a = await crypto.encrypt(plaintext);
      final b = await crypto.encrypt(plaintext);

      expect(a, isNot(b));
    });

    test('decrypting with the wrong key fails', () async {
      final keyA = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      final keyB = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      final wire = await SyncCrypto(
        keyA.secret,
      ).encrypt(Uint8List.fromList(utf8.encode('secret')));

      expect(() => SyncCrypto(keyB.secret).decrypt(wire), throwsException);
    });

    test('decrypting a tampered message fails', () async {
      final key = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      final crypto = SyncCrypto(key.secret);
      final wire = await crypto.encrypt(
        Uint8List.fromList(utf8.encode('do not modify me')),
      );
      wire[wire.length - 1] ^= 0xFF;

      expect(() => crypto.decrypt(wire), throwsException);
    });

    test('decrypting too-short input throws a FormatException', () async {
      final key = (await SyncKey.generate(permissions: {SyncPermission.sync})).key;
      final crypto = SyncCrypto(key.secret);
      expect(
        () => crypto.decrypt(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });
  });

  group('SyncEnvelope + SyncCommand', () {
    test('envelope encode/decode round-trips', () {
      final envelope = SyncEnvelope(
        id: 'row-1',
        deviceId: 'device-a',
        entityType: 'task',
        op: SyncOp.upsert,
        updatedAt: DateTime.utc(2026, 8, 4, 12, 0, 0),
        payload: {'title': 'Buy milk', 'priority': 2},
      );

      final decoded = SyncEnvelope.decode(envelope.encode());

      expect(decoded.id, envelope.id);
      expect(decoded.deviceId, envelope.deviceId);
      expect(decoded.entityType, envelope.entityType);
      expect(decoded.op, envelope.op);
      expect(decoded.updatedAt, envelope.updatedAt);
      expect(decoded.payload, envelope.payload);
    });

    test('command encode/decode round-trips', () {
      final command = SyncCommand(
        action: 'complete',
        args: {'taskId': 42, 'amount': 1.0},
      );

      final decoded = SyncCommand.decode(command.encode());

      expect(decoded.action, command.action);
      expect(decoded.args, command.args);
    });
  });
}
