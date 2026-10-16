# Spec Delta

## Purpose

Provides comprehensive UI localization across topic details, cluster configuration dialogs, schema viewer, message views, and json trees, along with clear discoverability for tree row actions.

## ADDED Requirements

### Requirement: Comprehensive UI Localization Across Topic, Cluster, Schema, and Message Views
All user-facing action labels, dialog headers, field labels, tooltips, validation messages, and empty states in `TopicDetailView`, `ClusterConfigDialog`, `ClusterBasicInfoForm`, `ClusterSslForm`, `ClusterSaslForm`, `SchemaViewerDialog`, and `MessagesView` SHALL be retrieved from `AppLocalizations` (`app_en.arb` and `app_de.arb`) without hardcoded English text.

#### Scenario: Rendering TopicDetailView in German locale
- **WHEN** the user opens `TopicDetailView` with locale set to `de`
- **THEN** action buttons ("Stream", "Stop", "Schema"), progress label ("Scan Progress"), and tooltips ("Clear Messages") SHALL render in German

#### Scenario: Rendering Cluster Configuration and Security Forms in German locale
- **WHEN** the user opens `ClusterConfigDialog` with locale set to `de`
- **THEN** the dialog title, footer action buttons ("Cancel", "Save" / "Add"), security protocol field, SSL form headers and labels, SASL mechanism options and credential labels, and URL validation messages SHALL render in German

#### Scenario: Rendering SchemaViewerDialog and MessagesView in German locale
- **WHEN** the user views `SchemaViewerDialog` or an empty `MessagesView` with locale set to `de`
- **THEN** the schema viewer title, navigation tooltips, error states, and empty messages placeholders SHALL render in German

---

### Requirement: Discoverable Row Actions in SmartVirtualJsonTree
`SmartVirtualJsonTree` SHALL provide clear visual affordances and localized tooltips for row actions, including an intuitive pin icon (`Icons.push_pin_outlined`) for pinning JSON paths as columns and localized feedback for value copying.

#### Scenario: Pinning a JSON path to column in SmartVirtualJsonTree
- **WHEN** the user hovers over or views a JSON row that supports column pinning
- **THEN** a clear pin icon button (`Icons.push_pin_outlined`) SHALL be displayed with a localized tooltip ("Pin as column" / "Als Spalte anheften")
- **AND** clicking the button SHALL trigger the `onPinToColumn` callback with the normalized JSON path

#### Scenario: Copying a value to clipboard
- **WHEN** the user clicks the copy icon on a JSON row
- **THEN** the value SHALL be copied to the clipboard and a localized confirmation snackbar ("Value copied to clipboard" / "Wert in die Zwischenablage kopiert") SHALL be displayed
