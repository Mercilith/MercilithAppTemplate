import 'package:flutter_test/flutter_test.dart';
import 'package:mercilith_app_template/mercilith_app_template.dart';

void main() {
  group('generateSyncId', () {
    test('produces a UUIDv4-shaped string', () {
      final id = generateSyncId();
      expect(
        id,
        matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        )),
      );
    });

    test('generates unique ids', () {
      final ids = List.generate(1000, (_) => generateSyncId());
      expect(ids.toSet().length, 1000);
    });
  });
}
