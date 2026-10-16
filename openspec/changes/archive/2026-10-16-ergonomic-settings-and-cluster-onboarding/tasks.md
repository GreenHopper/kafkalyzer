# Tasks

## 1. Localization & String Assets

- [x] 1.1 Add localized strings for client authentication modes (`sslClientAuthNone`, `sslClientAuthKeystore`, `sslClientAuthPem`), file picker tooltips (`browseFiles`), password visibility (`showPassword`, `hidePassword`), and connection test states (`testConnection`, `testingConnection`, `connectionSuccessful`, `connectionFailed`) in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`.
- [x] 1.2 Add localized descriptions clarifying global configuration backup vs. cluster ZIP bundle export in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`.
- [x] 1.3 Run `flutter gen-l10n` to regenerate localizations.

## 2. SettingsView Ergonomics & Cluster List Badges

- [x] 2.1 In `lib/src/features/settings/presentation/settings_view.dart`, constrain settings view content to `maxWidth: 960` with centered alignment.
- [x] 2.2 Place numeric inputs (`maxScriptRunsController` and `maxLagQueriesController`) side-by-side in a two-column row.
- [x] 2.3 Add clarifying subtitle labels to global configuration backup/restore and cluster ZIP export/import sections.
- [x] 2.4 Update cluster list tiles in `SettingsView` to render informative badges for security protocol (`PLAINTEXT`, `SSL`, `SASL_PLAINTEXT`, `SASL_SSL`) and Schema Registry status.

## 3. ClusterConfigDialog & Certificate File Pickers

- [x] 3.1 Expand `ClusterConfigDialog` dialog width constraint to 600 px for comfortable form viewing.
- [x] 3.2 Create or integrate a file picker suffix action button in file path fields (Truststore, Keystore, PEM Certificate, PEM Private Key, Kerberos Keytab, Kerberos Config) using `FilePicker.platform.pickFiles()`.
- [x] 3.3 Add password visibility toggles (`Icons.visibility` / `Icons.visibility_off`) on all password/secret fields in `ClusterBasicInfoForm`, `ClusterSslForm`, and `ClusterSaslForm`.
- [x] 3.4 In `ClusterBasicInfoForm`, implement progressive disclosure for Schema Registry credentials (username and password) so they are revealed only when a non-empty Schema Registry URL is entered or expanded.

## 4. Segmented SSL Client Authentication Selector

- [x] 4.1 In `ClusterSslForm`, add a `SegmentedButton` or selector for client authentication mode: `None`, `Keystore (PKCS12 / JKS)`, and `PEM Certificate & Key`.
- [x] 4.2 Initialize the client authentication mode based on the loaded cluster profile's existing paths.
- [x] 4.3 Dynamically show only the Keystore fields when `Keystore` is selected, only PEM fields when `PEM` is selected, and hide both when `None` is selected, while keeping the server Truststore inputs visible.

## 5. Live Broker Connection Test in Cluster Dialog

- [x] 5.1 In `ClusterConfigDialog`, add a "Test Connection" button in the dialog actions.
- [x] 5.2 Validate the form and construct a candidate `ClusterProfile` from the active input controllers.
- [x] 5.3 Invoke `getIt<KafkaMetadataService>().validateConnection(profile: candidate)` with async visual progress indicator.
- [x] 5.4 Display clear success or error banner feedback directly within the dialog without saving or dismissing the dialog.

## 6. Testing & Quality Verification

- [x] 6.1 Update existing settings tests in `test/src/features/settings/presentation/settings_view_test.dart` to verify constrained layout and cluster badges.
- [x] 6.2 Add/update tests in `test/src/features/cluster/presentation/widgets/config_dialog/cluster_config_dialog_test.dart` (or create new widget tests) to verify SSL mode switching, file picker integration, password visibility toggle, and connection test flow.
- [x] 6.3 Run `dart analyze lib test` and `flutter test` to ensure zero regressions and clean static analysis.
