# Tasks

## 1. Controller State Management

- [x] 1.1 Add `connectingProfile` property to `ActiveConnectionController` and manage its lifecycle in `connect()`, ensuring it is set immediately before validation and cleared in `finally`. Verify via unit tests.
- [x] 1.2 Add unit tests for `ActiveConnectionController` in `test/src/features/cluster/presentation/controllers/active_connection_controller_test.dart` verifying `connectingProfile` and `isConnecting` states during connection initiation, success, failure, and timeout scenarios. Verify with `flutter test test/src/features/cluster/presentation/controllers/active_connection_controller_test.dart`.

## 2. UI Presentation & Loading Feedback

- [x] 2.1 Update `_buildClusterListItem` in `lib/src/features/explorer/presentation/explorer_view.dart` to display `CircularProgressIndicator` when `activeController.connectingProfile?.name == cluster.name || (isActive && activeController.isConnecting)` and ignore redundant taps. Verify by checking widget rendering.
- [x] 2.2 Update `ExplorerOnboardingView` in `lib/src/features/explorer/presentation/widgets/explorer_onboarding_view.dart` to accept `connectingProfile` and show a loading indicator on the connecting cluster card action button while disabling interaction. Verify with widget tests.
- [x] 2.3 Add widget tests in `test/src/features/explorer/presentation/explorer_view_test.dart` and `test/src/features/explorer/presentation/widgets/explorer_onboarding_view_test.dart` confirming the progress indicator appears immediately upon clicking a cluster to connect and remains visible until resolution. Verify with `flutter test test/src/features/explorer/`.

## 3. Verification & Code Quality

- [x] 3.1 Format Dart files using `dart format` and verify zero issues with `flutter analyze`.
- [x] 3.2 Execute complete test suite with `flutter test` and confirm all tests pass.
