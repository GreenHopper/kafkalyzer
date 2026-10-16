# Proposal

## Why

The UI/UX audit in `design/ui_ux_audit_und_onboarding_konzept.md` (Measure 7) identified widespread language-mixing across Kafkalyzer views where hardcoded English strings bypass Flutter's `AppLocalizations` framework (`app_de.arb` / `app_en.arb`). In views such as `TopicDetailView`, `ClusterConfigDialog`, `ClusterSslForm`, `ClusterSaslForm`, `ClusterBasicInfoForm`, `SchemaViewerDialog`, and `MessagesView`, buttons, field labels, tooltips, and empty states remain in English when users select the German locale.

Furthermore, within `SmartVirtualJsonTree`, row actions (`Copy value` and `Pin as Column`) suffer from discoverability issues: `Icons.view_column_outlined` is non-obvious to new users as a "Pin as Column" action, and tooltips and feedback snackbars use untranslated English strings. Resolving these issues completes full German/English localization and makes JSON inspection actions immediately discoverable and self-explanatory.

## What Changes

1. **Complete UI Localization**:
   - Add localized translation keys in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` covering all remaining unlocalized strings.
   - Replace hardcoded English strings in:
     - `TopicDetailView`: "Schema", "Scan Progress", "Stream", "Stop", "Clear Messages".
     - `ClusterConfigDialog`, `ClusterBasicInfoForm`, `ClusterSslForm`, `ClusterSaslForm`: "Security Protocol", "Cancel", "Add", "Save", SSL labels ("SSL Configuration", "Truststore Location (PEM or JKS)", "Truststore Password", keystore and PEM certificate/key paths), SASL labels ("SASL Mechanism", Kerberos fields, OAuthbearer, SASL credentials), and validation messages.
     - `SchemaViewerDialog`: "Schema Viewer", "No Avro schema found for this topic.", "Previous match", "Next match", "Error loading schema: {error}".
     - `MessagesView`: "No messages to display".
     - `SmartVirtualJsonTree`: "Copy value", "Value copied to clipboard", "Empty JSON", "Pin as column".
2. **Discoverability in JSON Tree Inspector (`SmartVirtualJsonTree`)**:
   - Replace the ambiguous `Icons.view_column_outlined` icon with an intuitive pin icon (`Icons.push_pin_outlined`) or dedicated visual affordance.
   - Ensure the tooltip clearly reads "Pin as column" / "Als Spalte anheften" via `AppLocalizations`.
   - Ensure copy action tooltip and snackbar feedback ("Value copied to clipboard" / "Wert in die Zwischenablage kopiert") are fully localized.

## Capabilities

### New Capabilities
- `complete-ui-localization-and-discoverability`: Provides comprehensive German/English UI localization across all remaining dialogs, inspector views, and forms, and improves discoverability of JSON tree row actions.

### Modified Capabilities
<!-- None -->

## Impact

- **Affected Files**:
  - `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`
  - `lib/src/features/topic/topic_detail_view.dart`
  - `lib/src/features/cluster/presentation/widgets/config_dialog/cluster_config_dialog.dart`
  - `lib/src/features/cluster/presentation/widgets/config_dialog/cluster_basic_info_form.dart`
  - `lib/src/features/cluster/presentation/widgets/config_dialog/cluster_ssl_form.dart`
  - `lib/src/features/cluster/presentation/widgets/config_dialog/cluster_sasl_form.dart`
  - `lib/src/features/schema/presentation/widgets/schema_viewer_dialog.dart`
  - `lib/src/ui/messages/messages_view.dart`
  - `lib/src/ui/smart_tree/smart_virtual_json_tree.dart`
- **Tests**: Existing widget tests across topic, cluster config, schema, and smart tree will be updated and extended to verify German and English rendering without regressions.
