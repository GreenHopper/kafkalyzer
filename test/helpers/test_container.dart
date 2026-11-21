/// Shared test container setup.
///
/// kafkalyzer's screens obtain their session-wide state from the application
/// container. `test/flutter_test_config.dart` resets that container before and
/// after every test, so a test file must not rely on a registration another
/// test happened to leave behind. This helper provides the same wiring the
/// application builds at startup, plus a way for one test to replace an entry
/// with a fake.
library;

import 'package:kafkalyzer/src/dependency_injection.dart';

/// Builds the session-wide state a screen can ask for.
///
/// Reassignment is allowed on purpose: a test that needs a fake for one of
/// these types calls [provideSubstitute] afterwards and wins.
void registerTestSessionState() {
  getIt.allowReassignment = true;
  setupDependencyInjection();
}

/// Replaces one entry of the container for the current test only.
///
/// The container is reset around every test, so the replacement cannot reach
/// the next one.
void provideSubstitute<T extends Object>(T substitute) {
  getIt.registerSingleton<T>(substitute);
}
