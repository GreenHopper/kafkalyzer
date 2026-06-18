import 'package:package_info_plus/package_info_plus.dart';

class AppVersionHelper {
  static String _version = 'DEV';

  static Future<void> init() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _version = '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      // Fallback to environment variable if native initialization fails
      _version = const String.fromEnvironment(
        'APP_VERSION',
        defaultValue: 'DEV',
      );
    }
  }

  static String get version => _version;
}
