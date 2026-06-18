import 'package:kafkalyzer/src/utils/app_version_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppVersionHelper', () {
    test('version is initialized from package info', () async {
      PackageInfo.setMockInitialValues(
        appName: 'kafkalyzer',
        packageName: 'com.example.kafkalyzer',
        version: '1.2.3',
        buildNumber: '4',
        buildSignature: '',
      );

      await AppVersionHelper.init();
      expect(AppVersionHelper.version, '1.2.3+4');
    });
  });
}
