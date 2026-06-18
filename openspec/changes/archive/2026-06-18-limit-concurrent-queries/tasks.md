## 1. Settings & Persistence Implementation

- [x] 1.1 Add maximum concurrent queries input and persistence logic in `SettingsView`
- [x] 1.2 Add localizations and helper/warning info texts under the new setting in `SettingsView`

## 2. Concurrency Queue Logic

- [x] 2.1 Refactor `ConsumerLagView` to read queue limits dynamically from `SharedPreferences`
- [x] 2.2 Remove search-matching bypass `!matchesSearch` from `_loadGroupLag` queue guard
- [x] 2.3 Verify strict concurrency limit during background query enqueuing

## 3. Verification & Testing

- [x] 3.1 Update `settings_view_test.dart` to verify rendering and change of the new concurrent queries limit setting
- [x] 3.2 Verify all project widget tests pass successfully with the new queue limits
