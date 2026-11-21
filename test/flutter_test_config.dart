import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/services/cluster_profile_tools.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_cluster_profile_tools.dart';
import 'helpers/test_container.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    registerTestSessionState();
    getIt.registerLazySingleton<ClusterProfileTools>(
      () => FakeClusterProfileTools(),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  await testMain();
}
