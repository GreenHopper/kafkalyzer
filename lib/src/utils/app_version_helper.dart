class AppVersionHelper {
  static const String version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'DEV',
  );
}
