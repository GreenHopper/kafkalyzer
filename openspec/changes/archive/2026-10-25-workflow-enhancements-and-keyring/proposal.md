# Proposal

## Why

`design/feature-gap-analysis.md` §4 (Gruppe 2: Datenpfad & Workflows, B6–B10) identifies five operational and security gaps in kafkalyzer's daily workflows:
1. **B6 (CSV Export)**: Message export is currently limited to full JSON payloads and ZIP bundles. Business analysis, spreadsheet auditing, and tabular reporting require CSV containing projected and visible columns, which the UI already calculates but cannot export.
2. **B7 (Saved Searches)**: Shift teams and operators repeatedly configure identical scan modes, filter expressions, and column projections across shifts. Today, preserving complex search parameters requires writing multi-step automation scripts, which is excessive for recurring single-topic searches.
3. **B8 (Session Restoration)**: When restarting the desktop application, all open topic tabs and explorer contexts are discarded because tab state is held solely in memory, imposing repetitive startup setup every morning.
4. **B9 (Headless Script Execution)**: Automation scripts are strictly tethered to the Flutter desktop UI. Continuous integration (CI), periodic health audits, and terminal-first operators cannot execute multi-step pipelines headlessly with automated exit codes and structured JSON output.
5. **B10 (OS Keyring for Secrets)**: Sensitive credentials (SASL passwords, OAuth tokens, PEM key passwords, keystore/truststore passwords, and Schema Registry passwords) are currently stored in plaintext JSON inside `SharedPreferences` on disk, creating an avoidable security exposure on multi-user and developer workstations.

Addressing these five workflow features together eliminates operational friction in daily use while elevating security, without compromising kafkalyzer's strict read-only design principles.

## What Changes

- **B6: Projected Column CSV Export**: The results toolbar export affordance is upgraded from an immediate JSON file picker to an ergonomic format selector offering "JSON (Full Messages)" and "CSV (Visible & Projected Columns)". Exported CSV files follow RFC 4180 with standard message headers, dynamic JSONPath-projected columns, proper cell quoting, and UTF-8 encoding.
- **B7: Reusable Topic Search Presets**: Topic search configurations (scan mode, filter type/scope/term, partition targets, limit, start/end conditions, and associated table column configurations) can be named, saved, updated, and recalled via a compact preset selector within the collapsible Search Configuration Panel.
- **B8: Workspace Tab Session Persistence**: Open topic tabs and the active tab selection are persistently recorded per cluster and automatically restored when reconnecting or restarting the application, with a user setting in General Settings to disable automatic restoration if desired.
- **B9: Headless Script Pipeline Runner**: A command-line runner allows multi-step script pipelines to execute without launching the Flutter GUI. It supports parameter injection via CLI flags, environment variables, or JSON parameter files, emits structured JSON execution reports, returns non-zero process exit codes on step failures, and offers a "Copy CLI Command" helper in the script GUI.
- **B10: Secure Credential Storage in OS Keyring**: Sensitive credentials (SASL passwords, OAuth tokens, keystore/truststore passwords, PEM private key passwords, and Schema Registry passwords) are migrated out of plaintext `SharedPreferences` into the native OS keyring/keychain (Secret Service on Linux, Keychain on macOS, Credential Manager on Windows). Non-sensitive cluster configuration remains in local preferences. Profile export bundles provide safe options to omit or securely handle secrets.

All new UI elements are designed to integrate seamlessly into existing controls without creating visual clutter, extra button rows, or cognitive overload.

## Capabilities

### New Capabilities

- `message-csv-export`: Exports consumed Kafka messages to RFC 4180 compliant CSV using the currently visible standard columns and dynamic JSONPath projected columns, integrated cleanly into the message results export action.
- `saved-topic-searches`: Persistence, recall, and management of named search presets per topic (combining scan mode, filter criteria, limits, start/end boundaries, and table column setups) via a compact selector in the Search Configuration area.
- `headless-script-execution`: Standalone non-GUI execution of multi-step automation scripts with parameter overrides, semantic exit codes, structured JSON reporting, and a one-click CLI command generator in the desktop workspace.
- `secure-credentials-storage`: Native OS keyring integration for encrypting and storing sensitive Kafka and Schema Registry credentials, with automatic migration from plaintext storage and safe export handling.

### Modified Capabilities

- `topic-search-tabs`: Added requirement for persisting open tab instances and active tab selection across application restarts, automatically restoring the explorer session when the cluster reconnects.
- `cluster-profile-persistence`: Modified requirements to separate sensitive credentials into secure keyring storage while preserving lossless profile round-trips and safe bundle export/import.

## Impact

- **UI & Presentation**:
  - `lib/src/ui/messages/messages_view.dart`: Replace single-format download button with a compact export menu (JSON / CSV).
  - `lib/src/features/search/presentation/widgets/search_stream_configuration.dart`: Add compact preset selection and save affordance to the Search Configuration header/toolbar.
  - `lib/src/features/explorer/presentation/explorer_view.dart` & `active_connection_controller.dart`: Save and restore open tab records and active selection.
  - `lib/src/features/settings/presentation/settings_view.dart`: Add session restore toggle in General Settings.
  - `lib/src/features/scripting/presentation/widgets/script_run_view.dart`: Add "Copy CLI Command" button with tooltip.
  - `lib/src/features/cluster/presentation/widgets/cluster_config_dialog.dart`: Display subtle OS Keyring security indicator for secret fields.
- **Services & Storage**:
  - `lib/src/services/message_export_service.dart`: Add CSV generation with delimiter escaping and projected column mapping.
  - `lib/src/services/saved_searches_service.dart`: New service for persisting and managing search presets in `SharedPreferences`.
  - `lib/src/services/session_restore_service.dart`: New service for storing and restoring open topic tab states per cluster.
  - `lib/src/services/secure_storage_service.dart`: New secure storage abstraction targeting the OS Keyring (`flutter_secure_storage` or native platform keyring), with fallback handling for headless environments.
  - `lib/src/services/cluster_service.dart`: Split credential persistence between `SharedPreferences` and `SecureStorageService`.
  - `lib/src/services/settings_service.dart`: Update cluster profile export/import to sanitize or prompt regarding sensitive credentials.
- **CLI & Automation**:
  - `bin/kafkalyzer_script.dart` / headless entry point: Command-line runner for executing saved scripts using decoupled pipeline logic with exit codes and JSON output.
- **Dependencies**:
  - Add `csv` package for compliant RFC 4180 CSV serialization.
  - Add `flutter_secure_storage` for cross-platform OS Keyring access (Linux Secret Service / libsecret, macOS Keychain, Windows Credential Manager).
- **Localization**:
  - Add localized strings in `app_en.arb` and `app_de.arb` for all new UI text, tooltips, dialogs, and format options.
