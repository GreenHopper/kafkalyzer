import 'package:kafkalyzer/src/utils/app_version_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppVersionHelper', () {
    test('version defaults to DEV when environment variable is not set', () {
      expect(AppVersionHelper.version, 'DEV');
    });
  });
}
