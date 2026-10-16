# Design: Ergonomic Settings & Guided Cluster Onboarding

## Context

`SettingsView` manages both global preferences (export directories, max script runs, lag query limits) and Kafka cluster profiles (`ClusterProfile`). Currently, the settings page lacks visual constraints, expanding up to 1800+ px wide on desktop monitors. The cluster configuration dialog (`ClusterConfigDialog`) and its child forms (`ClusterBasicInfoForm`, `ClusterSslForm`, `ClusterSaslForm`) expose every SSL and authentication field simultaneously without file pickers, password toggles, or connectivity verification.

`file_picker` is already available in the project dependencies, and `KafkaMetadataService.validateConnection` already wraps native broker connection checks.

## Goals / Non-Goals

**Goals:**
- Constrain `SettingsView` content to `maxWidth: 960` with centered alignment and ergonomic multi-column form rows.
- Clearly differentiate global configuration backup/restore from cluster ZIP export/import.
- Display protocol (`PLAINTEXT`, `SSL`, `SASL_SSL`, etc.) and Schema Registry status badges in the cluster list items.
- Widen `ClusterConfigDialog` to an ergonomic 600 px width.
- Integrate file picker buttons into all file path text fields (Truststore, Keystore, PEM Cert/Key, Kerberos Keytab/Conf).
- Introduce a segmented selector for SSL client authentication (`None`, `Keystore`, `PEM`) so only relevant fields are rendered.
- Hide Schema Registry credentials behind progressive disclosure until a URL is entered or expanded.
- Add password visibility toggles (`Icons.visibility` / `Icons.visibility_off`) on all password inputs.
- Add a live "Test Connection" button in `ClusterConfigDialog` that invokes `KafkaMetadataService.validateConnection` and provides visual feedback.

**Non-Goals:**
- Rewriting cluster persistence storage or changing the Rust `ClusterProfile` data schema.
- Changing export/import ZIP archive format.
- Adding multi-broker latency charts or deep network diagnostics.

## Decisions

### 1. Constrained Settings Layout
- Wrap the `ListView` child in `SettingsView` in `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 960), child: ...))`.
- Pair `maxScriptRunsController` and `maxLagQueriesController` in a `Row` with `Expanded` children and 16 px spacing.
- Provide descriptive subtitle text for the global configuration import/export and the cluster import/export sections to clarify scope.

### 2. Informative Badges in Cluster List
- In `_buildClusterListContent`, update `ListTile` subtitle or trailing layout to include:
  - Security protocol badge (e.g. `Container` with rounded border and text, such as `SSL`, `SASL_SSL`, `PLAINTEXT`).
  - Schema Registry badge (e.g. `Row` with `Icons.schema` or text `Schema Registry`).

### 3. File Picker Helper Widget
- Create or use a reusable file input decoration / suffix button with `Icons.folder_open` or `Icons.attach_file`.
- When clicked, invoke `FilePicker.platform.pickFiles()`. If a file is selected, set `controller.text = result.files.single.path!`.

### 4. Segmented SSL Client Authentication Mode
- Define an enum or state variable in `ClusterConfigDialog` / `ClusterSslForm`:
  ```dart
  enum SslClientAuthMode { none, keystore, pem }
  ```
- Infer initial mode from existing cluster profile:
  - If `sslPemCertificateLocation` or `sslPemKeyLocation` is non-empty -> `SslClientAuthMode.pem`
  - Else if `sslKeystoreLocation` is non-empty -> `SslClientAuthMode.keystore`
  - Else -> `SslClientAuthMode.none`
- Render a `SegmentedButton<SslClientAuthMode>` in `ClusterSslForm`.
- If `none`: hide Keystore and PEM fields.
- If `keystore`: show Keystore location and password.
- If `pem`: show PEM certificate location, PEM key location, and PEM key password.
- Server Truststore location and password remain visible whenever SSL or SASL_SSL is active.

### 5. Password Visibility State
- Implement stateful password inputs (or local booleans) for each password field (`_obscureTruststorePassword`, `_obscureKeystorePassword`, `_obscurePemKeyPassword`, `_obscureSaslPassword`, `_obscureSchemaRegistryPassword`), toggled via `IconButton` in `InputDecoration.suffixIcon`.

### 6. Progressive Disclosure for Schema Registry Credentials
- In `ClusterBasicInfoForm`, show the username and password fields only if `schemaRegistryUrlController.text.trim().isNotEmpty` or if an expansion tile / toggle is expanded. Add a listener to `schemaRegistryUrlController` to rebuild when URL changes.

### 7. Live Broker Connection Test
- In `ClusterConfigDialog`, add a "Test Connection" button in the `AlertDialog.actions` (left-aligned) or inside the form.
- When clicked:
  1. Trigger form validation (`_formKey.currentState!.validate()`).
  2. Assemble a temporary `ClusterProfile` from the current controllers and settings.
  3. Set `_isTestingConnection = true` and `_testConnectionResult = null`.
  4. Call `getIt<KafkaMetadataService>().validateConnection(profile: candidateProfile)`.
  5. If true: display a green success banner / indicator ("Connection successful").
  6. If false or error thrown: display a red warning banner with error details.

## Risks / Trade-offs

- **File Picker on Linux/macOS/Windows**: `FilePicker.platform.pickFiles()` requires native desktop permissions and dialog plugins. Kafkalyzer already uses `file_picker` in `SettingsView` and `ScriptRunDetailsView` successfully, so desktop platform integration is established.
- **Connection Test Timeout**: If a user enters an invalid IP or port with long TCP timeout, `validateConnection` could take several seconds. Showing a prominent `CircularProgressIndicator` and disabling the test button while pending prevents duplicate requests and clarifies state.
