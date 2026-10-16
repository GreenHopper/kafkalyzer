# Design

## Context

The Kafkalyzer Flutter desktop client supports English (`en`) and German (`de`) via standard Flutter ARB translation files (`lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`). While prior ergonomic upgrades localized major navigation hubs, an audit of secondary dialogs and inspectors revealed residual hardcoded English strings:
1. `TopicDetailView`: Action buttons ("Stream", "Stop", "Schema"), scan progress indicators, and "Clear Messages" tooltip.
2. `ClusterConfigDialog` & sub-forms (`ClusterBasicInfoForm`, `ClusterSslForm`, `ClusterSaslForm`): Titles, buttons, labels for SSL/TLS, SASL mechanisms, credential fields, and URL typo validation warnings.
3. `SchemaViewerDialog`: Header title, empty state ("No Avro schema found for this topic."), match navigation tooltips, and loading error descriptions.
4. `MessagesView`: "No messages to display" empty state.
5. `SmartVirtualJsonTree`: Ambiguous `Icons.view_column_outlined` icon for column pinning, untranslated tooltips, and unlocalized snackbars.

## Goals / Non-Goals

**Goals:**
- Eliminate all hardcoded English strings across target views, providing complete German and English parity.
- Enhance the visual discoverability of JSON tree row actions by adopting `Icons.push_pin_outlined` and localized tooltips.
- Provide parameterized ARB messages for dynamic errors and counts (e.g. schema loading failures).
- Maintain 100% test pass rate with zero analyzer warnings.

**Non-Goals:**
- Localizing raw Kafka protocol values or technical protocol identifiers (e.g., `PLAINTEXT`, `SSL`, `SASL_SSL`, `SCRAM-SHA-256`, `GSSAPI`).
- Modifying backend Rust communication or domain data structures.

## Decisions

### 1. Unified ARB Key Naming and Parameterization
- New keys added to `app_en.arb` and `app_de.arb` with descriptive prefixes:
  - Cluster config: `sslConfigTitle`, `truststoreLocationLabel`, `truststorePasswordLabel`, `keystoreLocationLabel`, `keystorePasswordLabel`, `clientCertPemLocationLabel`, `clientKeyPemLocationLabel`, `clientKeyPasswordLabel`, `saslMechanismLabel`, `kerberosServiceNameLabel`, `kerberosKeytabPathLabel`, `kerberosPrincipalLabel`, `kerberosConfigPathLabel`, `schemaRegistryUrlTypoPort`, `schemaRegistryUrlMissingProtocol`.
  - Topic details: `streamAction`, `stopAction`, `schemaAction`, `scanProgressTitle`, `clearMessagesTooltip`.
  - Schema viewer: `schemaViewerTitle`, `noAvroSchemaFound`, `previousMatchTooltip`, `nextMatchTooltip`, `errorLoadingSchema`.
  - Messages and Tree: `noMessagesToDisplay`, `copyValueTooltip`, `valueCopiedToClipboard`.
- Parameterized strings (e.g. `errorLoadingSchema`) will use ICU placeholders `{error}`.

### 2. SmartVirtualJsonTree Pin Icon and Feedback Discoverability
- Replace `Icons.view_column_outlined` with `Icons.push_pin_outlined`.
- Ensure the tooltip uses `l10n?.pinAsColumn ?? 'Pin as column'`.
- Ensure the copy value tooltip uses `l10n?.copyValueTooltip ?? 'Copy value'` and the confirmation snackbar uses `l10n?.valueCopiedToClipboard ?? 'Value copied to clipboard'`.

### 3. Null-Safe Localization Handling in Presentational Widgets
- In widgets like `ClusterSaslForm` or `SmartVirtualJsonTree`, access `AppLocalizations.of(context)` with safe fallbacks (`l10n?.key ?? "Default"`) to prevent runtime null-check assertions in isolated unit tests that might not mount full localization delegates.

## Risks / Trade-offs

- **Risk**: Missing delegates in tests: If any existing widget test mounts a widget directly under `MaterialApp` without `AppLocalizations.localizationsDelegates`, missing delegates could result in null `AppLocalizations`.
  - *Mitigation*: All calls will use null-safe navigation with appropriate English fallbacks (`l10n?.field ?? "Fallback"`).
- **Risk**: Line length violations: Adding long localization getters could exceed the 120-character line length limit.
  - *Mitigation*: Run `dart format` across all modified files.
