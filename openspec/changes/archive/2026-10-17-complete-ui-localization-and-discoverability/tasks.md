# Tasks

## 1. Localization Strings

- [x] 1.1 Add localized strings to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` for topic details actions and progress (`streamAction`, `stopAction`, `schemaAction`, `scanProgressTitle`, `clearMessagesTooltip`).
- [x] 1.2 Add localized strings for cluster config and security forms (SSL section titles, truststore/keystore labels, client PEM certificate/key labels, SASL mechanism options and credential labels, URL validation messages).
- [x] 1.3 Add localized strings for schema viewer (`schemaViewerTitle`, `noAvroSchemaFound`, `previousMatchTooltip`, `nextMatchTooltip`, `errorLoadingSchema`), messages view (`noMessagesToDisplay`), and JSON tree actions (`copyValueTooltip`, `valueCopiedToClipboard`).
- [x] 1.4 Run `flutter gen-l10n` to regenerate `AppLocalizations`.

## 2. Topic Details Localization

- [x] 2.1 Replace hardcoded strings in `lib/src/features/topic/topic_detail_view.dart` for "Schema", "Scan Progress", "Stream", "Stop", and "Clear Messages" with `AppLocalizations`.

## 3. Cluster Configuration & Security Dialog Localization

- [x] 3.1 Replace hardcoded strings in `lib/src/features/cluster/presentation/widgets/config_dialog/cluster_config_dialog.dart` for "Security Protocol", "Cancel", "Add", and "Save" with `AppLocalizations`.
- [x] 3.2 Replace hardcoded strings in `lib/src/features/cluster/presentation/widgets/config_dialog/cluster_basic_info_form.dart` for URL validation errors and optional schema registry credential labels with `AppLocalizations`.
- [x] 3.3 Replace hardcoded strings in `lib/src/features/cluster/presentation/widgets/config_dialog/cluster_ssl_form.dart` for SSL section header, truststore and keystore/PEM labels and passwords with `AppLocalizations`.
- [x] 3.4 Integrate `AppLocalizations` into `lib/src/features/cluster/presentation/widgets/config_dialog/cluster_sasl_form.dart` and replace all hardcoded mechanism names, Kerberos labels, and credential field labels with localized strings.

## 4. Schema Viewer & Messages View Localization

- [x] 4.1 Replace hardcoded strings in `lib/src/features/schema/presentation/widgets/schema_viewer_dialog.dart` for title, empty schema message, match navigation tooltips, and loading error descriptions with `AppLocalizations`.
- [x] 4.2 Replace hardcoded "No messages to display" in `lib/src/ui/messages/messages_view.dart` with localized string from `AppLocalizations`.

## 5. SmartVirtualJsonTree Row Actions Discoverability & Localization

- [x] 5.1 In `lib/src/ui/smart_tree/smart_virtual_json_tree.dart`, replace `Icons.view_column_outlined` with `Icons.push_pin_outlined` and verify the tooltip uses `l10n?.pinAsColumn`.
- [x] 5.2 Localize copy action tooltip and "Value copied to clipboard" snackbar feedback in `SmartVirtualJsonTree`.

## 6. Widget Tests and Verification

- [x] 6.1 Update and extend widget tests in `test/src/features/topic/`, `test/src/features/cluster/`, and `test/src/features/schema/` to verify localized UI rendering and German locale switching.
- [x] 6.2 Update and extend `SmartVirtualJsonTree` widget tests to verify the pin icon, tooltip, and localized clipboard copy feedback.
- [x] 6.3 Run `flutter test` across all affected test suites and execute `flutter analyze` to ensure zero regressions.
