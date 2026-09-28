import 'package:package_info_plus/package_info_plus.dart';

class AppVersionHelper {
  static String _version = 'DEV';

  static Future<void> init() async {
    const envVersion = String.fromEnvironment('APP_VERSION');
    if (envVersion.isNotEmpty && envVersion != 'DEV') {
      _version = envVersion;
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;
      if (version.isNotEmpty) {
        _version = buildNumber.isNotEmpty ? '$version+$buildNumber' : version;
        return;
      }
    } catch (_) {
      // Fallback to environment variable or default
    }

    _version = envVersion.isNotEmpty ? envVersion : 'DEV';
  }

  static String get version => _version;
}
