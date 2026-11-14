import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/services/cluster_profile_tools.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_cluster_profile_tools.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    if (!getIt.isRegistered<ClusterProfileTools>()) {
      getIt.registerLazySingleton<ClusterProfileTools>(
        () => FakeClusterProfileTools(),
      );
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    if (!getIt.isRegistered<ClusterProfileTools>()) {
      getIt.registerLazySingleton<ClusterProfileTools>(
        () => FakeClusterProfileTools(),
      );
    }
  });

  await testMain();
}
