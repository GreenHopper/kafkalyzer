# Proposal: Ergonomic Settings & Guided Cluster Onboarding

## Why

In `SettingsView` and `ClusterConfigDialog`, configuring clusters and navigating general application settings currently imposes heavy friction and cognitive load on users:
1. **Unbounded Layout & Duplicated Import/Export**: In `SettingsView`, text fields stretch across full ultrawide displays (1800+ px), and two competing import/export button rows (global app configuration backup vs. cluster-specific ZIP export) appear stacked with ambiguous labeling.
2. **Missing Metadata in Cluster List**: In the settings cluster list, items display only cluster name and bootstrap servers, omitting security protocols (`SSL`, `SASL_SSL`, `PLAINTEXT`) or Schema Registry readiness indicators.
3. **Painful Certificate & Auth Configuration**: In `ClusterConfigDialog` and `ClusterSslForm`, all certificate and key fields are plain text inputs requiring manual path typing or external copy-pasting, with no file pickers (`file_picker`). Both Keystore (Option A) and PEM (Option B) fields render simultaneously regardless of use, creating a long and confusing form.
4. **No Password Visibility Toggles**: Password inputs lack visibility toggle icons (`Icons.visibility` / `Icons.visibility_off`).
5. **No Connection Test Action**: Users must save blind and attempt a connection in the Explorer to discover invalid paths, bad credentials, or unreachable brokers.
6. **Eager Schema Registry Credentials**: Schema Registry username and password fields take up vertical space even when no Schema Registry URL is specified.

Streamlining these views directly implements Measure 8 of `design/ui_ux_audit_und_onboarding_konzept.md` to eliminate onboarding blockers when setting up Kafka clusters.

## What Changes

1. **Constrained & Ergonomic `SettingsView` Layout**:
   - Wrap settings content in an ergonomically constrained container (maximum width 960 px, centered).
   - Arrange numeric settings (maximum script runs and maximum concurrent lag queries) in a clean two-column grid.
   - Distinguish and clarify global app configuration backup/restore vs. cluster ZIP package export/import with clear descriptive text.
   - Enhance the cluster list items with informative badges: Security protocol (`PLAINTEXT`, `SSL`, `SASL_PLAINTEXT`, `SASL_SSL`) and Schema Registry status badge.
2. **Streamlined `ClusterConfigDialog` (Width 600 px)**:
   - Provide file picker buttons (`Icons.folder_open` / `browse`) next to all file path inputs (Truststore, Keystore, PEM Certificate, PEM Private Key, Kerberos Keytab, Kerberos Config).
   - Introduce an SSL client authentication method selector (`None`, `Keystore (PKCS12 / JKS)`, `PEM Certificate & Key`) to display only the relevant certificate and password inputs.
   - Progressive disclosure for Schema Registry credentials: show username and password fields only when a Schema Registry URL is entered or expanded.
   - Add password visibility toggles (`obscureText` toggle) on all secret fields.
   - Add a "Test Connection" (`Icons.electrical_services` / `Icons.cable`) action in the dialog footer to run a quick metadata validation against the broker, providing immediate visual feedback (success or detailed error message) before saving.

## Capabilities

### New Capabilities
- `ergonomic-settings-and-cluster-onboarding`: Provides an ergonomically constrained settings view with cluster capability badges, clear backup distinctions, file pickers for certificates, segmented client-auth selection in cluster configuration, password toggles, and live connection testing.

### Modified Capabilities
None.

## Impact

- **Frontend UI**:
  - `lib/src/features/settings/presentation/settings_view.dart`
  - `lib/src/features/cluster/presentation/widgets/config_dialog/cluster_config_dialog.dart`
  - `lib/src/features/cluster/presentation/widgets/config_dialog/cluster_basic_info_form.dart`
  - `lib/src/features/cluster/presentation/widgets/config_dialog/cluster_ssl_form.dart`
  - `lib/src/features/cluster/presentation/widgets/config_dialog/cluster_sasl_form.dart`
- **Services / Controllers**:
  - Use `KafkaMetadataService.validateConnection` to execute direct broker connectivity checks with candidate `ClusterProfile`.
- **Localization**:
  - `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` with new localized strings for client auth modes, file browsing, test connection states, and settings descriptions.
- **Dependencies**:
  - Leverages existing `file_picker` package (already in `pubspec.yaml`).
