# Design

## Context

kafkalyzer's architecture separates computational tasks (`kafkalyzer-core`), Kafka wire protocol/consumer operations (`kafkalyzer-kafka`), and desktop UI/orchestration (Flutter/Dart with `get_it`, `watch_it`, `material_ui`, `shared_preferences`).

Currently:
- `MessageExportService` only supports full JSON payload serialization and multi-topic ZIP packaging. The message table view already calculates dynamic JSONPath projected columns, but these cannot be exported as tabular CSV.
- `SearchStreamConfiguration` contains rich filter and scan controls, but configurations are ephemeral; operators re-entering identical criteria across shifts have no preset mechanism.
- `ActiveConnectionController` tracks `openTopics` purely in memory. Quitting the app loses open tabs.
- `ScriptRunner` orchestrates multi-step pipelines in a UI-agnostic manner, but lacks a headless CLI entrypoint for CI or terminal-driven environments.
- `ClusterService` stores all cluster profiles (including passwords and tokens) in plaintext JSON within `SharedPreferences`.

All new features must integrate into the existing UI seamlessly without adding visual clutter or overwhelming the user.

## Goals / Non-Goals

**Goals:**
- Provide single-topic and multi-topic RFC 4180 CSV export of visible standard and dynamic projected columns directly from the results toolbar without adding persistent buttons.
- Enable naming, saving, recalling, updating, and deleting search presets per topic and cluster through a compact preset selector in `SearchConfigurationPanel`.
- Persistently preserve open topic tabs and the active tab selection per cluster, restoring them automatically on reconnection.
- Provide a headless CLI script runner supporting parameter overrides, structured JSON summaries, and semantic exit codes, accompanied by a "Copy CLI Command" button in the script workspace.
- Encrypt and isolate sensitive credentials in the native OS keyring with automatic migration from plaintext storage and safe bundle export options.

**Non-Goals:**
- Any Kafka write operations (producing messages, committing offsets, resetting consumer groups, creating or deleting topics).
- Background server daemon or web-based multi-user orchestration.
- Persisting consumed Kafka message bodies across app restarts (only tab configurations are restored).

## Decisions

### Decision 1: Export Format Affordance in MessagesView Toolbar
- **Approach**: Replace the standalone download icon button (`Icons.download`) with a compact `PopupMenuButton<ExportFormat>` that presents two concise options:
  1. `JSON (Full Messages)`
  2. `CSV (Visible & Projected Columns)`
- **Rationale**: Keeps the results toolbar footprint completely unchanged. No extra buttons, no new toolbars, and zero visual clutter.
- **Alternatives Considered**:
  - *Adding a separate CSV button*: Clutters the results toolbar, which already contains search, sort, and view switches.
  - *Showing a dialog on every download click*: Adds modal friction for users who just want to quickly dump JSON. A popup menu is standard and frictionless.

### Decision 2: RFC 4180 CSV Serialization and Projected Column Mapping
- **Approach**: Integrate the mature `csv` Dart package (`ListToCsvConverter`). `MessageExportService.exportMessages` accepts an optional `List<String> visibleColumns` and `Map<String, String> projectedPaths`. The export iterates through messages, uses `json-path-resolution`'s shared extractor for dynamic columns, and outputs clean RFC 4180 CSV. Multi-topic exports produce individual `.csv` files inside a `.zip` archive.
- **Rationale**: Avoids ad-hoc string formatting errors with commas, line breaks, or quotation marks. Ensures that CSV columns match what the user sees on screen.
- **Alternatives Considered**:
  - *Custom string concatenation*: Fragile against multiline payloads, embedded quotes, and delimiter escaping.

### Decision 3: Search Preset Storage and UI Integration
- **Approach**:
  - Create `SavedSearchesService` storing presets in `SharedPreferences` namespaced by `search_presets_${clusterName}_${topicName}`.
  - A preset data model stores: scan mode, filter type, filter query, search scope, fast trace flag, limit, partition filter, start/stop strategies, and active column configurations.
  - In `SearchStreamConfiguration`, render a compact preset dropdown in the upper action row of the panel. Clicking "Save Current Search..." opens a small dialog prompting for a preset name.
- **Rationale**: Places the preset control exactly where operators configure searches, without wasting vertical screen space.
- **Alternatives Considered**:
  - *Dedicated sidebar panel for saved searches*: Adds extra navigation layers and pulls the user away from the active search stream.

### Decision 4: Tab Session Restoration Lifecycle
- **Approach**:
  - Create `SessionRestoreService` tracking active tabs per cluster: `{clusterName: {openTopicNames: List<String>, activeTopicName: String?}}`.
  - `ActiveConnectionController` updates this state whenever tabs are opened, closed, or switched.
  - Upon successful cluster connection, if the user setting `restore_open_tabs_on_startup` is enabled (default: true), `ActiveConnectionController` silently re-populates `_openTopics` with the saved topic metadata.
  - A simple toggle switch in General Settings allows users to turn off session restoration.
- **Rationale**: Completely automatic and unobtrusive. Does not begin streaming messages until the user clicks Start or inspects the tab, avoiding startup bandwidth surges.
- **Alternatives Considered**:
  - *Auto-starting message consumption on all restored tabs*: Would cause severe network and CPU spikes upon launching the app on large clusters.

### Decision 5: Headless Script Runner Architecture
- **Approach**:
  - Create a lightweight CLI runner entry point (`bin/kafkalyzer_script.dart`) that boots the non-UI dependency injection graph (headless profile repository, `ScriptRunner`, console logger).
  - Accepts CLI arguments: `--script <id|path>`, `--cluster <name>`, `--var key=value`, `--params <file.json>`, and `--output <file.json>`.
  - Emits human-readable progress to `stderr` and machine-readable JSON summary to `stdout` (or `--output`).
  - Exits with `0` on success, or non-zero codes (1 = error, 2 = missing params, 3 = connection failure).
  - In `ScriptRunView`, add a subtle "Copy CLI Command" button in the parameter action bar that generates the exact CLI invocation string with current values.
- **Rationale**: Full headless automation for CI/CD pipelines while sharing the exact same step execution and variable interpolation logic.
- **Alternatives Considered**:
  - *Re-implementing the script runner in pure Rust*: Duplicates step graph handling, JSONPath substitution, and step condition logic.

### Decision 6: Secure Storage Abstraction & OS Keyring Integration
- **Approach**:
  - Introduce `SecureStorageService` backed by `flutter_secure_storage` (Linux Secret Service / libsecret, macOS Keychain, Windows Credential Manager).
  - Encapsulate secret fields: `saslPassword`, `schemaRegistryPassword`, `sslKeystorePassword`, `sslTruststorePassword`, `sslPemKeyPassword`, `saslOauthbearerToken`.
  - In `ClusterService`, persist non-sensitive cluster configuration in `SharedPreferences` while storing secret fields in `SecureStorageService` under keys `cluster_${profileName}_${secretField}`.
  - On startup, a one-time migration scans `cluster_profiles` in `SharedPreferences`, copies any plaintext secrets into the OS keyring, and clears them from the `SharedPreferences` JSON.
  - In `ClusterConfigDialog`, display a discreet lock badge with tooltip `Protected by OS Keyring`.
  - In `SettingsService` profile export, offer a safe default that scrubs secrets, with an explicit opt-in checkbox to export credentials.
- **Rationale**: Solves the single security finding on developer workstations without modifying broker protocol behavior or user workflows.
- **Alternatives Considered**:
  - *Master password encryption in SharedPreferences*: Annoying for users to enter on every startup and provides weak protection compared to the native OS keyring.

## Risks / Trade-offs

- **[Risk] Headless CI environment lacks graphical OS Keyring (e.g. Docker container without D-Bus / Secret Service)**
  - *Mitigation*: `SecureStorageService` catches missing keyring errors gracefully; headless runners accept credentials directly via environment variables (`KAFKALYZER_SASL_PASSWORD`) or CLI parameters.
- **[Risk] CSV export of large message sets causing UI thread pauses**
  - *Mitigation*: CSV formatting and JSONPath column resolution operate in batched microtasks, writing to file via streaming sinks without blocking the UI event loop.
- **[Risk] Restoring tabs for a topic that was deleted on the broker**
  - *Mitigation*: When `ActiveConnectionController` restores tabs, it checks broker topic metadata; if a topic is absent, it is quietly skipped or marked with an inactive notice rather than throwing an error.
- **[Risk] Profile renaming leaving orphaned keys in the OS Keyring**
  - *Mitigation*: `ClusterService.renameCluster` updates the associated keys in `SecureStorageService` in the same operation.

## Migration Plan

1. **Automatic Credential Migration**: On app boot, `ClusterService` checks a preference flag `credentials_migrated_to_keyring`. If false, it traverses loaded profiles, writes non-null secrets to `SecureStorageService`, updates `SharedPreferences` with sanitized profiles, and sets the flag to true.
2. **Rollback Safety**: If secure storage fails to initialize on a platform, `ClusterService` logs an error and gracefully maintains compatibility without crashing the application.
